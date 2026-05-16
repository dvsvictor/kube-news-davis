# Referência: Catálogo de Alertas Kubernetes

Alertas a verificar automaticamente em cada execução da skill `k8s-postmortem`.

---

## Alertas Críticos (🔴 Alto)

### A01 — Banco de dados sem PersistentVolumeClaim
- **Detecção:** deployment com imagem postgres/mysql/mongo/redis sem PVC associado
- **Risco:** perda total de dados ao reiniciar/recriar o pod
- **Verificação:** `kubectl get pvc -n <ns>` — lista vazia para o namespace do banco
- **Correção:** criar PVC + volumeMount + mountPath no deployment
- **Impacto:** dados de produção perdidos sem aviso

### A02 — Sem Ingress Controller instalado
- **Detecção:** `kubectl get ingress --all-namespaces` retorna lista vazia E nenhum pod `ingress-nginx` ou `traefik` nos namespaces do sistema
- **Risco:** acesso externo depende de port-forward manual, que quebra ao fechar o terminal
- **Correção:** instalar NGINX Ingress para kind: `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml`

### A03 — Credenciais em texto plano nos manifests
- **Detecção:** variáveis de ambiente com nomes como `PASSWORD`, `SECRET`, `KEY`, `TOKEN` com valores em texto literal (não `secretKeyRef`)
- **Risco:** credenciais expostas em git, logs, `kubectl describe`
- **Correção:** `kubectl create secret generic` + referenciar via `secretKeyRef`

### A04 — Ponto único de falha em aplicação crítica
- **Detecção:** `replicas: 1` em deployment de aplicação web/API sem PDB
- **Risco:** downtime total durante rollout ou falha de nó
- **Correção:** `replicas: 2` + podAntiAffinity + PodDisruptionBudget

---

## Alertas de Atenção (⚠️ Médio)

### B01 — Pod com restarts recorrentes
- **Detecção:** campo `RESTARTS` > 0 na listagem de pods
- **Causa comum:** startup probe muito agressivo, dependência de serviço não pronto, OOM
- **Investigação:** `kubectl describe pod <nome>` (seção Events) + `kubectl logs <nome> --previous`
- **Correção típica:** aumentar `initialDelaySeconds` do startupProbe ou adicionar `initContainer`

### B02 — Nó worker ocioso
- **Detecção:** nó worker com apenas pods de sistema (kindnet, kube-proxy) e nenhuma carga de aplicação
- **Causa:** scheduler não distribui pods por falta de réplicas ou por nodeSelector restritivo
- **Correção:** aumentar réplicas + adicionar podAntiAffinity para forçar distribuição

### B03 — Metrics Server ausente
- **Detecção:** `kubectl top nodes` retorna `Metrics API not available`
- **Impacto:** HPA não funciona, impossível monitorar uso real de CPU/memória
- **Correção:** `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`

### B04 — Sem HPA configurado
- **Detecção:** `kubectl get hpa --all-namespaces` retorna lista vazia para aplicações com tráfego variável
- **Risco:** sem escalonamento automático sob carga
- **Correção:** criar HPA após instalar Metrics Server

### B05 — ReplicaSet antigo não removido
- **Detecção:** `kubectl get rs --all-namespaces` mostra ReplicaSets com 0 pods mas não deletados
- **Risco:** baixo (ocupa espaço no etcd)
- **Correção:** `kubectl rollout history deployment/<nome>` para auditar; limpeza automática via `revisionHistoryLimit: 3`

---

## Alertas Informativos (ℹ️ Info)

### C01 — Sem NetworkPolicy
- **Detecção:** `kubectl get networkpolicy --all-namespaces` retorna lista vazia
- **Risco:** qualquer pod pode acessar qualquer outro pod na rede do cluster
- **Recomendação:** criar NetworkPolicy para isolar banco de dados

### C02 — Sem ResourceQuota
- **Detecção:** `kubectl get resourcequota --all-namespaces` retorna lista vazia
- **Risco:** uma aplicação pode consumir todos os recursos do cluster
- **Recomendação:** definir quotas por namespace

### C03 — Sem PodDisruptionBudget
- **Detecção:** `kubectl get pdb --all-namespaces` retorna lista vazia para aplicações críticas
- **Risco:** manutenção de nó pode derrubar todas as réplicas simultaneamente
- **Recomendação:** criar PDB com `minAvailable: 1`

### C04 — Imagem sem tag de versão fixa
- **Detecção:** imagens usando tag `latest` ou sem tag
- **Risco:** deployments não reproduzíveis, difícil rollback
- **Recomendação:** usar tags semânticas (`postgres:15.3-alpine`, não `postgres:latest`)

---

## Verificações de Saúde dos Nós

Para cada nó, verificar as condições abaixo. Qualquer `True` nas três primeiras é alerta crítico:

| Condição | Status Saudável | Se True significa |
|---|---|---|
| `MemoryPressure` | False | Memória baixa — pods podem ser evicted |
| `DiskPressure` | False | Disco cheio — novos pods não conseguem iniciar |
| `PIDPressure` | False | PIDs esgotados — novos processos não conseguem iniciar |
| `Ready` | True | Nó pronto para receber pods |
