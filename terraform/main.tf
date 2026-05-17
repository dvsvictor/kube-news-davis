# =============================================================================
# Kube-News — Terraform / Kubernetes Provider
# Provisionamento local com Docker Desktop
#
# Pré-requisitos:
#   - Docker Desktop com Kubernetes habilitado (Settings → Kubernetes)
#   - kubectl configurado: kubectl config use-context docker-desktop
#   - NGINX Ingress Controller instalado:
#       kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
#   - Entrada no /etc/hosts:
#       echo "127.0.0.1 kube-news.local" | sudo tee -a /etc/hosts
#
# Comandos:
#   terraform init
#   terraform plan
#   terraform apply
#   terraform destroy
# =============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"
}

# -----------------------------------------------------------------------------
# Namespace — isolamento de todos os recursos do projeto
# -----------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "kube_news" {
  metadata {
    name = var.namespace
    labels = {
      app = "kube-news"
    }
  }
}
