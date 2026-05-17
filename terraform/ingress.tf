# -----------------------------------------------------------------------------
# Ingress — acesso externo via NGINX
# Requer NGINX Ingress Controller instalado no cluster:
#   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
# Requer entrada no /etc/hosts:
#   127.0.0.1 kube-news.local
# -----------------------------------------------------------------------------

resource "kubernetes_ingress_v1" "kube_news" {
  metadata {
    name      = "kube-news"
    namespace = kubernetes_namespace_v1.kube_news.metadata[0].name
    labels = {
      app       = "kube-news"
      component = "app"
    }
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.kube_news.metadata[0].name
              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }
}
