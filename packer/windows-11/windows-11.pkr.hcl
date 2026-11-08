packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# Windows 11 Pro, built like the Windows Server 2025 Desktop Experience template (same hardware, Ansible role and
# sysprep script). The Windows 11 differences are in the answer files; see their headers.
locals {
  winrm_password_xml = replace(replace(replace(var.winrm_password, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")

  # OVMF shows "Press any key to boot from CD or DVD" for only ~5s, at a time that varies with firmware init. Tap
  # Enter once a second for ~30s so one lands inside that window (see windows-server-2025.pkr.hcl).
  boot_keypress = [join("", [for i in range(30) : "<enter><wait1s>"])]

  # Proxmox stores vIOMMU in the machine setting; the plugin sends this value to the API unchanged.
  machine = var.viommu == "" ? "q35" : "q35,viommu=${var.viommu}"
}

source "proxmox-iso" "windows-11" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node

  vm_id                = var.template_id
  vm_name              = var.template_name
  template_name        = var.template_name
  packer_force         = local.replace_template
  template_description = "Windows 11 Pro, built ${timestamp()}"

  boot_iso {
    iso_file         = var.iso_file
    iso_storage_pool = var.iso_storage_pool
    type             = "sata" # q35 only allows ide0/ide2; three CDs need SATA
    unmount          = true
  }

  # Autounattend.xml on an ephemeral CD, which Windows Setup picks up automatically.
  additional_iso_files {
    cd_content = {
      "Autounattend.xml" = templatefile("answer_files/Autounattend.xml.pkrtpl", {
        image_name     = var.image_name
        product_key    = var.product_key
        winrm_password = local.winrm_password_xml
      })
    }
    cd_label         = "cidata"
    iso_storage_pool = var.iso_storage_pool
    type             = "sata"
    unmount          = true
  }

  # VirtIO drivers so Setup can see the virtio-scsi disk and virtio NIC.
  additional_iso_files {
    iso_file         = var.virtio_win_iso_file
    iso_storage_pool = var.iso_storage_pool
    type             = "sata"
    unmount          = true
  }

  qemu_agent      = true
  sockets         = var.sockets
  cores           = var.cores
  numa            = true
  cpu_type        = "host"
  memory          = var.memory
  scsi_controller = "virtio-scsi-single" # required by the disk's io_thread
  os              = "win11"

  # UEFI + Secure Boot + vTPM 2.0 on q35: Windows 11 Setup requires all three.
  machine = local.machine
  bios    = "ovmf"
  efi_config {
    efi_storage_pool  = var.efi_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }
  tpm_config {
    tpm_storage_pool = var.efi_storage_pool
    tpm_version      = "v2.0"
  }

  disks {
    disk_size    = var.disk_size
    storage_pool = var.vm_storage_pool
    # scsi -> vioscsi driver, which the answer file loads; proxmox-deploy expects the disk at scsi0.
    type = "scsi"

    cache_mode = "writeback"
    discard    = true
    io_thread  = true
    ssd        = true
  }

  network_adapters {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = false
  }

  vga {
    type   = "virtio"
    memory = 512
  }

  cloud_init   = false
  boot_wait    = "1s"
  boot_command = local.boot_keypress

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "6h"
  winrm_use_ssl  = false
  winrm_insecure = true
}

build {
  sources = ["source.proxmox-iso.windows-11"]

  provisioner "ansible" {
    playbook_file    = "../../ansible/playbooks/windows.yml"
    user             = var.winrm_username
    use_proxy        = false
    ansible_env_vars = ["ANSIBLE_ROLES_PATH=../../ansible/roles"]
    extra_arguments = [
      "-e", "ansible_password=${var.winrm_password}",
      "-e", "ansible_winrm_transport=basic",
      "-e", "ansible_winrm_server_cert_validation=ignore",
    ]
  }

  provisioner "file" {
    content = templatefile("answer_files/unattend-clone.xml.pkrtpl", {
      winrm_password = local.winrm_password_xml
    })
    destination = "C:/Windows/System32/Sysprep/unattend-clone.xml"
  }

  # Shared with the Windows Server 2025 build; it removes per-user apps that would fail sysprep on Windows 11.
  provisioner "powershell" {
    scripts     = ["../windows-server-2025/scripts/sysprep.ps1"]
    max_retries = 5
  }
}
