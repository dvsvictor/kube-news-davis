# CLAUDE.md — Kube-News

Guia de operação para o Claude Code neste repositório. Leia antes de qualquer ação.

---

## Identidade do projeto

| Item | Valor |
|------|-------|
| App | Node.js 18 Alpine — `node:18-alpine` |
| Banco | PostgreSQL 15 Alpine — `postgres:15-alpine` |
| Porta da app | **8080** (definida em `server.js` e no `Dockerfile`) |
| Usuário no container | `appuser` (não-root) |
| Cluster local | Docker Desktop — contexto `docker-desktop` |
| Acesso local | `http://localhost:8080` via `kubectl port-forward` |

---

## Regras de git — NÃO negociáveis

**Nunca faça commit ou push diretamente em `main`.** Toda mudança vai em branch, abre PR, e só mergeia após revisão.

```bash
# Fluxo obrigatório
git checkout -b feat/minha-feature   # sempre a partir de main atualizado
# ... trabalhar ...
git push origin feat/minha-feature
# Abrir PR via GitHub — nunca git push origin main
```

Convenção de nomes de branch:

| Tipo | Prefixo | Exemplo |
|------|---------|---------|
| Nova funcionalidade | `feat/` | `feat/add-ingress` |
| Correção de bug | `fix/` | `fix/probe-timeout` |
| Infraestrutura / K8s | `infra/` | `infra/pvc-postgres` |
| Documentação | `docs/` | `docs/update-readme` |
| Skill / automação | `skill/` | `skill/chaos-testing` |

**Outras regras:**
- Nunca use `git push --force` em branches compartilhadas
- Nunca pule hooks com `--no-verify`
- Sempre confira `git status` antes de commitar
- Mensagens de commit em português, no imperativo ("Adicionar", "Corrigir", "Atualizar")
- Inclua sempre `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` em commits gerados pelo Claude

---

## Skills disponíveis — use antes de agir

Antes de criar qualquer infraestrutura, manifesto, Dockerfile ou script, ative a skill correspondente. Elas contêm decisões já tomadas e erros já corrigidos.

| Skill | Quando ativar |
|-------|--------------|
| `project-directives` | **Ponto de partida obrigatório** para criar ou revisar qualquer manifesto Kubernetes, Dockerfile, ou configuração de acesso local |
| `docker-devops` | Containers, docker-compose, build de imagem, CI/CD, troubleshoot de ambiente local |
| `postgres-k8s` | Acesso ao PostgreSQL no cluster, queries, Secrets, logs, conectividade app↔banco |
| `claude_devops_1605` | Diagnóstico completo do cluster: relatório, diagramas Mermaid, postmortem |
| `gerar-diagrama` | Gerar ou atualizar diagramas Mermaid de arquitetura |
| `git-commit-guard` | **Ativar a cada commit** — verifica branch, nome, arquivos sensíveis, compõe mensagem em pt-BR no imperativo e inclui Co-Authored-By |

Para ativar uma skill, use a ferramenta `Skill` antes de responder à tarefa.

---

## Estrutura do repositório

```
/
├── src/                    # Código-fonte da aplicação
│   ├── server.js           # Entrypoint — porta 8080
│   ├── system-life.js      # Endpoints /health, /ready, /metrics, chaos
│   ├── models/post.js      # Modelo Sequelize (tabela Posts)
│   ├── views/              # Templates EJS
│   ├── static/             # CSS e imagens
│   ├── Dockerfile          # Imagem de produção (non-root, Alpine)
│   └── package.json
├── k8s/
│   └── deploy.yaml         # Manifestos Kubernetes (Deployment + Service)
├── .claude/
│   ├── settings.json       # Permissões do Claude Code
│   └── skills/             # Skills do projeto (não editar manualmente)
├── docker-compose.yml      # Ambiente de desenvolvimento com hot-reload
├── popula-dados.http       # Requisições para popular o banco
└── CLAUDE.md               # Este arquivo
```

---

## Variáveis de ambiente

| Variável | Valor no cluster | Observação |
|----------|-----------------|------------|
| `DB_HOST` | `postgres` | Nome do Service K8s |
| `DB_PORT` | `5432` | |
| `DB_DATABASE` | `kubedevnews` | |
| `DB_USERNAME` | `kubedevnews` | |
| `DB_PASSWORD` | `Pg#123` | Mover para Secret antes de produção |
| `DB_SSL_REQUIRE` | `false` | |

---

## Padrões de manifesto Kubernetes

