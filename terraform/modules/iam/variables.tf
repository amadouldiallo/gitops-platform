variable "project_id" {
  description = "ID du projet GCP cible"
  type        = string
}

variable "terraform_sa_roles" {
  description = "Rôles IAM attribués au compte de service Terraform (pas de primitifs owner/editor/viewer)"
  type        = list(string)
  default = [
    "roles/compute.networkAdmin",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
  ]
}

variable "iam_bindings" {
  description = "Liaisons IAM additionnelles : map rôle → liste de membres (ex. l'accès kubectl de l'opérateur humain au cluster)"
  type        = map(list(string))
  default     = {}
}
