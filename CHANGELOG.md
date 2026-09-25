# Changelog

All notable changes to this project are documented here. Releases are cut by
pushing a `vX.Y.Z` tag; the release workflow publishes the matching section.

## [Unreleased]

- Added: CI via the shared `SAL9000-HomeLab/shared-actions` workflows: Ansible checks (yamllint,
  ansible-lint) on pushes to `main` and pull requests, and Markdown, link and YAML linting on pull
  requests. Adds `.yamllint.yml`, `.ansible-lint`, `.markdownlint.json`, `.linkspector.yml`, a PR
  template, a tag-driven release workflow and this changelog.
- Changed: Ansible roles renamed to `linux_common`, `qemu_guest_agent` and `windows_common`
  (hyphens aren't valid in role names). The `restart sshd` handler is now `Restart sshd`.
- Fixed: Running the playbooks from `ansible/` against deployed VMs (per
  `inventory/hosts.ini.example`) failed to find the roles; `ansible/ansible.cfg` now sets
  `roles_path`, and a root `ansible.cfg` does the same for tools run from the repo root.
