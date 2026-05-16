# Kube-News

Portal de notícias desenvolvido em Node.js para demonstrar containerização e orquestração com Kubernetes.

## Tecnologias

| Camada | Tecnologia |
|--------|-----------|
| Runtime | Node.js 18 (Alpine) |
| Framework | Express.js |
| Templates | EJS |
| Banco de dados | PostgreSQL 15 (Alpine) |
| ORM | Sequelize |
| Métricas | Prometheus via express-prom-bundle |
| Container | Docker + Docker Compose |
| Orquestração | Kubernetes |

## Estrutura do projeto

```
/
├── src/                    # Código-fonte
│   ├── models/post.js      # Modelo de dados (Sequelize)
│   ├── views/              # Templates EJS
│   ├── static/             # CSS e imagens
│   ├── server.js           # Entrypoint — escuta na porta 8080
│   ├── system-life.js      # Endpoints de health e chaos
│   ├── middleware.js       # Middlewares customizados
│   ├── Dockerfile          # Imagem de produção (non-root, Alpine)
│   └── package.json
├── k8s/
│   └── deploy.yaml         # Manifestos Kubernetes (Deployment + Service)
├── popula-dados.http       # Requisições de exemplo para popular o banco
└── docker-compose.yml      # Ambiente de desenvolvimento com hot-reload
```

## Variáveis de ambiente

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `DB_HOST` | Host do PostgreSQL | `localhost` |
| `DB_PORT` | Porta do PostgreSQL | `5432` |
| `DB_DATABASE` | Nome do banco | `kubedevnews` |
| `DB_USERNAME` | Usuário do banco | `kubedevnews` |
| `DB_PASSWORD` | Senha do banco | `Pg#123` |
| `DB_SSL_REQUIRE` | Habilitar SSL | `false` |

## Execução

### 1. Local (Node.js)

**Pré-requisitos:** Node.js 18+, PostgreSQL 15 rodando localmente.

```bash
cd src
npm install
DB_HOST=localhost DB_PASSWORD=Pg#123 node server.js
```

Acesse: http://localhost:8080

---

### 2. Docker Compose (recomendado para desenvolvimento)

**Pré-requisitos:** Docker Desktop.

```bash
# Subir app + banco com hot-reload
docker compose up -d

# Acompanhar logs
docker compose logs -f app

# Parar (mantém dados)
docker compose down

# Parar e apagar dados
docker compose down -v
```

O código em `src/` é montado como volume — alterações refletem automaticamente sem rebuild.

Acesse: http://localhost:8080

---

### 3. Kubernetes

**Pré-requisitos:** cluster Kubernetes com `kubectl` configurado, imagem buildada localmente.

#### Buildar a imagem

```bash
docker build -t kube-news:1.0.0 ./src
```

> No Docker Desktop, a imagem fica disponível ao cluster automaticamente.  
> Para outros clusters, faça o push para um registry: `docker push <registry>/kube-news:1.0.0`  
> e atualize o campo `image:` no `k8s/deploy.yaml`.

#### Aplicar os manifestos

```bash
kubectl apply -f k8s/deploy.yaml
```

#### Verificar os pods

```bash
kubectl get pods -l app=kube-news
kubectl get services -l app=kube-news
```

#### Acessar a aplicação

O Service padrão é `ClusterIP`. Para expor localmente:

```bash
kubectl port-forward service/kube-news 8080:80
```

Acesse: http://localhost:8080

##### Acesso permanente (macOS — Docker Desktop com kind)

> Clusters kind no Docker Desktop usam rede interna isolada do macOS.  
> NodePort e LoadBalancer não são roteáveis diretamente pelo host.  
> Use um agente launchd para manter o port-forward ativo após reboot:

