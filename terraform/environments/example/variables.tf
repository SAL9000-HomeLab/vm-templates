variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API URL, e.g. https://proxmox.example.lan:8006/"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token in \"tokenid=secret\" form"
}

variable "proxmox_insecure" {
  type    = bool
  default = false
}

variable "target_node" {
  type        = string
  description = "Proxmox node to deploy VMs on — the short cluster node name (see `pvecm nodes` or `/etc/pve/nodes/`), not the FQDN"
}

variable "disk_datastore_id" {
  type        = string
  description = "Storage pool for VM disks"
}

variable "ssh_keys" {
  type        = list(string)
  default     = []
  description = "Public SSH keys authorized on Linux VMs"
}
