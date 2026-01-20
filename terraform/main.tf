terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# VPC Network (using default for cost-effectiveness)
# In production, create a custom VPC

# Firewall Rules
resource "google_compute_firewall" "neo4j_ssh" {
  name    = "${var.instance_name}-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.allowed_ip]
  target_tags   = ["neo4j-graphrag"]

  description = "Allow SSH access from authorized IP"
}

resource "google_compute_firewall" "neo4j_http" {
  name    = "${var.instance_name}-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["7474"]
  }

  source_ranges = [var.allowed_ip]
  target_tags   = ["neo4j-graphrag"]

  description = "Allow Neo4j HTTP access from authorized IP"
}

resource "google_compute_firewall" "neo4j_bolt" {
  name    = "${var.instance_name}-bolt"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["7687"]
  }

  source_ranges = [var.allowed_ip]
  target_tags   = ["neo4j-graphrag"]

  description = "Allow Neo4j Bolt protocol access from authorized IP"
}

# Service Account for the VM (principle of least privilege)
resource "google_service_account" "neo4j_sa" {
  account_id   = "${var.instance_name}-sa"
  display_name = "Service Account for Neo4j GraphRAG POC"
  description  = "Minimal permissions for Neo4j compute instance"
}

# IAM role for logging (optional but recommended for production monitoring)
resource "google_project_iam_member" "neo4j_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.neo4j_sa.email}"
}

resource "google_project_iam_member" "neo4j_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.neo4j_sa.email}"
}

# Cloud-init configuration with Neo4j password injection
data "template_file" "cloud_init" {
  template = file("${path.module}/cloud-init.yml")

  vars = {
    neo4j_password = var.neo4j_password
  }
}

# Compute Engine Instance
# Free Tier: e2-micro, non-preemptible, 30GB standard disk, us-central1/us-west1/us-east1
resource "google_compute_instance" "neo4j_graphrag" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["neo4j-graphrag"]

  # Scheduling: Non-preemptible for Always Free tier eligibility
  # Spot VMs are NOT eligible for free tier!
  scheduling {
    preemptible       = false
    automatic_restart = true
    on_host_maintenance = "MIGRATE"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.boot_disk_size_gb
      type  = "pd-standard" # Standard persistent disk (free tier eligible)
    }
  }

  # No separate data disk - using boot disk to stay under 30GB free tier limit
  # Neo4j data will be stored in /opt/neo4j on the boot disk

  network_interface {
    network = "default"

    # Ephemeral public IP for external access
    access_config {
      # Ephemeral IP
    }
  }

  service_account {
    email  = google_service_account.neo4j_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = data.template_file.cloud_init.rendered
    block-project-ssh-keys = "false"
  }

  # Self-healing: metadata startup script ensures Docker Compose runs
  # Free Tier: Data stored on boot disk at /opt/neo4j (no separate disk to stay under 30GB)
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Ensure Neo4j data directory exists on boot disk
    mkdir -p /opt/neo4j

    # Ensure Docker Compose is running (self-healing)
    cd /opt/neo4j
    if docker compose ps | grep -q "neo4j-graphrag.*Up"; then
      echo "Neo4j is already running"
    else
      echo "Starting Neo4j..."
      docker compose up -d
    fi

    echo "Startup script completed at $(date)" >> /var/log/neo4j-startup.log
  EOF

  labels = {
    environment = "poc"
    component   = "neo4j-graphrag"
    tier        = "free"
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }
}

# Output important information
output "instance_name" {
  description = "Name of the created compute instance"
  value       = google_compute_instance.neo4j_graphrag.name
}

output "instance_id" {
  description = "ID of the created compute instance"
  value       = google_compute_instance.neo4j_graphrag.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the Neo4j instance"
  value       = google_compute_instance.neo4j_graphrag.network_interface[0].access_config[0].nat_ip
}

output "neo4j_http_url" {
  description = "Neo4j Browser URL"
  value       = "http://${google_compute_instance.neo4j_graphrag.network_interface[0].access_config[0].nat_ip}:7474"
}

output "neo4j_bolt_url" {
  description = "Neo4j Bolt connection URL"
  value       = "bolt://${google_compute_instance.neo4j_graphrag.network_interface[0].access_config[0].nat_ip}:7687"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "gcloud compute ssh ${google_compute_instance.neo4j_graphrag.name} --zone=${var.zone} --project=${var.project_id}"
}
