output "runner_vm_name" {
  description = "Name of the GitHub Actions runner VM"
  value       = google_compute_instance.runner.name
}

output "runner_service_account_email" {
  description = "Service account used by the GitHub Actions runner"
  value       = google_service_account.runner.email
}

output "runner_zone" {
  description = "Zone where the runner VM is deployed"
  value       = google_compute_instance.runner.zone
}

output "runner_internal_ip" {
  description = "Internal IP address of the runner VM"
  value       = google_compute_instance.runner.network_interface[0].network_ip
}

output "iap_ssh_command" {
  description = "Command to SSH into the runner VM using IAP"
  value       = "gcloud compute ssh ${google_compute_instance.runner.name} --zone ${google_compute_instance.runner.zone} --tunnel-through-iap --project ${var.project_id}"
}
