# Diagramas — Arquitetura do Cluster Kubernetes
**Gerado em:** 16/05/2026 — baseado em `relatorio_atual.md`

---

## 1. Arquitetura Geral do Cluster

Visão completa da infraestrutura: host macOS → VM Docker Desktop → nós → namespaces → pods.

```mermaid
flowchart TD
    subgraph HOST["🖥️ macOS (Apple Silicon — arm64)"]
        USER["👤 Usuário\nlocalhost:8080"]
        PF["kubectl port-forward\nPID 73639"]
        DOCKER["Docker Desktop\n10 vCPUs / 8 GB RAM"]
    end

    subgraph VM["🐧 VM Linux — Debian 12 (6.12.76-linuxkit)"]
        subgraph CP["desktop-control-plane · 172.18.0.2"]
            API["kube-apiserver"]
            ETCD["etcd"]
            SCHED["kube-scheduler"]
            CM["kube-controller-manager"]
            DNS1["coredns (x2)"]
            KN1["kindnet"]
            KP1["kube-proxy"]
            LPP["local-path-provisioner"]
        end

        subgraph W1["desktop-worker · 172.18.0.3  ⚠️ ocioso"]
            KN2["kindnet"]
            KP2["kube-proxy"]
        end

        subgraph W2["desktop-worker2 · 172.18.0.4"]
            subgraph NS_DEFAULT["namespace: default"]
                APP["🌐 kube-news\n10.244.2.3:8080\n⚠️ 2 restarts"]
                DB["🐘 postgres\n10.244.2.4:5432"]
            end
            KN3["kindnet"]
            KP3["kube-proxy"]
        end
    end

    USER -->|"port-forward\n8080→80"| PF
    PF -->|"ClusterIP\n10.96.170.86:80"| APP
    APP -->|"ClusterIP\n10.96.35.207:5432"| DB
    DOCKER --> VM
```

---

## 2. Fluxo de Acesso à Aplicação (Atual vs. Ideal)

Comparativo entre o acesso atual via port-forward e o acesso ideal via Ingress.

```mermaid
flowchart LR
    subgraph ATUAL["🔴 Acesso Atual (frágil)"]
        direction LR
        U1["👤 Usuário"] -->|"localhost:8080"| PF["kubectl\nport-forward"]
        PF -->|"TCP tunnel"| SVC1["Service: kube-news\nClusterIP :80"]
        SVC1 --> POD1["Pod: kube-news\n:8080"]
        POD1 -->|"DB_HOST=postgres"| SVC2["Service: postgres\nClusterIP :5432"]
        SVC2 --> POD2["Pod: postgres\n:5432"]
    end

    subgraph IDEAL["✅ Acesso Ideal (com Ingress)"]
        direction LR
        U2["👤 Usuário"] -->|"kube-news.local:80"| ING["Ingress NGINX\nkube-news.local → /"]
        ING --> SVC3["Service: kube-news\nClusterIP :80"]
        SVC3 --> POD3["Pod: kube-news\n:8080"]
        POD3 --> SVC4["Service: postgres\nClusterIP :5432"]
        SVC4 --> POD4["Pod: postgres\n:5432"]
    end
```

---

## 3. Distribuição de Pods por Nó

Mostra onde cada pod está agendado no cluster.

```mermaid
flowchart TD
    subgraph CP["🔷 desktop-control-plane\n172.18.0.2 · CIDR 10.244.0.0/24"]
        P1["📦 kube-apiserver"]
        P2["📦 etcd"]
        P3["📦 kube-scheduler"]
        P4["📦 kube-controller-manager"]
        P5["📦 coredns (x2)"]
        P6["📦 kindnet"]
        P7["📦 kube-proxy"]
        P8["📦 local-path-provisioner"]
    end

    subgraph W1["🔶 desktop-worker\n172.18.0.3 · CIDR 10.244.1.0/24\n⚠️ NENHUMA carga de trabalho de aplicação"]
        P9["📦 kindnet"]
        P10["📦 kube-proxy"]
    end

    subgraph W2["🟢 desktop-worker2\n172.18.0.4 · CIDR 10.244.2.0/24"]
        P11["🌐 kube-news\n10.244.2.3 · ⚠️ 2 restarts"]
        P12["🐘 postgres\n10.244.2.4 · sem PVC"]
        P13["📦 kindnet"]
        P14["📦 kube-proxy"]
    end
```

