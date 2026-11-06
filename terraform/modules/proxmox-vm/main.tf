resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.target_node
  vm_id     = var.vm_id
  tags      = var.tags

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.disk_datastore_id
    interface    = "scsi0"
    size         = var.disk_size
  }

  network_device {
    bridge = var.network_bridge
  }

  # Proxmox's cloud-init drive is only consumed on first boot by
  # cloud-init-aware guests. Windows templates in this repo rely on
  # Autounattend.xml + DHCP instead, so skip identity injection for them.
  dynamic "initialization" {
    for_each = var.os_type == "linux" ? [1] : []
    content {
      dns {
        servers = var.dns_servers
      }

      ip_config {
        ipv4 {
          address = var.ip_address
          gateway = var.ip_address == "dhcp" ? null : var.gateway
        }
      }

      user_account {
        username = var.ci_user
        keys     = var.ssh_keys
      }
    }
  }

  lifecycle {
    ignore_changes = [
      clone,
    ]
  }
}
