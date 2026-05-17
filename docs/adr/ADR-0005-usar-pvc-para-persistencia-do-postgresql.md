# ADR-0005 — Usar PersistentVolumeClaim para dados do PostgreSQL

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O Deployment do PostgreSQL no Kubernetes (`k8s/deploy.yaml`) armazena os dados em
`/var/lib/postgresql/data`. Sem configuração explícita de volume, os dados ficam no sistema
de arquivos efêmero do container — ao reiniciar o pod (por restart, rollout ou crash), todos
os dados são perdidos. Isso tornava o ambiente de demonstração inutilizável para testes que
exigissem dados persistentes entre sessões. O ambiente de desenvolvimento com docker-compose
já tinha persistência via volume local (`.docker_vol/postgres`).

## Decisão

Decidimos criar um `PersistentVolumeClaim` de 1Gi com `accessMode: ReadWriteOnce`
(`k8s/pvc.yaml`) e montá-lo em `/var/lib/postgresql/data` no container do postgres. O PVC
usa a StorageClass padrão do Docker Desktop (que provisiona volumes locais no host). O nome
`postgres-pvc` é referenciado pelo Deployment via `claimName`. No Terraform, o mesmo PVC é
gerenciado como `kubernetes_persistent_volume_claim_v1.postgres_pvc`.

## Consequências

### Positivas
- Dados do banco sobrevivem a restarts de pod, rollouts e crashes
- O ambiente de demonstração é estável entre sessões — não é necessário popular o banco a cada restart
- Alinhado com o comportamento do docker-compose (`.docker_vol/postgres` persiste entre `docker compose down/up`)

### Negativas (trade-offs aceitos)
- `ReadWriteOnce` permite montagem em apenas um nó por vez — impede réplicas do PostgreSQL em nós diferentes (não é um requisito atual)
- O PVC ocupa 1Gi no armazenamento do host Docker Desktop permanentemente, mesmo que o banco esteja vazio
- `terraform destroy` remove o PVC e os dados — requer atenção antes de destruir o ambiente

### Neutras
- A StorageClass padrão do Docker Desktop usa `hostPath` — adequado para desenvolvimento local, não para produção

## Alternativas Consideradas

### Alternativa 1: Sem volume (armazenamento efêmero)
Não configurar volume — dados ficam no container.
**Por que descartada:** qualquer restart do pod apaga todos os dados. Inviável mesmo para
demonstração — o usuário precisaria popular o banco após cada reinicialização.

### Alternativa 2: hostPath volume diretamente no Deployment
Montar um diretório do host diretamente via `hostPath`.
**Por que descartada:** acopla o pod a um nó específico e a um caminho fixo no host. PVC
é a abstração correta no Kubernetes — permite trocar o storage backend sem alterar o
Deployment.

### Alternativa 3: StatefulSet com volumeClaimTemplate
Usar StatefulSet em vez de Deployment para gerenciar o PVC automaticamente.
**Por que descartada:** StatefulSet adiciona complexidade (nome de pod estável, headless
Service) que não é necessária para uma única réplica. O Deployment com PVC explícito é mais
simples e igualmente funcional para este caso.

## Referências
- `k8s/pvc.yaml` — definição do PVC
- `k8s/deploy.yaml:52-54` — volumeMount no container postgres
- `k8s/deploy.yaml:80-84` — volumes no spec do pod
- `terraform/postgres.tf` — recurso `kubernetes_persistent_volume_claim_v1`
