output "terraform_sa_email" {
  description = "Email du compte de service Terraform"
  value       = google_service_account.terraform.email
}
