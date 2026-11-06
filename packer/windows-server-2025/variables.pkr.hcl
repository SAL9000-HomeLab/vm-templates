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
  description = "Proxmox storage path to the Windows Server 2025 install ISO"
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

variable "core_template_name" {
  type    = string
  default = "tpl-windows-server-2025-core"
}

variable "core_template_id" {
  type        = number
  description = "Proxmox VMID for the resulting Server Core template"
}

variable "core_image_name" {
  type        = string
  default     = "Windows Server 2025 Standard"
  description = "install.wim image name for Server Core (volume-licence media; eval media appends \" Evaluation\"). List with: dism /Get-WimInfo /WimFile:D:\\sources\\install.wim"
}

variable "desktop_image_name" {
  type        = string
  default     = "Windows Server 2025 Standard (Desktop Experience)"
  description = "install.wim image name for Desktop Experience (volume-licence media; eval media appends \" Evaluation\")"
}

variable "product_key" {
  type        = string
  default     = "TVRH6-WHNXV-R9WG3-9XRFY-MY832"
  description = "Setup product key. Defaults to Microsoft's public KMS client (GVLK) key for Server 2025 Standard, which volume-licence media needs to install unattended; activation happens later against KMS/ADBA. Set to \"\" for evaluation media."
}

variable "desktop_template_name" {
  type    = string
  default = "tpl-windows-server-2025-desktop"
}

variable "desktop_template_id" {
  type        = number
  description = "Proxmox VMID for the resulting Server (Desktop Experience) template"
}

variable "disk_size" {
  type    = string
  default = "60G"
}

variable "cores" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 4096
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