```bash
# Criar o agente
cat > ~/Library/LaunchAgents/dev.kube-news.portforward.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.kube-news.portforward</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/kubectl</string>
    <string>port-forward</string>
    <string>service/kube-news</string>
    <string>8080:80</string>
    <string>--namespace</string>
    <string>default</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>StandardOutPath</key>
  <string>/tmp/kube-news-portforward.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/kube-news-portforward.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>/Users/SEU_USUARIO</string>
    <key>KUBECONFIG</key>
    <string>/Users/SEU_USUARIO/.kube/config</string>
  </dict>
</dict>
</plist>
EOF

# Ativar
launchctl load ~/Library/LaunchAgents/dev.kube-news.portforward.plist
```

#### Popular o banco no cluster

```bash
kubectl exec deployment/postgres -- \
  psql -U kubedevnews -d kubedevnews -c "SELECT COUNT(*) FROM \"Posts\";"
```

---

## Build de produção e CI/CD

### Build e push manual

```bash
docker build -t kube-news:1.0.0 ./src
docker tag kube-news:1.0.0 ghcr.io/<seu-usuario>/kube-news:1.0.0
docker push ghcr.io/<seu-usuario>/kube-news:1.0.0
```

### Pipeline GitHub Actions

O repositório inclui suporte para pipeline CI/CD via GitHub Actions com build automático, push para `ghcr.io` e smoke test no `/health`.

Exemplo de pipeline em `.github/workflows/ci.yml`:

```yaml
name: CI/CD
on:
  push:
    branches: [main]
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: ./src
          push: true
          tags: |
            ghcr.io/${{ github.repository }}/kube-news:latest
            ghcr.io/${{ github.repository }}/kube-news:${{ github.sha }}
```

---

## Endpoints

### Aplicação

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/` | GET | Listagem de notícias |
| `/post` | GET | Formulário de criação |
| `/post` | POST | Criar notícia |
| `/post/:id` | GET | Visualizar notícia |
| `/api/post` | POST | Inserção em massa via JSON |

### Monitoramento

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/health` | GET | Liveness — retorna `{"state":"up","machine":"<hostname>"}` |
| `/ready` | GET | Readiness — retorna `200 Ok` ou `500` |
| `/metrics` | GET | Métricas Prometheus |

### Chaos Engineering

Úteis para testar probes de liveness/readiness e resiliência no Kubernetes:

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/unhealth` | PUT | Coloca a app em estado não saudável (todas as requests retornam 500) |
| `/unreadyfor/:seconds` | PUT | Simula indisponibilidade por N segundos (`/ready` retorna 500) |

```bash
# Simular falha de liveness
curl -X PUT http://localhost:8080/unhealth

# Simular indisponibilidade por 30 segundos
curl -X PUT http://localhost:8080/unreadyfor/30
```

---

## Modelo de dados

Tabela `Posts`:

| Campo | Tipo | Limite |
|-------|------|--------|
| `title` | String | 30 caracteres |
| `summary` | String | 50 caracteres |
| `content` | String | 2000 caracteres |
| `publishDate` | Date | — |

### Popular o banco com dados de exemplo

```bash
# Via Docker Compose
curl -s -X POST http://localhost:8080/api/post \
  -H "Content-Type: application/json" \
  -d @popula-dados.http

# Ou usar o arquivo .http com REST Client (VS Code)
```

---

## Recursos Kubernetes criados

O arquivo `k8s/deploy.yaml` cria os seguintes recursos:

| Recurso | Nome | Descrição |
|---------|------|-----------|
| Deployment | `postgres` | PostgreSQL 15 Alpine |
| Service | `postgres` | ClusterIP interno — resolvido como `DB_HOST=postgres` |
| Deployment | `kube-news` | Aplicação Node.js 18 Alpine |
| Service | `kube-news` | ClusterIP na porta 80 → container 8080 |

Probes configuradas:
- **startupProbe** na app: aguarda até 120s para o banco estar pronto (equivalente ao `depends_on: service_healthy` do Compose)
- **livenessProbe**: `GET /health` — alinhada ao `HEALTHCHECK` do Dockerfile
- **readinessProbe**: `GET /ready` — controlada pelos endpoints de chaos
