output "cluster_name" {
  description = "Nom du cluster GKE"
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint (IP privée) du control plane"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Certificat CA du cluster, encodé en base64"
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Pool Workload Identity du cluster (PROJECT_ID.svc.id.goog)"
  value       = google_container_cluster.main.workload_identity_config[0].workload_pool
}

output "node_service_account_email" {
  description = "Email du compte de service des nodes"
  value       = google_service_account.gke_nodes.email
}

output "workload_identity_service_account_emails" {
  description = "Map clé -> email des comptes de service Workload Identity créés (vide par défaut)"
  value       = { for k, sa in google_service_account.workload_identity : k => sa.email }
}
