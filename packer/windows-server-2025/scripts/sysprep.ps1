# Generalizes the image (new SID/machine identity on every clone). Run by
# Packer's powershell provisioner over WinRM. Uses /quit, not /shutdown:
# powering off mid-command would drop the WinRM session and fail the build.
# The proxmox-iso builder then does an ACPI shutdown itself and converts the
# stopped VM into a template; the next boot (a clone's) goes into OOBE.

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

# Clear the build-time AutoLogon (answer file's oobeSystem pass) so clones
# don't inherit a leftover AutoLogonCount or a stored DefaultPassword.
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '0'
Remove-ItemProperty -Path $winlogon -Name AutoLogonCount, DefaultPassword -ErrorAction SilentlyContinue

# sysprep.exe is a GUI-subsystem app: invoked with & PowerShell neither
# waits for it nor sets $LASTEXITCODE, so wait on the process explicitly.
$sysprep = Start-Process -FilePath "$env:SystemRoot\System32\Sysprep\sysprep.exe" `
    -ArgumentList '/generalize', '/oobe', '/quit', '/quiet' -Wait -PassThru
if ($sysprep.ExitCode -ne 0) {
    Write-Error "sysprep failed (exit $($sysprep.ExitCode)); see C:\Windows\System32\Sysprep\Panther\setuperr.log"
    exit $sysprep.ExitCode
}
