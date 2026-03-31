############################################################
# Project & Location
############################################################

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy resources"
  type        = string
}

variable "zone" {
  description = "The zone to deploy the VM"
  type        = string
}

############################################################
# Networking
############################################################

variable "network" {
  description = "The name of the existing VPC network"
  type        = string
}

variable "subnet" {
  description = "The name of the existing subnetwork"
  type        = string
}

############################################################
# Compute Instance (GHA Runner)
############################################################

variable "instance_name" {
  description = "Name of the GitHub Actions runner VM"
  type        = string
  default     = "gha-runner"
}

variable "machine_type" {
  description = "The machine type for the runner VM"
  type        = string
  default     = "e2-medium"
}

variable "boot_disk" {
  description = "Boot disk configuration"
  type = object({
    image = string
    size  = number
  })
  default = {
    image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
    size  = 30
  }
}

############################################################
# Security & Secrets
############################################################

variable "secret_name" {
  description = "The name of the Secret Manager secret containing the GitHub PAT"
  type        = string
  default     = "github_pat"
}

variable "repo_url" {
  description = "The full GitHub repository URL the runner will access to"
  type        = string
  #default     = "https://github.com/goland10/multi-cloud-k8s"
}
