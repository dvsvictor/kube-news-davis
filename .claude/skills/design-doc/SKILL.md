---
name: design-doc
description: >
  Use esta skill SEMPRE que o usuário pedir para criar documentação técnica, registrar uma decisão
  arquitetural, escrever um ADR, criar um RFC, fazer um design doc, documentar o projeto, documentar
  um componente, registrar "por que usamos X", "como decidimos Y", "proposta de mudança em Z",
  "arquitetura do sistema", "documenta isso", "escreve a decisão", "quero propor uma mudança",
  "design doc do ingress", "ADR para o banco", "RFC para o pipeline", ou qualquer variante que
  envolva registrar conhecimento técnico, decisões ou propostas de forma estruturada.
  Suporta três formatos: ADR (decisão já tomada), RFC (proposta em revisão) e Google Design Doc
  (documentação de sistema/componente). Ative mesmo que o usuário não mencione o tipo — se a
  intenção for registrar conhecimento técnico do projeto, esta skill é o ponto de entrada.
version: 1.0.0
---

# Skill: design-doc

Guia a criação de documentação técnica de alta qualidade para o projeto Kube-News, seguindo
as práticas de ADR (Michael Nygard), RFC (estilo Rust/IETF) e Google Design Doc.

---

## Por que esta skill existe

Documentação técnica mal feita tem dois problemas clássicos: ou é vaga demais ("decidimos usar
Alpine por ser menor") sem registrar o raciocínio real, ou é genérica demais sem referenciar
o projeto concreto. Esta skill força o padrão certo: dados reais do repositório, alternativas
com argumentos de descarte, e Non-Goals explícitos para evitar scope creep futuro.

---

## Passo 1 — Identificar o tipo de documento

Se o usuário não especificou, escolha baseado na natureza do que está sendo documentado:

| Tipo | Quando usar | Pergunta diagnóstica |
|------|------------|---------------------|
| **ADR** | Decisão já tomada ou sendo finalizada | "Isso já foi decidido ou ainda está em avaliação?" |
| **RFC** | Proposta que precisa de revisão antes de implementar | "Há alternativas abertas? Outros precisam opinar?" |
| **Design Doc** | Documentação de um sistema, componente ou feature completa | "É um componente com múltiplas partes? Tem arquitetura?" |

Se ainda não estiver claro após a análise do contexto, pergunte diretamente ao usuário.

Leia o arquivo de referência correspondente antes de gerar:
- ADR → `references/adr-template.md`
- RFC → `references/rfc-template.md`
- Design Doc → `references/design-doc-template.md`

---

## Passo 2 — Coletar contexto do projeto

Antes de escrever uma linha do documento, leia os arquivos relevantes para basear o conteúdo
em dados reais. Nunca invente nomes de serviços, endpoints, imagens ou configurações.

Leitura obrigatória (sempre):
```
README.md
CLAUDE.md
k8s/deploy.yaml
```

Leitura condicional (conforme o tema):
```
docker-compose.yml          → decisões de ambiente dev
.github/workflows/ci-cd.yml → decisões de CI/CD
src/Dockerfile              → decisões de imagem
src/server.js               → endpoints e porta
k8s/secrets.yaml            → decisões de segurança
k8s/ingress.yaml            → decisões de acesso
endpoints.md                → contratos de API
```

Verifique também os ADRs e Design Docs já existentes para evitar duplicata e manter
numeração sequencial:
```bash
ls docs/adr/ 2>/dev/null || echo "(diretório ainda não existe)"
ls docs/rfc/ 2>/dev/null || echo "(diretório ainda não existe)"
ls docs/design/ 2>/dev/null || echo "(diretório ainda não existe)"
```

---

## Passo 3 — Fazer as perguntas certas

Não escreva o documento sem ter respostas para as perguntas mínimas do tipo. Pergunte ao
usuário de forma objetiva — uma pergunta por vez se o contexto já estiver claro, ou em bloco
se estiver começando do zero.

**Para ADR:**
- Qual foi a decisão exata?
- Quais alternativas foram consideradas e descartadas?
- Quais são as consequências negativas (o trade-off aceito)?

**Para RFC:**
- O que exatamente está sendo proposto?
- Por que agora (qual evento ou necessidade motivou)?
- Quais questões ainda não estão decididas?

**Para Design Doc:**
- Quais são os Non-Goals (o que explicitamente NÃO está no escopo)?
- Quem são os stakeholders ou usuários afetados?
- Quais são os critérios de sucesso mensuráveis?

---

## Passo 4 — Gerar o documento

Siga o template do arquivo de referência correspondente. Algumas diretrizes transversais:

**Idioma e tom:** português, direto, técnico. Sem jargão vago ("melhor", "eficiente",
"robusto") — use dados concretos ("reduz o tamanho da imagem de 900MB para 80MB").

**Diagramas Mermaid:** inclua sempre que o documento envolver fluxos de dados, arquitetura
ou sequências de chamadas. Use `flowchart TD` para arquitetura, `sequenceDiagram` para
interações, `flowchart LR` para comparações.

**Alternativas consideradas:** cada alternativa descartada precisa de um argumento de
descarte claro e honesto — não é para dizer que a alternativa é ruim, mas para registrar
por que não se encaixa *neste contexto*.

**Non-Goals:** toda documentação precisa de Non-Goals explícitos. Eles previnem que o
documento seja usado para justificar coisas que não foram decididas.

**Referências a arquivos reais:** use caminhos relativos ao repositório (`k8s/deploy.yaml:44`,
`src/server.js:12`) quando citar código ou configuração específica.

---

## Passo 5 — Salvar no diretório correto

Crie o diretório se não existir:

```bash
mkdir -p docs/adr     # para ADRs
mkdir -p docs/rfc     # para RFCs
mkdir -p docs/design  # para Design Docs
```

Nomes de arquivo:
- ADR: `docs/adr/ADR-NNNN-titulo-em-kebab-case.md` — NNNN = próximo número sequencial
- RFC: `docs/rfc/RFC-NNNN-titulo-em-kebab-case.md` — NNNN = próximo número sequencial
- Design Doc: `docs/design/nome-do-componente.md`

---

## Passo 6 — Atualizar o índice

Crie ou atualize `docs/INDEX.md` com uma linha para o novo documento:

```markdown
## ADRs
- [ADR-0001 — Título](adr/ADR-0001-titulo.md) — *Aceito* — resumo em uma linha
```

Se `docs/INDEX.md` não existir, crie com cabeçalho e seções para ADR, RFC e Design Doc.

---

## Passo 7 — Sugerir commit

Ao final, oriente o usuário a commitar usando a skill `git-commit-guard`:

> "Commit sugerido (crie uma branch `docs/<tipo>-<titulo>` antes):"
> ```bash
> git checkout -b docs/adr-0001-alpine-base
> git add docs/
> # a skill git-commit-guard vai compor a mensagem
> ```

---

## Resumo dos templates

| Tipo | Seções obrigatórias | Arquivo de referência |
|------|--------------------|-----------------------|
| ADR | Título, Status, Contexto, Decisão, Consequências, Alternativas | `references/adr-template.md` |
| RFC | Sumário, Motivação, Design Detalhado, Drawbacks, Alternativas, Questões em Aberto, Plano | `references/rfc-template.md` |
| Design Doc | Overview, Context, Goals/Non-Goals, Design, Alternativas, Segurança, Testing, Plano, Open Questions | `references/design-doc-template.md` |
