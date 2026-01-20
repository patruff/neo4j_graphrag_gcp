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
    provisioning    = google_compute_instance.neo4j_graphrag.scheduling[0].provisioning_model
    service_account = google_service_account.neo4j_sa.email
  }
}

output "connection_instructions" {
  description = "Instructions for connecting to the deployed resources"
  value = <<-EOT

    ====================================
    Neo4j GraphRAG POC - Connection Info
    ====================================

    Neo4j Browser:  http://${google_compute_instance.neo4j_graphrag.network_interface[0].access_config[0].nat_ip}:7474
    Bolt Protocol:  bolt://${google_compute_instance.neo4j_graphrag.network_interface[0].access_config[0].nat_ip}:7687

    Username:       neo4j
    Password:       <your_neo4j_password>

    SSH Access:
    gcloud compute ssh ${google_compute_instance.neo4j_graphrag.name} --zone=${var.zone} --project=${var.project_id}

    Note: Instance is a Spot VM - may be terminated by GCP with 30 seconds notice.
          Data is persisted on the attached disk.

  EOT
}
