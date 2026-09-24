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

# XML-escape the password before it's templated into Autounattend.xml.
locals {
  winrm_password_xml = replace(replace(replace(var.winrm_password, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
}

source "proxmox-iso" "windows-server-2025-core" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node

  vm_id                 = var.core_template_id
  vm_name               = var.core_template_name
  template_name         = var.core_template_name
  template_description  = "Windows Server 2025 Standard, Server Core, built ${timestamp()}"

  boot_iso {
    iso_file         = var.iso_file
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  # Autounattend.xml + first-boot scripts, burned onto an ephemeral CD so
  # Windows Setup picks it up automatically.
  additional_iso_files {
    cd_files         = ["scripts/sysprep.ps1"]
    cd_content = {
      "Autounattend.xml" = templatefile("answer_files/Autounattend-core.xml.pkrtpl", {
        winrm_password = local.winrm_password_xml
      })
    }
    cd_label         = "cidata"
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  # VirtIO drivers so Setup can see the virtio-scsi disk and virtio NIC.
  additional_iso_files {
    iso_file         = var.virtio_win_iso_file
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  qemu_agent      = true
  cores           = var.cores
  memory          = var.memory
  scsi_controller = "virtio-scsi-pci"
  os              = "win11"

  disks {
    disk_size    = var.disk_size
    storage_pool = var.vm_storage_pool
    type         = "virtio"
  }

  network_adapters {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = false
  }

  cloud_init = false # Windows: no native cloud-init support in Proxmox
  boot_wait  = "5s"

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "6h" # Windows install + updates can take a while
  winrm_use_ssl  = false
  winrm_insecure = true
}

source "proxmox-iso" "windows-server-2025-desktop" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node

  vm_id                 = var.desktop_template_id
  vm_name               = var.desktop_template_name
  template_name         = var.desktop_template_name
  template_description  = "Windows Server 2025 Standard, Desktop Experience, built ${timestamp()}"

  boot_iso {
    iso_file         = var.iso_file
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  additional_iso_files {
    cd_files         = ["scripts/sysprep.ps1"]
    cd_content = {
      "Autounattend.xml" = templatefile("answer_files/Autounattend-desktop.xml.pkrtpl", {
        winrm_password = local.winrm_password_xml
      })
    }
    cd_label         = "cidata"
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  additional_iso_files {
    iso_file         = var.virtio_win_iso_file
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  qemu_agent      = true
  cores           = var.cores
  memory          = var.memory
  scsi_controller = "virtio-scsi-pci"
  os              = "win11"

  disks {
    disk_size    = var.disk_size
    storage_pool = var.vm_storage_pool
    type         = "virtio"
  }

  network_adapters {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = false
  }

  cloud_init = false
  boot_wait  = "5s"

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "6h"
  winrm_use_ssl  = false
  winrm_insecure = true
}

build {
  sources = [
    "source.proxmox-iso.windows-server-2025-core",
    "source.proxmox-iso.windows-server-2025-desktop",
  ]

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

  # Generalize the image so cloned VMs each get a unique SID, then shut
  # down — Packer converts the stopped VM into a Proxmox template.
  provisioner "windows-shell" {
    scripts = ["scripts/sysprep.ps1"]
  }
}
