# Valores para o ambiente local — Docker Desktop
# A senha do banco (db_password) usa o default de variables.tf.
# Em produção, sobrescreva via variável de ambiente:
#   export TF_VAR_db_password="sua-senha-segura"
#   terraform apply

app_image     = "dvsvictor/kube-news"
app_image_tag = "main"
db_image      = "postgres:15-alpine"
namespace     = "kube-news"
ingress_host  = "kube-news.local"
