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

variable "github_repository" {
  # Pas de défaut : vide tant que le Projet 4 n'est pas branché — aucune
  # ressource Workload Identity Federation créée dans ce cas (voir les
  # `count = var.github_repository != null ? 1 : 0` de main.tf).
  description = "Dépôt GitHub autorisé à s'authentifier via Workload Identity Federation, format \"owner/repo\" (ex. amadouldiallo/gitops-platform)"
  type        = string
  default     = null
}

variable "region" {
  description = "Région GCP du dépôt Artifact Registry ciblé par le SA de CI"
  type        = string
  default     = "europe-west1"
}

variable "artifact_registry_repository" {
  description = "Nom du dépôt Artifact Registry que la CI est autorisée à pousser (roles/artifactregistry.writer, scopé à ce dépôt précis)"
  type        = string
  default     = "gitops-images"
}
