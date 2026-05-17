output "namespace" {
  description = "Namespace Kubernetes provisionado"
  value       = kubernetes_namespace_v1.kube_news.metadata[0].name
}

output "app_image" {
  description = "Imagem da aplicação provisionada"
  value       = "${var.app_image}:${var.app_image_tag}"
}

output "app_url" {
  description = "URL de acesso à aplicação via Ingress"
  value       = "http://${var.ingress_host}"
}

output "verify_pods" {
  description = "Comando para verificar os pods após o apply"
  value       = "kubectl get pods -n ${var.namespace}"
}

output "verify_all" {
  description = "Comando para verificar todos os recursos provisionados"
  value       = "kubectl get all,ingress,pvc,secret -n ${var.namespace}"
}

output "health_check" {
  description = "Comando para testar o endpoint de liveness"
  value       = "curl http://${var.ingress_host}/health"
}