---

## 4. Mapa de Saúde — Alertas e Severidade

```mermaid
flowchart TD
    CLUSTER["🏠 Cluster Kubernetes\ndocker-desktop · v1.34.2"]

    CLUSTER --> N1["✅ Nós\n3/3 Ready\nSem pressão de memória/disco"]
    CLUSTER --> N2["✅ Deployments\n4/4 disponíveis"]
    CLUSTER --> N3["⚠️ Aplicações"]
    CLUSTER --> N4["🔴 Infraestrutura"]

    N3 --> A1["⚠️ kube-news\n2 restarts\nstartup probe falhou\naguardando postgres"]
    N3 --> A2["⚠️ desktop-worker\nNó ocioso\nsem workloads\nde aplicação"]
    N3 --> A3["⚠️ Metrics Server\nNão instalado\nkubectl top inoperante"]

    N4 --> B1["🔴 postgres\nSem PVC\nDados efêmeros\nrisco de perda total"]
    N4 --> B2["🔴 Sem Ingress\nport-forward manual\nfrágil e temporário"]
    N4 --> B3["🔴 Credenciais\nem texto plano\nDB_PASSWORD exposto\nnos manifests"]
```

---

## 5. Prioridade de Melhorias

```mermaid
quadrantChart
    title Melhorias — Impacto vs Urgência
    x-axis Baixa Urgência --> Alta Urgência
    y-axis Baixo Impacto --> Alto Impacto
    quadrant-1 Fazer Agora
    quadrant-2 Planejar
    quadrant-3 Avaliar
    quadrant-4 Monitorar
    PVC para Postgres: [0.85, 0.95]
    Ingress Controller: [0.80, 0.85]
    Secrets p/ Credenciais: [0.75, 0.90]
    Metrics Server: [0.60, 0.70]
    Replicas kube-news x2: [0.55, 0.75]
    HPA: [0.45, 0.65]
    AntiAffinity Workers: [0.40, 0.60]
    NetworkPolicy: [0.30, 0.55]
    ResourceQuota: [0.25, 0.40]
    PodDisruptionBudget: [0.20, 0.45]
```

---

## 6. Sequência de Inicialização dos Pods

Mostra a ordem de startup e o motivo dos 2 restarts do kube-news.

```mermaid
sequenceDiagram
    participant K8s as Kubernetes Scheduler
    participant PG as Pod: postgres
    participant APP as Pod: kube-news
    participant PROBE as Startup Probe

    K8s->>PG: Schedule → desktop-worker2
    K8s->>APP: Schedule → desktop-worker2
    PG-->>PG: pg_isready (startup delay 5s)
    APP-->>PROBE: GET /health (delay 10s)
    PROBE-->>APP: ❌ FAIL (postgres ainda iniciando)
    APP-->>APP: restart #1
    APP-->>PROBE: GET /health (delay 10s)
    PROBE-->>APP: ❌ FAIL (postgres ainda iniciando)
    APP-->>APP: restart #2
    PG-->>PG: ✅ pg_isready OK — postgres pronto
    APP-->>PROBE: GET /health (delay 10s)
    PROBE-->>APP: ✅ OK
    APP-->>APP: Running (estável)
```

---

## Como renderizar

| Ferramenta | Como usar |
|---|---|
| **GitHub** | Abra `diagrama-palestra.md` — renderiza automaticamente |
| **VS Code** | Extensão [Mermaid Preview](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-mermaid) |
| **Obsidian** | Suporte nativo a blocos `mermaid` |
| **CLI (export PNG/SVG)** | `npx mmdc -i diagrama-palestra.md -o diagrama-palestra.png` |
