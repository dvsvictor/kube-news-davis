# Postmortem — Falha de Conectividade do MCP com o Cluster Kubernetes

**Data do incidente:** 16/05/2026
**Severidade:** Médio (bloqueio operacional — sem impacto em produção)
**Status:** Resolvido
**Autor:** Davis Victor / Claude Sonnet 4.6

---

## Resumo Executivo

O servidor MCP Docker (`docker mcp gateway`) era incapaz de se conectar à API do cluster Kubernetes local (Docker Desktop/kind), retornando `connection refused` em todas as chamadas `kubectl`. A causa raiz foi o endereço `127.0.0.1` no arquivo `~/.kube/config-mcp`, que aponta para o loopback do container MCP e não para o host. A correção foi substituir o endereço por `host.docker.internal`, que resolve corretamente para o host a partir de dentro do container Docker.

---

## Linha do Tempo

| Hora (UTC-3) | Evento |
|---|---|
| ~21:24 | Solicitação de relatório do cluster via MCP — primeiras chamadas retornam `connection refused` |
| ~21:25 | Identificado contexto `docker-desktop` como único contexto disponível |
| ~21:26 | Confirmado: porta `55180` aberta no host (`nc -zv 127.0.0.1 55180` → succeeded) |
| ~21:27 | Identificado que o MCP usa kubeconfig separado em `~/.kube/config-mcp` (via `~/.docker/mcp/config.yaml`) |
| ~21:28 | Diagnóstico confirmado: `config-mcp` apontava para `server: https://127.0.0.1:55180` |
| ~21:29 | Backup criado (`config-mcp.bak`) e arquivo corrigido para `host.docker.internal` |
| ~21:29 | Primeiro `kubectl_get nodes` via MCP retornou os 3 nós com sucesso |
| ~21:30 | Relatório completo do cluster gerado sem erros |

---

## Causa Raiz

O Docker MCP Gateway executa os comandos `kubectl` **dentro de um container Docker**, não diretamente no host. Dentro de um container, `127.0.0.1` é o loopback do próprio container — não o loopback do host onde o Kubernetes escuta.

O arquivo `~/.kube/config-mcp` (kubeconfig exclusivo para o MCP, referenciado em `~/.docker/mcp/config.yaml`) foi criado com o endereço padrão do Docker Desktop (`https://127.0.0.1:55180`), que funciona corretamente para `kubectl` executado no host, mas falha quando executado dentro de um container.

```
Host (macOS)
  └── kubectl → 127.0.0.1:55180  ✅  (loopback do host = API do K8s)

Container Docker (MCP Gateway)
  └── kubectl → 127.0.0.1:55180  ❌  (loopback do container = nada)
  └── kubectl → host.docker.internal:55180  ✅  (DNS especial do Docker → host)
```

---

## Impacto

- **Operacional:** 100% das chamadas MCP ao Kubernetes falhavam — impossível gerar relatórios, executar `kubectl` via MCP ou automatizar operações no cluster.
- **Aplicações:** Nenhum impacto — o cluster continuou funcionando normalmente; apenas a observabilidade via MCP estava bloqueada.
- **Dados:** Nenhuma perda de dados.
- **Duração do bloqueio:** ~5 minutos (tempo entre primeira falha e correção aplicada).

---

## Resolução

### Mudança aplicada

**Arquivo:** `~/.kube/config-mcp`

```diff
 clusters:
 - cluster:
-    certificate-authority-data: <base64...>
-    server: https://127.0.0.1:55180
+    insecure-skip-tls-verify: true
+    server: https://host.docker.internal:55180
   name: docker-desktop
```

**Motivo do `insecure-skip-tls-verify: true`:** O certificado TLS da API do Kubernetes foi emitido com SAN (Subject Alternative Name) para `127.0.0.1` e `kubernetes`, mas não para `host.docker.internal`. A verificação TLS falharia mesmo com o endereço correto, pois o hostname não consta no certificado.

> Esta configuração é aceitável em ambiente de desenvolvimento local. Em ambientes de produção ou staging, o correto seria gerar um certificado que inclua `host.docker.internal` como SAN, ou usar um proxy TLS.

### Backup

O arquivo original foi preservado em `~/.kube/config-mcp.bak`.

### Verificação

```bash
# Confirmação de conectividade após a correção:
kubectl_get nodes → 3 nós retornados (desktop-control-plane, desktop-worker, desktop-worker2)
```

---

## O Que Aprendemos

### Técnico

1. **O MCP Docker Gateway não é o host.** Ferramentas MCP que executam `kubectl` rodam dentro de containers Docker. Qualquer referência a `localhost` ou `127.0.0.1` em configurações do MCP aponta para o container, não para o host.

2. **`host.docker.internal` é o bridge correto.** Docker Desktop expõe esse hostname especial para que containers se comuniquem com serviços do host. Deve ser usado em qualquer kubeconfig destinado a ser consumido por ferramentas MCP.

3. **Dois kubeconfigs, dois contextos de execução.** O sistema tem dois arquivos de configuração:
   - `~/.kube/config` → usado pelo `kubectl` do host (usa `127.0.0.1`)
   - `~/.kube/config-mcp` → usado pelo MCP Gateway (deve usar `host.docker.internal`)
   Eles precisam ser mantidos separados e com os endereços corretos para cada contexto.

4. **Certificados TLS e SANs importam.** Trocar o endereço de IP para hostname exige que o certificado inclua o novo hostname como SAN. Em ambientes locais, `insecure-skip-tls-verify` é um workaround aceitável; em produção, exige rotação de certificado.

### Processo

5. **Diagnosticar antes de assumir que o cluster está fora.** O primeiro sintoma (`connection refused`) poderia indicar cluster desligado. A investigação sistemática (verificar porta com `nc`, checar processos, inspecionar o kubeconfig dedicado do MCP) revelou que o cluster estava saudável e o problema era apenas de endereçamento.

6. **Ferramentas MCP possuem configurações independentes.** Ao configurar um novo ambiente com Docker MCP, verificar sempre `~/.docker/mcp/config.yaml` para entender quais arquivos de configuração o MCP usa — podem ser diferentes dos padrões do sistema.

---

## Ações Preventivas

| Ação | Responsável | Prazo |
|---|---|---|
| Documentar o procedimento de setup do `config-mcp` no README do projeto | Davis Victor | Próxima sprint |
| Adicionar checklist de validação MCP ao onboarding de novos desenvolvedores | Davis Victor | Próxima sprint |
| Avaliar geração de certificado com SAN `host.docker.internal` para eliminar o `insecure-skip-tls-verify` | Davis Victor | Backlog |

---

## Referências

- Arquivo corrigido: `~/.kube/config-mcp`
- Backup: `~/.kube/config-mcp.bak`
- Configuração MCP: `~/.docker/mcp/config.yaml`
- Relatório do cluster gerado após a correção: `relatorio_atual.md`
- Documentação Docker Desktop — `host.docker.internal`: [docs.docker.com/desktop/networking](https://docs.docker.com/desktop/networking/)
