---
name: project-directives
description: >
  Diretrizes e boas práticas consolidadas do projeto Kube-News. Use esta skill
  sempre que o usuário pedir para criar, revisar ou atualizar qualquer
  infraestrutura do projeto: manifestos Kubernetes, arquivos Docker, novas
  skills, configurações de acesso local, pipelines CI/CD, ou qualquer decisão
  de arquitetura. Ative também quando o usuário perguntar "como fazemos X neste
  projeto", "qual o padrão aqui", "cria um manifesto", "adiciona um serviço",
  "cria uma skill para", ou qualquer variante que envolva criar ou modificar
  infraestrutura. Esta skill é o ponto de partida obrigatório — ela evita que
  decisões já tomadas e erros já corrigidos sejam repetidos.
---

# Diretrizes do Projeto — Kube-News

## Identidade do projeto

| Item | Valor |
|------|-------|
| App | Node.js 18 Alpine — `node:18-alpine` |
| Banco | PostgreSQL 15 Alpine — `postgres:15-alpine` |
| Porta da app | **8080** (definida em `server.js`, espelhada no Dockerfile) |
| Usuário no container | `appuser` (não-root, criado no Dockerfile) |
| Cluster local | Docker Desktop multi-node (kind) — contexto `docker-desktop` |

---

## Parte 1 — Analisar um projeto antes de criar infraestrutura

Antes de gerar qualquer manifesto ou Dockerfile, sempre colete:

1. **Runtime e versão** — checar `Dockerfile` (linha `FROM`) ou `package.json`/`pom.xml`/`requirements.txt`
2. **Porta real** — buscar no código-fonte (`app.listen`, `server.listen`, `EXPOSE`) — nunca assumir
3. **Variáveis de ambiente** — verificar em ordem: `.env.example` → `docker-compose.yml` → código-fonte (`process.env.*`)
4. **Dependências externas** — banco, cache, fila — identificar via docker-compose ou imports no código
5. **Endpoints de health** — procurar `/health`, `/ready`, `/ping`, `/actuator/health` — eles definem as probes do Kubernetes

Para este projeto os valores já estão definidos:

```
DB_HOST        → nome do Service postgres no cluster
DB_PORT        → 5432
DB_DATABASE    → kubedevnews
DB_USERNAME    → kubedevnews
DB_PASSWORD    → Pg#123  (mover para Secret antes de produção)
DB_SSL_REQUIRE → false
```

---

## Parte 2 — Padrões de manifesto Kubernetes

### Regras obrigatórias

**Tipos de resource:** usar apenas `Deployment` e `Service` salvo solicitação explícita.

**Ordem no arquivo:** dependências primeiro (banco, cache), aplicação principal por último. Isso é relevante para legibilidade — o Kubernetes aplica tudo em paralelo de qualquer forma.

**Labels consistentes em todos os recursos:**
```yaml
labels:
  app: kube-news
  component: db      # ou: app, cache, worker
```

**Imagem nunca com `:latest`** — sempre versão semântica ou SHA:
```yaml
image: kube-news:1.0.0          # local / Docker Desktop
image: ghcr.io/org/kube-news:abc1234   # registry externo
```
No Docker Desktop, imagens buildadas com `docker build` ficam disponíveis ao cluster automaticamente (`imagePullPolicy: IfNotPresent`).

**Portas nomeadas** — referenciar pelo nome, não pelo número, para maior robustez:
```yaml
ports:
  - name: http
    containerPort: 8080
# e no Service:
targetPort: http   # não: targetPort: 8080
```

### Template de Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <nome>
  labels:
    app: kube-news
    component: <componente>
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kube-news
      component: <componente>
  template:
    metadata:
      labels:
        app: kube-news
        component: <componente>
    spec:
      containers:
        - name: <nome>
          image: <imagem>:<tag>
          imagePullPolicy: IfNotPresent
          ports:
            - name: <nome-porta>
              containerPort: <porta>
          env: [...]
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"    # 256Mi para banco
            limits:
              cpu: "500m"
              memory: "256Mi"    # 512Mi para banco
          startupProbe: [...]
          readinessProbe: [...]
          livenessProbe: [...]
```

### Template de Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <nome>
  labels:
    app: kube-news
    component: <componente>
spec:
  type: ClusterIP          # padrão — ver seção de acesso local
  selector:
    app: kube-news
    component: <componente>
  ports:
    - name: <nome-porta>
      port: <porta-service>
      targetPort: <nome-porta>
```

### Probes — padrão para este projeto

**Aplicação Node.js** (alinhado com o `HEALTHCHECK` do Dockerfile):
```yaml
startupProbe:            # aguarda banco ficar pronto — substitui depends_on do compose
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 12   # 12 × 10s = 120s total para app + banco subirem

readinessProbe:          # usa /ready — controlado por /unreadyfor/:seconds
  httpGet:
    path: /ready
    port: http
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

livenessProbe:           # espelha --interval=30s --timeout=5s --start-period=10s --retries=3
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3
```

