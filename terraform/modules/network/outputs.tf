output "vpc_id" {
  description = "ID du VPC créé"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "Nom du VPC créé"
  value       = google_compute_network.main.name
}

output "vpc_self_link" {
  description = "Self-link du VPC (à passer à modules/gke)"
  value       = google_compute_network.main.self_link
}

output "subnet_self_link" {
  description = "Self-link du subnet (à passer à modules/gke)"
  value       = google_compute_subnetwork.main.self_link
}
