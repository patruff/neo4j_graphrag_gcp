variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for deployment"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone for deployment"
  type        = string
  default     = "us-central1-a"
}

variable "allowed_ip" {
  description = "IP address allowed to access Neo4j and SSH (CIDR format, e.g., '1.2.3.4/32')"
  type        = string
  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}$", var.allowed_ip))
    error_message = "The allowed_ip must be a valid CIDR notation (e.g., '1.2.3.4/32')."
  }
}

variable "neo4j_password" {
  description = "Password for Neo4j database"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.neo4j_password) >= 8
    error_message = "Neo4j password must be at least 8 characters long."
  }
}

variable "machine_type" {
  description = "GCP machine type for the Compute Engine instance (e2-micro is Always Free)"
  type        = string
  default     = "e2-micro"
}

variable "instance_name" {
  description = "Name of the Compute Engine instance"
  type        = string
  default     = "neo4j-graphrag-poc"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB (max 30GB for Always Free tier)"
  type        = number
  default     = 30
  validation {
    condition     = var.boot_disk_size_gb <= 30
    error_message = "Boot disk must be <= 30GB to stay within GCP Always Free tier limit."
  }
}

variable "use_free_tier" {
  description = "Use GCP Always Free Tier settings (e2-micro, non-preemptible, 30GB disk)"
  type        = bool
  default     = true
}
