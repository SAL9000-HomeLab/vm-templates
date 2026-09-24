terraform {
  required_version = ">= 1.7"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66.0"
    }
  }

  # Uncomment and configure for shared state once you have a backend.
  # backend "s3" {
  #   bucket = "homelab-terraform-state"
  #   key    = "vm-templates/example.tfstate"
  #   region = "us-east-1"
  # }
}
