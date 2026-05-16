---
name: k8s-postmortem
description: >
  Use esta skill SEMPRE que o usuário pedir para diagnosticar, auditar, inspecionar ou gerar relatório
  de um cluster Kubernetes local (Docker Desktop, kind, minikube). Ative também quando o usuário
  mencionar "postmortem", "relatório do cluster", "o que tem rodando no kubernetes", "diagrama da
  arquitetura k8s", "problema no MCP com kubernetes", "config-mcp não conecta", "connection refused
  no kubectl", "gerar relatório do cluster", "auditar o cluster", "o que está errado no cluster",
  "saúde do kubernetes", ou qualquer variante. Esta skill cobre o ciclo completo: corrige
  conectividade MCP → coleta dados reais → gera relatorio_atual.md → gera diagrama-palestra.md →
  gera postmortem_atual.md. Use mesmo que o usuário não mencione todos os artefatos — se ele quer
  saber "o que tem no cluster", execute o ciclo completo.
version: 1.0.0
---

# Skill: k8s-postmortem

Ciclo completo de diagnóstico, documentação e aprendizado para clusters Kubernetes locais.

## O que esta skill faz

1. **Verifica e corrige** a conectividade do MCP Docker com o cluster
2. **Coleta dados reais** do cluster via ferramentas MCP kubectl (nunca via Bash)
3. **Gera `relatorio_atual.md`** com inventário, pods, apps, saúde e sugestões
4. **Gera `diagrama-palestra.md`** com diagramas Mermaid da arquitetura
5. **Gera `postmortem_atual.md`** com causa raiz, linha do tempo, aprendizados e ações preventivas
6. **Commita e envia** os três arquivos ao repositório git

---

## Fase 1 — Diagnóstico de Conectividade MCP

Antes de qualquer coleta de dados, valide que o MCP consegue falar com o cluster.

### 1.1 Carregar as ferramentas MCP necessárias

Use `ToolSearch` para carregar em um único chamado:
```
select:mcp__MCP_DOCKER__kubectl_get,mcp__MCP_DOCKER__kubectl_describe,
mcp__MCP_DOCKER__kubectl_generic,mcp__MCP_DOCKER__kubectl_context,
mcp__MCP_DOCKER__kubectl_logs,mcp__MCP_DOCKER__ping
```

### 1.2 Testar a conectividade

Execute `mcp__MCP_DOCKER__kubectl_get` com `resourceType: nodes`. Se retornar nós → vá para Fase 2.

Se retornar `connection refused`, execute o diagnóstico abaixo.

### 1.3 Diagnóstico e correção de "connection refused"

**Por que isso acontece:** O MCP Docker Gateway executa `kubectl` dentro de um container Docker. `127.0.0.1` dentro do container aponta para o próprio container, não para o host. O endereço correto é `host.docker.internal`.

**Passos de correção:**

```
Host macOS
  └── kubectl → 127.0.0.1:PORTA  ✅ (loopback do host = API do K8s)

Container Docker (MCP Gateway)
  └── kubectl → 127.0.0.1:PORTA  ❌ (loopback do container = nada)
  └── kubectl → host.docker.internal:PORTA  ✅
```

1. Verificar o arquivo de config do MCP:
   ```bash
   cat ~/.docker/mcp/config.yaml
   ```
   Localizar o campo `kubernetes.config_path` — geralmente `~/.kube/config-mcp`.

2. Verificar o endereço atual:
   ```bash
   grep server ~/.kube/config-mcp
   ```

3. Se contiver `127.0.0.1`, fazer backup e corrigir:
   ```bash
   cp ~/.kube/config-mcp ~/.kube/config-mcp.bak
   ```
   Editar `~/.kube/config-mcp`: substituir `certificate-authority-data` + `server: https://127.0.0.1:PORTA` por:
   ```yaml
   insecure-skip-tls-verify: true
   server: https://host.docker.internal:PORTA
   ```
   > `insecure-skip-tls-verify` é necessário porque o certificado TLS foi emitido para `127.0.0.1` como SAN, não para `host.docker.internal`. Em ambiente de desenvolvimento local isso é aceitável.

4. Retestar `mcp__MCP_DOCKER__kubectl_get nodes`. Se ainda falhar, verificar se o Docker Desktop está rodando e se o Kubernetes está habilitado em Settings → Kubernetes.

---

## Fase 2 — Coleta de Dados via MCP

**Regra fundamental:** use APENAS ferramentas MCP para coletar dados do cluster. Não use Bash com kubectl diretamente — o objetivo é validar e exercitar o canal MCP.

Execute todas as coletas em paralelo para eficiência:

### Coleta paralela (Lote 1)
```
kubectl_context  → operation: get, detailed: true
kubectl_get      → resourceType: nodes, output: json
kubectl_get      → resourceType: pods, allNamespaces: true, output: wide
kubectl_get      → resourceType: namespaces, output: json
```

### Coleta paralela (Lote 2 — após confirmar conectividade)
```
kubectl_describe → nodes (um por um, em paralelo)
kubectl_get      → deployments, allNamespaces: true, output: json
kubectl_get      → services, allNamespaces: true, output: wide
kubectl_get      → ingress, allNamespaces: true, output: json
kubectl_get      → persistentvolumeclaims, allNamespaces: true
kubectl_get      → events, allNamespaces: true, sortBy: lastTimestamp
```

### Coleta paralela (Lote 3 — detalhes de aplicações)
```
kubectl_describe → deployment kube-news (namespace: default)
kubectl_describe → deployment postgres (namespace: default)
kubectl_generic  → command: top, resourceType: nodes  (pode falhar se Metrics Server ausente)
```

Registre todos os erros — eles são dados relevantes para o relatório e postmortem.

