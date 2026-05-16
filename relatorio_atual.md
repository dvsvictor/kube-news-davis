# Relatório do Cluster Kubernetes
**Data:** 16/05/2026 — **Cluster:** `docker-desktop` (kind/Docker Desktop) — **Versão K8s:** v1.34.2

---

## 1. Inventário de Hardware

O cluster é executado em uma VM Linux gerenciada pelo Docker Desktop (Apple Silicon — arm64) com 3 nós.

| Nó | Papel | IP Interno | CPU | Memória | Armazenamento | OS | Container Runtime |
|---|---|---|---|---|---|---|---|
| `desktop-control-plane` | control-plane | 172.18.0.2 | 10 vCPUs | 7,9 GB | 463 GB | Debian 12 | containerd 2.2.0 |
| `desktop-worker` | worker | 172.18.0.3 | 10 vCPUs | 7,9 GB | 463 GB | Debian 12 | containerd 2.2.0 |
| `desktop-worker2` | worker | 172.18.0.4 | 10 vCPUs | 7,9 GB | 463 GB | Debian 12 | containerd 2.2.0 |

> **Nota:** Os recursos de CPU e memória são compartilhados da VM do Docker Desktop (configurada com 10 CPUs / 8 GB RAM). Não é hardware dedicado por nó.

**CIDRs de Pods:**
- control-plane: `10.244.0.0/24`
- worker: `10.244.1.0/24`
- worker2: `10.244.2.0/24`

---

## 2. Pods em Execução

**Total: 15 pods — 15 Running / 0 Failed**

### Namespace `default` (Aplicações)

| Pod | Status | Restarts | Nó | IP |
|---|---|---|---|---|
| `kube-news-5ff99b7dfc-5nprp` | Running | **2** | desktop-worker2 | 10.244.2.3 |
| `postgres-85df697448-gzbtw` | Running | 0 | desktop-worker2 | 10.244.2.4 |

### Namespace `kube-system` (Sistema)

| Pod | Status | Restarts | Nó |
|---|---|---|---|
| `coredns-66bc5c9577-gvcvv` | Running | 0 | control-plane |
| `coredns-66bc5c9577-mzhcz` | Running | 0 | control-plane |
| `etcd-desktop-control-plane` | Running | 0 | control-plane |
| `kube-apiserver-desktop-control-plane` | Running | 0 | control-plane |
| `kube-controller-manager-desktop-control-plane` | Running | 0 | control-plane |
| `kube-scheduler-desktop-control-plane` | Running | 0 | control-plane |
| `kindnet-zkvsn` | Running | 0 | control-plane |
| `kindnet-g6pq5` | Running | 0 | desktop-worker |
| `kindnet-skqxl` | Running | 0 | desktop-worker2 |
| `kube-proxy-gnf6p` | Running | 0 | control-plane |
| `kube-proxy-frmz4` | Running | 0 | desktop-worker |
| `kube-proxy-mnfc5` | Running | 0 | desktop-worker2 |

### Namespace `local-path-storage`

| Pod | Status |
|---|---|
| `local-path-provisioner-5c4cdb564f-s5z92` | Running |

---

## 3. Aplicações em Execução

### kube-news (Aplicação Web)

| Atributo | Valor |
|---|---|
| Imagem | `kube-news:1.0.0` |
| Deployment | 1 réplica / 1 disponível |
| Porta interna | 8080/TCP |
| Service | `kube-news` — ClusterIP `10.96.170.86:80` |
| CPU Request/Limit | 100m / 500m |
| Memory Request/Limit | 128Mi / 256Mi |
| Acesso externo | port-forward `localhost:8080 → service:80` (processo PID 73639) |
| Probes | Liveness `/health`, Readiness `/ready`, Startup `/health` |
| Banco de dados | `postgres:5432` (via env `DB_HOST=postgres`) |

### PostgreSQL (Banco de Dados)

| Atributo | Valor |
|---|---|
| Imagem | `postgres:15-alpine` |
| Deployment | 1 réplica / 1 disponível |
| Porta interna | 5432/TCP |
| Service | `postgres` — ClusterIP `10.96.35.207:5432` |
| CPU Request/Limit | 100m / 500m |
| Memory Request/Limit | 256Mi / 512Mi |
| Persistência | **NENHUMA** — sem PersistentVolumeClaim |
| Probes | Liveness/Readiness/Startup via `pg_isready` |

### Serviços de Rede (Namespace default)

| Service | Tipo | ClusterIP | Porta | Selector |
|---|---|---|---|---|
| `kube-news` | ClusterIP | 10.96.170.86 | 80/TCP | app=kube-news,component=app |
| `postgres` | ClusterIP | 10.96.35.207 | 5432/TCP | app=kube-news,component=db |
| `kubernetes` | ClusterIP | 10.96.0.1 | 443/TCP | — |

---

## 4. Status de Saúde do Cluster e Aplicações

### Nós

| Nó | Ready | MemoryPressure | DiskPressure | PIDPressure |
|---|---|---|---|---|
| desktop-control-plane | ✅ True | ✅ False | ✅ False | ✅ False |
| desktop-worker | ✅ True | ✅ False | ✅ False | ✅ False |
| desktop-worker2 | ✅ True | ✅ False | ✅ False | ✅ False |

