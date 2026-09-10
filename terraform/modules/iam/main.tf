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
