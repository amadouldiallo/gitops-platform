variable "project_id" {
  # Pas de défaut : peut être le même projet GCP que le Projet 1, ou un
  # projet distinct — un choix qui t'appartient, jamais codé en dur ici.
  description = "ID du projet GCP cible (ex. mon-projet-12345)"
  type        = string
}

variable "region" {
  description = "Région GCP par défaut"
  type        = string
  default     = "europe-west1"
}

variable "billing_account_id" {
  description = "ID du compte de facturation GCP (format XXXXXX-XXXXXX-XXXXXX)"
  type        = string
}

variable "admin_email" {
  description = "Adresse email du compte Google humain autorisé à piloter le cluster (kubectl)"
  type        = string
}

variable "environment" {
  description = "Label FinOps 'environment'"
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.environment))
    error_message = "environment doit être en minuscules, [a-z0-9_-], 63 caractères max (contrainte de label GCP)."
  }
}

variable "cost_center" {
  description = "Label FinOps 'cost_center'"
  type        = string
  default     = "lab-perso"

  validation {
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.cost_center))
    error_message = "cost_center doit être en minuscules, [a-z0-9_-], 63 caractères max (contrainte de label GCP)."
  }
}

variable "extra_labels" {
  description = "Labels FinOps additionnels, fusionnés par-dessus le socle"
  type        = map(string)
  default     = {}
}

variable "budget_amount_eur" {
  description = "Montant du budget mensuel en euros"
  type        = number
  default     = 30
}
