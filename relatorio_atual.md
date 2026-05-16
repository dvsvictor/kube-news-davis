# Relatório do Cluster Kubernetes
**Data:** 2026-05-16 — **Cluster:** docker-desktop (kind) — **Versão K8s:** v1.34.2

---

## 1. Inventário de Hardware

| Nó | Papel | IP Interno | CPU | Memória | Armazenamento | OS | Container Runtime |
|----|-------|-----------|-----|---------|---------------|----|------------------|
| desktop-control-plane | control-plane | 172.18.0.2 | 10 vCPUs | 7,9 GB | 474 GB | Debian 12 (arm64) | containerd 2.2.0 |
| desktop-worker | worker | 172.18.0.3 | 10 vCPUs | 7,9 GB | 474 GB | Debian 12 (arm64) | containerd 2.2.0 |
| desktop-worker2 | worker | 172.18.0.4 | 10 vCPUs | 7,9 GB | 474 GB | Debian 12 (arm64) | containerd 2.2.0 |

**Observações:** Cluster kind rodando via Docker Desktop em macOS arm64. O nó `desktop-control-plane` possui taint `NoSchedule`, impedindo scheduling de workloads de aplicação (comportamento esperado). Kernel: 6.12.76-linuxkit. CNI: kindnet.

---

## 2. Pods em Execução

**Total: 15 pods — 15 Running / 0 Failed**

### Namespace: `default`

| Pod | Status | Restarts | Nó | IP |
|-----|--------|----------|----|----|
| kube-news-5ff99b7dfc-7kqs7 | Running | **2** ⚠️ | desktop-worker | 10.244.1.3 |
| postgres-78ccf76d95-45z9s | Running | 0 ✅ | desktop-worker2 | 10.244.2.5 |

### Namespace: `kube-system`

| Pod | Status | Restarts | Nó |
|-----|--------|----------|----|
| coredns-66bc5c9577-gvcvv | Running | 0 | desktop-control-plane |
| coredns-66bc5c9577-mzhcz | Running | 0 | desktop-control-plane |
| etcd-desktop-control-plane | Running | 0 | desktop-control-plane |
| kindnet-g6pq5 | Running | 0 | desktop-worker |
| kindnet-skqxl | Running | 0 | desktop-worker2 |
| kindnet-zkvsn | Running | 0 | desktop-control-plane |
| kube-apiserver-desktop-control-plane | Running | 0 | desktop-control-plane |
| kube-controller-manager-desktop-control-plane | Running | 0 | desktop-control-plane |
| kube-proxy-frmz4 | Running | 0 | desktop-worker |
| kube-proxy-gnf6p | Running | 0 | desktop-control-plane |
| kube-proxy-mnfc5 | Running | 0 | desktop-worker2 |
| kube-scheduler-desktop-control-plane | Running | 0 | desktop-control-plane |

### Namespace: `local-path-storage`

| Pod | Status | Restarts | Nó |
|-----|--------|----------|----|
| local-path-provisioner-5c4cdb564f-s5z92 | Running | 0 | desktop-control-plane |

---

## 3. Aplicações em Execução

### kube-news

| Campo | Valor |
|-------|-------|
| Imagem | `kube-news:1.0.0` (imagem local, ~55 MB) |
| Réplicas | 1/1 Ready |
| Porta container | 8080/TCP (named: `http`) |
| Service | `kube-news` — ClusterIP `10.96.20.6:80` → pod:8080 |
| CPU Request/Limit | 100m / 500m |
| Memory Request/Limit | 128Mi / 256Mi |
| Liveness Probe | HTTP GET `:http/health` — delay 10s, period 30s, failure 3x |
| Readiness Probe | HTTP GET `:http/ready` — delay 0s, period 10s, failure 3x |
| Startup Probe | HTTP GET `:http/health` — delay 10s, period 10s, failure 12x |
| Acesso externo | ❌ Nenhum — apenas via `kubectl port-forward` |
| Variáveis de ambiente | DB_HOST=postgres, DB_PORT=5432, DB_DATABASE=kubedevnews, DB_USERNAME=kubedevnews, **DB_PASSWORD=Pg#123 (plaintext)** 🔴 |

### postgres

| Campo | Valor |
|-------|-------|
| Imagem | `postgres:15-alpine` (já presente no node) |
| Réplicas | 1/1 Ready |
| Porta container | 5432/TCP (named: `postgres`) |
| Service | `postgres` — ClusterIP `10.96.184.193:5432` |
| CPU Request/Limit | 100m / 500m |
| Memory Request/Limit | 256Mi / 512Mi |
| Liveness Probe | exec `pg_isready -U kubedevnews -d kubedevnews` — delay 30s, period 30s |
| Readiness Probe | exec `pg_isready` — delay 0s, period 10s, failure 5x |
| Startup Probe | exec `pg_isready` — delay 5s, period 6s, failure 10x |
| PersistentVolumeClaim | ❌ Nenhum — **dados efêmeros** 🔴 |
| Variáveis de ambiente | POSTGRES_DB=kubedevnews, POSTGRES_USER=kubedevnews, **POSTGRES_PASSWORD=Pg#123 (plaintext)** 🔴 |

