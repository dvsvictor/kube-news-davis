# ADR-0003 — Usar Docker Hub como registry de imagens de produção

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O pipeline de CI/CD (`.github/workflows/ci-cd.yml`) precisa de um registry para armazenar
as imagens Docker geradas a cada build. O registry deve ser acessível tanto pelo runner do
GitHub Actions (para push) quanto pelo cluster Kubernetes local (para pull). A escolha do
registry afeta a configuração de autenticação, os limites de uso e a complexidade operacional
do pipeline.

## Decisão

Decidimos usar o Docker Hub (`hub.docker.com`) como registry, publicando a imagem como
`dvsvictor/kube-news:<tag>`. A autenticação no pipeline é feita via GitHub Secrets
(`DOCKER_USERNAME` e `DOCKER_PASSWORD` com access token). O cluster usa
`imagePullPolicy: Always` no Deployment da app para garantir que a tag atualizada seja
sempre puxada. A estratégia de tags usa SHA curto (7 chars) para rastreabilidade e `main`
como tag flutuante do último build aprovado.

## Consequências

### Positivas
- Docker Hub é gratuito para repositórios públicos — zero custo para o projeto
- Amplamente suportado: qualquer cluster Kubernetes faz pull sem configuração especial
- A CLI `docker` já está autenticada no Docker Hub na maioria dos ambientes de desenvolvimento
- `docker/login-action`, `docker/metadata-action` e `docker/build-push-action` têm integração nativa

### Negativas (trade-offs aceitos)
- Repositório público: qualquer pessoa pode fazer pull da imagem (aceitável para projeto de demonstração)
- Docker Hub tem rate limiting para pulls anônimos — o cluster local deve usar `imagePullPolicy: IfNotPresent` para imagens estáveis
- Dependência de serviço externo: se o Docker Hub estiver fora do ar, o pipeline falha no push

### Neutras
- A imagem `postgres:15-alpine` já vem do Docker Hub — usar o mesmo registry para a app é consistente

## Alternativas Consideradas

### Alternativa 1: GitHub Container Registry (GHCR)
Registry integrado ao GitHub, em `ghcr.io/dvsvictor/kube-news`.
**Por que descartada:** GHCR requer configurar `imagePullSecret` no cluster para imagens
privadas, adicionando complexidade. Para imagens públicas funcionaria bem, mas o Docker Hub
já é familiar e não requer configuração adicional no cluster.

### Alternativa 2: Registry local (registry:2 no Docker)
Container registry rodando localmente no Docker.
**Por que descartada:** não acessível pelo runner do GitHub Actions (que roda em
`ubuntu-latest`, não na máquina local). Exigiria split de pipeline: build local + push local
+ deploy local, eliminando o valor do CI/CD remoto.

### Alternativa 3: Amazon ECR / Google Artifact Registry
Registries gerenciados em cloud.
**Por que descartada:** requer conta e configuração em provedor de cloud, adicionando custo
e complexidade desnecessários para um projeto de demonstração local.

## Referências
- `.github/workflows/ci-cd.yml:29` — `docker/login-action` com DOCKER_USERNAME/DOCKER_PASSWORD
- `.github/workflows/ci-cd.yml:33` — `docker/metadata-action` gerando tags sha7 e main
- `k8s/deploy.yaml` — `image: dvsvictor/kube-news:main`
