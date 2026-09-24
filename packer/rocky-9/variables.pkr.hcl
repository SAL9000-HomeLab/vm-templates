variable "proxmox_url" {
  type    = string
  default = env("PROXMOX_URL")
}

variable "proxmox_api_token_id" {
  type    = string
  default = env("PROXMOX_API_TOKEN_ID")
}

variable "proxmox_api_token_secret" {
  type      = string
  default   = env("PROXMOX_API_TOKEN_SECRET")
  sensitive = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build the template on — the short cluster node name (see `pvecm nodes` or `/etc/pve/nodes/`), not the FQDN"
}

variable "proxmox_insecure_skip_tls_verify" {
  type    = bool
  default = false
}

variable "iso_file" {
  type        = string
  description = "Proxmox storage path to the Rocky Linux DVD ISO, e.g. local:iso/Rocky-9.5-x86_64-dvd.iso"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
}

variable "vm_storage_pool" {
  type        = string
  description = "Storage pool for the built VM's disks"
}

variable "network_bridge" {
  type        = string
  default     = "vnet30"
  description = "Proxmox bridge or SDN VNet to attach the build VM's NIC to"
}

variable "http_interface" {
  type        = string
  default     = "eth0"
  description = "Local network interface Packer advertises to the booting VM for fetching the kickstart file. Override per-machine if it doesn't have a usable IP (e.g. WSL2 boxes with multiple NICs) — see README's WSL2 section."
}

variable "template_name" {
  type    = string
  default = "tpl-rocky-9"
}

variable "template_id" {
  type        = number
  description = "Proxmox VMID for the resulting template"
}

variable "disk_size" {
  type    = string
  default = "20G"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "ssh_username" {
  type    = string
  default = "ansible"
}
