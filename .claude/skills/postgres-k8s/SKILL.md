---
name: postgres-k8s
description: >
  Skill de operações PostgreSQL em Kubernetes para o projeto Kube-News. Use
  esta skill sempre que o usuário precisar interagir com o banco de dados em
  ambiente Kubernetes: acessar o pod do banco, rodar queries SQL, checar saúde
  do PostgreSQL, depurar conexão entre app e banco, verificar logs do banco,
  criar ou referenciar Secrets com credenciais, ou qualquer operação de
  troubleshoot envolvendo o PostgreSQL no cluster. Ative quando o usuário
  disser coisas como "entrar no banco", "rodar uma query no k8s", "banco não
  conecta no cluster", "ver logs do postgres", "o pod do banco caiu", "como
  crio o secret da senha", "resetar os dados em produção", etc.
---

# PostgreSQL no Kubernetes — Kube-News

## Contexto do banco no cluster

| Recurso | Nome | Namespace padrão |
|---------|------|-----------------|
| Deployment | `postgres` | `default` |
| Service | `postgres` | `default` |
| Porta | 5432 | — |
| Usuário | `kubedevnews` | — |
| Database | `kubedevnews` | — |

A app se conecta via `DB_HOST=postgres` — esse nome resolve pelo Service do Kubernetes.

---

## Operações essenciais no banco

### Abrir sessão interativa no psql

```bash
kubectl exec -it deployment/postgres -- \
  psql -U kubedevnews -d kubedevnews
```

### Rodar uma query avulsa sem abrir sessão

```bash
kubectl exec deployment/postgres -- \
  psql -U kubedevnews -d kubedevnews -c "SELECT COUNT(*) FROM \"Posts\";"
```

### Listar todas as tabelas

```bash
kubectl exec deployment/postgres -- \
  psql -U kubedevnews -d kubedevnews -c "\dt"
```

### Ver registros da tabela de posts

```bash
kubectl exec deployment/postgres -- \
  psql -U kubedevnews -d kubedevnews \
  -c "SELECT id, title, \"publishDate\" FROM \"Posts\" ORDER BY id DESC LIMIT 10;"
```

---

## Verificar saúde do banco

### Status do pod e das probes

```bash
kubectl get pod -l app=kube-news,component=db
kubectl describe pod -l app=kube-news,component=db   # ver eventos e probe failures
```

### Checar se o PostgreSQL está aceitando conexões

```bash
kubectl exec deployment/postgres -- \
  pg_isready -U kubedevnews -d kubedevnews
```

Retorno esperado: `postgres:5432 - accepting connections`

### Ver logs do banco

```bash
kubectl logs deployment/postgres --tail=50
kubectl logs deployment/postgres -f          # em tempo real
kubectl logs deployment/postgres --previous  # logs do container anterior (crash)
```

---

## Troubleshoot: app não conecta no banco

Siga esta sequência:

1. **O pod do banco está rodando e healthy?**
   ```bash
   kubectl get pods -l component=db
   # STATUS deve ser Running, READY 1/1
   ```

2. **O Service `postgres` existe e tem endpoint?**
   ```bash
   kubectl get service postgres
   kubectl get endpoints postgres
   # Se ENDPOINTS estiver <none>, o selector não está batendo com o pod
   ```

3. **Testar conectividade a partir do pod da app**
   ```bash
   kubectl exec deployment/kube-news -- \
     wget -qO- postgres:5432 || echo "porta fechada"
   # alternativa com nc se disponível:
   kubectl exec deployment/kube-news -- \
     nc -zv postgres 5432
   ```

4. **As variáveis de ambiente estão chegando certo na app?**
   ```bash
   kubectl exec deployment/kube-news -- env | grep DB_
   ```

5. **Logs da app no momento da falha de conexão**
   ```bash
   kubectl logs deployment/kube-news --tail=100 | grep -i "connect\|error\|ECONN"
   ```

### Causas comuns

| Sintoma | Causa | Solução |
|---------|-------|---------|
| `ECONNREFUSED postgres:5432` | Pod do banco não está Ready | Aguardar startupProbe passar ou checar logs do banco |
| `password authentication failed` | `DB_PASSWORD` incorreta ou Secret desatualizado | Verificar o Secret e recriar se necessário |
| `database "kubedevnews" does not exist` | Banco não foi criado | Recriar o pod do postgres (o `POSTGRES_DB` cria o banco na inicialização) |
| `ENDPOINTS <none>` no Service | Label do pod não bate com selector | Verificar labels do Deployment vs selector do Service |
| App em CrashLoopBackOff | startupProbe esgotou antes do banco ficar pronto | Aumentar `failureThreshold` da startupProbe no deploy.yaml |

---

## Gerenciar credenciais com Kubernetes Secret

A senha `Pg#123` está atualmente em texto puro no manifesto. Para protegê-la:

### Criar o Secret

```bash
kubectl create secret generic kube-news-db-secret \
  --from-literal=POSTGRES_PASSWORD=Pg#123 \
  --from-literal=DB_PASSWORD=Pg#123
```

### Referenciar no Deployment do postgres

```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: kube-news-db-secret
        key: POSTGRES_PASSWORD
```

### Referenciar no Deployment da app

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: kube-news-db-secret
        key: DB_PASSWORD
```

### Verificar o Secret criado (sem expor o valor)

```bash
kubectl get secret kube-news-db-secret
kubectl describe secret kube-news-db-secret  # mostra tamanho, não o valor
```

---

## Operações de dados

### Dump do banco para backup

```bash
kubectl exec deployment/postgres -- \
  pg_dump -U kubedevnews kubedevnews > backup-$(date +%Y%m%d).sql
```

### Restaurar a partir de um dump

```bash
kubectl exec -i deployment/postgres -- \
  psql -U kubedevnews -d kubedevnews < backup.sql
```

### Resetar todos os dados (apagar e recriar o pod)

```bash
# ⚠️  Sem PersistentVolume, apagar o pod destrói os dados
kubectl rollout restart deployment/postgres
```

> **Atenção:** o Deployment atual não usa PersistentVolumeClaim. Os dados são perdidos se o pod for recriado. Para persistência em produção, adicione um PVC.

---

## Monitorar em tempo real

```bash
# Acompanhar pods de banco e app ao mesmo tempo
kubectl get pods -l app=kube-news -w

# Ver consumo de recursos do banco
kubectl top pod -l component=db

# Eventos recentes no namespace
kubectl get events --sort-by='.lastTimestamp' | grep postgres
```
