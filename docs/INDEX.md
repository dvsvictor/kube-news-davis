# Índice de Documentação Técnica — Kube-News

Documentação gerada seguindo os formatos ADR, RFC e Google Design Doc.
Para criar novos documentos, use a skill `design-doc`.

---

## Design Docs

| Documento | Status | Descrição |
|-----------|--------|-----------|
| [Kube-News: Sistema Completo](design/kube-news-sistema-completo.md) | Implementado | Arquitetura geral, stack, CI/CD, segurança, roadmap |

---

## ADRs — Architecture Decision Records

| Documento | Status | Decisão |
|-----------|--------|---------|
| [ADR-0001 — Usar Alpine como base das imagens Docker](adr/ADR-0001-usar-alpine-como-base-das-imagens-docker.md) | Aceito | `node:18-alpine` e `postgres:15-alpine` — imagens ~10× menores e superfície de ataque reduzida |
| [ADR-0002 — Usar ClusterIP e kubectl port-forward para acesso local](adr/ADR-0002-usar-clusterip-e-port-forward-para-acesso-local.md) | Aceito | Services ClusterIP + port-forward via launchd para acesso do host macOS ao cluster kind |
| [ADR-0003 — Usar Docker Hub como registry de imagens](adr/ADR-0003-usar-docker-hub-como-registry-de-imagens.md) | Aceito | `dvsvictor/kube-news` no Docker Hub com tags sha7 + `main` |
| [ADR-0004 — Usar self-hosted runner para o job de deploy](adr/ADR-0004-usar-self-hosted-runner-para-deploy-local.md) | Aceito | Runner local para o job `deploy` — único modo de alcançar o cluster em `127.0.0.1` |
| [ADR-0005 — Usar PersistentVolumeClaim para dados do PostgreSQL](adr/ADR-0005-usar-pvc-para-persistencia-do-postgresql.md) | Aceito | PVC `postgres-pvc` (1Gi ReadWriteOnce) para persistência entre restarts de pod |
| [ADR-0006 — Usar namespace dedicado kube-news](adr/ADR-0006-usar-namespace-dedicado-kube-news.md) | Aceito | Namespace `kube-news` isolando todos os recursos do projeto do namespace `default` |
| [ADR-0007 — Usar Kubernetes Secret para credenciais do banco](adr/ADR-0007-usar-kubernetes-secret-para-credenciais-do-banco.md) | Aceito | Secret `postgres-secret` substituindo `DB_PASSWORD` em texto plano nos manifestos |
| [ADR-0008 — Usar NGINX Ingress Controller para acesso externo](adr/ADR-0008-usar-nginx-ingress-controller-para-acesso-externo.md) | Aceito | NGINX Ingress + host `kube-news.local` como proxy HTTP real em vez de port-forward |
| [ADR-0009 — Usar Terraform para provisionamento Kubernetes](adr/ADR-0009-usar-terraform-para-provisionamento-kubernetes.md) | Aceito | Provider `hashicorp/kubernetes ~> 2.27` com estado local para IaC declarativo |
| [ADR-0010 — Pipeline CI/CD em três jobs sequenciais no GitHub Actions](adr/ADR-0010-pipeline-cicd-github-actions-tres-jobs.md) | Aceito | build-push (ubuntu-latest) → smoke-test (ubuntu-latest) → deploy (self-hosted, push main only) |

---

## RFCs — Requests for Comments

*(nenhum criado ainda — use `/design-doc cria um RFC para...`)*

---

## Como usar esta documentação

- **Novo no projeto?** Comece pelo [Design Doc do sistema completo](design/kube-news-sistema-completo.md)
- **Quer entender uma decisão?** Consulte os ADRs
- **Quer propor uma mudança?** Abra um RFC antes de implementar
- **Quer criar um documento?** Use a skill `design-doc` no Claude Code
