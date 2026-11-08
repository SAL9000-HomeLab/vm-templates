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
  description = "Proxmox storage path to the Windows 11 install ISO (consumer or business media)"
}

variable "virtio_win_iso_file" {
  type        = string
  description = "Proxmox storage path to the virtio-win driver ISO, e.g. local:iso/virtio-win.iso"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
}

variable "vm_storage_pool" {
  type        = string
  description = "Storage pool for the built VM's disks"
}

variable "efi_storage_pool" {
  type        = string
  description = "Storage pool for the OVMF EFI vars disk and the TPM 2.0 state disk"
}

variable "network_bridge" {
  type        = string
  default     = "vnet30"
  description = "Proxmox bridge or SDN VNet to attach the build VM's NIC to"
}

variable "template_name" {
  type    = string
  default = "tpl-windows-11-pro"
}

variable "template_id" {
  type        = number
  description = "Proxmox VMID for the resulting Windows 11 Pro template"
}

variable "image_name" {
  type        = string
  default     = "Windows 11 Pro"
  description = "install.wim image name. List with: dism /Get-WimInfo /WimFile:D:\\sources\\install.wim"
}

variable "product_key" {
  type        = string
  default     = "W269N-WFGWX-YVC9B-4J6C9-9T83GX"
  description = "Setup product key. Defaults to Microsoft's public KMS client (GVLK) key for Windows 11 Pro, which selects Pro and lets Setup run unattended; activate later against KMS or with your own key. Set to \"\" to omit it."
}

variable "disk_size" {
  type        = string
  default     = "64G"
  description = "Windows 11 Setup refuses disks under 64 GB"
}

variable "sockets" {
  type        = number
  default     = 2
  description = "Windows 11 Pro supports up to 2 sockets"
}

variable "cores" {
  type        = number
  default     = 2
  description = "Cores per socket: the VM has sockets x cores vCPUs"
}

variable "memory" {
  type    = number
  default = 4096
}

variable "viommu" {
  type        = string
  default     = "intel"
  description = "Emulated IOMMU: intel, virtio, or an empty string for none"

  validation {
    condition     = contains(["intel", "virtio", ""], var.viommu)
    error_message = "The viommu value must be intel, virtio, or an empty string."
  }
}

variable "winrm_username" {
  type    = string
  default = "Administrator"
}

variable "winrm_password" {
  type        = string
  sensitive   = true
  description = "Build-time local Administrator password, templated into Autounattend.xml. No default — supply it via PKR_VAR_winrm_password (preferred) or an uncommitted pkrvars file."
}
