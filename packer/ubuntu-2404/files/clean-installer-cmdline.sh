#!/bin/sh
# Remove the autoinstall options from the template's kernel command line.
#
# Packer types "autoinstall ds=nocloud-net;s=http://<packer>/" into the installer's GRUB entry after its "---", and
# Ubuntu's installer copies everything after "---" into the installed system's GRUB settings. Left there, every
# clone boots with ds=nocloud-net: cloud-init takes an empty NoCloud source from the command line instead of
# Proxmox's cloud-init drive, so clones get DHCP and none of proxmox-deploy's settings (IP, hostname, SSH keys).
set -eu

clean() {
  # Drop the autoinstall, ds=... and --- words (the installer's separator, copied too) from GRUB_CMDLINE_LINUX and
  # GRUB_CMDLINE_LINUX_DEFAULT; keep the rest.
  sed -i -E '/^GRUB_CMDLINE_LINUX/ {
    s/(^|[" ])(autoinstall|ds=[^" ]*|---)( |")/\1\3/g
    s/(^|[" ])(autoinstall|ds=[^" ]*|---)( |")/\1\3/g
    s/  +/ /g
    s/=" /="/
    s/ "$/"/
  }' "$1"
}

clean /etc/default/grub
for f in /etc/default/grub.d/*.cfg; do
  [ -f "$f" ] && clean "$f"
done
update-grub

if grep -qE '^[[:space:]]*linux[[:space:]].*[[:space:]](autoinstall|ds=[^[:space:]]*|---)([[:space:]]|$)' /boot/grub/grub.cfg; then
  echo "autoinstall options are still in /boot/grub/grub.cfg:" >&2
  grep -nE '^[[:space:]]*linux[[:space:]].*[[:space:]](autoinstall|ds=[^[:space:]]*|---)([[:space:]]|$)' /boot/grub/grub.cfg >&2
  exit 1
fi
echo "Kernel command line clean: $(grep -hE '^GRUB_CMDLINE_LINUX' /etc/default/grub /etc/default/grub.d/*.cfg 2>/dev/null | tr '\n' ' ')"
