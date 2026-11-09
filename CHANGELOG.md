# Changelog

All notable changes to this project are documented here. Releases are cut by
pushing a `vX.Y.Z` tag; the release workflow publishes the matching section.

## [Unreleased]

- Fixed: Windows builds could stop at "BdsDxe: No bootable option or device was found" when firmware init took
  longer than the 30 seconds the build tapped Enter for, so the "Press any key to boot from CD or DVD" prompt timed
  out. The Windows Server 2025 and Windows 11 builds tap for 90 seconds by default, set with `boot_key_seconds`.
- Fixed: Windows Server 2025 Desktop builds could wait forever for the QEMU guest agent. The VirtIO guest tools
  (drivers and agent) and the build's WinRM setup ran as FirstLogonCommands, which never run when explorer.exe
  crashes at the first logon (the 24H2/2025 first-logon bug, Desktop Experience only). They now run from a build-time
  `SetupComplete.cmd` (`scripts/SetupComplete-build.cmd`, copied from the answer file CD in the specialize pass),
  which Windows Setup runs as SYSTEM before the logon screen, with output in
  `C:\Windows\Temp\vm-templates-setupcomplete.log`. The Server 2025 answer files no longer log on automatically.
  `sysprep.ps1` replaces the file with the clones' `SetupComplete.cmd`, as before.
- Added: the Windows templates install Windows updates during the build (`win_updates`, restarting as needed and
  searching again until none are found). Every category except Drivers and Upgrades is installed, set with
  `windows_common_update_categories`, and optional updates are skipped. Before this the Windows templates had only
  the updates on their ISO. Windows builds take an hour or more longer.
- Added: the Windows templates have OpenSSH Server installed (`win_capability`), so Windows 11 clones no longer
  download it from Windows Update when ans-features adds it. `sshd` stays disabled and never starts in the template,
  and any SSH host keys are removed, so clones don't share host keys. `ansible/requirements.yml` needs
  `ansible.windows` 3.6.0 or later, and the root `requirements.yml` links to it so CI installs those collections.
- Fixed: the Ubuntu template held back updates that need new packages, including kernel updates, because
  `linux_common` ran a "safe" `apt` upgrade. It now runs a full (`dist`) upgrade.

- Fixed: `template_catalog.yml` was missing Windows 11 Pro; it is now listed as `windows11_pro: tpl-win11-pro`.
- Added: `packer/windows-11` builds `tpl-win11-pro`, a Windows 11 Pro template with the Windows Server 2025 Desktop
  template's hardware, Ansible role and sysprep script. Its answer files enable the built-in Administrator, block
  BitLocker device encryption, set the network to Private before enabling WinRM, and turn Store app updates off for
  the build. `sysprep.ps1` removes apps installed for a user but not provisioned, on Windows 11 only, and
  `SetupComplete.cmd` turns Store updates back on.
- Fixed: Rocky 10 builds stopped at a `grub>` prompt: the boot command was typed 5 seconds after power-on, before the
  installer's menu was ready, so `e` never opened the editor and the `c` in `ks.cfg` opened the GRUB command line. The
  Linux templates wait 20 seconds (new `boot_wait` variable), and Rocky 10 pauses after `e` as Rocky 9 does.
- Changed: the Linux templates' disk is SCSI (`scsi0`) on a `virtio-scsi-single` controller instead of virtio-blk
  (`virtio0`), with writeback cache, discard, IO thread and SSD emulation, as on the Windows templates. proxmox-deploy
  expects `scsi0`, so it no longer falls back to `virtio0` with a warning. Inside the guest the disk is `/dev/sda`
  instead of `/dev/vda`; the installers and `fstab` don't use the name. `linux_common` enables `fstrim.timer`, so freed
  blocks go back to thin storage (Rocky 9 had it disabled). Rebuild the Linux templates to pick this up; existing VMs
  are unchanged.
- Changed: `packer build .` replaces the existing template when its VMID holds a VM template with the same name.
  Anything else on that VMID is left alone and the build fails, as before. The old template is deleted when the build
  starts, so a failed build leaves no template.
- Changed: Windows Server 2025 templates use 2 sockets with 2 cores each (4 vCPUs, as before) and NUMA, and the disk uses
  writeback cache, discard, IO thread and SSD emulation. The SCSI controller is now `virtio-scsi-single`, which IO thread
  requires. The Desktop template uses a VirtIO-GPU display with 512 MB. Rebuild the templates to pick this up.
- Added: Windows Server 2025 templates use an Intel vIOMMU by default, set with the `viommu` variable (`intel`, `virtio`,
  or an empty string for none). Rebuild the templates to pick this up.
