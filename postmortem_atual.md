# Postmortem — Race Condition na Inicialização do kube-news e Exposição de Credenciais

**Data do incidente:** 2026-05-16  
**Severidade:** Médio (impacto operacional imediato + risco de segurança latente)  
**Status:** Parcialmente resolvido — kube-news estabilizou após restarts; correções estruturais pendentes  
**Autor:** Davis Victor / Claude Sonnet 4.6

---

## Resumo Executivo

O pod `kube-news` falhou 2 vezes logo após o deploy devido a uma race condition: a aplicação Node.js tentou conectar ao PostgreSQL antes de ele estar pronto para aceitar conexões, resultando em `ECONNREFUSED`. O pod se recuperou automaticamente após o PostgreSQL inicializar, mas a ausência de `initContainers` torna esse comportamento não determinístico. Paralelamente, a auditoria revelou credenciais em texto plano nos manifests de deployment e ausência de PersistentVolumeClaim no banco de dados — riscos de segurança e perda de dados que demandam ação imediata.

---

## Linha do Tempo

| Hora (UTC) | Evento |
|-----------|--------|
| 20:01:12 | Cluster kind criado — `desktop-control-plane` pronto |
| 20:01:26 | Workers `desktop-worker` e `desktop-worker2` joinam o cluster |
| 21:56:26 | Pods anteriores (`kube-news-5ff99b7dfc-5nprp`, `postgres-85df697448-gzbtw`) encerrados (Killing) |
| 21:59:19 | Novo deploy aplicado — pods `kube-news` e `postgres` agendados simultaneamente |
| 21:59:19 | `postgres` agendado em `desktop-worker2`; imagem `postgres:15-alpine` já presente (sem pull) |
| 21:59:19 | `kube-news` agendado em `desktop-worker`; iniciando pull da imagem `kube-news:1.0.0` |
| 21:59:20 | `kube-news:1.0.0` pulled em 979ms; container inicia e tenta conectar ao postgres |
| 21:59:20 | **1º crash** — `ECONNREFUSED 10.96.184.193:5432` (postgres ainda inicializando) |
| 21:59:22 | BackOff iniciado — Kubernetes aguarda antes de reiniciar |
| 21:59:22–29 | 3 eventos de `BackOff` registrados |
| 21:59:44 | **2º restart** — `kube-news` reiniciado, tenta conexão novamente |
| 21:59:44 | PostgreSQL já pronto — conexão aceita; `kube-news` estabiliza |
| 22:01:12 | Estado atual: 2 restarts registrados, ambos pods `Running` e estáveis |
| 22:01:40 | Auditoria MCP coletou estado completo do cluster |

---

## Causa Raiz

### Race condition na ordem de inicialização

Kubernetes não garante ordem de inicialização entre pods distintos. Quando o deployment foi aplicado, ambos os pods (`kube-news` e `postgres`) foram agendados ao mesmo tempo (21:59:19).

```
Linha do tempo de cada pod:

postgres:
  21:59:19 → agendado
  21:59:19 → imagem já presente (sem pull)
  21:59:19 → container iniciado
  ~21:59:30 → PostgreSQL pronto para conexões (pg_isready OK)

kube-news:
  21:59:19 → agendado
  21:59:19-20 → pull da imagem (979ms)
  21:59:20 → container iniciado → conecta 10.96.184.193:5432
  21:59:20 → ECONNREFUSED (postgres ainda nos 10s de delay da startup probe)
  21:59:20 → CRASH
```

O `postgres` tinha sua `startupProbe` configurada com `delay=5s, period=6s, failure=10` — ou seja, até 65 segundos para considerar pronto. O `kube-news`, ao iniciar, não aguarda o postgres: a aplicação Node.js conecta ao banco imediatamente na inicialização, sem retry automático de conexão.

**Por que não foi mitigado pelo `startupProbe` do kube-news?** O `startupProbe` do kube-news aponta para `/health` no próprio pod — não verifica dependências externas. Se a aplicação trava no startup ao tentar conectar ao banco, o probe sequer chega a ser executado.

### Credenciais em texto plano

As senhas do banco de dados estão hardcoded diretamente nas variáveis de ambiente dos deployments:

```yaml
# No deployment kube-news
- name: DB_PASSWORD
  value: "Pg#123"

# No deployment postgres
- name: POSTGRES_PASSWORD
  value: "Pg#123"
```

Qualquer pessoa com acesso a `kubectl describe deployment` ou ao repositório git onde os manifests estão versionados tem acesso às credenciais. Kubernetes Secrets é o mecanismo correto para isso.

### PostgreSQL sem PersistentVolumeClaim

O pod `postgres-78ccf76d95-45z9s` não tem volume persistente montado. Os dados ficam no filesystem efêmero do container (`/var/lib/postgresql/data`). Qualquer restart do pod — seja por OOM, por falha de liveness probe, por redeploy ou por falha do nó — resulta em **perda total dos dados**.

---

## Impacto