---

## 4. Status de Saúde do Cluster e Aplicações

### Condições dos Nós

| Nó | MemoryPressure | DiskPressure | PIDPressure | Ready |
|----|---------------|-------------|------------|-------|
| desktop-control-plane | False ✅ | False ✅ | False ✅ | True ✅ |
| desktop-worker | False ✅ | False ✅ | False ✅ | True ✅ |
| desktop-worker2 | False ✅ | False ✅ | False ✅ | True ✅ |

### Status dos Deployments

| Deployment | Namespace | Desejado | Disponível | Status |
|------------|-----------|---------|-----------|--------|
| kube-news | default | 1 | 1 | ✅ Available |
| postgres | default | 1 | 1 | ✅ Available |
| coredns | kube-system | 2 | 2 | ✅ Available |
| local-path-provisioner | local-path-storage | 1 | 1 | ✅ Available |

### Tabela de Alertas

| Severidade | Componente | Problema Detectado |
|-----------|-----------|-------------------|
| 🔴 Crítico | kube-news + postgres | Credenciais (`DB_PASSWORD`, `POSTGRES_PASSWORD`) em texto plano nos manifests — deve usar Kubernetes Secrets |
| 🔴 Crítico | postgres | Ausência de PersistentVolumeClaim — todos os dados do banco serão perdidos se o pod reiniciar |
| ⚠️ Atenção | kube-news | 2 restarts por race condition na inicialização (kube-news tentou conectar ao postgres antes de ele estar pronto) — mitigar com `initContainers` |
| ⚠️ Atenção | Cluster | Ausência de Ingress Controller — acesso externo só via `kubectl port-forward`, não escalável |
| ⚠️ Atenção | Cluster | Metrics Server não instalado — `kubectl top nodes/pods` indisponível, sem observabilidade de uso |
| ⚠️ Atenção | kube-news + postgres | Deployments com réplica única (1/1) — sem HA; falha do pod causa downtime imediato |
| ℹ️ Info | Cluster | Sem Ingress resources definidos — nenhum roteamento HTTP externo configurado |

---

## 5. Sugestões de Melhorias

### Prioridade Alta

**5.1 — Migrar credenciais para Kubernetes Secret**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: default
type: Opaque
stringData:
  password: "Pg#123"
  username: "kubedevnews"
  database: "kubedevnews"
```

Nos deployments, substituir variáveis `DB_PASSWORD` e `POSTGRES_PASSWORD` por:
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-secret
        key: password
```

**5.2 — Adicionar PersistentVolumeClaim ao postgres**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

No deployment do postgres, adicionar:
```yaml
volumes:
  - name: postgres-data
    persistentVolumeClaim:
      claimName: postgres-pvc
volumeMounts:
  - name: postgres-data
    mountPath: /var/lib/postgresql/data
```

**5.3 — Eliminar race condition com initContainer**

Adicionar ao deployment do `kube-news`:
```yaml
initContainers:
  - name: wait-for-postgres
    image: busybox:1.36
    command: ['sh', '-c', 'until nc -z postgres 5432; do echo waiting for postgres; sleep 2; done']
```

### Prioridade Média

**5.4 — Instalar Ingress NGINX Controller**

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Após instalação, criar recurso Ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kube-news-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - host: kube-news.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kube-news
                port:
                  number: 80
```

**5.5 — Instalar Metrics Server**

Para kind, adicionar flag `--kubelet-insecure-tls` no deployment do Metrics Server após aplicar o manifesto oficial.

### Prioridade Baixa

**5.6 — Configurar HorizontalPodAutoscaler para kube-news**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: kube-news-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: kube-news
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

---

## Apêndice — Status da Coleta MCP

| Ferramenta | Status | Observação |
|-----------|--------|-----------|
| `kubectl_context` | ✅ | Contexto: docker-desktop |
| `kubectl_get nodes` | ✅ | 3 nós coletados |
| `kubectl_get pods` | ✅ | 15 pods, todos Running |
| `kubectl_get deployments` | ✅ | 4 deployments |
| `kubectl_get services` | ✅ | 4 services |
| `kubectl_get ingress` | ✅ | 0 recursos (nenhum configurado) |
| `kubectl_get pvc` | ✅ | 0 recursos (nenhum configurado) |
| `kubectl_get events` | ✅ | 17 eventos coletados |
| `kubectl_describe node` | ✅ | Todos os 3 nós descritos |
| `kubectl_describe deployment` | ✅ | kube-news e postgres |
| `kubectl_logs` (previous) | ✅ | Causa raiz dos restarts confirmada |
| `kubectl top nodes` | ❌ | Metrics Server não instalado |
