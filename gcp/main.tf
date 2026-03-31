############################################
# Secure GitHub Actions Runner VM on GCP
# - No public IP
# - Private GKE access
# - Minimal IAM
# - Firewall rule for IAP tunnel
# - gcloud with GKE auth plugin and kubectl installed
# - Cloud NAT for internet access
############################################

############################
# Service Account
############################

resource "google_service_account" "runner" {
  account_id   = "github-actions-runner"
  display_name = "GitHub Actions Runner"
}

# Minimal permissions for GKE deploys
resource "google_project_iam_member" "gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_project_iam_member" "runner_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

############################
# Network (existing VPC)
############################

data "google_compute_network" "vpc" {
  name = var.network
}

data "google_compute_subnetwork" "subnet" {
  name   = var.subnet
  region = var.region
}

############################
# Cloud NAT (for private subnet internet access)
############################

resource "google_compute_router" "nat_router" {
name = "gha-runner-nat-router"
network = data.google_compute_network.vpc.name
region = var.region
}

resource "google_compute_router_nat" "nat" {
  name   = "gha-runner-nat"
  router = google_compute_router.nat_router.name
  region = var.region

  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = data.google_compute_subnetwork.subnet.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

############################
# Firewall: IAP tunnel inbound
############################

resource "google_compute_firewall" "iap_tunnel_ingress" {
name = "allow-ingress-from-iap"
network = data.google_compute_network.vpc.name

direction = "INGRESS"
allow {
protocol = "tcp"
ports = ["22"]
}

target_service_accounts = [google_service_account.runner.email]
source_ranges = ["35.235.240.0/20"] # IAP TCP forwarding range
}

############################
# Firewall: outbound only
############################

resource "google_compute_firewall" "runner_egress" {
  name    = "gha-runner-egress"
  network = data.google_compute_network.vpc.name

  direction = "EGRESS"
  #priority = 

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  destination_ranges       = ["0.0.0.0/0"]
  target_service_accounts  = [google_service_account.runner.email]
}

############################
# Compute Engine VM
############################

resource "google_compute_instance" "runner" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["github-runner"]

  boot_disk {
    initialize_params {
      image = var.boot_disk.image
      size  = var.boot_disk.size
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.subnet.self_link
    # NO public IP
  }

  service_account {
    email  = google_service_account.runner.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/startup_script.sh", {
  secret_name      = var.secret_name
  repo_url  = var.repo_url
  gh_api      = "${replace(var.repo_url, "github.com", "api.github.com/repos")}/actions/runners/registration-token"
  })

}
