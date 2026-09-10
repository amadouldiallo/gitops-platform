output "budget_name" {
  description = "Nom affiché du budget"
  value       = google_billing_budget.main.display_name
}