**PostgreSQL** (espelha o `healthcheck` do docker-compose):
```yaml
startupProbe:
  exec:
    command: ["pg_isready", "-U", "kubedevnews", "-d", "kubedevnews"]
  initialDelaySeconds: 5
  periodSeconds: 6
  failureThreshold: 10   # 60s para cold start

readinessProbe:
  exec:
    command: ["pg_isready", "-U", "kubedevnews", "-d", "kubedevnews"]
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 5    # espelha retries: 5 do compose

livenessProbe:
  exec:
    command: ["pg_isready", "-U", "kubedevnews", "-d", "kubedevnews"]
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3
```

---

## Parte 3 — Acesso local ao cluster (Docker Desktop kind)

### O problema

Este cluster usa nós kind em rede Docker interna (`172.18.0.x`), isolada do macOS.
`NodePort` e `LoadBalancer` atribuem IPs nessa rede — inacessíveis do host.

| Tipo de Service | Funciona do Mac? |
|-----------------|-----------------|
| ClusterIP | não |
| NodePort | não — IP `172.18.0.x` não roteável |
| LoadBalancer | não — mesmo problema |
| `kubectl port-forward` | **sim** |

### Solução: port-forward via launchd

O agente launchd já está configurado em:
`~/Library/LaunchAgents/dev.kube-news.portforward.plist`

Ele sobe automaticamente no login e reinicia se morrer (`KeepAlive: true`).

**Acesso:** http://localhost:8080

**Controle:**
```bash
launchctl list | grep kube-news            # ver status
launchctl unload ~/Library/LaunchAgents/dev.kube-news.portforward.plist  # parar
launchctl load  ~/Library/LaunchAgents/dev.kube-news.portforward.plist   # iniciar
tail -f /tmp/kube-news-portforward.log     # ver log
```

**Ao adicionar novo serviço** que precisa de acesso local — criar novo plist com label e porta diferentes. Não reutilizar o mesmo arquivo.

---

## Parte 4 — Erros conhecidos e soluções

| Erro | Causa | Solução |
|------|-------|---------|
| `InvalidImageName` | Nome de imagem com `<>` (ex: `<REGISTRY>/app:<TAG>`) | Substituir por nome válido: `app:1.0.0` ou `ghcr.io/org/app:sha` |
| `ErrImagePull` / `ImagePullBackOff` | Download interrompido (EOF) | `docker pull <imagem>` + `kubectl rollout restart deployment/<nome>` |
| `CrashLoopBackOff` (app) | Banco não estava pronto quando startupProbe verificou | Aumentar `failureThreshold` da startupProbe ou aguardar estabilização |
| `ENDPOINTS <none>` no Service | Selector não bate com labels do pod | Conferir labels do Deployment vs selector do Service |
| Port-forward cai após fechar terminal | `&` simples sem nohup não persiste | Usar agente launchd ou `nohup ... &` |
| `password authentication failed` | Secret desatualizado ou env errada | `kubectl exec deployment/kube-news -- env \| grep DB_` para verificar |

---

## Parte 5 — Padrão de skills por domínio

Skills deste projeto ficam em `.claude/skills/<nome>/SKILL.md`.

| Skill | Domínio | Quando usar |
|-------|---------|-------------|
| `docker-devops` | Docker Compose | Subir ambiente, troubleshoot, build, CI/CD |
| `postgres-k8s` | PostgreSQL no K8s | psql, queries, logs, secrets, conectividade |
| `project-directives` | Esta skill | Criar/revisar qualquer infraestrutura do projeto |

**Ao criar nova skill:**
- Description deve ser "pushy" — incluir exemplos de frases que disparam
- Incluir a tabela de variáveis de ambiente relevantes ao domínio
- Referenciar as outras skills quando os domínios se cruzam
- Manter abaixo de 500 linhas; usar `references/` para conteúdo extenso

---

## Parte 6 — Checklist para novos manifestos

Antes de entregar um manifesto, verificar:

- [ ] Imagem com tag versionada (sem `:latest`)
- [ ] `imagePullPolicy: IfNotPresent` no Deployment da app
- [ ] Labels `app` e `component` consistentes em Deployment e Service
- [ ] Portas nomeadas (`name:`) e `targetPort` referenciando o nome
- [ ] `startupProbe` na app (para aguardar dependências)
- [ ] Probes da app apontando para `/health` (liveness) e `/ready` (readiness)
- [ ] `DB_PASSWORD` marcado com comentário `⚠️ mover para Secret`
- [ ] Ordem do arquivo: dependências → aplicação
- [ ] Service tipo `ClusterIP` (padrão) com explicação se outro tipo for necessário
- [ ] Comando `kubectl apply -f k8s/deploy.yaml` documentado