Regras que se aplicam a **todo** manifesto gerado neste projeto:

- **Sem `:latest`** — sempre tag versionada (`1.0.0`) ou SHA
- **`imagePullPolicy: IfNotPresent`** — imagens buildadas localmente no Docker Desktop
- **Labels obrigatórios** em todo recurso: `app: kube-news` + `component: <nome>`
- **Portas nomeadas** — usar `name: http` e referenciar via `targetPort: http`
- **Service padrão: `ClusterIP`** — NodePort e LoadBalancer não funcionam no kind via Docker Desktop (rede isolada `172.18.0.x`)
- **Ordem no arquivo:** dependências primeiro (postgres), aplicação por último
- **Probes obrigatórias:** `startupProbe` + `readinessProbe` + `livenessProbe` em todos os pods

### Endpoints de probe

| Probe | App (Node.js) | Banco (PostgreSQL) |
|-------|--------------|-------------------|
| startup | `GET /health` — failureThreshold: 12 (120s) | `pg_isready` — failureThreshold: 10 (60s) |
| readiness | `GET /ready` | `pg_isready` |
| liveness | `GET /health` | `pg_isready` |

Checklist antes de entregar qualquer manifesto:

- [ ] Imagem com tag versionada (sem `:latest`)
- [ ] `imagePullPolicy: IfNotPresent` na app
- [ ] Labels `app` e `component` consistentes em Deployment e Service
- [ ] Portas nomeadas e `targetPort` referenciando o nome
- [ ] `startupProbe` configurada na app
- [ ] Service tipo `ClusterIP`
- [ ] `DB_PASSWORD` com comentário `# ⚠️ mover para Secret`
- [ ] Ordem: postgres → kube-news

---

## Acesso local ao cluster

O cluster kind usa rede Docker interna (`172.18.0.x`) — inacessível diretamente do macOS. A solução é `kubectl port-forward` mantido pelo launchd:

```bash
# Verificar status
launchctl list | grep kube-news

# Controlar o agente
launchctl load   ~/Library/LaunchAgents/dev.kube-news.portforward.plist
launchctl unload ~/Library/LaunchAgents/dev.kube-news.portforward.plist

# Ver log
tail -f /tmp/kube-news-portforward.log
```

Acesso: **http://localhost:8080**

---

## Boas práticas gerais

### Código
- Não adicione comentários que explicam o **que** o código faz — use nomes descritivos
- Só adicione comentário quando o **porquê** for não-óbvio (workaround, invariante oculta)
- Não adicione tratamento de erro para cenários impossíveis
- Não crie abstrações antecipadas — três linhas repetidas é melhor que uma abstração prematura
- Não adicione features além do que foi pedido

### Segurança
- Nunca commite credenciais, tokens ou `.env` com dados reais
- Credenciais no `k8s/deploy.yaml` devem ter comentário `# ⚠️ mover para Secret`
- Evite command injection ao montar comandos com input do usuário
- Usuário no container deve ser `appuser` (não-root) — nunca altere isso

### Kubernetes
- Não use `kubectl delete` sem confirmar com o usuário primeiro
- Não faça `kubectl apply` em produção sem revisão do diff
- Antes de qualquer operação destrutiva no cluster, informe o usuário e aguarde confirmação
- Ao diagnosticar o cluster, use as ferramentas MCP (`mcp__MCP_DOCKER__*`) — não Bash com kubectl

### Docker
- Nunca use `docker system prune` sem confirmação explícita
- Imagens de produção sempre baseadas em Alpine — sem `node:18` genérico
- Build sempre a partir de `./src` — `docker build -t kube-news:1.0.0 ./src`

---

## CI/CD — GitHub Actions

Pipeline em `.github/workflows/ci-cd.yml` com 3 jobs em sequência:

```
[build-push] → [smoke-test] → [deploy]
     ↑               ↑              ↑
   PR + push       PR + push    push main
                                (self-hosted)
```

| Job | Runner | Quando roda | O que faz |
|-----|--------|------------|-----------|
| `build-push` | `ubuntu-latest` | Todo PR e push em `main` | Build + push para Docker Hub com tag SHA |
| `smoke-test` | `ubuntu-latest` | Todo PR e push em `main` | `docker compose up` + curl no `/health` |
| `deploy` | `self-hosted` | Apenas push em `main` | `kubectl apply` + aguarda rollout |

### Secrets obrigatórios no repositório GitHub