---

## Fase 3 — Geração do `relatorio_atual.md`

Com os dados coletados, gere o relatório com as seguintes seções obrigatórias. Sempre use dados reais da coleta — nunca invente valores.

```markdown
# Relatório do Cluster Kubernetes
**Data:** <DATA> — **Cluster:** <NOME> — **Versão K8s:** <VERSÃO>

## 1. Inventário de Hardware
Tabela: Nó | Papel | IP | CPU | Memória | Armazenamento | OS | Container Runtime

## 2. Pods em Execução
Total: N pods — N Running / N Failed
Subtabelas por namespace: default, kube-system, outros

## 3. Aplicações em Execução
Para cada aplicação: imagem, réplicas, porta, service, recursos, acesso externo, probes

## 4. Status de Saúde do Cluster e Aplicações
Tabela de nós (condições), tabela de deployments
Tabela de alertas: Severidade (🔴/⚠️/ℹ️) | Componente | Problema detectado

## 5. Sugestões de Melhorias
Prioridade Alta / Média / Baixa com YAMLs de exemplo

## Apêndice — Correções Aplicadas Nesta Sessão
Se alguma correção foi feita (ex: config-mcp), documentar aqui.
```

**Alertas comuns a verificar sempre:**
- Pod restarts > 0 → investigar causa
- Sem PersistentVolumeClaim em bancos de dados → risco de perda de dados
- Sem Ingress Controller / recursos Ingress → acesso externo frágil
- Credenciais em texto plano nos manifests → usar Secrets
- Nós ociosos → ausência de workloads distribuídos
- Metrics Server ausente → `kubectl top` inoperante
- `desktop-worker` sem cargas de aplicação → má distribuição

---

## Fase 4 — Geração do `diagrama-palestra.md`

Gere **6 diagramas Mermaid** a partir dos dados do relatório. Sobrescreva o arquivo se já existir.

### Diagrama 1 — Arquitetura Geral (`flowchart TD`)
Mostrar: host macOS → VM Docker Desktop → subgraphs por nó → namespaces → pods com IPs.
Destacar visualmente pods com problemas (restarts, sem PVC).

### Diagrama 2 — Fluxo de Acesso: Atual vs. Ideal (`flowchart LR`)
Lado esquerdo: acesso atual (port-forward manual, marcado como 🔴).
Lado direito: acesso ideal (Ingress NGINX + Ingress resource, marcado como ✅).

### Diagrama 3 — Distribuição de Pods por Nó (`flowchart TD`)
Subgraph por nó mostrando todos os pods. Destacar nós ociosos com ⚠️.

### Diagrama 4 — Mapa de Saúde (`flowchart TD`)
Árvore partindo do cluster: ramos ✅ (ok), ⚠️ (atenção), 🔴 (crítico).

### Diagrama 5 — Prioridade de Melhorias (`quadrantChart`)
Eixo X: urgência (baixa→alta). Eixo Y: impacto (baixo→alto).
Plotar cada sugestão do relatório com coordenadas coerentes.

### Diagrama 6 — Sequência de Inicialização (`sequenceDiagram`)
Mostrar ordem de startup dos pods e qualquer falha de probe.
Se houve restarts de kube-news aguardando postgres → representar o ciclo de falha e recuperação.

---

## Fase 5 — Geração do `postmortem_atual.md`

O postmortem deve documentar **o que foi encontrado e corrigido nesta sessão específica**, não apenas teoria. Estrutura obrigatória:

```markdown
# Postmortem — <TÍTULO DO INCIDENTE>

**Data do incidente:** <DATA>
**Severidade:** <Alto/Médio/Baixo>
**Status:** Resolvido / Em acompanhamento
**Autor:** <NOME> / Claude Sonnet 4.6

## Resumo Executivo
2-3 frases: o que falhou, causa raiz em uma linha, como foi resolvido.

## Linha do Tempo
Tabela: Hora | Evento (usar timestamps reais da sessão quando possível)

## Causa Raiz
Explicação técnica detalhada do porquê o problema ocorreu.
Incluir diagramas ASCII ou comparações de comportamento quando útil.

## Impacto
Operacional, em aplicações, em dados, duração estimada do bloqueio.

## Resolução
Mudança exata aplicada (diff, comando, arquivo editado).
Justificativa de cada decisão tomada.
Onde está o backup, se aplicável.

## O Que Aprendemos
Subseções: Técnico (numerado) e Processo (numerado).
Cada aprendizado deve ser acionável e generalizável — não apenas "isso aconteceu".

## Ações Preventivas
Tabela: Ação | Responsável | Prazo

## Referências
Arquivos modificados, backups, documentação relevante.
```

**Princípio do postmortem:** o documento deve ser útil para alguém que não estava presente na sessão. Explique o *porquê* de cada decisão, não apenas o *o quê*.

---

## Fase 6 — Commit e Push

Após gerar os três arquivos, commitar e enviar ao repositório:

```bash
git add relatorio_atual.md diagrama-palestra.md postmortem_atual.md
git commit -m "mensagem descritiva com Co-Authored-By: Claude Sonnet 4.6"
git push origin main
```

Verificar `git status` antes para confirmar quais arquivos foram modificados.

---

## Referências Adicionais

- `references/mcp-connectivity.md` — Tabela de problemas e soluções de conectividade MCP↔K8s
- `references/alertas-comuns.md` — Catálogo de alertas Kubernetes com severidade e correção

---

## Saída esperada ao final da skill

```
✅ Conectividade MCP corrigida (se necessário)
✅ relatorio_atual.md — <N linhas>
✅ diagrama-palestra.md — 6 diagramas Mermaid
✅ postmortem_atual.md — <N linhas>
✅ Commit e push realizados
```
