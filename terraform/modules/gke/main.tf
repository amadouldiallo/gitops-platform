# =============================================================================
# GKE — le cluster qui héberge toute la plateforme GitOps
# =============================================================================
#
# 🎯 Le concept
# Un cluster Kubernetes régional managé par Google : control plane répliqué
# sur 3 zones, nodes privés (aucune IP publique), autoscaling borné en
# nombre TOTAL de nodes (pas par zone — voir la note ⚠️ plus bas),
# Workload Identity activé pour que les futurs pods (Argo CD, External
# Secrets Operator...) authentifient leurs appels GCP sans clé JSON.
#
# 🧠 Analogie
# Le control plane régional est la loge du gardien, dupliquée dans
# plusieurs quartiers (zones) de l'immeuble : si un quartier a une
# coupure, les autres continuent de fonctionner. Le node pool est le
# nombre d'appartements réellement construits — l'autoscaling en ajoute ou
# en retire selon le nombre de locataires (pods) à loger.
#
# ❓ Pourquoi c'est important
# Haute disponibilité (résistance à la panne d'une zone) et coût maîtrisé
# — l'autoscaling fait qu'on ne paie que les nodes réellement utilisés.
# C'est CE cluster que les Étapes 3 à 8 du guide utilisent : Helm y
# déploie l'appli, le socle de sécurité s'applique à ses namespaces,
# l'Ingress y route le trafic, Argo CD le réconcilie en continu.
#
# ⚠️ Piège — « régional » ne veut PAS dire "au moins 1 node par zone".
# `autoscaling.total_min_node_count`/`total_max_node_count` (utilisés ici,
# avec `location_policy = "BALANCED"`) bornent le nombre de nodes sur
# l'ensemble des 3 zones, pas par zone — sinon un cluster régional
# forcerait 3 nodes minimum même pour un cluster de lab à faible trafic.

resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "gitops-gke-nodes"
  display_name = "GKE Nodes — GitOps Platform"
  description  = "Compte de service attaché aux VM du node pool GKE de la plateforme GitOps"
}

resource "google_project_iam_member" "gke_nodes_roles" {
  for_each = toset(var.gke_node_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ⚠️ Piège — sur un cluster PRIVÉ, le control plane doit initier des
# connexions vers les nodes pour appeler les webhooks d'admission des
# opérateurs qu'on va installer (cert-manager à l'Étape 5, External
# Secrets Operator à l'Étape 7, Argo CD lui-même) — GCP ne crée PAS
# automatiquement de règle pour ces ports non standards. Sans cette règle,
# l'installation de ces opérateurs échoue avec des erreurs de timeout
# opaques ("failed calling webhook"), un problème classique et mal
# documenté des clusters GKE privés.
resource "google_compute_firewall" "allow_master_webhooks" {
  project   = var.project_id
  name      = "${var.cluster_name}-allow-master-webhooks"
  network   = var.vpc_id
  direction = "INGRESS"

  source_ranges = [var.master_ipv4_cidr_block]

  allow {
    protocol = "tcp"
    ports    = ["8443", "9443", "15017"] # cert-manager, external-secrets/argocd, et un port webhook courant additionnel
  }
}

resource "google_container_cluster" "main" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.region

  network    = var.vpc_self_link
  subnetwork = var.subnet_self_link

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # ⚠️ Piège rencontré en testant l'Étape 4 (NetworkPolicy) sur ce cluster
  # précis : sans ce champ, `google_container_cluster` NE FAIT PAS
  # respecter les NetworkPolicy Kubernetes par défaut — elles restent des
  # objets API valides, acceptés par `kubectl apply`, mais silencieusement
  # SANS AUCUN EFFET sur le trafic réel. Un test réel (un pod labellisé
  # "frontend" qui parvenait à joindre Postgres malgré la NetworkPolicy
  # censée l'en empêcher) a révélé le problème là où une simple lecture du
  # YAML ne l'aurait jamais montré. ADVANCED_DATAPATH active GKE Dataplane
  # V2 (basé sur Cilium), qui applique nativement les NetworkPolicy.
  datapath_provider = "ADVANCED_DATAPATH"

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # laisse un accès kubectl depuis des IP autorisées, pas un isolement total
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = var.release_channel
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }

  resource_labels = merge(var.labels, {
    component = "gke-cluster"
  })

  # false pour un cluster de plateforme d'apprentissage détruit/recréé
  # librement — repasser à true dès qu'un usage réel en dépend.
  deletion_protection = var.deletion_protection
}

resource "google_container_node_pool" "main" {
  project  = var.project_id
  name     = "${var.cluster_name}-default-pool"
  location = var.region
  cluster  = google_container_cluster.main.name

  autoscaling {
    total_min_node_count = var.total_min_node_count
    total_max_node_count = var.total_max_node_count
    location_policy      = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-balanced"

    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# =============================================================================
# Workload Identity — prêt pour Argo CD / External Secrets Operator
# =============================================================================
# Même mécanisme que le Projet 1 (réécrit indépendamment ici, voir son
# modules/gke/main.tf pour le détail pédagogique complet) : un compte GCP
# par usage applicatif, lié à un ServiceAccount Kubernetes précis, sans
# clé JSON. Vide par défaut ({}) — se remplit à l'Étape 7 (Vault/External
# Secrets Operator) une fois le namespace et le ServiceAccount K8s connus.

resource "google_service_account" "workload_identity" {
  for_each = var.workload_identity_service_accounts

  project      = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}

locals {
  workload_identity_roles_flat = flatten([
    for key, sa in var.workload_identity_service_accounts : [
      for role in sa.roles : { key = "${key}/${role}", sa_key = key, role = role }
    ]
  ])
}

resource "google_project_iam_member" "workload_identity_roles" {
  for_each = { for pair in local.workload_identity_roles_flat : pair.key => pair }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.workload_identity[each.value.sa_key].email}"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  for_each = var.workload_identity_service_accounts

  service_account_id = google_service_account.workload_identity[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.k8s_namespace}/${each.value.k8s_service_account}]"
}