| Secret | Como obter |
|--------|-----------|
| `DOCKER_USERNAME` | Login do Docker Hub |
| `DOCKER_PASSWORD` | Docker Hub → Security → New Access Token |
| `KUBECONFIG_B64` | `cat ~/.kube/config \| base64` |

### Self-hosted runner (deploy local)

O job `deploy` precisa de um runner na mesma máquina que o cluster:

```bash
# GitHub → Settings → Actions → Runners → New self-hosted runner → macOS
mkdir ~/actions-runner && cd ~/actions-runner
# Seguir comandos exibidos pelo GitHub (download + configure)
./run.sh   # ou: ./svc.sh install && ./svc.sh start
```

### Estratégia de tags de imagem

| Evento | Tags geradas |
|--------|-------------|
| Push para `main` | `dvsvictor/kube-news:<sha7>`, `dvsvictor/kube-news:main` |
| Pull Request | `dvsvictor/kube-news:<sha7>` |

---

## Infraestrutura Kubernetes — arquivos

| Arquivo | Descrição | Aplicar antes de |
|---------|-----------|-----------------|
| `k8s/namespace.yaml` | Namespace `kube-news` | Todos os outros |
| `k8s/secrets.yaml` | Secret `postgres-secret` com senha em base64 | `deploy.yaml` |
| `k8s/pvc.yaml` | PVC `postgres-pvc` (1Gi) para dados do PostgreSQL | `deploy.yaml` |
| `k8s/deploy.yaml` | Deployments e Services (usa Secret e PVC) | `ingress.yaml` |
| `k8s/ingress.yaml` | Ingress com host `kube-news.local` | — |

**Instalar NGINX Ingress Controller (uma vez):**

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
```

**Adicionar ao `/etc/hosts` para acesso local:**

```bash
echo "127.0.0.1 kube-news.local" | sudo tee -a /etc/hosts
```

**Aplicar tudo em ordem:**

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/deploy.yaml
kubectl apply -f k8s/ingress.yaml
```

---

## Comandos frequentes

```bash
# Ambiente local
docker compose up -d                          # subir app + banco com hot-reload
docker compose logs -f app                    # acompanhar logs
docker compose down                           # parar (mantém dados)
docker compose down -v                        # parar e apagar dados

# Build de imagem
docker build -t kube-news:1.0.0 ./src

# Kubernetes
kubectl apply -f k8s/deploy.yaml
kubectl get pods -l app=kube-news
kubectl get services -l app=kube-news
kubectl logs -l app=kube-news,component=app --follow
kubectl rollout restart deployment/kube-news

# Popular banco
curl -s -X POST http://localhost:8080/api/post \
  -H "Content-Type: application/json" \
  -d @popula-dados.http

# Chaos engineering
curl -X PUT http://localhost:8080/unhealth
curl -X PUT http://localhost:8080/unreadyfor/30
```

---

## Erros conhecidos e soluções

| Erro | Causa | Solução |
|------|-------|---------|
| `InvalidImageName` | Nome com `<>` no manifesto | Substituir por tag real: `kube-news:1.0.0` |
| `ErrImagePull` / `ImagePullBackOff` | Download interrompido | `docker pull <imagem>` + `kubectl rollout restart deployment/<nome>` |
| `CrashLoopBackOff` (app) | Banco não estava pronto | Aumentar `failureThreshold` da startupProbe |
| `ENDPOINTS <none>` no Service | Selector não bate com labels | Conferir labels do Deployment vs selector do Service |
| `connection refused` no MCP | `127.0.0.1` não funciona dentro do container Docker | Editar `~/.kube/config-mcp`: trocar `127.0.0.1` por `host.docker.internal` |
| `password authentication failed` | Secret desatualizado ou env errada | `kubectl exec deployment/kube-news -- env \| grep DB_` |
| Port-forward cai | `&` simples sem nohup não persiste | Usar agente launchd |

---

## Artefatos gerados pelo Claude

O Claude pode gerar e atualizar os seguintes arquivos neste repositório:

| Arquivo | Skill | Descrição |
|---------|-------|-----------|
| `relatorio_atual.md` | `claude_devops_1605` | Inventário e saúde atual do cluster |
| `diagrama-palestra.md` | `claude_devops_1605` / `gerar-diagrama` | Diagramas Mermaid da arquitetura |
| `postmortem_atual.md` | `claude_devops_1605` | Postmortem do incidente mais recente |

Esses arquivos são sobrescritos a cada execução das skills — não edite manualmente.
