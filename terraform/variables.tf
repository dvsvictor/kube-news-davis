variable "namespace" {
  description = "Namespace Kubernetes onde todos os recursos serão criados"
  type        = string
  default     = "kube-news"
}

variable "app_image" {
  description = "Imagem Docker da aplicação no Docker Hub (sem tag)"
  type        = string
  default     = "dvsvictor/kube-news"
}

variable "app_image_tag" {
  description = "Tag da imagem da aplicação — use SHA curto para rastreabilidade"
  type        = string
  default     = "main"
}

variable "db_image" {
  description = "Imagem Docker do PostgreSQL"
  type        = string
  default     = "postgres:15-alpine"
}

variable "db_password" {
  description = "Senha do banco PostgreSQL — passe via TF_VAR_db_password em produção"
  type        = string
  sensitive   = true
  default     = "Pg#123"
}

variable "ingress_host" {
  description = "Hostname para acesso via Ingress — deve estar no /etc/hosts apontando para 127.0.0.1"
  type        = string
  default     = "kube-news.local"
}
