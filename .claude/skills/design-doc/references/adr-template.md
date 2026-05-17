# Template ADR — Architecture Decision Record

Baseado no formato de Michael Nygard com extensões da Thoughtworks.

Um ADR registra **uma única decisão arquitetural**: o que foi decidido, o contexto que tornou
essa decisão necessária, e as consequências (positivas e negativas) de tê-la tomado. O objetivo
não é convencer — é preservar o raciocínio para que decisões futuras possam questioná-la
conscientemente, não por ignorância.

---

## Template

```markdown
# ADR-NNNN — <Decisão em uma linha, verbo no infinitivo>

**Status:** Proposto | Aceito | Depreciado | Substituído por [ADR-MMMM](ADR-MMMM-titulo.md)
**Data:** AAAA-MM-DD
**Autor(es):** <nome(s)>

---

## Contexto

<Descreva a situação que tornou necessário tomar esta decisão. O que estava acontecendo?
Quais forças ou restrições estavam em jogo? Qual problema precisava ser resolvido?
Use dados concretos quando disponíveis.>

## Decisão

<Descreva a decisão tomada, de forma direta. Comece com "Decidimos usar/adotar/implementar..."
Explique o raciocínio principal — por que esta opção e não outra. Seja específico sobre
o que exatamente foi decidido, não apenas a direção geral.>

## Consequências

### Positivas
- <consequência positiva direta da decisão>
- <outra consequência positiva>

### Negativas (trade-offs aceitos)
- <consequência negativa ou limitação que aceitamos ao tomar essa decisão>
- <outra limitação>

### Neutras
- <mudança de comportamento ou processo que não é necessariamente boa ou ruim>

## Alternativas Consideradas

### Alternativa 1: <Nome>
<Descrição breve do que seria.>
**Por que descartada:** <argumento específico de por que não se encaixa neste contexto —
não é que seja ruim em geral, mas que não serve aqui por motivo X.>

### Alternativa 2: <Nome>
<Descrição breve.>
**Por que descartada:** <argumento.>

## Referências
- <link ou caminho de arquivo relevante>
- <documentação externa se aplicável>
```

---

## Exemplo preenchido — ADR-0001

```markdown
# ADR-0001 — Usar Alpine Linux como base das imagens Docker

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O Dockerfile da aplicação Kube-News (`src/Dockerfile`) precisava de uma imagem base para
Node.js 18. Imagens base mais pesadas aumentam o tempo de build, o tamanho do pull no cluster
e a superfície de ataque (mais pacotes = mais vulnerabilidades potenciais). Em um ambiente de
demonstração com pipeline de CI/CD (`.github/workflows/ci-cd.yml`), builds mais rápidos
reduzem o ciclo de feedback.

## Decisão

Decidimos usar `node:18-alpine` como imagem base do Dockerfile (`src/Dockerfile:1`).
Alpine Linux usa musl libc e busybox, resultando em imagens ~80MB versus ~900MB da imagem
Debian completa. A ausência de shell completo e pacotes desnecessários reduz a superfície
de ataque. Todos os pacotes necessários para o projeto (Node.js, npm, wget para healthcheck)
estão disponíveis no Alpine sem configuração adicional.

## Consequências

### Positivas
- Imagem de produção ~10x menor (~80MB vs ~900MB)
- Tempo de pull no cluster significativamente menor
- Superfície de ataque reduzida (menos pacotes instalados)
- Build mais rápido no pipeline GitHub Actions

### Negativas (trade-offs aceitos)
- musl libc pode causar incompatibilidades com alguns pacotes npm nativos
- Ausência de bash — scripts de debug devem usar sh
- Ferramentas de diagnóstico (curl, ps completo) não disponíveis por padrão no container

### Neutras
- Healthcheck usa `wget` em vez de `curl` (ambos disponíveis, wget presente no Alpine por padrão)

## Alternativas Consideradas

### Alternativa 1: node:18 (Debian Bullseye)
Imagem oficial completa com todas as ferramentas GNU.
**Por que descartada:** Tamanho ~900MB é inaceitável para um pipeline de CI/CD onde build
e pull acontecem a cada commit. A compatibilidade extra do Debian não é necessária pois
o projeto usa apenas dependências Node.js puras (sem módulos nativos com compilação C++).

### Alternativa 2: node:18-slim
Imagem Debian reduzida (~200MB).
**Por que descartada:** Ainda 2.5x maior que Alpine sem benefício concreto para este projeto.
Alpine é suficiente e mais alinhado com a prática de segurança de containers.

### Alternativa 3: Distroless (gcr.io/distroless/nodejs18)
Sem shell, sem gerenciador de pacotes — apenas o runtime.
**Por que descartada:** Impossibilita execução de `npm ci` durante o build e dificulta
diagnóstico em desenvolvimento. Adequado para produção madura, mas adiciona complexidade
desnecessária para um projeto de demonstração.

## Referências
- `src/Dockerfile:1` — FROM node:18-alpine
- Docker Hub: https://hub.docker.com/_/node (tags disponíveis)
```

---

## Status possíveis e quando usar cada um

| Status | Quando usar |
|--------|------------|
| **Proposto** | A decisão ainda não foi implementada ou está em revisão |
| **Aceito** | A decisão foi tomada e está em vigor |
| **Depreciado** | A decisão foi substituída mas o ADR é mantido por histórico |
| **Substituído por ADR-NNNN** | Há um ADR mais recente que reverte ou substitui este |

---

## ADRs sugeridos para o projeto Kube-News

Para inicializar a base de ADRs do projeto, os seguintes já têm decisões tomadas:

| Número | Título | Status |
|--------|--------|--------|
| ADR-0001 | Usar Alpine Linux como base das imagens Docker | Aceito |
| ADR-0002 | Usar ClusterIP + kubectl port-forward em vez de NodePort | Aceito |
| ADR-0003 | Usar Docker Hub como registry de imagens de produção | Aceito |
| ADR-0004 | Usar self-hosted runner para job de deploy no GitHub Actions | Aceito |
| ADR-0005 | Usar PersistentVolumeClaim para dados do PostgreSQL | Aceito |
| ADR-0006 | Usar namespace dedicado `kube-news` em vez do `default` | Aceito |
| ADR-0007 | Usar Kubernetes Secret para credenciais do banco | Aceito |
| ADR-0008 | Usar NGINX Ingress Controller para acesso externo | Aceito |
