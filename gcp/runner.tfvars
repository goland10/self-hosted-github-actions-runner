############################################################
# Project & Location
############################################################
project_id = "internal-project-mission"
region     = "me-west1"
zone       = "me-west1-b"

############################################################
# Networking
############################################################
network = "internal-vpc"
subnet  = "internal-subnet"

############################################################
# Compute Instance (GHA Runner)
############################################################
instance_name = "gha-runner"
machine_type  = "e2-medium"

boot_disk = {
  image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
  size  = 30
}

############################################################
# GitHub Configuration
############################################################
repo_url = "https://github.com/goland10/multi-cloud-k8s"

############################################################
# Security & Secrets
############################################################
secret_name = "multi-cloud-k8s_github-runner"
