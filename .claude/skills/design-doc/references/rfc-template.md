# Template RFC — Request for Comments

Baseado no processo RFC do projeto Rust com influências do estilo IETF.

Um RFC é usado para **propor mudanças significativas que precisam de revisão e consenso antes
de serem implementadas**. A diferença do ADR é que o ADR registra uma decisão já tomada; o RFC
é o processo de tomar essa decisão. Um RFC pode resultar em um ADR após aprovação.

Use RFC quando: a mudança afeta múltiplos componentes, tem impacto em como o sistema é usado,
ou quando há alternativas genuinamente abertas que precisam ser avaliadas em conjunto.

---

## Template

```markdown
# RFC-NNNN — <Título da proposta>

**Status:** Rascunho | Em Revisão | Aceito | Rejeitado | Substituído por RFC-MMMM
**Data:** AAAA-MM-DD
**Autor(es):** <nome(s)>
**Revisores:** <nome(s) ou "aberto para revisão">

---

## Sumário

<2-3 frases que descrevem a proposta de forma completa. Quem ler só o sumário deve
entender o que está sendo proposto e por que. Evite jargão — seja direto.>

## Motivação

<Por que esta mudança é necessária agora? Qual evento, problema ou oportunidade motivou
a proposta? Inclua dados ou observações concretas. Descreva o estado atual do sistema e
por que ele é inadequado para os requisitos identificados.>

## Design Detalhado

<Descreva como a proposta vai funcionar tecnicamente. Esta é a seção mais longa.
Inclua:
- Arquitetura proposta (com diagrama Mermaid quando aplicável)
- Mudanças em arquivos específicos (com caminhos)
- Novos componentes ou recursos necessários
- Fluxo de dados ou sequência de operações
- Interface/contrato com outros componentes>

### Diagrama (se aplicável)

```mermaid
flowchart TD
    ...
```

### Mudanças necessárias

| Arquivo / Componente | Tipo de mudança | Descrição |
|---------------------|-----------------|-----------|
| `k8s/deploy.yaml` | Modificação | ... |
| `.github/workflows/ci-cd.yml` | Modificação | ... |

## Drawbacks

<Quais são os riscos, desvantagens ou complexidades introduzidas por esta proposta?
Seja honesto — um RFC que não reconhece trade-offs não é credível. Inclua:
- Complexidade operacional adicionada
- Riscos de segurança ou disponibilidade
- Custo de manutenção no longo prazo
- Dependências externas introduzidas>

## Alternativas Consideradas

### Alternativa 1: <Nome>
<Descrição da alternativa.>
**Vantagens:** <o que seria melhor nesta alternativa>
**Por que não foi escolhida:** <argumento específico para este contexto>

### Alternativa 2: <Nome>
<Descrição.>
**Vantagens:** <...>
**Por que não foi escolhida:** <...>

### Não fazer nada
<O que acontece se esta proposta for rejeitada? Qual é o custo de manter o status quo?>

## Questões em Aberto

<Lista de pontos que ainda não foram decididos e precisam de input dos revisores.
Cada item deve ser uma pergunta específica, não uma área vaga.>

- [ ] <Pergunta específica que precisa de resposta antes da implementação>
- [ ] <Outra questão em aberto>

## Plano de Implementação

<Como a proposta seria implementada? Divida em fases se a mudança for grande.>

### Fase 1 — <Nome> (estimativa: X dias)
- [ ] <tarefa concreta>
- [ ] <outra tarefa>

### Fase 2 — <Nome> (depende da Fase 1)
- [ ] <tarefa>

### Critérios de aceitação
<Como saberemos que a implementação foi bem-sucedida? Use critérios mensuráveis.>

## Referências
- <ADR relacionado, se houver>
- <documentação externa relevante>
- <issues ou PRs relacionados>
```

---

## Exemplo preenchido — RFC-0001

