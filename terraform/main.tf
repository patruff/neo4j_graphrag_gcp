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

# Data disk for Neo4j persistence
resource "google_compute_disk" "neo4j_data" {
  name = "${var.instance_name}-data"
  type = "pd-standard" # Cost-effective standard persistent disk
  zone = var.zone
  size = var.data_disk_size_gb

  labels = {
    environment = "poc"
    component   = "neo4j-data"
  }
}

# Cloud-init configuration with Neo4j password injection
data "template_file" "cloud_init" {
  template = file("${path.module}/cloud-init.yml")

  vars = {
    neo4j_password = var.neo4j_password
  }
}

# Compute Engine Instance (Spot VM for cost savings)
resource "google_compute_instance" "neo4j_graphrag" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["neo4j-graphrag"]

  # Spot VM configuration for cost optimization
  scheduling {
    preemptible                 = true
    automatic_restart           = false
    provisioning_model          = "SPOT"
    instance_termination_action = "STOP"
    on_host_maintenance         = "TERMINATE"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.boot_disk_size_gb
      type  = "pd-standard"
    }
  }

  # Attach persistent data disk
  attached_disk {
    source      = google_compute_disk.neo4j_data.id
    device_name = "neo4j-data"
    mode        = "READ_WRITE"
  }

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

  # Self-healing: metadata startup script that mounts data disk and ensures Docker Compose runs
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Format and mount data disk if not already mounted
    DEVICE_NAME="/dev/disk/by-id/google-neo4j-data"
    MOUNT_POINT="/mnt/neo4j_data"

    if [ ! -d "$MOUNT_POINT" ]; then
      mkdir -p "$MOUNT_POINT"
    fi

    # Check if disk is formatted
    if ! blkid "$DEVICE_NAME"; then
      mkfs.ext4 -F "$DEVICE_NAME"
    fi

    # Mount if not already mounted
    if ! mountpoint -q "$MOUNT_POINT"; then
      mount "$DEVICE_NAME" "$MOUNT_POINT"
      echo "$DEVICE_NAME $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
    fi

    # Ensure Docker Compose is running (self-healing)
    cd /opt/neo4j
    docker compose ps | grep -q "neo4j-graphrag.*Up" || docker compose up -d

    echo "Startup script completed at $(date)" >> /var/log/neo4j-startup.log
  EOF

  labels = {
    environment = "poc"
    component   = "neo4j-graphrag"
    cost-center = "demo"
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      scheduling[0].provisioning_model,
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
