# ADR-0004 — Usar self-hosted runner para o job de deploy no GitHub Actions

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O pipeline CI/CD (`ci-cd.yml`) precisa aplicar os manifestos Kubernetes no cluster local
(Docker Desktop). O cluster roda na máquina do desenvolvedor e seu endpoint de API é
`127.0.0.1:<porta>` — inacessível pela internet. Os runners padrão do GitHub Actions
(`ubuntu-latest`) rodam em infraestrutura gerenciada pelo GitHub, sem acesso à rede local
do desenvolvedor. Era necessário definir como o step de `kubectl apply` alcançaria o cluster.

## Decisão

Decidimos usar um **self-hosted runner** registrado na máquina local do desenvolvedor para
o job `deploy`. Os jobs `build-push` e `smoke-test` continuam usando `ubuntu-latest` (mais
rápidos, sem dependência local). O job `deploy` usa `runs-on: self-hosted` e só executa em
push para `main` — não em PRs. O kubeconfig é passado como secret Base64 (`KUBECONFIG_B64`)
e decodificado em memória durante o job. O runner é instalado via script do GitHub
(Settings → Actions → Runners) e pode ser configurado como serviço para persistir entre
reboots.

## Consequências

### Positivas
- Acesso direto ao cluster local sem expor o kubeconfig pela internet
- Sem custo adicional — GitHub oferece self-hosted runners gratuitamente
- O runner tem `kubectl` e `docker` disponíveis no PATH da máquina local
- Separação clara: CI (build + test) em cloud, CD (deploy) local

### Negativas (trade-offs aceitos)
- Se a máquina do desenvolvedor estiver desligada, o job `deploy` trava até timeout
- O runner precisa estar registrado e rodando — adiciona um serviço a manter localmente
- O runner tem acesso ao cluster com as permissões do kubeconfig — risco se comprometido
- Não escala para equipes: cada desenvolvedor precisaria de seu próprio runner ou de cluster compartilhado

### Neutras
- O self-hosted runner é executado no contexto do usuário da máquina — não requer root

## Alternativas Consideradas

### Alternativa 1: Expor o cluster via ngrok ou similar
Tunelamento para tornar o endpoint Kubernetes acessível pela internet.
**Por que descartada:** expõe o cluster Kubernetes à internet pública, criando risco de
segurança sério. Requer renovação do token de túnel e não é solução sustentável.

### Alternativa 2: Deploy manual (sem CD automático)
Executar `kubectl apply` manualmente após cada merge em main.
**Por que descartada:** elimina o valor do CD — o principal benefício da automação é
garantir que o cluster sempre reflita o estado do repositório sem intervenção humana.

### Alternativa 3: Kind/k3d no runner do GitHub
Criar um cluster efêmero no runner ubuntu-latest para o deploy.
**Por que descartada:** um cluster efêmero não representa o estado real do ambiente local.
O objetivo do deploy é atualizar o cluster persistente onde a aplicação roda, não criar um
novo cluster para cada pipeline.

## Referências
- `.github/workflows/ci-cd.yml:90` — `runs-on: self-hosted` no job deploy
- `.github/workflows/ci-cd.yml:100` — decodificação do KUBECONFIG_B64
- `CLAUDE.md` — seção CI/CD com instruções de configuração do runner