```markdown
# RFC-0001 — Implementar Helm Chart para substituir manifestos YAML estáticos

**Status:** Rascunho
**Data:** 2026-05-17
**Autor(es):** Davis Victor
**Revisores:** aberto para revisão

---

## Sumário

Propõe substituir os manifestos Kubernetes estáticos em `k8s/` por um Helm Chart completo
para o Kube-News. Isso permitiria deploys parametrizados por ambiente (dev/staging/prod),
rollbacks via `helm rollback`, e gestão de ciclo de vida via `helm upgrade --install`.

## Motivação

O pipeline atual em `.github/workflows/ci-cd.yml` usa `kubectl apply -f k8s/` com `sed`
para substituir a tag da imagem. À medida que o projeto ganha ambientes (staging, prod),
este approach se torna frágil: mudanças de configuração por ambiente requerem múltiplos
arquivos YAML ou lógica complexa de sed. Helm resolve isso nativamente via `values.yaml`
por ambiente. Adicionalmente, `helm rollback` é mais confiável que `kubectl rollout undo`
para rollbacks que envolvem mudanças em ConfigMaps ou Secrets.

## Design Detalhado

Estrutura proposta do chart:

```
helm/kube-news/
├── Chart.yaml
├── values.yaml           # valores padrão (dev)
├── values.prod.yaml      # overrides de produção
└── templates/
    ├── namespace.yaml
    ├── secret.yaml
    ├── pvc.yaml
    ├── deployment-postgres.yaml
    ├── deployment-app.yaml
    ├── service-postgres.yaml
    ├── service-app.yaml
    └── ingress.yaml
```

O pipeline seria alterado de:
```bash
sed -i "s|image:.*|image: dvsvictor/kube-news:$SHA|" k8s/deploy.yaml
kubectl apply -f k8s/
```
Para:
```bash
helm upgrade --install kube-news helm/kube-news \
  --set image.tag=$SHA \
  -f helm/kube-news/values.prod.yaml \
  --namespace kube-news \
  --create-namespace
```

## Drawbacks

- Helm adiciona uma dependência externa ao pipeline e ao cluster
- A curva de aprendizado do Helm é não trivial para quem não conhece Go templates
- Debug de templates Helm é mais difícil que YAML puro
- Para um projeto com um único ambiente, o ganho é marginal agora

## Alternativas Consideradas

### Alternativa 1: Kustomize
Overlays de YAML sem linguagem de template.
**Vantagens:** sem dependência externa, já integrado ao kubectl, mais simples que Helm.
**Por que não foi escolhida:** menos adotado no mercado que Helm; `helm rollback` é superior
ao mecanismo de rollback do Kustomize para mudanças envolvendo Secrets.

### Alternativa 2: Manter kubectl + sed
Status quo.
**Vantagens:** sem nova dependência, zero curva de aprendizado.
**Por que não foi escolhida:** não escala para múltiplos ambientes; sed em YAML é frágil.

### Não fazer nada
O projeto funciona bem com `kubectl apply` hoje. O custo real só aparecerá quando um
segundo ambiente (staging) for necessário.

## Questões em Aberto

- [ ] Queremos suportar staging agora ou só quando necessário?
- [ ] O self-hosted runner tem Helm instalado?
- [ ] Como gerenciar o `values.prod.yaml` que pode conter dados sensíveis?

## Plano de Implementação

### Fase 1 — Criar o Helm Chart (3 dias)
- [ ] Criar estrutura de diretórios `helm/kube-news/`
- [ ] Converter cada arquivo de `k8s/` para template Helm
- [ ] Testar localmente com `helm install --dry-run`

### Fase 2 — Atualizar pipeline (1 dia)
- [ ] Substituir `kubectl apply -f k8s/` por `helm upgrade --install` no ci-cd.yml
- [ ] Verificar que Helm está instalado no self-hosted runner

### Critérios de aceitação
- `helm upgrade --install` substitui completamente o `kubectl apply -f k8s/`
- `helm rollback kube-news 1` funciona após um deploy defeituoso
- Nenhuma mudança no comportamento externo da aplicação

## Referências
- ADR-0003: Usar Docker Hub como registry (afeta values.yaml)
- `k8s/deploy.yaml` — manifestos a serem convertidos
- `.github/workflows/ci-cd.yml:44` — step de deploy a ser alterado
```

---

## Ciclo de vida de um RFC neste projeto

```
Rascunho → Em Revisão → Aceito → Implementado → [ADR criado]
                      ↘ Rejeitado → [Fechado com justificativa]
```

Quando um RFC é aceito e implementado, crie um ADR correspondente registrando a decisão final.
