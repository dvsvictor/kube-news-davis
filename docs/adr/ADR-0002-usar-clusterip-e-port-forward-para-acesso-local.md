# ADR-0002 — Usar ClusterIP e kubectl port-forward para acesso local

**Status:** Aceito
**Data:** 2026-05-17
**Autor(es):** Davis Victor / Claude Sonnet 4.6

---

## Contexto

O cluster Kubernetes local usa Docker Desktop com nós kind em rede Docker interna
(`172.18.0.x`). Essa rede é isolada do macOS — IPs dos nós não são roteáveis diretamente
pelo host. Era necessário definir como expor a aplicação para acesso do desenvolvedor durante
desenvolvimento e testes, antes de ter o Ingress Controller configurado.

## Decisão

Decidimos usar `ClusterIP` como tipo de Service padrão para todos os recursos (`k8s/deploy.yaml`)
e `kubectl port-forward` como mecanismo de acesso local temporário, mantido ativo via agente
launchd (`~/Library/LaunchAgents/dev.kube-news.portforward.plist`). O launchd garante que o
port-forward sobe automaticamente no login do macOS e reinicia se morrer (`KeepAlive: true`),
sem necessidade de terminal aberto. O acesso permanente é resolvido via NGINX Ingress Controller
(ver ADR-0008).

## Consequências

### Positivas
- `ClusterIP` é o tipo mais seguro — o Service nunca fica exposto fora do cluster acidentalmente
- O port-forward via launchd persiste entre reboots e reconnects sem intervenção manual
- Solução zero-custo que não exige configuração adicional no cluster

### Negativas (trade-offs aceitos)
- `kubectl port-forward` é uma ponte TCP, não um proxy real — não suporta múltiplas conexões simultâneas com o mesmo comportamento de um LoadBalancer
- A configuração do launchd é específica do macOS — desenvolvedores em Linux/Windows precisam de outra solução
- O port-forward falha silenciosamente se o pod reiniciar — o launchd resolve isso com `KeepAlive`, mas há uma janela de indisponibilidade

### Neutras
- NodePort e LoadBalancer estão disponíveis mas são inúteis neste ambiente — documentado para evitar confusão futura

## Alternativas Consideradas

### Alternativa 1: NodePort
Expõe uma porta em todos os nós do cluster.
**Por que descartada:** os nós ficam em `172.18.0.x` — IPs não roteáveis do macOS. O acesso
via NodePort simplesmente não funciona neste ambiente sem configuração adicional de roteamento.

### Alternativa 2: LoadBalancer
Provisiona um IP externo via cloud controller.
**Por que descartada:** mesmo problema do NodePort — o IP atribuído seria `172.18.0.x`,
inacessível do host. Sem MetalLB ou similar configurado, o Service ficaria em `<pending>`.

### Alternativa 3: hostNetwork: true no Pod
Faz o pod usar a rede do nó diretamente.
**Por que descartada:** causa conflitos de porta no host e remove o isolamento de rede que
o Kubernetes fornece. Adequado apenas para casos específicos de operação, não para aplicações.

## Referências
- `k8s/deploy.yaml` — todos os Services usam `type: ClusterIP`
- `~/Library/LaunchAgents/dev.kube-news.portforward.plist` — agente launchd
- [ADR-0008](ADR-0008-usar-nginx-ingress-controller-para-acesso-externo.md) — solução definitiva via Ingress
