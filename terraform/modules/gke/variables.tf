variable "project_id" {
  description = "ID du projet GCP cible"
  type        = string
}

variable "region" {
  description = "Région GCP du cluster (location régionale, pas zonale)"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC (sortie de module.network), pour la règle de firewall des webhooks d'admission"
  type        = string
}

variable "vpc_self_link" {
  description = "Self-link du VPC (sortie de module.network)"
  type        = string
}

variable "subnet_self_link" {
  description = "Self-link du subnet (sortie de module.network)"
  type        = string
}

variable "pods_range_name" {
  description = "Nom de la plage IP secondaire du subnet pour les IP de pods"
  type        = string
  default     = "gke-pods"
}

variable "services_range_name" {
  description = "Nom de la plage IP secondaire du subnet pour les IP de services"
  type        = string
  default     = "gke-services"
}

variable "cluster_name" {
  description = "Nom du cluster GKE"
  type        = string
  default     = "gitops-platform"
}

variable "release_channel" {
  description = "Canal de mise à jour automatique de GKE : RAPID, REGULAR (recommandé) ou STABLE"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel doit être RAPID, REGULAR ou STABLE."
  }
}

variable "maintenance_start_time" {
  description = "Heure de début (HH:MM, UTC) de la fenêtre quotidienne de maintenance"
  type        = string
  default     = "03:00"
}

variable "master_ipv4_cidr_block" {
  description = "Plage CIDR /28 dédiée au control plane (distincte de subnet_cidr et des plages secondaires pods/services)"
  type        = string
  default     = "172.17.0.0/28"
}

variable "machine_type" {
  description = "Type de machine des nodes. e2-small par défaut — un cluster régional facture le control plane ET chaque node en continu, voir README.md avant d'augmenter cette valeur ou total_max_node_count."
  type        = string
  default     = "e2-small"
}

variable "disk_size_gb" {
  description = "Taille du disque de boot de chaque node, en Go"
  type        = number
  default     = 30
}

variable "total_min_node_count" {
  description = "Nombre total MINIMUM de nodes sur l'ensemble des zones (pas par zone, voir la note ⚠️ dans main.tf)"
  type        = number
  default     = 1
}

variable "total_max_node_count" {
  # Relevé de 3 à 4 en testant l'Étape 5 : avec ingress-nginx + cert-manager
  # en plus de l'appli, 3 nodes e2-small tournaient déjà à 87-97 % de
  # mémoire ALLOUÉE (requests), sans aucune marge pour un pod de plus — le
  # scheduler refusait le controller ingress-nginx ("Insufficient memory").
  # Une seule unité de plus plutôt qu'un passage à un machine_type plus
  # gros : coût marginal, élasticité conservée par l'autoscaling.
  description = "Nombre total MAXIMUM de nodes sur l'ensemble des zones (pas par zone)"
  type        = number
  default     = 4
}

variable "gke_node_sa_roles" {
  description = "Rôles IAM attribués au compte de service des nodes GKE (moindre privilège)"
  type        = list(string)
  default = [
    # ⚠️ Piège rencontré en testant ce module sur un vrai cluster : sans
    # artifactregistry.reader, les nodes tombent en ImagePullBackOff avec
    # une erreur 403 opaque ("failed to authorize") au moment de tirer
    # LA PREMIÈRE image applicative — même si le cluster et le registre
    # sont, eux, créés sans erreur. Facile à manquer tant qu'aucun pod
    # applicatif n'a encore été déployé.
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ]
}

variable "labels" {
  description = "Labels FinOps appliqués au cluster via resource_labels"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Empêche un terraform destroy du cluster sans étape manuelle. false par défaut pour un cluster d'apprentissage."
  type        = bool
  default     = false
}

variable "workload_identity_service_accounts" {
  description = "Comptes de service GCP pour Workload Identity, liés à un ServiceAccount Kubernetes précis. Vide par défaut — se remplit à l'Étape 7 (External Secrets Operator)."
  type = map(object({
    account_id          = string
    display_name        = string
    k8s_namespace       = string
    k8s_service_account = string
    roles               = list(string)
  }))
  default = {}
}
