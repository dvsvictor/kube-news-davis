# Proposta de Arquitetura Cloud — Kube-News na AWS

**Versão:** 1.0
**Data:** 16 de maio de 2026
**Destinatários:** Equipe de Negócio e Diretoria
**Elaborado por:** Equipe de Engenharia

---

## 1. Resumo

Este documento apresenta a proposta de arquitetura cloud para hospedar a aplicação **Kube-News** — portal de notícias desenvolvido em Node.js — na Amazon Web Services (AWS). A solução adota o modelo de containers gerenciados com **Amazon ECS Fargate**, banco de dados relacional gerenciado via **Amazon RDS PostgreSQL Multi-AZ** e balanceamento de carga com **Application Load Balancer (ALB)**, oferecendo alta disponibilidade, escalabilidade automática, segurança por design e custo proporcional ao uso real.

A arquitetura foi desenhada para eliminar a necessidade de gerenciamento de infraestrutura manual, garantir continuidade operacional em caso de falhas e permitir crescimento sem retrabalho estrutural.

**Custo estimado mensal: ~USD 90–110** para carga inicial, com escalonamento proporcional à demanda.

---

## 2. Problema

A aplicação Kube-News opera atualmente em ambiente local/experimental, sem infraestrutura adequada para produção. Os principais desafios identificados são:

- **Ausência de alta disponibilidade:** uma falha de servidor derruba a aplicação inteira.
- **Escalabilidade manual:** não há mecanismo para absorver picos de tráfego sem intervenção humana.
- **Segurança insuficiente:** credenciais de banco de dados estão embutidas no código-fonte, sem controle de acesso centralizado.
- **Ausência de pipeline de deploy:** cada atualização da aplicação requer intervenção manual e gera risco de indisponibilidade.
- **Sem observabilidade:** não há coleta de métricas, logs estruturados ou alertas operacionais em produção.

Esses fatores tornam inviável a operação do Kube-News em ambiente produtivo sem uma reformulação da infraestrutura.

---

## 3. Arquitetura Proposta

A solução é composta por serviços AWS gerenciados, organizados em três camadas: **pública**, **de aplicação** e **de dados** — todas dentro de uma VPC (rede privada virtual) dedicada.

### 3.1 Diagrama

```
                        INTERNET
                            │
                            ▼
                       [Route 53]
                     DNS gerenciado
                            │
                            ▼
              [Application Load Balancer]
               HTTPS/443 — certificado ACM
               subnet pública — Multi-AZ
                     │           │
                     ▼           ▼
           [ECS Fargate]   [ECS Fargate]
             Task – AZ-a     Task – AZ-b
           subnet privada   subnet privada
                ↕ Auto Scaling (CPU > 70%)
                            │
                            ▼
              [RDS PostgreSQL Multi-AZ]
             Primary (AZ-a) ──► Standby (AZ-b)
                       subnet privada

  ┌─────────────────────────────────────────┐
  │  SERVIÇOS DE SUPORTE                    │
  │  [ECR] Registro de imagens              │
  │  [Secrets Manager] Credenciais seguras  │
  │  [CloudWatch Logs] Centralização logs   │
  │  [ACM] Certificado SSL gratuito         │
  │  [GitHub Actions] Pipeline CI/CD        │
  └─────────────────────────────────────────┘
```

### 3.2 Componentes e responsabilidades

| Serviço AWS | Função |
|---|---|
| **Amazon ECS Fargate** | Execução dos containers da aplicação sem gerenciamento de servidores |
| **Amazon RDS PostgreSQL Multi-AZ** | Banco de dados relacional com failover automático entre zonas de disponibilidade |
| **Application Load Balancer (ALB)** | Distribuição de tráfego, health checks e terminação SSL |
| **Amazon ECR** | Armazenamento e versionamento das imagens Docker da aplicação |
| **AWS Secrets Manager** | Gerenciamento seguro de credenciais (senhas, strings de conexão) |
| **Amazon CloudWatch Logs** | Coleta e retenção centralizada de logs da aplicação |
| **AWS Certificate Manager (ACM)** | Certificado SSL/TLS gratuito com renovação automática |
| **Amazon Route 53** | DNS gerenciado com roteamento para o ALB |
| **GitHub Actions** | Pipeline de CI/CD: build → push ECR → deploy ECS |

