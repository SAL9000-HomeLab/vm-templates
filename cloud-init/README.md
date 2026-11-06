# cloud-init snippets

`terraform/modules/proxmox-vm`'s `initialization` block covers the common
case (static/DHCP IP, DNS, one SSH-keyed user) via Proxmox's built-in
cloud-init fields — most VMs don't need anything here.

For per-VM customization beyond that (extra users, runcmd, package
installs at deploy time, mounting extra disks, etc.), write a cloud-init
user-data file, upload it to a `snippets`-enabled Proxmox storage:

```sh
pvesm set <storage> --content snippets   # enable snippets on a storage once
scp snippets/user-data-ubuntu.yaml root@pve1:/var/lib/vz/snippets/
```

then point the VM at it with `cicustom` (not currently exposed by the
Terraform module — add a `custom_cloud_init` variable that sets
`initialization.user_data_file_id = "local:snippets/user-data-ubuntu.yaml"`
if/when you need this).

Windows templates in this repo don't use cloud-init — see
[packer/windows-server-2025](../packer/windows-server-2025) for why.
