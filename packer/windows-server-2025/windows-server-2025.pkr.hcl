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

  # OVMF shows "Press any key to boot from CD or DVD" for only ~5s, and when
  # it appears depends on how long firmware init takes (Secure Boot + TPM on
  # q35 is slow and varies). Tap a key once a second for ~30s so one is
  # guaranteed to land inside that window. It must be Enter, not space: the
  # VLK media's Boot Manager then shows a "Windows Setup [EMS Enabled]" menu,
  # and any keypress halts its countdown, so only Enter gets past it. Strays
  # once Setup loads are ignored.
  boot_keypress = [join("", [for i in range(30) : "<enter><wait1s>"])]
}

source "proxmox-iso" "windows-server-2025-core" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node

  vm_id                = var.core_template_id
  vm_name              = var.core_template_name
  template_name        = var.core_template_name
  template_description = "Windows Server 2025 Standard, Server Core, built ${timestamp()}"

  boot_iso {
    iso_file         = var.iso_file
    iso_storage_pool = var.iso_storage_pool
    type             = "sata" # q35 only allows ide0/ide2; three CDs need SATA
    unmount          = true
  }

  # Autounattend.xml + first-boot scripts, burned onto an ephemeral CD so
  # Windows Setup picks it up automatically.
  additional_iso_files {
    cd_files = ["scripts/sysprep.ps1"]
    cd_content = {
      "Autounattend.xml" = templatefile("answer_files/Autounattend-core.xml.pkrtpl", {
        image_name     = var.core_image_name
        product_key    = var.product_key
        winrm_password = local.winrm_password_xml
      })
    }
    cd_label         = "cidata"
    iso_storage_pool = var.iso_storage_pool
    type             = "sata" # q35 only allows ide0/ide2; three CDs need SATA
    unmount          = true
  }

  # VirtIO drivers so Setup can see the virtio-scsi disk and virtio NIC.
  additional_iso_files {
    iso_file         = var.virtio_win_iso_file
    iso_storage_pool = var.iso_storage_pool
    type             = "sata" # q35 only allows ide0/ide2; three CDs need SATA
    unmount          = true
  }

  qemu_agent      = true
  cores           = var.cores
  cpu_type        = "host"
  memory          = var.memory
  scsi_controller = "virtio-scsi-pci"
  os              = "win11"

  # UEFI + Secure Boot + vTPM 2.0 on q35 — the hardware Windows Server 2025
  # expects. pre_enrolled_keys loads the Microsoft keys so Secure Boot is on.
  machine = "q35"
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
    # scsi (on the virtio-scsi-pci controller) -> vioscsi driver, which the
    # answer file loads; "virtio" would be virtio-blk, needing viostor
    # instead. Terraform clones also expect the disk at scsi0.
    type = "scsi"
  }

  network_adapters {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = false
  }

  cloud_init = false # Windows: no native cloud-init support in Proxmox
  # See local.boot_keypress — without it OVMF falls through to PXE/EFI shell.
  boot_wait    = "1s"
  boot_command = local.boot_keypress

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

  vm_id                = var.desktop_template_id
  vm_name              = var.desktop_template_name
  template_name        = var.desktop_template_name
  template_description = "Windows Server 2025 Standard, Desktop Experience, built ${timestamp()}"

  boot_iso {
    iso_file         = var.iso_file
    iso_storage_pool = var.iso_storage_pool
    type             = "sata" # q35 only allows ide0/ide2; three CDs need SATA
    unmount          = true
  }

  additional_iso_files {
    cd_files = ["scripts/sysprep.ps1"]
    cd_content = {
      "Autounattend.xml" = templatefile("answer_files/Autounattend-desktop.xml.pkrtpl", {
        image_name     = var.desktop_image_name
        product_key    = var.product_key
        winrm_password = local.winrm_password_xml
      })
    }
    cd_label         = "cidata"
    iso_storage_pool = var.iso_storage_pool
    type             = "sata" # q35 only allows ide0/ide2; three CDs need SATA
    unmount          = true
  }

  additional_iso_files {
    iso_file         = var.virtio_win_iso_file
    iso_storage_pool = var.iso_storage_pool
    type             = "sata" # q35 only allows ide0/ide2; three CDs need SATA
    unmount          = true
  }

  qemu_agent      = true
  cores           = var.cores
  cpu_type        = "host"
  memory          = var.memory
  scsi_controller = "virtio-scsi-pci"
  os              = "win11"

  # UEFI + Secure Boot + vTPM 2.0 on q35 — the hardware Windows Server 2025
  # expects. pre_enrolled_keys loads the Microsoft keys so Secure Boot is on.
  machine = "q35"
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
    # scsi (on the virtio-scsi-pci controller) -> vioscsi driver, which the
    # answer file loads; "virtio" would be virtio-blk, needing viostor
    # instead. Terraform clones also expect the disk at scsi0.
    type = "scsi"
  }

  network_adapters {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = false
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

  # The answer file each clone's first boot runs (no console needed); sysprep.ps1
  # passes it to sysprep with /unattend:.
  provisioner "file" {
    content = templatefile("answer_files/unattend-clone.xml.pkrtpl", {
      winrm_password = local.winrm_password_xml
    })
    destination = "C:/Windows/System32/Sysprep/unattend-clone.xml"
  }

  # Generalize the image so cloned VMs each get a unique SID. Must be the
  # powershell provisioner (windows-shell feeds the .ps1 to cmd.exe). The
  # builder then shuts the VM down and converts it into a Proxmox template.
  provisioner "powershell" {
    scripts = ["scripts/sysprep.ps1"]
  }
}
