# =============================================================================
# APIs GCP requises — activées explicitement, pas supposées pré-activées
# =============================================================================
#
# ❓ Pourquoi c'est important
# Un projet GCP fraîchement créé n'a que très peu d'APIs actives par
# défaut. Sans ces ressources, le premier `apply` échouerait au milieu de
# la création (ex. "Artifact Registry API has not been used in project
# ... before or it is disabled") — mieux vaut le déclarer explicitement,
# en code, que de compter sur une activation manuelle faite une fois et
# oubliée.
#
# disable_on_destroy = false : un `terraform destroy` de CE projet ne doit
# jamais désactiver ces APIs au niveau du projet GCP entier — si ce projet
# est partagé avec le Projet 1 (même project_id), les désactiver couperait
# aussi ses propres ressources.
resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "billingbudgets.googleapis.com",
  ])

  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}