### 3.3 Fluxo de deploy (CI/CD)

```
Desenvolvedor faz push no GitHub
         │
         ▼
GitHub Actions é acionado
         │
         ▼
Build da imagem Docker + push para ECR
         │
         ▼
Atualização do ECS Service (rolling update)
         │
         ▼
ALB valida /health e /ready antes de rotear tráfego
         │
         ▼
Nova versão ativa — zero downtime
```

### 3.4 Failover

| Componente | Comportamento em falha |
|---|---|
| Task ECS com falha | ECS reinicia automaticamente a task em segundos |
| AZ inteira indisponível | ALB redireciona 100% do tráfego para AZ saudável |
| RDS Primary com falha | Failover automático para Standby em ~60 segundos, transparente para a aplicação |
| Deploy com erro | ALB mantém versão anterior enquanto health check falhar na nova task |

---

## 4. Principais Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Falha de uma zona de disponibilidade AWS | Baixa | Alto | Arquitetura Multi-AZ em todas as camadas |
| Credenciais expostas em código-fonte | Alta (situação atual) | Crítico | Migração obrigatória para AWS Secrets Manager antes do go-live |
| Pico de tráfego não previsto | Média | Médio | Auto Scaling do ECS configurado com threshold de CPU em 70% |
| Falha no pipeline de deploy | Média | Médio | Rolling update com health check — versão anterior permanece ativa se nova falhar |
| Crescimento não planejado do banco de dados | Baixa | Médio | Storage do RDS com Auto Scaling habilitado |
| Acesso indevido a endpoints internos | Alta (sem proteção atual) | Médio | AWS WAF no ALB + autenticação nos endpoints sensíveis |

---

## 5. Custo

Estimativa baseada em **região us-east-1 (N. Virginia)**, configuração inicial para carga moderada, operação 24/7 (730 horas/mês). Todos os preços são obtidos diretamente das páginas e APIs oficiais de precificação da AWS.

### 5.1 Detalhamento mensal

| Serviço | Configuração | Preço unitário (oficial AWS) | Cálculo | Custo/mês |
|---|---|---|---|---|
| **ECS Fargate** | 2 tasks × 0,5 vCPU × 1 GB / 24h × 30d | $0,040478/vCPU-h + $0,004446/GB-h | (2 × 0,5 × $0,040478 × 730) + (2 × 1 × $0,004446 × 730) | **~$35,94** |
| **RDS PostgreSQL Multi-AZ** | db.t3.micro × 730h | $0,036/hora | $0,036 × 730 | **~$26,28** |
| **Application Load Balancer** | 1 ALB + uso leve (est. 2 LCUs) | $0,0225/hora + $0,008/LCU-h | ($0,0225 × 730) + (2 × $0,008 × 730) | **~$28,22** |
| **Amazon ECR** | ~2 GB de imagens armazenadas | $0,10/GB/mês | 2 × $0,10 | **~$0,20** |
| **AWS Secrets Manager** | 5 segredos | $0,40/segredo/mês | 5 × $0,40 | **~$2,00** |
| **CloudWatch Logs** | ~3 GB/mês ingestão + armazenamento | $0,50/GB ingestão · $0,03/GB armazenamento | (3 × $0,50) + (3 × $0,03) | **~$1,59** |
| **Amazon Route 53** | 1 zona hospedada | $0,50/zona/mês | $0,50 | **~$0,50** |
| **AWS Certificate Manager** | Certificado SSL público | Gratuito | — | **$0,00** |
| **ECR → ECS (transferência)** | Mesmo região | Gratuito | — | **$0,00** |
| **Total estimado** | | | | **~$94,73/mês** |

> **Nota sobre escalonamento:** Em cenários de alto tráfego com auto scaling ativo (4–6 tasks Fargate), o custo da camada de aplicação pode dobrar proporcionalmente, atingindo **USD 130–160/mês**. No Fargate, não há cobrança por capacidade ociosa — a redução de tasks diminui o custo automaticamente.

### 5.2 Comparativo com alternativas

| Arquitetura | Custo estimado/mês | Complexidade operacional |
|---|---|---|
| **ECS Fargate (proposta)** | ~$95 | Baixa |
| EKS (Kubernetes gerenciado) | ~$220–300 | Alta |
| EC2 auto-gerenciado | ~$60–80 | Muito alta |
| Elastic Beanstalk | ~$70–90 | Média |

