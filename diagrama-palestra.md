# Diagramas da Arquitetura — Kube-News Cluster
**Gerado em:** 2026-05-16 | **Cluster:** docker-desktop (kind) | **K8s:** v1.34.2

---

## Diagrama 1 — Arquitetura Geral

```mermaid
flowchart TD
    subgraph HOST["🖥️ Host macOS (Apple Silicon arm64)"]
        subgraph DD["Docker Desktop"]
            subgraph CP["desktop-control-plane (172.18.0.2)"]
                CP_ROLE["🔒 control-plane\nTaint: NoSchedule"]
                API["kube-apiserver"]
                ETCD["etcd"]
                SCHED["kube-scheduler"]
                CM["kube-controller-manager"]
                CORE1["coredns (10.244.0.2)"]
                CORE2["coredns (10.244.0.3)"]
                LPP["local-path-provisioner"]
            end

            subgraph W1["desktop-worker (172.18.0.3)"]
                W1_INFO["worker · 10 CPU · 7.9GB RAM"]
                KN["kube-news:1.0.0\n10.244.1.3:8080\n⚠️ 2 restarts"]
                SVC_KN["Service: kube-news\nClusterIP 10.96.20.6:80"]
            end

            subgraph W2["desktop-worker2 (172.18.0.4)"]
                W2_INFO["worker · 10 CPU · 7.9GB RAM"]
                PG["postgres:15-alpine\n10.244.2.5:5432\n🔴 Sem PVC"]
                SVC_PG["Service: postgres\nClusterIP 10.96.184.193:5432"]
            end
        end
    end

    KN -->|"ECONNREFUSED\nno startup (race)"| SVC_PG
    KN -->|"conectado\napós 2 restarts"| SVC_PG
    SVC_PG --> PG
    SVC_KN --> KN

    style KN fill:#fff3cd,stroke:#ffc107
    style PG fill:#f8d7da,stroke:#dc3545
    style CP_ROLE fill:#e2e3e5,stroke:#6c757d
```

---

## Diagrama 2 — Fluxo de Acesso: Atual vs. Ideal

```mermaid
flowchart LR
    subgraph ATUAL["🔴 Acesso Atual (Inadequado)"]
        USER1["👤 Usuário"] -->|"kubectl port-forward\npod/kube-news 8080:8080"| KN1["kube-news pod\n(10.244.1.3:8080)"]
        NOTE1["⚠️ Requer sessão de terminal ativa\nNão escalável\nSem TLS\nSem load balancing"]
    end

    subgraph IDEAL["✅ Acesso Ideal (Com Ingress)"]
        USER2["👤 Usuário"] -->|"http://kube-news.local"| ING["NGINX Ingress Controller\n(NodePort 80/443)"]
        ING -->|"Ingress Resource\nhost: kube-news.local"| SVC2["Service kube-news\nClusterIP 10.96.20.6:80"]
        SVC2 --> KN2["kube-news pod\n(10.244.1.3:8080)"]
        NOTE2["✅ Roteamento declarativo\nEscalável com HPA\nSuporta TLS via cert-manager\nLoad balancing automático"]
    end

    style ATUAL fill:#f8d7da,stroke:#dc3545
    style IDEAL fill:#d1e7dd,stroke:#198754
```

---

## Diagrama 3 — Distribuição de Pods por Nó

```mermaid
flowchart TD
    CLUSTER["🌐 Cluster docker-desktop"]

    subgraph NODE_CP["desktop-control-plane (172.18.0.2)"]
        CP_TAINT["🔒 Taint: NoSchedule\n(sem workloads de app)"]
        POD_API["kube-apiserver"]
        POD_ETCD["etcd"]
        POD_SCHED["kube-scheduler"]
        POD_CM["kube-controller-manager"]
        POD_DNS1["coredns ×2"]
        POD_LPP["local-path-provisioner"]
        POD_KN_CP["kindnet + kube-proxy"]
    end

    subgraph NODE_W1["desktop-worker (172.18.0.3)"]
        W1_LOAD["CPU: 2% req · 6% limit\nMem: 2% req · 3% limit"]
        POD_APP["⚠️ kube-news:1.0.0\n(2 restarts)"]
        POD_KN_W1["kindnet + kube-proxy"]
    end

    subgraph NODE_W2["desktop-worker2 (172.18.0.4)"]
        W2_LOAD["CPU: 2% req · 6% limit\nMem: 3% req · 7% limit"]
        POD_DB["🔴 postgres:15-alpine\n(sem PVC)"]
        POD_KN_W2["kindnet + kube-proxy"]
    end

    CLUSTER --> NODE_CP
    CLUSTER --> NODE_W1
    CLUSTER --> NODE_W2

    style POD_APP fill:#fff3cd,stroke:#ffc107
    style POD_DB fill:#f8d7da,stroke:#dc3545
    style CP_TAINT fill:#e2e3e5,stroke:#6c757d
```

