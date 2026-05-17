# ADR-0010 — Estruturar o pipeline CI/CD em três jobs sequenciais no GitHub Actions

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O projeto precisava de automação para build, validação e deploy da imagem Docker a cada
mudança no repositório. Os requisitos eram:

1. Build e push da imagem em todo PR — para que a imagem existisse no registry antes
   de qualquer deploy
2. Validação funcional mínima — verificar que a aplicação sobe e responde ao `/health`
   antes de chegar ao cluster
3. Deploy automático no cluster local apenas em push para `main` — não em PRs, para
   evitar deploys de código não revisado
4. O cluster roda em `127.0.0.1` — inacessível pelos runners gerenciados do GitHub
   (ver ADR-0004)

O pipeline está definido em `.github/workflows/ci-cd.yml`.

## Decisão

Decidimos estruturar o pipeline em **três jobs sequenciais** com runners distintos:

```
[build-push] ──► [smoke-test] ──► [deploy]
ubuntu-latest    ubuntu-latest    self-hosted
PR + push        PR + push        push main apenas
```

**Job 1 — `build-push`** (`ubuntu-latest`): faz checkout, autentica no Docker Hub via
`DOCKER_USERNAME`/`DOCKER_PASSWORD`, usa `docker/metadata-action@v5` para gerar duas
tags por evento (SHA curto de 7 chars + nome do branch), e faz build + push com
`docker/build-push-action@v5` com context `./src`. O SHA da imagem é exposto como
output (`image_tag`) para o job `deploy`.

**Job 2 — `smoke-test`** (`ubuntu-latest`, `needs: build-push`): sobe o ambiente completo
com `docker compose up -d`, aguarda o endpoint `/health` responder em até 150s (30
tentativas × 5s), e derruba o ambiente com `docker compose down -v` (sempre, mesmo em
falha via `if: always()`).

**Job 3 — `deploy`** (`self-hosted`, `needs: smoke-test`, `if: push && ref == main`):
decodifica `KUBECONFIG_B64` para `~/.kube/config` (permissão 600), atualiza a tag da
imagem no `k8s/deploy.yaml` via `sed`, aplica os manifestos em ordem (namespace →
secrets → pvc → deploy → ingress), e aguarda o rollout com `kubectl rollout status
--timeout=120s`.

## Consequências

### Positivas
- PRs têm build + smoke-test automáticos — feedback antes do merge
- Deploy só acontece após validação funcional (smoke-test passou)
- Deploy só acontece em `main` — código não revisado nunca vai ao cluster
- O kubeconfig nunca trafega em texto plano — é decodificado em memória durante o job
- Tags SHA garantem rastreabilidade: é possível saber exatamente qual commit está no cluster
- `docker compose down -v` no `always()` garante que o ambiente de teste nunca vaza entre runs

### Negativas (trade-offs aceitos)
- O job `deploy` trava se o self-hosted runner estiver offline — sem fallback
- `sed` para atualizar a tag no `deploy.yaml` é frágil: se o formato da linha mudar,
  o `sed` pode falhar silenciosamente (ou pior, corromper o arquivo)
- O `deploy.yaml` modificado pelo `sed` não é commitado de volta ao repositório — o
  cluster tem a imagem atualizada mas o YAML no repo continua com a tag anterior
- O smoke-test usa `docker compose exec` diretamente — depende do compose subir na máquina
  do runner, que pode ter imagens em cache diferentes do registry

### Neutras
- O job `build-push` roda para PRs de qualquer branch, não apenas de branches prefixadas —
  isso é intencional para que forks também possam usar o CI (sem acesso aos secrets de push)

## Alternativas Consideradas

### Alternativa 1: Pipeline único com steps condicionais
Um único job com `if:` em cada step para controlar o que roda em PRs vs. push para main.
**Por que descartada:** jobs separados permitem executar smoke-test e build em paralelo
no futuro, têm timeouts independentes, e tornam o log de cada fase separado e legível no
GitHub UI. Um job monolítico mistura responsabilidades e dificulta debug de falhas pontuais.

### Alternativa 2: Deploy via ArgoCD (GitOps)
Usar ArgoCD no cluster para sincronizar automaticamente ao detectar mudanças no repositório.
**Por que descartada:** ArgoCD requer instalação e configuração no cluster local, e
precisaria de acesso de saída à internet para observar o repositório GitHub — adicionando
complexidade de rede no ambiente Docker Desktop. Para um cluster de desenvolvimento local,
o `kubectl apply` direto via self-hosted runner é mais simples e igualmente confiável.

### Alternativa 3: Não fazer smoke-test — ir direto do build para o deploy
Build-push → deploy, sem validação intermediária.
**Por que descartada:** o deploy no cluster local é harder to roll back do que um PR
rejeitado. O smoke-test com docker-compose é rápido (~2min) e captura falhas de
inicialização (banco não conectou, variável de ambiente errada) antes de afetar o cluster.

### Alternativa 4: Usar GitHub Environments para o deploy
Definir um GitHub Environment (`production`) com proteção de aprovação manual antes do deploy.
**Por que descartada:** aprovação manual elimina o benefício do CD automático para um
projeto de desenvolvedor único. Environments são valiosos em equipes onde o deploy precisa
de revisão humana — aqui, o smoke-test é o gate suficiente.

### Alternativa 5: Reusable Workflows ou composite actions para reduzir duplicação
Extrair os steps repetidos (checkout, configuração) em composite actions.
**Por que descartada:** os três jobs compartilham apenas o `actions/checkout@v4` —
não há duplicação significativa que justifique a abstração. Composite actions adicionam
uma camada de indireção que dificulta o entendimento do pipeline para quem está aprendendo.

## Referências
- `.github/workflows/ci-cd.yml` — definição completa do pipeline
- `.github/workflows/ci-cd.yml:94` — condição `if: github.event_name == 'push'`
- `.github/workflows/ci-cd.yml:108` — `sed` para atualizar tag no deploy.yaml
- `.github/workflows/ci-cd.yml:120` — `kubectl rollout status --timeout=120s`
- [ADR-0003](ADR-0003-usar-docker-hub-como-registry-de-imagens.md) — escolha do registry e estratégia de tags
- [ADR-0004](ADR-0004-usar-self-hosted-runner-para-deploy-local.md) — por que self-hosted runner no job deploy
- `CLAUDE.md` — seção CI/CD com secrets obrigatórios e setup do runner
