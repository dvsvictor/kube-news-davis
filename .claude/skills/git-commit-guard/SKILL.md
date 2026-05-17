---
name: git-commit-guard
description: >
  Use esta skill SEMPRE que o usuário pedir para fazer um commit, usar git commit, "commita isso",
  "salva as mudanças", "faz commit", "commitar", "registra", "sobe as mudanças", "push isso",
  "cria um commit", "gera um commit" ou qualquer variante de salvar/commitar mudanças no git.
  A skill garante que todo commit siga as regras do CLAUDE.md: nunca em main, branch com prefixo
  correto, mensagem em português no imperativo, sem arquivos sensíveis, Co-Authored-By no rodapé.
  Ative mesmo que o usuário não mencione explicitamente "commit" — se a intenção for persistir
  mudanças no repositório, esta skill é o ponto de entrada obrigatório.
version: 1.0.0
---

# Skill: git-commit-guard

Guarda de commits para o projeto Kube-News. Executa o fluxo completo de commit garantindo conformidade com o CLAUDE.md.

---

## Por que esta skill existe

O CLAUDE.md deste projeto define regras que, se ignoradas, causam problemas reais: commitar em `main` quebra o histórico compartilhado; arquivos sensíveis no histórico git são difíceis de remover; mensagens inconsistentes dificultam o `git log`. Esta skill torna as regras automáticas — o Claude não precisa ser lembrado a cada commit.

---

## Passo 1 — Verificar a branch atual

```bash
git branch --show-current
```

**Se o resultado for `main`:** interrompa imediatamente e diga ao usuário:

> "Você está em `main`. O CLAUDE.md proíbe commits diretos nessa branch. Crie uma branch antes de continuar:"
> ```bash
> git checkout -b <prefixo>/<nome-descritivo>
> ```
> Sugira um nome de branch baseado no que o usuário está fazendo (ex: `feat/add-ingress`, `fix/probe-timeout`).

Só avance para o próximo passo após o usuário mudar de branch.

---

## Passo 2 — Verificar o nome da branch

Prefixos válidos: `feat/`, `fix/`, `infra/`, `docs/`, `skill/`

Se a branch atual não começar com um desses prefixos, **avise** (não bloqueie):

> "A branch `<nome>` não segue a convenção do projeto (prefixos: feat/, fix/, infra/, docs/, skill/). Recomendo renomear antes de commitar:
> ```bash
> git branch -m <prefixo>/<nome-atual>
> ```
> Posso prosseguir com o commit mesmo assim se você preferir."

Aguarde a decisão do usuário.

---

## Passo 3 — Inspecionar o que será commitado

Execute em paralelo:

```bash
git status
git diff HEAD
```

Mostre o resumo ao usuário: quais arquivos foram modificados, adicionados ou removidos.

---

## Passo 4 — Verificar arquivos sensíveis

Analise o diff e a lista de arquivos em busca de:

| Padrão | Risco |
|--------|-------|
| `.env`, `.env.*` | Credenciais de ambiente |
| `*credentials*`, `*secret*`, `*token*` | Chaves e tokens |
| `config-mcp`, `*.pem`, `*.key` | Certificados e configurações privadas |
| Qualquer arquivo com `DB_PASSWORD`, `senha`, `password` em texto plano | Senhas expostas |

Se encontrar algum desses padrões, **bloqueie** o commit e informe:

> "Arquivo sensível detectado: `<arquivo>`. Adicione-o ao `.gitignore` antes de continuar. Nunca commite credenciais ou chaves no histórico git."

Se o arquivo já estiver no `.gitignore` mas aparecer como "untracked" por acidente, oriente o usuário a verificar se foi adicionado por engano ao staging.

---

## Passo 5 — Selecionar os arquivos para o commit

Use `git add` com arquivos específicos — **nunca** `git add -A` ou `git add .`.

Se o usuário não especificou quais arquivos commitar, liste os arquivos modificados (do `git status`) e confirme:

> "Vou adicionar ao commit: `arquivo1.md`, `arquivo2.yaml`. Correto?"

Só execute o `git add` após confirmação.

```bash
git add <arquivo1> <arquivo2> ...
```

---

## Passo 6 — Compor a mensagem de commit

A mensagem deve seguir estas regras:

- **Idioma:** português
- **Forma verbal:** imperativo ("Adicionar", "Corrigir", "Atualizar", "Remover", "Refatorar")
- **Tom:** objetivo — descreve o que muda e, quando relevante, por quê
- **Tamanho:** 1 linha de título (máximo 72 caracteres); corpo opcional para contexto adicional

**Exemplos corretos:**
```
Adicionar manifesto de Ingress para o kube-news
Corrigir timeout da startupProbe do postgres
Atualizar CLAUDE.md com regras de branch e commit
Remover credencial hardcoded do deploy.yaml
```

**Exemplos incorretos:**
```
added ingress manifest         ❌ inglês
adicionei o ingress            ❌ passado
fix probe                      ❌ inglês, sem contexto
update                         ❌ vago demais
```

Se o usuário sugerir uma mensagem em inglês ou no passado, adapte para o padrão correto e confirme antes de usar.

---

## Passo 7 — Executar o commit

Use HEREDOC para garantir formatação correta, incluindo o `Co-Authored-By` obrigatório:

```bash
git commit -m "$(cat <<'EOF'
<mensagem no imperativo>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

Se a mensagem tiver corpo (contexto adicional), adicione entre o título e o `Co-Authored-By`:

```bash
git commit -m "$(cat <<'EOF'
<título no imperativo>

<corpo com contexto — opcional>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Passo 8 — Confirmar o resultado

```bash
git log --oneline -3
git status
```

Mostre os últimos 3 commits para o usuário confirmar que o commit foi criado corretamente.

Se o usuário pedir push em seguida, lembre que push em `main` também é proibido pelo CLAUDE.md — o fluxo correto é abrir um PR.

---

## Regras absolutas (nunca quebre)

| Regra | O que fazer se violada |
|-------|----------------------|
| Nunca commitar em `main` | Bloquear, sugerir branch |
| Nunca `git add -A` ou `git add .` | Usar arquivos específicos sempre |
| Nunca commitar arquivos sensíveis | Bloquear, orientar `.gitignore` |
| Sempre incluir `Co-Authored-By` | Incluir automaticamente no HEREDOC |
| Mensagem sempre em português no imperativo | Adaptar e confirmar com o usuário |

---

## Referência rápida — prefixos de branch

| Prefixo | Quando usar |
|---------|------------|
| `feat/` | Nova funcionalidade |
| `fix/` | Correção de bug |
| `infra/` | Manifestos K8s, Dockerfile, infraestrutura |
| `docs/` | Documentação, README, CLAUDE.md |
| `skill/` | Nova skill ou modificação de skill existente |