| Dimensão | Impacto |
|---------|---------|
| Operacional | `kube-news` indisponível por ~24 segundos durante startup (2 restarts automáticos) |
| Em aplicações | Requests ao `kube-news` durante o período de BackOff seriam recusados com connection refused |
| Em dados | Nenhum no incidente — mas **risco permanente** de perda de dados do postgres a qualquer restart |
| Segurança | Credenciais expostas em manifests versionáveis e visíveis via `kubectl describe` |
| Observabilidade | `kubectl top` indisponível — impossível correlacionar restarts com picos de CPU/memória |

---

## Resolução

### O que o Kubernetes resolveu automaticamente

O mecanismo de restart automático do Kubernetes (`restartPolicy: Always` implícito) reiniciou o `kube-news` até que o `postgres` estivesse pronto. Isso funcionou porque o `postgres` foi agendado no mesmo momento e só levou ~10-20s para estar operacional — dentro da janela de espera do BackOff.

**Atenção:** Em cenários onde o postgres demora mais (cold start sem imagem cacheada, volume grande de dados), o BackOff poderia escalonar (10s → 20s → 40s → ... → 5 minutos) e o `kube-news` poderia ficar em `CrashLoopBackOff` por longos períodos.

### Correções pendentes (ainda não aplicadas)

| Correção | Arquivo a modificar | Tipo |
|---------|---------------------|------|
| Adicionar `initContainer` wait-for-postgres | `k8s/deployment-kube-news.yaml` | Estrutural |
| Migrar senhas para `Secret` | Novo `k8s/secret.yaml` + ambos deployments | Segurança |
| Adicionar PVC ao postgres | Novo `k8s/pvc-postgres.yaml` + deployment postgres | Dados |
| Instalar Ingress NGINX | `kubectl apply` manifesto oficial kind | Infraestrutura |
| Instalar Metrics Server | `kubectl apply` manifesto oficial | Observabilidade |

---

## O Que Aprendemos

### Técnico

1. **Kubernetes não garante ordem de inicialização entre pods** — a única forma correta de garantir que um pod espere por outro é usando `initContainers`. `depends_on` existe apenas em docker-compose.

2. **Startup probe não substitui dependency check** — o `startupProbe` verifica se o container próprio está saudável, não se suas dependências externas estão prontas. Para dependências externas, use `initContainers`.

3. **BackOff exponencial pode mascarar o problema** — a aplicação pareceu "resolver sozinha", mas o mecanismo que a salvou (BackOff + retry automático) tem limites. Em deploys de produção com cold start mais lento, o comportamento seria muito pior.

4. **Ausência de PVC em bancos de dados é perda de dados garantida** — não é uma questão de "se vai perder", mas de "quando". Qualquer operação de manutenção que reinicie o pod (OOMKill, upgrade de versão, falha de liveness) apaga os dados.

5. **Credentials em plaintext sobrevivem ao git history** — uma vez que a senha entra em um commit, ela fica na história do repositório mesmo depois de removida. O correto é nunca versionar senhas, usando Secrets desde o início.

6. **Metrics Server não é instalado por padrão em kind** — ao contrário do Docker Desktop com Kubernetes, kind exige instalação manual. Sem Metrics Server, HPA baseado em CPU também não funciona.

### Processo

1. **Auditorias periódicas de cluster revelam dívida técnica acumulada** — sem o ciclo de diagnóstico desta sessão, as issues de credenciais e PVC poderiam passar desapercebidas até um incidente grave.

2. **O canal MCP deve ser validado antes de qualquer operação** — o histórico deste projeto mostra problemas de `127.0.0.1` vs `host.docker.internal`. Validar conectividade MCP como primeiro passo evita diagnósticos incorretos baseados em dados ausentes.

3. **Events do Kubernetes são o primeiro lugar a olhar após restarts** — `kubectl get events --sort-by=lastTimestamp` revelou toda a sequência de falhas em ordem cronológica, mais rápido que logs dos pods.

---

## Ações Preventivas

| Ação | Responsável | Prazo | Prioridade |
|------|------------|-------|-----------|
| Criar `k8s/secret.yaml` e remover senhas dos deployments | Davis Victor | Imediato | 🔴 Alta |
| Criar `k8s/pvc-postgres.yaml` e montar volume no postgres | Davis Victor | Imediato | 🔴 Alta |
| Adicionar `initContainer` wait-for-postgres ao kube-news | Davis Victor | Esta semana | ⚠️ Média |
| Instalar Ingress NGINX Controller no cluster | Davis Victor | Esta semana | ⚠️ Média |
| Instalar Metrics Server | Davis Victor | Esta semana | ⚠️ Média |
| Adicionar step de `kubectl get events` ao runbook de deploy | Davis Victor | Este mês | ℹ️ Baixa |
| Avaliar uso de `helm` para gerenciar os manifests | Davis Victor | Este mês | ℹ️ Baixa |

---

## Referências

| Artefato | Localização |
|---------|------------|
| Relatório completo do cluster | `relatorio_atual.md` |
| Diagramas Mermaid da arquitetura | `diagrama-palestra.md` |
| Documentação initContainers | https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ |
| Documentação Secrets | https://kubernetes.io/docs/concepts/configuration/secret/ |
| Documentação PVC | https://kubernetes.io/docs/concepts/storage/persistent-volumes/ |
| Ingress NGINX para kind | https://kind.sigs.k8s.io/docs/user/ingress/ |
