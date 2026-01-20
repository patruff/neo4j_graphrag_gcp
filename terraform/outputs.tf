# Outputs are defined in main.tf for better cohesion with resources
# This file is kept for Terraform best practices structure
# All outputs can be viewed with: terraform output

output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    instance_name   = google_compute_instance.neo4j_graphrag.name
    instance_zone   = google_compute_instance.neo4j_graphrag.zone
    public_ip       = google_compute_instance.neo4j_graphrag.network_interface[0].access_config[0].nat_ip
    machine_type    = google_compute_instance.neo4j_graphrag.machine_type
    preemptible     = google_compute_instance.neo4j_graphrag.scheduling[0].preemptible
    service_account = google_compute_instance.neo4j_graphrag.service_account[0].email
    free_tier       = var.machine_type == "e2-micro" && var.boot_disk_size_gb <= 30
  }
}

output "connection_instructions" {
  description = "Instructions for connecting to the deployed resources"
  value = <<-EOT

    ================================================
    Neo4j GraphRAG POC - Connection Info (Free Tier)
    ================================================

    Neo4j Browser:  http://${google_compute_instance.neo4j_graphrag.network_interface[0].access_config[0].nat_ip}:7474
    Bolt Protocol:  bolt://${google_compute_instance.neo4j_graphrag.network_interface[0].access_config[0].nat_ip}:7687

    Username:       neo4j
    Password:       <your_neo4j_password>

    SSH Access:
    gcloud compute ssh ${google_compute_instance.neo4j_graphrag.name} --zone=${var.zone} --project=${var.project_id}

    Free Tier Details:
    - Instance: ${google_compute_instance.neo4j_graphrag.machine_type} (e2-micro qualifies for Always Free)
    - Disk: ${var.boot_disk_size_gb}GB standard persistent disk (30GB max for free)
    - Region: ${var.region} (us-central1/us-west1/us-east1 eligible)
    - Network: 1GB outbound transfer/month included

    Note: Stay within free tier limits to avoid charges.
          Monitor usage at: https://console.cloud.google.com/billing

  EOT
}
