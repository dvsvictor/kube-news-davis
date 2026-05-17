# ADR-0006 — Usar namespace dedicado kube-news em vez do namespace default

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

Ao criar os primeiros manifestos Kubernetes, todos os recursos foram inicialmente criados no
namespace `default` — o comportamento padrão quando `namespace` não é especificado. Com a
adição de múltiplos recursos (2 Deployments, 2 Services, 1 PVC, 1 Secret, 1 Ingress), o
namespace `default` começou a misturar recursos do Kube-News com outros recursos do cluster
(como componentes do próprio Docker Desktop). Isso dificultava o `kubectl get all` e
aumentava o risco de remoção acidental de recursos errados.

## Decisão

Decidimos criar o namespace `kube-news` (`k8s/namespace.yaml`) e mover todos os recursos do
projeto para ele. O namespace usa o label `app: kube-news` para identificação. Todos os
outros manifestos receberam `namespace: kube-news` em seu `metadata`. O pipeline de CI/CD
aplica o namespace antes dos outros recursos para garantir que ele exista. No Terraform, o
namespace é gerenciado como `kubernetes_namespace_v1.kube_news` e todos os outros recursos
referenciam `kubernetes_namespace_v1.kube_news.metadata[0].name`.

## Consequências

### Positivas
- `kubectl get all -n kube-news` mostra apenas recursos do projeto — sem ruído
- `kubectl delete namespace kube-news` remove tudo de uma vez de forma limpa
- Isola recursos do Kube-News de outros workloads no cluster
- Facilita RBAC futuro — permissões podem ser definidas por namespace

### Negativas (trade-offs aceitos)
- Todos os comandos `kubectl` precisam do flag `-n kube-news` ou do contexto configurado
- O pipeline de CI/CD precisa aplicar o namespace antes dos outros recursos (ordem de dependência)

### Neutras
- O NGINX Ingress Controller fica no namespace `ingress-nginx` — os recursos do Ingress do Kube-News ficam em `kube-news`, o que é o padrão correto

## Alternativas Consideradas

### Alternativa 1: Manter no namespace default
Continuar usando o namespace padrão do Kubernetes.
**Por que descartada:** mistura recursos do projeto com outros componentes do cluster,
dificultando operação e aumentando risco de remoção acidental.

### Alternativa 2: Um namespace por componente (kube-news-app, kube-news-db)
Separar app e banco em namespaces diferentes.
**Por que descartada:** adiciona complexidade de configuração de NetworkPolicy e DNS entre
namespaces sem benefício real para este escopo. App e banco são parte do mesmo sistema e
devem compartilhar o namespace.

## Referências
- `k8s/namespace.yaml` — definição do namespace
- `k8s/deploy.yaml` — `namespace: kube-news` em todos os recursos
- `terraform/main.tf` — `kubernetes_namespace_v1.kube_news`
