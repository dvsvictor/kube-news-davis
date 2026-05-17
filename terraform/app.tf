# -----------------------------------------------------------------------------
# Kube-News App — Deployment + Service
# Probes calibradas para espelhar o HEALTHCHECK do Dockerfile:
#   startupProbe:  12 × 10s = 120s — aguarda banco estar pronto
#   readinessProbe: usa /ready (controlado por /unreadyfor/:seconds)
#   livenessProbe:  usa /health — espelha --interval=30s --start-period=10s
# DB_HOST referencia o nome do Service do postgres para resolução DNS interna
# -----------------------------------------------------------------------------

resource "kubernetes_deployment_v1" "kube_news" {
  metadata {
    name      = "kube-news"
    namespace = kubernetes_namespace_v1.kube_news.metadata[0].name
    labels = {
      app       = "kube-news"
      component = "app"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app       = "kube-news"
        component = "app"
      }
    }

    template {
      metadata {
        labels = {
          app       = "kube-news"
          component = "app"
        }
      }

      spec {
        container {
          name              = "kube-news"
          image             = "${var.app_image}:${var.app_image_tag}"
          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 8080
          }

          env {
            name  = "DB_HOST"
            value = kubernetes_service_v1.postgres.metadata[0].name
          }

          env {
            name  = "DB_PORT"
            value = "5432"
          }

          env {
            name  = "DB_DATABASE"
            value = "kubedevnews"
          }

          env {
            name  = "DB_USERNAME"
            value = "kubedevnews"
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres_secret.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name  = "DB_SSL_REQUIRE"
            value = "false"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          startup_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 12
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = "http"
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 3
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.postgres]
}

resource "kubernetes_service_v1" "kube_news" {
  metadata {
    name      = "kube-news"
    namespace = kubernetes_namespace_v1.kube_news.metadata[0].name
    labels = {
      app       = "kube-news"
      component = "app"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app       = "kube-news"
      component = "app"
    }

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
  }
}
