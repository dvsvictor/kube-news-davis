# Diagramas — Kube-News na AWS

---

## Diagrama 1 — Arquitetura Geral (Visão de Camadas)

```mermaid
flowchart TB
    subgraph INTERNET["☁️ Internet"]
        USER["👤 Usuário"]
    end

    subgraph AWS["AWS — VPC Dedicada"]
        subgraph PUBLICA["Camada Pública (Subnet Pública Multi-AZ)"]
            R53["🌐 Route 53\nDNS Gerenciado"]
            ALB["⚖️ Application Load Balancer\nHTTPS/443 · ACM SSL · Health Check"]
        end

        subgraph APP["Camada de Aplicação (Subnet Privada)"]
            ECSAZ1["🐳 ECS Fargate\nTask — AZ-a\n0.5 vCPU / 1 GB"]
            ECSAZ2["🐳 ECS Fargate\nTask — AZ-b\n0.5 vCPU / 1 GB"]
            AS["📈 Auto Scaling\nCPU > 70%"]
        end

        subgraph DADOS["Camada de Dados (Subnet Privada)"]
            RDSM["🗄️ RDS PostgreSQL\nPrimary — AZ-a"]
            RDSS["🗄️ RDS PostgreSQL\nStandby — AZ-b\n(failover ~60s)"]
        end

        subgraph SUPORTE["Serviços de Suporte"]
            ECR["📦 Amazon ECR\nImagens Docker"]
            SM["🔐 Secrets Manager\nCredenciais"]
            CW["📋 CloudWatch Logs\nLogs Centralizados"]
            ACM["🔒 ACM\nSSL Gratuito"]
        end
    end

    USER -->|HTTPS| R53
    R53 --> ALB
    ALB -->|AZ-a| ECSAZ1
    ALB -->|AZ-b| ECSAZ2
    ECSAZ1 <-->|Auto Scaling| AS
    ECSAZ2 <-->|Auto Scaling| AS
    ECSAZ1 --> RDSM
    ECSAZ2 --> RDSM
    RDSM -.->|Replicação Síncrona| RDSS
    ECSAZ1 --- ECR
    ECSAZ2 --- ECR
    ECSAZ1 --- SM
    ECSAZ2 --- SM
    ECSAZ1 --- CW
    ECSAZ2 --- CW
    ALB --- ACM

    style INTERNET fill:#e3f2fd,stroke:#1565c0
    style PUBLICA fill:#e8f5e9,stroke:#2e7d32
    style APP fill:#fff3e0,stroke:#e65100
    style DADOS fill:#fce4ec,stroke:#880e4f
    style SUPORTE fill:#f3e5f5,stroke:#6a1b9a
```

---

## Diagrama 2 — Pipeline CI/CD (GitHub Actions)

```mermaid
flowchart LR
    DEV["👨‍💻 Desenvolvedor\ngit push"] --> GH["🐙 GitHub\nRepositório"]
    GH -->|Trigger| GA["⚙️ GitHub Actions\nWorkflow"]

    subgraph PIPELINE["Pipeline Automatizado"]
        BUILD["🔨 Build\nImagem Docker"]
        TEST["✅ Testes\n& Lint"]
        PUSH["📤 Push\npara ECR"]
        DEPLOY["🚀 Deploy\nECS Rolling Update"]
        HC["🩺 Health Check\n/health · /ready"]
    end

    GA --> BUILD
    BUILD --> TEST
    TEST --> PUSH
    PUSH --> DEPLOY
    DEPLOY --> HC

    HC -->|✅ Saudável| LIVE["🌐 Nova Versão\nAtiva (Zero Downtime)"]
    HC -->|❌ Falhou| ROLLBACK["🔄 Mantém Versão\nAnterior no ALB"]

    style PIPELINE fill:#e8f5e9,stroke:#2e7d32
    style LIVE fill:#c8e6c9,stroke:#1b5e20
    style ROLLBACK fill:#ffcdd2,stroke:#b71c1c
```

---

## Diagrama 3 — Comportamento de Failover

```mermaid
flowchart TD
    subgraph FALHAS["Cenários de Falha → Resposta Automática"]
        F1["💥 Task ECS com falha"]
        F2["💥 Zona de\nDisponibilidade cai"]
        F3["💥 RDS Primary\ncom falha"]
        F4["💥 Deploy com\nerro no health check"]

        R1["♻️ ECS reinicia\na task em segundos"]
        R2["↩️ ALB redireciona\n100% para AZ saudável"]
        R3["⚡ Failover automático\npara Standby (~60s)"]
        R4["🔄 ALB mantém versão\nanterior ativa"]

        F1 --> R1
        F2 --> R2
        F3 --> R3
        F4 --> R4
    end

    style FALHAS fill:#fff8e1,stroke:#f57f17
```

---

## Diagrama 4 — Comparativo de Custo e Complexidade

```mermaid
quadrantChart
    title Custo vs Complexidade Operacional
    x-axis "Baixa Complexidade" --> "Alta Complexidade"
    y-axis "Menor Custo" --> "Maior Custo"
    quadrant-1 Caro e Complexo
    quadrant-2 Caro mas Simples
    quadrant-3 Barato mas Complexo
    quadrant-4 Barato e Simples
    ECS Fargate (proposta): [0.2, 0.42]
    Elastic Beanstalk: [0.45, 0.35]
    EC2 Auto-gerenciado: [0.85, 0.28]
    EKS Kubernetes: [0.9, 0.75]
```

---

## Diagrama 5 — Cronograma de Implementação (6 Semanas)

```mermaid
gantt
    title Cronograma de Implementação — Kube-News AWS
    dateFormat  YYYY-MM-DD
    axisFormat  Sem %W

    section Fase 1 · Infraestrutura
    VPC + Subnets                    :f1a, 2026-05-18, 2d
    RDS PostgreSQL Multi-AZ          :f1b, after f1a, 1d
    Secrets Manager                  :f1c, after f1b, 1d
    ECR + Políticas                  :f1d, after f1b, 1d
    ALB + ACM + Health Checks        :f1e, after f1c, 2d
    Route 53 + DNS                   :f1f, after f1e, 1d

    section Fase 2 · Containerização
    Dockerfile + Validação Local     :f2a, 2026-06-01, 2d
    Remoção de Credenciais Hardcoded :f2b, after f2a, 1d
    Proteção Endpoints de Chaos      :f2c, after f2b, 1d
    Migrations Controladas           :f2d, after f2c, 2d
    ECS Task Definition + Service    :f2e, after f2b, 2d
    Teste de Failover                :f2f, after f2e, 1d

    section Fase 3 · Automação & Segurança
    Pipeline GitHub Actions CI/CD    :f3a, 2026-06-15, 2d
    ECS Auto Scaling                 :f3b, after f3a, 1d
    CloudWatch Logs (30 dias)        :f3c, after f3a, 1d
    AWS WAF no ALB                   :f3d, after f3b, 1d
    Teste de Carga                   :f3e, after f3c, 1d
    Teste Failover RDS               :f3f, after f3e, 1d
    Documentação + Handoff           :f3g, after f3f, 1d
```

---

## Diagrama 6 — Custos Mensais por Serviço

```mermaid
pie title Custo Mensal Estimado — ~USD 94,73
    "ECS Fargate (containers)" : 35.94
    "RDS PostgreSQL Multi-AZ" : 26.28
    "Application Load Balancer" : 28.22
    "Secrets Manager" : 2.00
    "CloudWatch Logs" : 1.59
    "Route 53" : 0.50
    "Amazon ECR" : 0.20
```
