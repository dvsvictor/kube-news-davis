---
name: gerar-diagrama
description: This skill should be used when the user asks to "gerar diagrama", "criar diagrama", "visualizar arquitetura", "gerar mermaid", or runs /gerar-diagrama. Gera diagramas Mermaid para palestra a partir de um arquivo de relatório/roteiro.
version: 1.0.0
---

# Skill: gerar-diagrama

Gera diagramas Mermaid para palestra a partir de um arquivo de relatório/roteiro.

## Uso

```
/gerar-diagrama [arquivo]
```

- `[arquivo]`: caminho para o arquivo de relatório (padrão: `relatorio.md`)

## O que faz

1. Lê o arquivo de relatório indicado (ou `relatorio.md` se nenhum for passado).
2. Analisa o conteúdo e identifica os blocos temáticos: arquitetura, fluxos, custos, cronograma, riscos.
3. Gera um arquivo `diagrama-palestra.md` com diagramas Mermaid adequados para apresentação, escolhendo os tipos mais apropriados para cada bloco:
   - `flowchart` para arquiteturas e fluxos
   - `gantt` para cronogramas
   - `pie` para distribuição de custos
   - `quadrantChart` para comparativos
   - `flowchart` para cenários de falha/failover
4. Salva o resultado em `diagrama-palestra.md` no diretório de trabalho atual.
5. Informa quais diagramas foram gerados e como renderizá-los.

## Instruções para o modelo

Ao executar esta skill:

1. Leia o arquivo passado como argumento `$ARGUMENTS`. Se vazio, use `relatorio.md`.
2. Identifique todos os temas que se beneficiam de visualização gráfica.
3. Para cada tema, escolha o tipo de diagrama Mermaid mais adequado.
4. Gere o arquivo `diagrama-palestra.md` com todos os diagramas em sequência, separados por `---`, com título e breve descrição de cada um.
5. Não reutilize o arquivo de diagrama anterior — sobrescreva com conteúdo atualizado.
6. Ao final, liste os diagramas gerados e mencione que podem ser renderizados no GitHub, Obsidian, VS Code (extensão Mermaid) ou exportados via `mmdc` (Mermaid CLI).
