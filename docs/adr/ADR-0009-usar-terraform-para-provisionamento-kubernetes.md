# ADR-0009 — Usar Terraform para provisionamento da infraestrutura Kubernetes

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O projeto já tinha manifestos Kubernetes em `k8s/` aplicados manualmente via `kubectl apply`.
Com o crescimento da infraestrutura (Namespace, Secret, PVC, 2 Deployments, 2 Services,
Ingress — 7 recursos no total), surgiu a necessidade de uma forma declarativa e rastreável
de gerenciar o estado do cluster. O pipeline CI/CD aplica os manifestos via `kubectl apply`
para deploys contínuos, mas o provisionamento inicial da infraestrutura (criar namespace,
PVC, Secret pela primeira vez) era feito manualmente sem registro de estado.

## Decisão

Decidimos criar um projeto Terraform em `terraform/` usando o provider
`hashicorp/kubernetes ~> 2.27` com contexto `docker-desktop`. A infraestrutura é dividida
em arquivos por responsabilidade: `main.tf` (provider + namespace), `variables.tf`
(parâmetros configuráveis), `secrets.tf` (Secret do banco), `postgres.tf` (PVC +
Deployment + Service do banco), `app.tf` (Deployment + Service da app), `ingress.tf`
(Ingress), e `outputs.tf` (comandos de verificação). O estado do Terraform é local
(`terraform.tfstate`) — não há backend remoto. A senha do banco (`var.db_password`) é
`sensitive = true` e deve ser passada via `TF_VAR_db_password`.

## Consequências

### Positivas
- Estado declarativo e rastreável — `terraform plan` mostra o diff antes de aplicar
- `terraform destroy` remove todos os recursos de uma vez de forma ordenada
- Variáveis parametrizáveis — `var.app_image_tag` permite trocar a imagem sem editar HCL
- `sensitive = true` no `var.db_password` impede que a senha apareça nos planos e logs
- Paralelismo: Terraform gerencia dependências e aplica recursos em paralelo onde possível
- Documentação implícita: `terraform/outputs.tf` fornece comandos de verificação prontos

### Negativas (trade-offs aceitos)
- Duplicação: toda a infraestrutura existe em dois formatos — `k8s/*.yaml` e `terraform/*.tf`.
  Isso é intencional (demonstração de ambas as abordagens), mas cria risco de drift
- Estado local (`terraform.tfstate`) não é compartilhável em equipe — requer backend remoto
  (S3, GCS, Terraform Cloud) para uso colaborativo
- `terraform destroy` remove o PVC e os dados do banco — requer atenção antes de destruir
- O pipeline CI/CD usa `kubectl apply` (não Terraform) para deploys — os dois sistemas
  podem divergir se o Terraform for aplicado manualmente após o pipeline

### Neutras
- O provider `hashicorp/kubernetes ~> 2.27` traduz HCL diretamente para chamadas da API
  Kubernetes — não há componente intermediário ou agente no cluster

## Alternativas Consideradas

### Alternativa 1: Manter apenas `kubectl apply` com manifestos YAML
Não usar Terraform — continuar com os manifestos `k8s/*.yaml` aplicados manualmente ou via pipeline.
**Por que descartada:** `kubectl apply` não rastreia o estado — não há como saber o que
foi aplicado, quando, ou o que mudou. `terraform plan` fornece um diff declarativo que
`kubectl diff` só aproxima. Para demonstrar boas práticas de IaC, o Terraform é o padrão
da indústria.

### Alternativa 2: Helm Charts
Empacotar a aplicação como um Helm Chart.
**Por que descartada:** Helm adiciona uma camada de abstração (templates, values) que
aumenta a complexidade sem benefício direto para um único ambiente. Seria a escolha certa
para distribuição pública do chart ou múltiplos ambientes com parametrização pesada.
Terraform com variáveis cobre os casos de uso atuais de forma mais simples.

### Alternativa 3: Kustomize
Usar Kustomize para gerenciar overlays de ambiente (dev, staging, prod).
**Por que descartada:** Kustomize resolve o problema de múltiplos ambientes (overlays),
mas não fornece rastreamento de estado. Para o ambiente único atual (Docker Desktop), a
complexidade de base + overlays não é justificada.

### Alternativa 4: Pulumi
Usar Pulumi com TypeScript ou Python em vez de HCL.
**Por que descartada:** Pulumi usa linguagens de programação reais (vs. HCL declarativo),
o que aumenta a curva de aprendizado sem benefício para este caso. O provider Pulumi para
Kubernetes é equivalente ao Terraform, mas o ecossistema e a documentação do Terraform são
significativamente maiores.

### Alternativa 5: Terraform com backend remoto (Terraform Cloud / S3)
Usar backend remoto para estado compartilhado.
**Por que descartada:** o projeto é de desenvolvedor único em ambiente local. Backend
remoto é essencial para equipes, mas adiciona dependência externa (conta AWS, Terraform
Cloud) sem benefício para o uso atual. Documentado como evolução futura em `outputs.tf`.

## Referências
- `terraform/main.tf` — provider config e namespace
- `terraform/variables.tf` — parâmetros configuráveis
- `terraform/secrets.tf` — Secret do banco
- `terraform/postgres.tf` — PVC + Deployment + Service do PostgreSQL
- `terraform/app.tf` — Deployment + Service da aplicação
- `terraform/ingress.tf` — Ingress Controller resource
- `terraform/outputs.tf` — outputs de verificação
- `terraform/terraform.tfvars` — valores padrão (sem senha)
- `.gitignore` — entradas Terraform (`.terraform/`, `*.tfstate*`)
