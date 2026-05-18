---
name: kube-news-deploy-check
description: Verifica e corrige autonomamente todos os pré-requisitos para o app kube-news rodar no cluster Kubernetes local (Docker Desktop). Use esta skill sempre que o usuário relatar que o app não abre, o localhost não responde, pods estão com erro, o deploy falhou, ou quiser saber se o ambiente está saudável. Ative para "o app não carrega", "localhost não funciona", "pod travou", "CrashLoopBackOff", "CreateContainerConfigError", "namespace not found", "secret not found", "pvc not found", "verificar deploy", "checar cluster", "diagnosticar kubernetes", "port-forward não funciona", ou qualquer variante de troubleshoot do ambiente local kube-news.
---

Executa um ciclo de verificação e autocorreção em 6 etapas, na ordem exata de dependências do projeto. Cada etapa detecta o problema, corrige imediatamente, e só então avança para a próxima. Registre o status de cada etapa para o relatório final.

## Contexto do projeto

| Recurso | Valor |
|---------|-------|
| Namespace | `kube-news` |
| Secret | `postgres-secret` (em `k8s/secrets.yaml`) |
| PVC | `postgres-pvc` (em `k8s/pvc.yaml`) |
| Manifesto principal | `k8s/deploy.yaml` |
| Porta local | `8080` via port-forward |
| Agente launchd | `dev.kube-news.portforward` |
| Log port-forward | `/tmp/kube-news-portforward.log` |

---

## Etapa 1 — Namespace

```bash
kubectl get namespace kube-news 2>&1
```

Se retornar `NotFound`, criar:
```bash
kubectl apply -f k8s/namespace.yaml
```

---

## Etapa 2 — Secret

```bash
kubectl get secret postgres-secret -n kube-news 2>&1
```

Se retornar `NotFound`, aplicar:
```bash
kubectl apply -f k8s/secrets.yaml
```

O Secret contém a senha do PostgreSQL em base64. Sem ele, o pod da app entra em `CreateContainerConfigError` — exatamente o erro que impede o container de iniciar.

---

## Etapa 3 — PVC

```bash
kubectl get pvc postgres-pvc -n kube-news 2>&1
```

Se retornar `NotFound`, aplicar:
```bash
kubectl apply -f k8s/pvc.yaml
```

Sem o PVC, o pod do postgres fica `Pending` indefinidamente porque o scheduler não consegue alocar o volume.

---

## Etapa 4 — Deploy e pods

Aplicar o manifesto principal (idempotente — pode rodar mesmo se já existir):
```bash
kubectl apply -f k8s/deploy.yaml
```

Aguardar o PostgreSQL ficar Ready (até 90s):
```bash
kubectl rollout status deployment/postgres -n kube-news --timeout=90s
```

Aguardar o app ficar Ready (até 120s — a startupProbe dá até 120s):
```bash
kubectl rollout status deployment/kube-news -n kube-news --timeout=120s
```

Se algum rollout falhar ou timeout, inspecionar a causa:
```bash
kubectl get pods -n kube-news
kubectl describe pod -n kube-news -l component=app 2>&1 | tail -25
kubectl logs -n kube-news -l component=app --tail=30 2>&1
```

Interpretar os erros mais comuns:

| Erro no pod | Causa | Correção |
|-------------|-------|----------|
| `CreateContainerConfigError` + `secret not found` | Secret não aplicado | Voltar à Etapa 2 |
| `Pending` + `pvc not found` | PVC não aplicado | Voltar à Etapa 3 |
| `CrashLoopBackOff` nos primeiros minutos | Banco ainda subindo | Aguardar — a startupProbe retry por até 120s |
| `ImagePullBackOff` | Imagem não encontrada no registry | Reportar ao usuário — requer push manual |

---

## Etapa 5 — Port-forward

Verificar o agente launchd:
```bash
launchctl list | grep kube-news
tail -5 /tmp/kube-news-portforward.log
```

O agente está com problema quando:
- O log mostra `Error from server` ou `services "kube-news" not found`
- A segunda coluna do `launchctl list` (exit code) é diferente de `0`

Se estiver com problema, recarregar:
```bash
launchctl unload ~/Library/LaunchAgents/dev.kube-news.portforward.plist
launchctl load ~/Library/LaunchAgents/dev.kube-news.portforward.plist
sleep 5
tail -5 /tmp/kube-news-portforward.log
```

O port-forward falha com `services not found` quando o Service `kube-news` ainda não existe no cluster — por isso esta etapa vem depois do deploy.

---

## Etapa 6 — Health check

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health
```

- **200**: app saudável — sucesso
- **Outro código**: app subiu mas retornou erro — reportar o código e verificar logs
- **`connection refused`**: port-forward não está ativo — reexecutar Etapa 5

---

## Relatório final

Ao concluir todas as etapas, apresentar a tabela de status:

```
## Resultado do deploy check

| Etapa          | Status       | Ação tomada              |
|----------------|--------------|--------------------------|
| Namespace      | ✓ OK         | Já existia               |
| Secret         | ✗ → Corrigido| Aplicado secrets.yaml    |
| PVC            | ✗ → Corrigido| Aplicado pvc.yaml        |
| Pods           | ✓ Ready      | 2/2 Running              |
| Port-forward   | ✗ → Corrigido| Agente recarregado       |
| Health check   | ✓ 200        | http://localhost:8080    |
```

Se alguma etapa não puder ser corrigida automaticamente (ex: `ImagePullBackOff`), indicar claramente o que o usuário precisa fazer manualmente.
