# Makes `packer build .` replace an existing template. The build deletes what is on its VMID only when that VMID holds
# a VM template with this build's name; anything else there is left alone and the build fails when it tries to create
# the VM. The old template is deleted when the build starts, so a failed build leaves no template.
data "http" "cluster_vms" {
  url = "${var.proxmox_url}/cluster/resources?type=vm"
  request_headers = {
    Authorization = "PVEAPIToken=${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  }
}

locals {
  cluster_vms = jsondecode(data.http.cluster_vms.body).data

  replace_core_template = anytrue([
    for vm in local.cluster_vms :
    lookup(vm, "type", "") == "qemu" && vm.vmid == var.core_template_id && lookup(vm, "name", "") == var.core_template_name && lookup(vm, "template", 0) == 1
  ])

  replace_desktop_template = anytrue([
    for vm in local.cluster_vms :
    lookup(vm, "type", "") == "qemu" && vm.vmid == var.desktop_template_id && lookup(vm, "name", "") == var.desktop_template_name && lookup(vm, "template", 0) == 1
  ])
}