> O ECS Fargate apresenta custo ligeiramente superior ao EC2/Beanstalk, porém elimina o overhead operacional de patching, provisionamento e gerenciamento de servidores — o que representa economia real de tempo de engenharia.

---

## 6. Cronograma de Implementação

### Fase 1 — Fundação de Infraestrutura (Semanas 1–2)

**Objetivo:** Criar a base de infraestrutura segura e funcional na AWS.

| Atividade | Responsável | Duração |
|---|---|---|
| Criação da VPC com subnets públicas e privadas | Engenharia Cloud | 2 dias |
| Provisionamento do RDS PostgreSQL Multi-AZ | Engenharia Cloud | 1 dia |
| Configuração do Secrets Manager com credenciais do banco | Engenharia Cloud | 1 dia |
| Criação do repositório ECR e políticas de acesso | Engenharia Cloud | 1 dia |
| Configuração do ALB com health checks e certificado ACM | Engenharia Cloud | 2 dias |
| Configuração do Route 53 e DNS | Engenharia Cloud | 1 dia |
| **Entregável:** Infraestrutura base validada, banco acessível, DNS resolvendo | | **~1 semana** |

### Fase 2 — Containerização e Deploy da Aplicação (Semanas 3–4)

**Objetivo:** Empacotar a aplicação, corrigir vulnerabilidades e realizar o primeiro deploy em produção.

| Atividade | Responsável | Duração |
|---|---|---|
| Criação do Dockerfile e validação local | Desenvolvimento | 2 dias |
| Remoção das credenciais hardcoded + integração com Secrets Manager | Desenvolvimento | 1 dia |
| Proteção dos endpoints de chaos (`/unhealth`, `/unreadyfor`) | Desenvolvimento | 1 dia |
| Substituição do `sync({ alter: true })` por migrations controladas | Desenvolvimento | 2 dias |
| Configuração da ECS Task Definition e Service | Engenharia Cloud | 2 dias |
| Teste de failover (derrubada manual de task e validação do ALB) | QA + Engenharia | 1 dia |
| **Entregável:** Aplicação rodando em produção com deploy manual validado | | **~1,5 semanas** |

### Fase 3 — Automação, Observabilidade e Hardening (Semanas 5–6)

**Objetivo:** Automatizar deploys, ativar monitoramento e finalizar endurecimento de segurança.

| Atividade | Responsável | Duração |
|---|---|---|
| Configuração do pipeline GitHub Actions (CI/CD completo) | Engenharia + DevOps | 2 dias |
| Configuração do ECS Auto Scaling (CPU threshold 70%) | Engenharia Cloud | 1 dia |
| Configuração do CloudWatch Logs com retenção definida (30 dias) | Engenharia Cloud | 1 dia |
| Configuração do AWS WAF no ALB | Segurança | 1 dia |
| Teste de carga para validação do auto scaling | QA | 1 dia |
| Teste de failover do RDS (simulação de queda do Primary) | QA + Engenharia | 1 dia |
| Documentação operacional e handoff para operações | Engenharia | 1 dia |
| **Entregável:** Ambiente produtivo completo, automatizado e monitorado | | **~1,5 semanas** |

### Resumo do cronograma

```
Semana 1    Semana 2    Semana 3    Semana 4    Semana 5    Semana 6
[══════════ FASE 1 ══════════][════════ FASE 2 ════════][════ FASE 3 ════]
Infraestrutura base          Containerização e deploy   Automação e segurança
```

**Prazo total estimado: 6 semanas**

---

## Referências

Todos os preços utilizados neste documento foram obtidos diretamente de fontes oficiais da Amazon Web Services:

- [AWS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [Amazon RDS Pricing API Oficial](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRDS/current/us-east-1/index.json)
- [Amazon RDS for PostgreSQL Pricing](https://aws.amazon.com/rds/postgresql/pricing/)
- [Elastic Load Balancing Pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)
- [Amazon ECR Pricing](https://aws.amazon.com/ecr/pricing/)
- [AWS Secrets Manager Pricing](https://aws.amazon.com/secrets-manager/pricing/)
- [Amazon CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/)
- [Amazon Route 53 Pricing](https://aws.amazon.com/route53/pricing/)
- [AWS Certificate Manager Pricing](https://aws.amazon.com/certificate-manager/pricing/)