---

## Diagrama 4 — Mapa de Saúde do Cluster

```mermaid
flowchart TD
    CL["🌐 Cluster docker-desktop\nK8s v1.34.2"]

    CL --> NODES["Nós"]
    NODES --> N1["✅ desktop-control-plane\nReady · Sem pressão"]
    NODES --> N2["✅ desktop-worker\nReady · Sem pressão"]
    NODES --> N3["✅ desktop-worker2\nReady · Sem pressão"]

    CL --> APPS["Aplicações"]
    APPS --> A1["⚠️ kube-news\n1/1 Running\n2 restarts históricos"]
    APPS --> A2["✅ postgres\n1/1 Running\n0 restarts"]

    CL --> INFRA["Infraestrutura"]
    INFRA --> I1["✅ CoreDNS 2/2"]
    INFRA --> I2["✅ local-path-provisioner"]
    INFRA --> I3["❌ Metrics Server\nausentado"]
    INFRA --> I4["❌ Ingress Controller\nausente"]

    CL --> SEC["Segurança"]
    SEC --> S1["🔴 Credenciais em plaintext\nkube-news + postgres"]
    SEC --> S2["🔴 Postgres sem PVC\nrisco de perda de dados"]
    SEC --> S3["⚠️ Race condition\nna inicialização"]

    style A1 fill:#fff3cd,stroke:#ffc107
    style I3 fill:#f8d7da,stroke:#dc3545
    style I4 fill:#f8d7da,stroke:#dc3545
    style S1 fill:#f8d7da,stroke:#dc3545
    style S2 fill:#f8d7da,stroke:#dc3545
    style S3 fill:#fff3cd,stroke:#ffc107
```

---

## Diagrama 5 — Prioridade de Melhorias

```mermaid
quadrantChart
    title Prioridade de Melhorias do Cluster
    x-axis Baixa Urgência --> Alta Urgência
    y-axis Baixo Impacto --> Alto Impacto
    quadrant-1 Fazer Agora
    quadrant-2 Planejar
    quadrant-3 Avaliar
    quadrant-4 Agendar
    Secrets para credenciais: [0.85, 0.90]
    PVC para postgres: [0.80, 0.95]
    initContainer race condition: [0.70, 0.75]
    Ingress NGINX Controller: [0.55, 0.80]
    Metrics Server: [0.45, 0.55]
    HPA para kube-news: [0.30, 0.65]
    Múltiplas réplicas: [0.35, 0.70]
    Imagem no registry externo: [0.20, 0.45]
```

---

## Diagrama 6 — Sequência de Inicialização (com falhas)

```mermaid
sequenceDiagram
    participant K8s as Kubernetes Scheduler
    participant PG as postgres pod
    participant APP as kube-news pod
    participant SVC as Service postgres<br/>(10.96.184.193:5432)

    Note over K8s: 21:59:19 — Deploy aplicado
    K8s->>PG: Schedule → desktop-worker2
    K8s->>APP: Schedule → desktop-worker

    Note over PG: Imagem já presente (no pull)
    PG->>PG: Iniciando PostgreSQL...
    Note over APP: Pull kube-news:1.0.0 (979ms)

    APP->>SVC: Tentativa 1: connect 10.96.184.193:5432
    SVC-->>APP: ECONNREFUSED ❌ (postgres ainda inicializando)
    APP->>APP: CRASH — exit code não zero

    Note over K8s: BackOff — aguarda antes de reiniciar

    APP->>SVC: Tentativa 2: connect 10.96.184.193:5432
    SVC-->>APP: ECONNREFUSED ❌ (postgres ainda inicializando)
    APP->>APP: CRASH — 2º restart

    Note over PG: ~21:59:30 — PostgreSQL pronto (pg_isready OK)
    PG->>SVC: Readiness probe: SUCCESS ✅

    APP->>SVC: Tentativa 3: connect 10.96.184.193:5432
    SVC->>PG: Forward → 5432
    PG-->>APP: Conexão aceita ✅

    Note over APP: 21:59:44 — kube-news estável<br/>Running · 2 restarts registrados

    Note over APP,PG: Solução: initContainer em kube-news<br/>aguardaria postgres antes de iniciar
```
