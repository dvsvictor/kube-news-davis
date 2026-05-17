# -----------------------------------------------------------------------------
# Secret — credenciais do PostgreSQL
# O Terraform gerencia o objeto Secret; o valor vem da variável db_password.
# Em produção, use TF_VAR_db_password=<senha> em vez de terraform.tfvars.
# -----------------------------------------------------------------------------
resource "kubernetes_secret_v1" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace_v1.kube_news.metadata[0].name
    labels = {
      app       = "kube-news"
      component = "db"
    }
  }

  type = "Opaque"

  data = {
    password = var.db_password
  }
}
