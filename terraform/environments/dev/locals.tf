# FinOps — voir le Projet 1 (locals.tf) pour l'explication complète des
# contraintes de label GCP et de la sanitization d'email. Réécrit
# indépendamment ici, avec un label `platform` en plus : c'est LUI que
# `budget_label_filter` (module.budget) utilise pour ne compter QUE la
# dépense de ce projet, même si le compte de facturation est partagé avec
# le Projet 1 (voir modules/budget/main.tf).
locals {
  owner_label = replace(lower(var.admin_email), "/[^a-z0-9_-]/", "-")

  common_labels = merge(
    {
      environment = var.environment
      cost_center = var.cost_center
      owner       = local.owner_label
      managed_by  = "terraform"
      platform    = "kubernetes-gitops"
    },
    var.extra_labels
  )
}
