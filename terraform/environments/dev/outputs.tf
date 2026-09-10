output "cluster_name" {
  description = "Nom du cluster GKE"
  value       = module.gke.cluster_name
}

output "vpc_name" {
  description = "Nom du VPC créé"
  value       = module.network.vpc_name
}

output "terraform_sa_email" {
  description = "Email du compte de service Terraform"
  value       = module.iam.terraform_sa_email
}

output "budget_name" {
  description = "Nom affiché du budget FinOps"
  value       = module.budget.budget_name
}

output "common_labels" {
  description = "Labels FinOps appliqués aux ressources labellisables"
  value       = local.common_labels
}

output "artifact_registry" {
  description = "Préfixe d'image à utiliser (imageRegistry du chart Helm)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "kubectl_credentials_command" {
  description = "Commande à lancer pour configurer kubectl une fois le cluster créé"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "github_actions_ci_sa_email" {
  description = "Projet 4 — email du SA emprunté par la CI GitHub Actions (vide si github_repository n'est pas défini)"
  value       = module.iam.github_actions_ci_sa_email
}

output "github_actions_workload_identity_provider" {
  description = "Projet 4 — à coller dans workload_identity_provider du workflow GitHub Actions"
  value       = module.iam.github_actions_workload_identity_provider
}
