variable "project_id" {
  description = "ID du projet GCP cible"
  type        = string
}

variable "region" {
  description = "Région GCP pour le subnet, le routeur et le NAT"
  type        = string
}

variable "vpc_name" {
  description = "Nom du VPC"
  type        = string
  default     = "gitops-vpc"
}

variable "subnet_cidr" {
  description = "Plage CIDR du subnet principal"
  type        = string
  default     = "10.40.0.0/20"
}

variable "secondary_ip_ranges" {
  description = "Plages IP secondaires du subnet (pods/services pour un cluster GKE VPC-native)"
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = []
}
