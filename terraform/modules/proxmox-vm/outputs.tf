output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  value = proxmox_virtual_environment_vm.this.name
}

output "ipv4_addresses" {
  description = "IP addresses reported by the QEMU guest agent, keyed by network interface"
  value       = proxmox_virtual_environment_vm.this.ipv4_addresses
}
