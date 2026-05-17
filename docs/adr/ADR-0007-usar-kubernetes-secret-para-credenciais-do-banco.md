# ADR-0007 — Usar Kubernetes Secret para credenciais do banco de dados

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O manifesto original `k8s/deploy.yaml` continha a senha do PostgreSQL em texto plano no
campo `value` da variável de ambiente `DB_PASSWORD: Pg#123`. Essa senha também aparecia
em `docker-compose.yml`. Com a adição do namespace `kube-news` e a preparação para um
pipeline CI/CD que usaria o repositório GitHub (público ou compartilhado), armazenar
credenciais em texto plano em manifestos Kubernetes representa um risco de segurança —
qualquer pessoa com acesso ao repositório poderia ver a senha.

## Decisão

Decidimos criar um `Secret` Kubernetes (`k8s/secrets.yaml`) do tipo `Opaque` com a chave
`password` armazenando o valor em Base64 (`UGcjMTIz` = base64 de `Pg#123`). Tanto o
container do PostgreSQL (variável `POSTGRES_PASSWORD`) quanto o container da aplicação
(variável `DB_PASSWORD`) referenciam esse Secret via `secretKeyRef`. No Terraform, o
Secret é gerenciado como `kubernetes_secret_v1.postgres_secret` com `var.db_password`
marcado como `sensitive = true`. O valor da senha nunca é commitado em arquivos de
variáveis — apenas via `TF_VAR_db_password` em ambiente.

## Consequências

### Positivas
- A senha não aparece em texto plano nos manifestos Kubernetes ou no repositório git
- Ambos os containers (app e banco) compartilham a mesma fonte de verdade para a senha
- O Secret pode ser rotacionado sem alterar os Deployments — apenas o Secret precisa ser
  atualizado e os pods reiniciados
- Terraform marca a variável como `sensitive` — o valor não aparece nos planos (`terraform plan`)

### Negativas (trade-offs aceitos)
- Base64 não é criptografia — o Secret é apenas ofuscação no manifesto estático. Em produção
  real, seria necessário usar Sealed Secrets, External Secrets Operator ou Vault
- `k8s/secrets.yaml` contém o valor em Base64, que é facilmente decodificável — esse arquivo
  não deve ser commitado em repositórios públicos sem proteção adicional
- O ambiente de desenvolvimento com `docker-compose.yml` ainda usa a senha em texto plano
  (comportamento aceito para dev local, fora do cluster Kubernetes)

### Neutras
- O Base64 no `k8s/secrets.yaml` (`UGcjMTIz`) é apenas para o ambiente de demonstração —
  não representa risco real para dados de produção, pois não há dados sensíveis neste ambiente

## Alternativas Consideradas

### Alternativa 1: Manter DB_PASSWORD em texto plano nos manifestos
Continuar com `value: Pg#123` diretamente no `deploy.yaml`.
**Por que descartada:** viola a prática básica de não commitar credenciais em repositórios.
Mesmo para ambiente de demonstração, o hábito de expor senhas em código é um anti-padrão
que deve ser evitado.

### Alternativa 2: Usar ConfigMap em vez de Secret
Armazenar a senha em um ConfigMap.
**Por que descartada:** ConfigMaps não têm semântica de segurança — o conteúdo é exibido
em texto plano em logs, dashboards e outputs do `kubectl describe`. Secrets ao menos sinalizam
a intenção de confidencialidade e têm suporte a `sensitive = true` no Terraform.

### Alternativa 3: Sealed Secrets (Bitnami)
Criptografar o Secret com a chave pública do cluster.
**Por que descartada:** requer instalação do Sealed Secrets Controller e do CLI `kubeseal`,
adicionando complexidade operacional que não é justificada para um ambiente de desenvolvimento
local. Seria a solução correta para produção.

### Alternativa 4: External Secrets Operator com Vault ou AWS Secrets Manager
Gerenciar segredos em sistema externo especializado.
**Por que descartada:** complexidade muito alta para o escopo atual. Requer infraestrutura
adicional (Vault, AWS) que não existe neste projeto. Solução adequada para produção com
múltiplos serviços e rotação automática de credenciais.

## Referências
- `k8s/secrets.yaml` — definição do Secret `postgres-secret`
- `k8s/deploy.yaml` — `secretKeyRef` em ambos os containers
- `terraform/secrets.tf` — `kubernetes_secret_v1.postgres_secret`
- `terraform/variables.tf` — `var.db_password` com `sensitive = true`
