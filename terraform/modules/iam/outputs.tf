output "terraform_sa_email" {
  description = "Email du compte de service Terraform"
  value       = google_service_account.terraform.email
}

output "github_actions_ci_sa_email" {
  description = "Email du compte de service emprunté par la CI GitHub Actions (vide si github_repository n'est pas défini)"
  value       = var.github_repository != null ? google_service_account.github_actions_ci[0].email : null
}

output "github_actions_workload_identity_provider" {
  description = "Nom complet du provider WIF, à utiliser dans workload_identity_provider du workflow GitHub Actions"
  value       = var.github_repository != null ? google_iam_workload_identity_pool_provider.github_actions[0].name : null
}