- Fixed: Ubuntu 24.04 clones disabled cloud-init (`disabled-by-generator`): the template's cloud-init drive was on IDE
  (Packer's default), which the guest doesn't detect, so ds-identify found no NoCloud seed. The template puts it on
  SCSI (`cloud_init_disk_type = "scsi"`), as the Rocky templates already do. Rebuild `tpl-ubuntu-2404`.
- Fixed: the Ubuntu kernel command line cleanup left the installer's `---` separator (`GRUB_CMDLINE_LINUX_DEFAULT="---"`);
  it's removed too, and the check now looks only at `grub.cfg`'s `linux` lines (and matches `ds=nocloud-net`).
- Fixed: Ubuntu 24.04 clones still ignored Proxmox's cloud-init drive (DHCP address, no hostname or SSH keys from
  proxmox-deploy): the installer copies Packer's `autoinstall ds=nocloud-net` boot options into the installed
  system's kernel command line, and cloud-init then uses an empty NoCloud source from the command line.
  `files/clean-installer-cmdline.sh` removes them from GRUB's settings during the build, and fails the build if
  `/boot/grub/grub.cfg` still has them. Rebuild `tpl-ubuntu-2404`.
- Fixed: Ubuntu 24.04 clones ignored Proxmox's cloud-init drive and came up without the IP address, hostname or SSH
  keys proxmox-deploy set: the installer's `/etc/cloud/cloud.cfg.d/99-installer.cfg` (`datasource_list: [None]`)
  stayed in the template. The build now removes it and limits cloud-init to Proxmox's drive (NoCloud, ConfigDrive).
  Rebuild `tpl-ubuntu-2404` and redeploy its clones.
- Added: `packer/rocky-10-rke2` builds `tpl-rocky-10-rke2`, a Rocky Linux 10 Kubernetes node template with RKE2
  `v1.36.5+rke2r1` (`rke2_version`) installed but not enabled. New `rke2_node` role: Rancher EL10 repositories (left
  disabled), `rke2-server` + `rke2-agent`, NFS/iSCSI clients, no swap, firewalld off, NetworkManager ignores the CNI
  interfaces, kernel modules and sysctls. The build reuses the Rocky 10 kickstart without a swap volume and clears
  the iSCSI initiator name so each clone gets its own.
- Changed: Windows Server 2025 clones boot through specialize and OOBE unattended. sysprep now runs with a clone
  answer file (random name, OOBE skipped, build Administrator password, no AutoLogon) instead of none, deletes the
  build's cached answer file first, and `SetupComplete.cmd` removes the clone answer file and writes
  `SetupComplete.done` for the deploy repo to wait on. Rebuild the templates to pick this up.
- Fixed: the Windows build fails when sysprep didn't generalize the image (its exit code can be 0 regardless):
  `sysprep.ps1` waits for `ImageState` to reach `IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE` and otherwise prints the
  end of sysprep's `setuperr.log`, instead of letting Packer turn an ungeneralized VM into a template.
- Fixed: sysprep runs as a SYSTEM scheduled task (with `/mode:vm`) instead of as a child of the WinRM session.
  Generalize resets the network and WinRM then killed sysprep mid-generalize, leaving templates whose clones stay
  as the build machine (GeneralizationState 3). The provisioner retries (`max_retries = 5`) and the script only
  resumes waiting on a retry; `SetupComplete.cmd` deletes the task on each clone.
- Added: README section on how sysprep runs in the Windows build and what a failed build prints.
- Fixed: the README's `PROXMOX_API_TOKEN_ID` example uses single quotes; in double quotes the `!` in a token ID
  triggers history expansion in interactive zsh and bash.
- Added: CI via the shared `SAL9000-HomeLab/shared-actions` workflows: Ansible checks (yamllint,
  ansible-lint) on pushes to `main` and pull requests, and Markdown, link and YAML linting on pull
  requests. Adds `.yamllint.yml`, `.ansible-lint`, `.markdownlint.json`, `.linkspector.yml`, a PR
  template, a tag-driven release workflow and this changelog.
- Changed: Ansible roles renamed to `linux_common`, `qemu_guest_agent` and `windows_common`
  (hyphens aren't valid in role names). The `restart sshd` handler is now `Restart sshd`.
- Fixed: Running the playbooks from `ansible/` against deployed VMs (per
  `inventory/hosts.ini.example`) failed to find the roles; `ansible/ansible.cfg` now sets
  `roles_path`, and a root `ansible.cfg` does the same for tools run from the repo root.
- Changed: Ansible CI runs on pull requests only, no longer on pushes to `main` (synced from ans-template).
