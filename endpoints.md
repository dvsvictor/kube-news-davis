# Endpoints da Aplicação kube-news

### GET /
**Descrição:** Página inicial — lista todas as postagens publicadas  
**Parâmetros:** nenhum  
**Retorno:** página HTML renderizada com array de postagens  
**Códigos HTTP:** 200 (sucesso), 500 (erro interno)

---

### GET /post
**Descrição:** Exibe o formulário para criação de uma nova postagem  
**Parâmetros:** nenhum  
**Retorno:** página HTML com formulário vazio  
**Códigos HTTP:** 200 (sucesso)

---

### POST /post
**Descrição:** Cria uma nova postagem com validação de campos  
**Parâmetros (body, form-urlencoded):**
- `title` (string, mínimo 30 caracteres)
- `resumo` (string, mínimo 50 caracteres)
- `description` (string, mínimo 2000 caracteres)

**Retorno:** redireciona para `/` em caso de sucesso; re-renderiza o formulário com mensagem de erro se a validação falhar  
**Códigos HTTP:** 302 (sucesso, redirect), 200 (falha de validação), 500 (erro interno)

---

### GET /post/:id
**Descrição:** Exibe uma postagem específica pelo seu ID  
**Parâmetros (rota):**
- `id` — chave primária da postagem no banco

**Retorno:** página HTML com os dados da postagem  
**Códigos HTTP:** 200 (sucesso), 500 (erro interno / ID não encontrado)

---

### POST /api/post
**Descrição:** Criação em lote de múltiplas postagens via API (sem validação de campos)  
**Parâmetros (body, JSON):**
- `artigos` — array de objetos, cada um com:
  - `title` (string)
  - `resumo` (string)
  - `description` (string)

**Retorno:** array JSON com as postagens criadas  
**Códigos HTTP:** 200 (sucesso), 500 (erro interno)

---

### GET /health
**Descrição:** Probe de liveness para o Kubernetes — indica se a aplicação está viva  
**Parâmetros:** nenhum  
**Retorno:** JSON `{ "state": "up", "machine": "<hostname>" }`  
**Códigos HTTP:** 200 (aplicação saudável)

---

### GET /ready
**Descrição:** Probe de readiness para o Kubernetes — indica se a aplicação está pronta para receber tráfego  
**Parâmetros:** nenhum  
**Retorno:** texto `"Ok"` se pronta, string vazia se não pronta  
**Códigos HTTP:** 200 (pronta), 500 (não pronta)

---

### PUT /unhealth
**Descrição:** Força a aplicação a reportar estado não saudável nas verificações de `/health`  
**Parâmetros:** nenhum  
**Retorno:** texto `"OK"`  
**Códigos HTTP:** 200 (sucesso)

---

### PUT /unreadyfor/:seconds
**Descrição:** Marca a aplicação como não pronta pelo número de segundos informado — útil para simular indisponibilidade temporária  
**Parâmetros (rota):**
- `seconds` — duração em segundos que a aplicação ficará como não pronta

**Retorno:** texto `"OK"`  
**Códigos HTTP:** 200 (sucesso)

---

**Total: 9 endpoints** — 5 GET, 2 POST, 2 PUT. Os endpoints `/health`, `/ready`, `/unhealth` e `/unreadyfor/:seconds` são utilitários de operação para uso com Kubernetes.
