data "google_project" "current" {
  project_id = var.project_id
}

# =============================================================================
# Budget — visibilité de coût dédiée à CETTE plateforme
# =============================================================================
#
# 🎯 Le concept
# Un cluster GKE régional facture le control plane et chaque node en
# continu (voir modules/gke) — un budget dédié à ce projet, séparé du
# budget du Projet 1, évite qu'un dépassement de coût sur l'un masque
# l'autre dans une seule alerte confondue.
#
# 🧠 Analogie
# Deux sous-compteurs électriques distincts sur le même compte EDF plutôt
# qu'un seul compteur global : chaque projet garde sa propre visibilité de
# consommation, même s'ils partagent le même compte de facturation.
#
# ❓ Pourquoi c'est important
# Sans budget dédié, la seule alerte visible serait celle du Projet 1 (si
# les deux tournent sur le même compte de facturation) — masquant lequel
# des deux projets est réellement responsable d'un dépassement.
resource "google_billing_budget" "main" {
  billing_account = var.billing_account_id
  display_name    = var.budget_display_name

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]

    # Si ce projet partage le même compte de facturation (voire le même
    # projet GCP) que le Projet 1, un budget SANS filtre compterait deux
    # fois la même dépense totale — les deux budgets se contenteraient de
    # dupliquer le même chiffre sous deux noms différents, sans vraie
    # séparation. Le filtre par label (ex. { platform = "kubernetes-gitops" })
    # restreint ce budget à SES ressources à lui uniquement.
    labels = length(var.budget_label_filter) > 0 ? var.budget_label_filter : null
  }

  amount {
    specified_amount {
      currency_code = "EUR"
      units         = tostring(floor(var.budget_amount_eur))
    }
  }

  dynamic "threshold_rules" {
    for_each = var.alert_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }
}
