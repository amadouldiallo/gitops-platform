# =============================================================================
# IAM — un compte pour Terraform, un accès pour l'humain, rien de plus
# =============================================================================
#
# 🎯 Le concept
# Deux identités distinctes gèrent ce projet : un compte de service dédié
# à l'automatisation Terraform (jamais de rôle primitif owner/editor), et
# l'accès humain nécessaire pour piloter le cluster une fois créé
# (`kubectl`, `gcloud container clusters get-credentials`).
#
# 🧠 Analogie
# Le compte Terraform est l'ouvrier du chantier, avec les outils pour
# construire (créer le réseau, le cluster). Le rôle `container.admin`
# donné à l'humain est la clé de l'appartement une fois construit : elle
# ouvre l'appartement (le cluster), pas le reste du chantier.
#
# ❓ Pourquoi c'est important
# Sans ce rôle explicite, un compte humain qui n'a créé le cluster via
# aucun rôle GCP `container.*` ne peut même pas lister les nodes avec
# `kubectl` — l'authentification GCP (IAM) est une couche à part de
# l'autorisation Kubernetes (RBAC, Étape 4), et les deux sont nécessaires.

locals {
  # Même technique d'aplatissement que le Projet 1 : voir son
  # modules/iam/main.tf pour le déroulé pas-à-pas commenté. Code réécrit
  # indépendamment ici (pas de référence croisée entre les deux dépôts),
  # même principe.
  iam_bindings_flat = flatten([
    for role, members in var.iam_bindings : [
      for member in members : { role = role, member = member }
    ]
  ])
}

resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = "gitops-terraform-runner"
  display_name = "GitOps Terraform Runner"
  description  = "Compte de service utilisé pour les opérations Terraform de la plateforme Kubernetes GitOps"
}

resource "google_project_iam_member" "terraform_sa_roles" {
  for_each = toset(var.terraform_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "custom_bindings" {
  for_each = { for b in local.iam_bindings_flat : "${b.role}/${b.member}" => b }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

# =============================================================================
# Fédération d'identité pour GitHub Actions — la CI de sécurité du Projet 4
# =============================================================================
#
# 🎯 Le concept
# Même mécanisme que le Projet 1 (voir son modules/iam/main.tf pour le
# détail pédagogique complet ; réécrit indépendamment ici) — mais pour un
# usage différent : ce n'est pas Terraform qui a besoin de s'authentifier
# depuis la CI, c'est le pipeline de build d'image (Projet 4, Étapes 1-4 :
# SAST, Trivy, SBOM, Cosign) qui doit pousser une image + sa signature
# vers Artifact Registry sans qu'aucune clé JSON n'existe jamais.
#
# ❓ Pourquoi un SA ET un provider SÉPARÉS de terraform-runner
# `terraform-runner` peut créer/modifier toute l'infra (moindre privilège
# vu depuis Terraform) — beaucoup trop large pour un pipeline qui n'a
# besoin que de pousser une image dans UN registre précis. Un compromis du
# jeton CI de build d'image avec les droits de terraform-runner aurait un
# rayon de destruction sans rapport avec son usage réel.
resource "google_iam_workload_identity_pool" "github_actions" {
  count = var.github_repository != null ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = "gitops-github-actions"
  # ⚠️ Piège rencontré pour de vrai : GCP limite display_name à 32
  # caractères pour un Workload Identity Pool — "GitHub Actions —
  # gitops-platform" (33 caractères, tiret cadratin compris) le dépassait
  # d'un cheveu, rejeté à l'apply avec un message d'erreur clair.
  display_name = "GitHub Actions (gitops)"
  description  = "Pool fédéré permettant à la CI de gitops-platform de s'authentifier sans clé statique"
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  count = var.github_repository != null ? 1 : 0

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # ⚠️ Sans cette ligne, n'importe quel repo GitHub au monde pourrait
  # emprunter l'identité du SA ci-dessous — voir le Projet 1 pour le piège
  # complet déjà rencontré et documenté sur ce même mécanisme.
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_actions_ci" {
  count = var.github_repository != null ? 1 : 0

  project      = var.project_id
  account_id   = "gitops-ci"
  display_name = "GitHub Actions CI — build/scan/sign d'images"
  description  = "Identité empruntée par la CI (Projet 4) pour pousser une image et sa signature Cosign vers Artifact Registry"
}

resource "google_service_account_iam_member" "github_actions_impersonation" {
  count = var.github_repository != null ? 1 : 0

  service_account_id = google_service_account.github_actions_ci[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions[0].name}/attribute.repository/${var.github_repository}"
}

# Accès scopé AU DÉPÔT ARTIFACT REGISTRY précis (pas au projet entier) —
# ce SA n'a besoin de pousser QUE dans "gitops-images" (voir
# environments/dev/main.tf), jamais de créer/supprimer un dépôt ou de
# toucher à autre chose sur le projet.
resource "google_artifact_registry_repository_iam_member" "github_actions_writer" {
  count = var.github_repository != null ? 1 : 0

  project    = var.project_id
  location   = var.region
  repository = var.artifact_registry_repository
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_actions_ci[0].email}"
}
