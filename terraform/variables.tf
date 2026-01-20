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
  description = "GCP machine type for the Compute Engine instance"
  type        = string
  default     = "e2-medium"
}

variable "instance_name" {
  description = "Name of the Compute Engine instance"
  type        = string
  default     = "neo4j-graphrag-poc"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 30
}

variable "data_disk_size_gb" {
  description = "Data disk size for Neo4j persistence in GB"
  type        = number
  default     = 50
}
