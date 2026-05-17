# ADR-0008 — Usar NGINX Ingress Controller para acesso externo à aplicação

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O acesso inicial à aplicação era feito via `kubectl port-forward` com um agente launchd
(ver ADR-0002). Embora funcional, essa solução tem limitações: não suporta múltiplas
conexões simultâneas de forma robusta, é específica do macOS, e não representa o padrão
de acesso que seria usado em produção. Era necessário evoluir para uma solução de Ingress
que funcionasse como proxy HTTP real, permitindo acesso via hostname (`kube-news.local`)
em vez de `localhost:8080`.

O cluster Docker Desktop suporta NGINX Ingress Controller via a versão `cloud/deploy.yaml`
do projeto `kubernetes/ingress-nginx`, que provisiona um LoadBalancer. No Docker Desktop,
o LoadBalancer recebe `EXTERNAL-IP: localhost` (ao contrário de clusters kind puros onde
ficaria em `<pending>`), tornando-o acessível do host macOS.

## Decisão

Decidimos instalar o NGINX Ingress Controller no namespace `ingress-nginx` via:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
```

E criar um recurso `Ingress` (`k8s/ingress.yaml`) no namespace `kube-news` com:
- `ingressClassName: nginx`
- Host: `kube-news.local`
- Path `/` (Prefix) → Service `kube-news`, porta `http`
- Annotation `nginx.ingress.kubernetes.io/rewrite-target: /`

O acesso local é habilitado adicionando `127.0.0.1 kube-news.local` ao `/etc/hosts`.
No Terraform, o Ingress é gerenciado como `kubernetes_ingress_v1.kube_news`.

## Consequências

### Positivas
- Acesso via hostname semântico (`http://kube-news.local`) em vez de porta numérica
- Proxy HTTP real: suporta múltiplas conexões simultâneas, headers HTTP, routing por path
- Representa o padrão de produção — migrar para um cluster real requer apenas trocar o host
- O Ingress Controller fica em namespace separado (`ingress-nginx`) — isolado dos recursos da aplicação
- Facilita futura adição de TLS, rate limiting e autenticação via annotations do NGINX

### Negativas (trade-offs aceitos)
- Requer entrada manual no `/etc/hosts` — não é automático em outros ambientes
- O NGINX Ingress Controller adiciona ~200MB de recursos ao cluster local
- A versão `cloud/deploy.yaml` é necessária (em vez de `kind/deploy.yaml`) — usar a versão errada faz o LoadBalancer ficar em `<pending>`
- O port-forward via launchd permanece como fallback (não foi removido) — dois mecanismos de acesso em paralelo

### Neutras
- O recurso `Ingress` fica no namespace `kube-news`, não em `ingress-nginx` — isso é o comportamento correto e esperado do Kubernetes

## Alternativas Consideradas

### Alternativa 1: Manter apenas o port-forward via launchd
Continuar com `kubectl port-forward` como única forma de acesso.
**Por que descartada:** não é um proxy HTTP real, não escala para múltiplas conexões,
e é específico do macOS. O Ingress é o padrão de produção e deve ser praticado no
ambiente de desenvolvimento.

### Alternativa 2: MetalLB para LoadBalancer real
Instalar MetalLB para atribuir IPs reais aos Services do tipo LoadBalancer.
**Por que descartada:** MetalLB em Docker Desktop requer configuração de pool de IPs na
faixa da rede Docker (`172.18.0.x`), que não é roteável do macOS. Não resolve o problema
de acesso do host sem roteamento adicional.

### Alternativa 3: Traefik Ingress Controller
Usar Traefik em vez de NGINX como Ingress Controller.
**Por que descartada:** NGINX é o Ingress Controller padrão de referência para Kubernetes
e o mais documentado. Para este projeto de demonstração, as funcionalidades são equivalentes
e NGINX tem maior familiaridade na comunidade.

### Alternativa 4: Istio ou Gateway API
Usar Service Mesh ou a nova Gateway API do Kubernetes.
**Por que descartada:** complexidade muito superior ao necessário para expor uma única
aplicação. Gateway API ainda estava em fase beta quando este projeto foi criado. Adequado
para ambientes multi-serviço com requisitos avançados de tráfego.

## Referências
- `k8s/ingress.yaml` — definição do Ingress `kube-news`
- `terraform/ingress.tf` — `kubernetes_ingress_v1.kube_news`
- [ADR-0002](ADR-0002-usar-clusterip-e-port-forward-para-acesso-local.md) — solução anterior de acesso local
- NGINX Ingress Controller v1.10.1 — `provider/cloud/deploy.yaml`
