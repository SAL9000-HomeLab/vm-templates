variable "name" {
  type        = string
  description = "VM name"
}

variable "target_node" {
  type        = string
  description = "Proxmox node to place the VM on — the short cluster node name (see `pvecm nodes` or `/etc/pve/nodes/`), not the FQDN"
}

variable "template_vm_id" {
  type        = number
  description = "VMID of the Proxmox template to clone (built by packer/<os>)"
}

variable "vm_id" {
  type        = number
  default     = null
  description = "Explicit VMID for the new VM, or null to let Proxmox pick one"
}

variable "os_type" {
  type        = string
  description = "\"linux\" or \"windows\" — controls whether cloud-init identity is applied"
  validation {
    condition     = contains(["linux", "windows"], var.os_type)
    error_message = "os_type must be \"linux\" or \"windows\"."
  }
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "disk_datastore_id" {
  type        = string
  description = "Storage pool for the cloned VM's disk"
}

variable "disk_size" {
  type        = number
  default     = 20
  description = "Disk size in GiB — must be >= the template's disk size"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "ip_address" {
  type        = string
  default     = "dhcp"
  description = "CIDR address (e.g. 10.0.0.50/24), or \"dhcp\". Ignored when os_type = \"windows\"."
}

variable "gateway" {
  type        = string
  default     = null
  description = "Gateway IP, required when ip_address is a static CIDR"
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "ci_user" {
  type        = string
  default     = "ansible"
  description = "cloud-init user account created on the cloned VM. Ignored when os_type = \"windows\"."
}

variable "ssh_keys" {
  type        = list(string)
  default     = []
  description = "Public SSH keys to authorize for ci_user"
}
