# Generalizes the image (new SID/machine identity on every clone) and
# shuts the VM down. Packer waits for the VM to power off, then Proxmox
# converts it into a template.

# The build talks to the VM over unencrypted WinRM with Basic auth (see the
# answer files). Turning that off here would drop Packer's own session, so
# instead have each clone switch it off on first boot: Windows Setup runs
# SetupComplete.cmd as SYSTEM once OOBE finishes. The HTTP listener on 5985
# stays up for Kerberos/NTLM (which encrypt the WinRM payload themselves).
$setupScripts = "$env:SystemRoot\Setup\Scripts"
New-Item -ItemType Directory -Path $setupScripts -Force | Out-Null
@'
@echo off
call winrm set winrm/config/service/auth @{Basic="false"}
call winrm set winrm/config/service @{AllowUnencrypted="false"}
'@ | Set-Content -Path "$setupScripts\SetupComplete.cmd" -Encoding Ascii

& "$env:SystemRoot\System32\Sysprep\sysprep.exe" /generalize /oobe /shutdown /quiet
