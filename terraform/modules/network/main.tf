# =============================================================================
# Réseau — le socle privé sur lequel le cluster GKE sera posé
# =============================================================================
#
# 🎯 Le concept
# Un VPC isolé, un subnet régional avec des plages IP secondaires réservées
# pour les pods et les services (mode "VPC-native", requis par GKE moderne
# pour router le trafic des pods sans encapsulation), et un Cloud NAT pour
# que les nodes privés (sans IP publique) puissent quand même tirer des
# images de conteneur et appeler des APIs externes.
#
# 🧠 Analogie
# Le subnet est le terrain sur lequel on construit l'immeuble (le
# cluster) ; les plages secondaires sont les lignes déjà tracées au sol
# pour les futurs appartements (pods) et les boîtes aux lettres (services)
# — tracées AVANT la construction, parce qu'un cluster VPC-native ne peut
# pas les ajouter après coup sans tout reconstruire.
#
# ❓ Pourquoi c'est important
# Sans plages secondaires dédiées, GKE retombe sur un adressage "routes"
# hérité, moins performant et moins interopérable avec les fonctionnalités
# réseau modernes de GCP (règles de pare-feu par plage de pods, par ex.).
# Sans Cloud NAT, des nodes privés ne pourraient tirer aucune image
# publique (Docker Hub, GCR...) ni contacter l'API GitHub d'Argo CD.
resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  project                  = var.project_id
  name                     = "${var.vpc_name}-subnet-${var.region}"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true # les nodes sans IP publique doivent quand même atteindre les APIs Google

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5 # échantillonnage à 50 % : visibilité représentative pour un coût de logs divisé par deux
    metadata             = "INCLUDE_ALL_METADATA"
  }

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

resource "google_compute_router" "main" {
  project = var.project_id
  name    = "${var.vpc_name}-router-${var.region}"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  project                            = var.project_id
  name                               = "${var.vpc_name}-nat-${var.region}"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
