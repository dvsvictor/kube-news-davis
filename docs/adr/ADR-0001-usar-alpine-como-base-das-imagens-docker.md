# ADR-0001 — Usar Alpine Linux como base das imagens Docker

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O `src/Dockerfile` da aplicação Kube-News precisava de uma imagem base para Node.js 18. Em
um ambiente com pipeline de CI/CD (`.github/workflows/ci-cd.yml`) onde build e push acontecem
a cada commit, o tamanho da imagem afeta diretamente o tempo de build, o tempo de pull no
cluster e a superfície de ataque — mais pacotes instalados significam mais vulnerabilidades
potenciais. O cluster local (Docker Desktop) também se beneficia de imagens menores por
consumir menos armazenamento no host.

## Decisão

Decidimos usar `node:18-alpine` como imagem base (`src/Dockerfile:1`). Alpine Linux usa
musl libc e busybox, resultando em imagem final de ~80MB contra ~900MB da variante Debian
completa. Todos os recursos necessários — Node.js, npm e `wget` (para o `HEALTHCHECK`) —
estão disponíveis no Alpine sem configuração adicional. O usuário não-root (`appuser`) é
criado via `addgroup`/`adduser` do Alpine sem dependências extras.

## Consequências

### Positivas
- Imagem de produção ~10x menor (~80MB vs ~900MB Debian)
- Pull mais rápido no cluster e no pipeline CI/CD
- Superfície de ataque reduzida — menos pacotes instalados
- Build mais rápido no GitHub Actions

### Negativas (trade-offs aceitos)
- musl libc pode causar incompatibilidades com módulos npm que compilam código nativo em C++
- Shell disponível é `sh`, não `bash` — scripts de debug devem usar sintaxe POSIX
- Ferramentas de diagnóstico comuns (`curl`, `ps` completo) não estão instaladas por padrão

### Neutras
- O `HEALTHCHECK` usa `wget` em vez de `curl` — ambos funcionam; `wget` está presente no Alpine por padrão

## Alternativas Consideradas

### Alternativa 1: node:18 (Debian Bullseye)
Imagem oficial completa com todas as ferramentas GNU.
**Por que descartada:** tamanho ~900MB é inaceitável para um pipeline onde build e pull
acontecem a cada commit. O projeto usa apenas dependências Node.js puras — sem módulos
nativos com compilação C++ — o que elimina a principal vantagem do Debian.

### Alternativa 2: node:18-slim
Debian reduzido, ~200MB.
**Por que descartada:** ainda 2.5x maior que Alpine sem benefício concreto para este projeto.
Alpine é suficiente e mais alinhado com a prática de segurança de containers mínimos.

### Alternativa 3: gcr.io/distroless/nodejs18
Sem shell, sem gerenciador de pacotes — apenas o runtime Node.js.
**Por que descartada:** impossibilita a execução de `npm ci` durante o build e dificulta
diagnóstico em desenvolvimento. Adequado para produção matura com equipe dedicada a
containers, mas adiciona complexidade desnecessária para este projeto de demonstração.

## Referências
- `src/Dockerfile:1` — `FROM node:18-alpine`
