module "network" {
  source     = "../../modules/network"
  project_id = var.project_id
  region     = var.region

  # Plages réservées dès maintenant pour le cluster VPC-native (module.gke)
  # — un cluster VPC-native ne peut pas les ajouter après coup sans
  # reconstruire le subnet.
  secondary_ip_ranges = [
    { range_name = "gke-pods", ip_cidr_range = "10.44.0.0/14" },
    { range_name = "gke-services", ip_cidr_range = "10.48.0.0/20" },
  ]

  depends_on = [google_project_service.required]
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id

  iam_bindings = {
    # roles/container.admin : accès complet au cluster (créer/lister/gérer
    # les node pools) — suffisant en plus pour `kubectl` une fois combiné
    # au RBAC in-cluster de l'Étape 4. Pas roles/container.developer ici
    # car ce compte humain est aussi celui qui pilotera le cluster en
    # dehors de tout pipeline CI pour l'instant.
    "roles/container.admin" = ["user:${var.admin_email}"]
  }
}

module "budget" {
  source              = "../../modules/budget"
  project_id          = var.project_id
  billing_account_id  = var.billing_account_id
  budget_amount_eur   = var.budget_amount_eur
  budget_label_filter = { platform = "kubernetes-gitops" }

  depends_on = [google_project_service.required]
}

module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  vpc_id              = module.network.vpc_id
  vpc_self_link       = module.network.vpc_self_link
  subnet_self_link    = module.network.subnet_self_link
  pods_range_name     = "gke-pods"
  services_range_name = "gke-services"

  labels = local.common_labels

  depends_on = [google_project_service.required, module.network]
}

# =============================================================================
# Artifact Registry — le registre que le cluster tire pour ses images
# =============================================================================
# ❓ Pourquoi c'est important
# Contrairement à un cluster local (kind, minikube) qui partage le démon
# Docker de la machine hôte, les nodes GKE ne voient JAMAIS les images
# construites en local (voir docker-compose.yml) : ils tirent depuis un
# registre. Artifact Registry est le remplaçant moderne de Container
# Registry (gcr.io) chez Google.
resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = "gitops-images"
  description   = "Images de la plateforme GitOps (frontend, backend, db)"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}