### Deployments

| Deployment | Desejado | Disponível | Status |
|---|---|---|---|
| `kube-news` | 1 | 1 | ✅ Ready |
| `postgres` | 1 | 1 | ✅ Ready |
| `coredns` | 2 | 2 | ✅ Ready |
| `local-path-provisioner` | 1 | 1 | ✅ Ready |

### Alertas e Problemas Detectados

| Severidade | Componente | Problema |
|---|---|---|
| ⚠️ Médio | `kube-news` pod | **2 restarts registrados** — o pod reiniciou 2 vezes (provavelmente por falha no startup probe aguardando o banco inicializar) |
| 🔴 Alto | `postgres` | **Sem PersistentVolumeClaim** — todos os dados são perdidos se o pod for reiniciado ou recriado |
| 🔴 Alto | Todos os serviços | **Sem Ingress Controller** — nenhum recurso Ingress configurado; o acesso externo depende de `kubectl port-forward` manual e frágil |
| 🔴 Alto | `kube-news` + `postgres` | **Credenciais em texto plano** nos manifests (`DB_PASSWORD: Pg#123`, `POSTGRES_PASSWORD: Pg#123`) — deveriam usar Kubernetes Secrets |
| ⚠️ Médio | `desktop-worker` | Nó praticamente ocioso — apenas 2 pods de sistema, **nenhuma carga de trabalho** distribuída |
| ⚠️ Médio | Metrics Server | **Não instalado** — `kubectl top` não funciona; impossível monitorar uso real de CPU/memória |
| ℹ️ Info | MCP / kubeconfig | **Problema de rede corrigido** nesta sessão — `~/.kube/config-mcp` apontava para `127.0.0.1` (inválido dentro do container Docker MCP); atualizado para `host.docker.internal` |

---

## 5. Sugestões de Melhorias

### Prioridade Alta

**1. Criar PersistentVolumeClaim para o PostgreSQL**

O banco de dados está usando armazenamento efêmero. Qualquer reinício do pod apagará todos os dados.

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
      storage: 5Gi
---
# Adicionar ao deployment do postgres em spec.template.spec:
volumes:
  - name: postgres-data
    persistentVolumeClaim:
      claimName: postgres-pvc
# E no container:
volumeMounts:
  - name: postgres-data
    mountPath: /var/lib/postgresql/data
```

**2. Instalar Ingress Controller (NGINX) e remover o port-forward manual**

O port-forward manual quebra ao reiniciar o terminal. O correto é instalar um Ingress Controller:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Em seguida, criar um recurso `Ingress`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kube-news-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
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

**3. Mover credenciais para Kubernetes Secrets**

```bash
kubectl create secret generic kube-news-db-secret \
  --from-literal=DB_PASSWORD='Pg#123' \
  --from-literal=POSTGRES_PASSWORD='Pg#123'
```

E referenciar nos manifests via `secretKeyRef`:

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: kube-news-db-secret
        key: DB_PASSWORD
```

### Prioridade Média

**4. Instalar o Metrics Server**

Necessário para `kubectl top`, HPA e monitoramento de recursos.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**5. Distribuir cargas de trabalho entre os workers**

O `desktop-worker` está ocioso. Usar `podAntiAffinity` para garantir que kube-news e postgres rodem em nós diferentes:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: component
                operator: In
                values: [db]
          topologyKey: kubernetes.io/hostname
```

**6. Aumentar réplicas do kube-news para pelo menos 2**

Uma única réplica cria ponto único de falha. Com 2 réplicas e anti-affinity, o downtime durante updates é eliminado:

```bash
kubectl scale deployment kube-news --replicas=2
```

**7. Configurar HorizontalPodAutoscaler (HPA)**

Após instalar o Metrics Server, adicionar HPA para escalar automaticamente o kube-news conforme demanda:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: kube-news-hpa
  namespace: default
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

### Prioridade Baixa

**8. Configurar NetworkPolicies**

Atualmente qualquer pod pode se comunicar com qualquer outro. Adicionar policies para isolar o PostgreSQL — apenas `kube-news` deve acessar a porta 5432:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-allow-only-kube-news
  namespace: default
spec:
  podSelector:
    matchLabels:
      component: db
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              component: app
      ports:
        - protocol: TCP
          port: 5432
```

**9. Adicionar Resource Quotas por namespace**

Impede que uma aplicação consuma todos os recursos do cluster:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: default
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    pods: "20"
```

**10. Configurar PodDisruptionBudget (PDB)**

Garante disponibilidade mínima durante operações de manutenção nos nós:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: kube-news-pdb
  namespace: default
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: kube-news
      component: app
```

---

## Apêndice — Correção Aplicada Nesta Sessão

| Item | Detalhe |
|---|---|
| Arquivo corrigido | `~/.kube/config-mcp` |
| Problema | `server: https://127.0.0.1:55180` — endereço inválido dentro do container Docker MCP |
| Solução | `server: https://host.docker.internal:55180` + `insecure-skip-tls-verify: true` |
| Backup | `~/.kube/config-mcp.bak` |
| Configuração MCP | `~/.docker/mcp/config.yaml` aponta para `~/.kube/config-mcp` |
