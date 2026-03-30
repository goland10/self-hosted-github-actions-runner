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
  name         = "gha-runner"
  machine_type = "e2-medium"
  zone         = var.zone

  tags = ["github-runner"]

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
      size  = 30
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

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -xe
    #exec > /var/log/startup-script.log 2>&1

    apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release jq

    # Install Google Cloud SDK and GKE auth plugin
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg --yes
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list
        
    # Install Helm
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg --yes
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    
    apt-get update && apt-get install -y google-cloud-cli  google-cloud-sdk-gke-gcloud-auth-plugin  kubectl helm unzip nodejs npm

    # Install Runner
    RUNNER_USER=github
    RUNNER_HOME=/home/$RUNNER_USER
    RUNNER_DIR=$RUNNER_HOME/actions-runner
    REPO_URL="https://github.com/goland10/multi-cloud-k8s"
    GH_API="https://api.github.com/repos/goland10/multi-cloud-k8s/actions/runners/registration-token"

    # Create runner user if needed
    id $RUNNER_USER &>/dev/null || useradd -m $RUNNER_USER

    # Download the latest runner package and Extract the installer
    mkdir -p $RUNNER_DIR
    
    if [ ! -f "$RUNNER_DIR/config.sh" ]; then
      cd $RUNNER_DIR
      curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.331.0/actions-runner-linux-x64-2.331.0.tar.gz
      tar xzf ./actions-runner-linux-x64.tar.gz
      chown -R $RUNNER_USER:$RUNNER_USER $RUNNER_HOME
    fi

    # Register runner only once
    if [ ! -f "$RUNNER_DIR/.runner" ]; then
      GH_PAT=$(gcloud secrets versions access latest --secret=${var.secret_name})

      RUNNER_TOKEN=$(curl -s -X POST \
        -H "Authorization: Bearer $GH_PAT" \
        -H "Accept: application/vnd.github+json" \
        $GH_API | jq -r .token)

      # Configure and start the runner
      sudo -u $RUNNER_USER bash -c "
      cd $RUNNER_DIR
      ./config.sh \
        --url $REPO_URL \
        --token $RUNNER_TOKEN \
        --unattended \
        --replace
      ./run.sh
      "
      
    fi
  EOT
}
