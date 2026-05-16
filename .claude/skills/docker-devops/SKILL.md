---
name: docker-devops
description: >
  Skill de DevOps Docker para o projeto Kube-News. Use esta skill sempre que o
  usuário mencionar containers, Docker, docker-compose, problemas para subir o
  ambiente, adicionar serviços, fazer build de imagem, configurar pipeline CI/CD,
  push para registry, troubleshoot de container, logs, variáveis de ambiente,
  volumes, healthcheck, ou qualquer tarefa relacionada à infraestrutura Docker
  do projeto. Ative mesmo que o usuário use linguagem informal como "sobe o
  ambiente", "o container travou", "como faço deploy", "adiciona um banco de
  cache", "preciso de uma imagem de produção", etc.
---

# Docker DevOps — Kube-News

## Contexto do projeto

O Kube-News é uma aplicação de notícias em **Node.js 18 + PostgreSQL 15**, containerizada com Docker.

### Serviços (docker-compose.yml)

| Serviço | Imagem | Porta | Função |
|---------|--------|-------|--------|
| `app`   | build local (`src/Dockerfile`) | 8080 | API + frontend Node.js |
| `db`    | `postgres:15-alpine` | — (interno) | Banco de dados |

### Variáveis de ambiente da aplicação

```
DB_HOST=db           DB_PORT=5432
DB_DATABASE=kubedevnews
DB_USERNAME=kubedevnews
DB_PASSWORD=Pg#123
DB_SSL_REQUIRE=false
```

### Endpoints úteis

| Endpoint | Método | Para que serve |
|----------|--------|----------------|
| `/health` | GET | Estado da app (liveness) |
| `/ready`  | GET | App pronta para tráfego (readiness) |
| `/metrics` | GET | Métricas Prometheus |
| `/unhealth` | PUT | Simula falha (chaos) |
| `/unreadyfor/:s` | PUT | Simula indisponibilidade por N segundos |

---

## Comandos essenciais do dia a dia

### Subir o ambiente de desenvolvimento

```bash
docker compose up -d          # sobe em background
docker compose logs -f app    # acompanha logs da app
docker compose logs -f db     # acompanha logs do banco
```

O ambiente de dev usa **hot-reload via nodemon** — editar arquivos em `src/` reflete automaticamente no container.

### Parar e limpar

```bash
docker compose down           # para os containers (mantém volumes)
docker compose down -v        # para E apaga volumes (reseta o banco)
```

### Rebuild após mudança no Dockerfile ou package.json

```bash
docker compose build app      # rebuilda só a imagem da app
docker compose up -d --build  # rebuilda e sobe tudo
```

### Acessar o banco diretamente

```bash
docker compose exec db psql -U kubedevnews -d kubedevnews
```

### Verificar saúde dos serviços

```bash
docker compose ps             # status de cada serviço
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

---

## Troubleshoot: container não sobe

Siga este roteiro na ordem:

1. **Ver o que aconteceu**
   ```bash
   docker compose ps
   docker compose logs app --tail=50
   docker compose logs db --tail=50
   ```

2. **Checar dependência de saúde** — a `app` depende do `db` estar `healthy`. Se o banco não passa no healthcheck, a app não inicia.
   ```bash
   docker inspect kube-news-davis-db-1 | grep -A5 Health
   ```

3. **Problemas comuns e soluções**

   | Sintoma | Causa provável | Solução |
   |---------|---------------|---------|
   | `ECONNREFUSED` ao conectar no banco | `db` ainda inicializando | Aguardar healthcheck ou aumentar `retries` no compose |
   | `npm ERR!` no start | `node_modules` corrompidos | `docker compose down -v && docker compose up -d` |
   | Porta 8080 em uso | Outro processo usando a porta | `lsof -i :8080` para identificar e matar |
   | Container reiniciando em loop | Erro na aplicação | `docker compose logs app --tail=100` para ver o erro |
   | Permissão negada em volume | Conflito de usuário (appuser) | Ver seção de permissões abaixo |

4. **Reset completo** (último recurso)
   ```bash
   docker compose down -v
   rm -rf .docker_vol/
   docker compose up -d
   ```

### Problema de permissões em volume

O Dockerfile cria `appuser` (não-root). Se o volume montado em `/app/node_modules` tiver dono diferente:

```bash
# Ver dono dos arquivos no container
docker compose exec app ls -la /app

# Forçar rebuild sem cache para recriar node_modules limpo
docker compose build --no-cache app
docker compose up -d
```

---

## Adicionar um novo serviço ao docker-compose

Ao adicionar um serviço (ex: Redis, Nginx, outro banco), siga este padrão:

```yaml
services:
  novo-servico:
    image: <imagem>:<tag-fixa>   # sempre fixe a versão, nunca use :latest
    restart: unless-stopped
    environment:
      VAR: valor
    healthcheck:
      test: [...]
      interval: 10s
      timeout: 5s
      retries: 5
```

**Boas práticas:**
- Sempre defina `restart: unless-stopped` para resiliência
- Adicione healthcheck em todo serviço que outros dependem
- Use `depends_on: condition: service_healthy` na `app` para novos backends
- Adicione variáveis de conexão na seção `environment` da `app`
- Documente a nova variável na tabela de variáveis do README

**Exemplo — adicionando Redis:**

```yaml
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    # ... existente ...
    environment:
      REDIS_HOST: redis
      REDIS_PORT: 6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
```

---

## Build de imagem de produção e CI/CD

### Build local da imagem de produção

```bash
# Build simples
docker build -t kube-news:latest ./src

# Build com tag versionada (boa prática)
docker build -t kube-news:1.0.0 ./src

# Verificar a imagem gerada
docker images kube-news
docker run --rm kube-news:1.0.0 node --version
```

### Pipeline CI/CD sugerido (GitHub Actions)

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

      - name: Login no registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build e push
        uses: docker/build-push-action@v5
        with:
          context: ./src
          push: true
          tags: |
            ghcr.io/${{ github.repository }}/kube-news:latest
            ghcr.io/${{ github.repository }}/kube-news:${{ github.sha }}

      - name: Smoke test
        run: |
          docker run -d --name test-app \
            -e DB_HOST=localhost -e DB_PORT=5432 \
            -e DB_DATABASE=test -e DB_USERNAME=test \
            -e DB_PASSWORD=test -e DB_SSL_REQUIRE=false \
            -p 8080:8080 \
            ghcr.io/${{ github.repository }}/kube-news:${{ github.sha }}
          sleep 5
          curl -f http://localhost:8080/health || exit 1
          docker stop test-app
```

### Boas práticas para a imagem de produção

O Dockerfile já segue boas práticas:
- Base Alpine (imagem mínima)
- Usuário não-root (`appuser`)
- `npm ci --omit=dev` (sem devDependencies)
- HEALTHCHECK embutido

O que **não** fazer na imagem de produção:
- Não monte `./src:/app` em produção (isso sobrescreve o código empacotado)
- Não exponha variáveis com senhas em `docker inspect` — use secrets
- Não use `:latest` como tag em deploy — sempre use SHA ou versão semântica

---

## Dicas rápidas

```bash
# Ver uso de recursos dos containers
docker stats

# Entrar no container da app para debug
docker compose exec app sh

# Copiar arquivo do container para o host
docker compose cp app:/app/package.json ./package.json

# Ver camadas da imagem (tamanho)
docker history kube-news:latest
```
