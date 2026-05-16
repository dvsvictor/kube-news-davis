# Referência: Problemas de Conectividade MCP ↔ Kubernetes

## Por que o MCP não consegue acessar o cluster local?

O Docker MCP Gateway executa comandos `kubectl` **dentro de um container Docker**.
Isso cria um isolamento de rede que quebra referências a `localhost` / `127.0.0.1`.

```
┌─────────────────────────────────────────────────┐
│ macOS Host                                       │
│                                                  │
│  kubectl (host) → 127.0.0.1:PORTA ✅            │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ Container Docker (MCP Gateway)           │   │
│  │                                          │   │
│  │  kubectl → 127.0.0.1:PORTA ❌            │   │
│  │  kubectl → host.docker.internal:PORTA ✅ │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

---

## Tabela de Problemas e Soluções

| Sintoma | Causa | Solução |
|---|---|---|
| `connection refused` em todas as chamadas MCP | `config-mcp` usa `127.0.0.1` | Trocar para `host.docker.internal` |
| `certificate verify failed` após troca de endereço | Certificado TLS não tem SAN para `host.docker.internal` | Adicionar `insecure-skip-tls-verify: true` |
| `no such host` para `host.docker.internal` | Docker Desktop não está rodando | Iniciar Docker Desktop |
| `context not found` | `config-mcp` aponta para contexto inexistente | Verificar `current-context` no `config-mcp` |
| `Unauthorized` | Certificados de cliente expirados | Recriar o cluster ou renovar os certificados |
| `connection refused` mesmo após correção | Kubernetes desabilitado no Docker Desktop | Settings → Kubernetes → Enable Kubernetes |

---

## Localização dos arquivos de configuração

| Arquivo | Propósito |
|---|---|
| `~/.docker/mcp/config.yaml` | Config do MCP Gateway — aponta para o kubeconfig a usar |
| `~/.kube/config-mcp` | Kubeconfig dedicado para o MCP (pode ter endereço diferente do config principal) |
| `~/.kube/config` | Kubeconfig principal do sistema (usado pelo kubectl do host) |
| `~/.kube/config-mcp.bak` | Backup automático criado antes de qualquer edição |

---

## Diff padrão de correção

```yaml
# ~/.kube/config-mcp — ANTES
clusters:
- cluster:
    certificate-authority-data: <base64...>
    server: https://127.0.0.1:55180
  name: docker-desktop

# ~/.kube/config-mcp — DEPOIS
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://host.docker.internal:55180
  name: docker-desktop
```

---

## Porta padrão por tipo de cluster

| Tipo de cluster | Porta padrão da API |
|---|---|
| Docker Desktop (kind) | Dinâmica (checar com `kubectl cluster-info`) |
| Minikube | 8443 |
| kind standalone | 6443 (pode variar) |
| k3d | 6550 (pode variar) |

Para encontrar a porta atual:
```bash
kubectl cluster-info | grep "control plane"
```

---

## Checklist de validação pós-correção

- [ ] `mcp__MCP_DOCKER__ping` retorna sem erro
- [ ] `mcp__MCP_DOCKER__kubectl_get nodes` retorna a lista de nós
- [ ] `mcp__MCP_DOCKER__kubectl_context get` mostra o contexto correto
- [ ] Backup `~/.kube/config-mcp.bak` existe
