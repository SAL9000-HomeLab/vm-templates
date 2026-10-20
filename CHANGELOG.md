# Changelog

All notable changes to this project are documented here. Releases are cut by
pushing a `vX.Y.Z` tag; the release workflow publishes the matching section.

## [Unreleased]

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
