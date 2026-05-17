# -----------------------------------------------------------------------------
# PostgreSQL — PVC + Deployment + Service
# Probes calibradas para espelhar o healthcheck do docker-compose.yml:
#   startupProbe:  10 × 6s = 60s máximo para cold start
#   readinessProbe: 5 falhas antes de remover do load balancer
#   livenessProbe: a cada 30s após 30s de delay inicial
# -----------------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim_v1" "postgres_pvc" {
  metadata {
    name      = "postgres-pvc"
    namespace = kubernetes_namespace_v1.kube_news.metadata[0].name
    labels = {
      app       = "kube-news"
      component = "db"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.kube_news.metadata[0].name
    labels = {
      app       = "kube-news"
      component = "db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app       = "kube-news"
        component = "db"
      }
    }

    template {
      metadata {
        labels = {
          app       = "kube-news"
          component = "db"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = var.db_image

          port {
            name           = "postgres"
            container_port = 5432
          }

          env {
            name  = "POSTGRES_DB"
            value = "kubedevnews"
          }

          env {
            name  = "POSTGRES_USER"
            value = "kubedevnews"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres_secret.metadata[0].name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          startup_probe {
            exec {
              command = ["pg_isready", "-U", "kubedevnews", "-d", "kubedevnews"]
            }
            initial_delay_seconds = 5
            period_seconds        = 6
            timeout_seconds       = 5
            failure_threshold     = 10
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "kubedevnews", "-d", "kubedevnews"]
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 5
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "kubedevnews", "-d", "kubedevnews"]
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        volume {
          name = "postgres-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.postgres_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.kube_news.metadata[0].name
    labels = {
      app       = "kube-news"
      component = "db"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app       = "kube-news"
      component = "db"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = "postgres"
    }
  }
}
