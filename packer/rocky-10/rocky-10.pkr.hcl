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

source "proxmox-iso" "rocky-10" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node

  vm_id                = var.template_id
  vm_name              = var.template_name
  template_name        = var.template_name
  template_description = "Rocky Linux 10, built ${timestamp()}"

  boot_iso {
    iso_file         = var.iso_file
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  qemu_agent      = true
  cores           = var.cores
  cpu_type        = "host"
  memory          = var.memory
  scsi_controller = "virtio-scsi-pci"

  bios = "ovmf"
  efi_config {
    efi_storage_pool  = var.vm_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

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

  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool
  # Rocky 10 guests don't detect the default IDE cloud-init CD-ROM, so no
  # NoCloud seed is found and cloud-init disables itself. SCSI is detected.
  cloud_init_disk_type = "scsi"

  boot_command = [
    "<up><wait>e",
    "<down><down><end><wait>",
    " inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<wait>",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]
  boot_wait      = "5s"
  http_directory = "http"
  http_interface = var.http_interface
  http_port_min  = 8300
  http_port_max  = 8310

  ssh_username         = var.ssh_username
  ssh_private_key_file = "files/ansible_build_key"
  ssh_timeout          = "30m"

  communicator = "ssh"
}

build {
  sources = ["source.proxmox-iso.rocky-10"]

  provisioner "ansible" {
    playbook_file    = "../../ansible/playbooks/rocky.yml"
    user             = var.ssh_username
    use_proxy        = false
    ansible_env_vars = ["ANSIBLE_ROLES_PATH=../../ansible/roles"]
  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs",
      # Drop Anaconda's build-time DHCP profile so it can't override the
      # static config cloud-init writes from ipconfig0 on each clone. Glob
      # runs under sudo because system-connections is root-only (0700).
      "sudo sh -c 'rm -f /etc/NetworkManager/system-connections/*.nmconnection /etc/sysconfig/network-scripts/ifcfg-*'",
      # Proxmox always seeds Linux guests via NoCloud; pin it so ds-identify
      # doesn't disable cloud-init if the seed drive is slow to appear.
      "echo 'datasource_list: [ NoCloud ]' | sudo tee /etc/cloud/cloud.cfg.d/90-proxmox-datasource.cfg",
      # Lock down the build account: no password, no build key, and no SSH
      # password auth on the template or its clones. Access to clones comes
      # from keys injected by cloud-init at deploy time. The 00- drop-in wins
      # over cloud-init's 50-cloud-init.conf (sshd uses the first value set).
      "sudo passwd -l ${var.ssh_username}",
      "sudo rm -f /home/${var.ssh_username}/.ssh/authorized_keys",
      "echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/00-vm-templates.conf",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
    ]
  }
}
