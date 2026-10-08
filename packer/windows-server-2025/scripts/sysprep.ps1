# Generalizes the image (new SID/machine identity on every clone). Run by
# Packer's powershell provisioner over WinRM. Uses /quit, not /shutdown:
# powering off mid-command would drop the WinRM session and fail the build.
# The proxmox-iso builder then does an ACPI shutdown itself and converts the
# stopped VM into a template; the next boot (a clone's) runs specialize and
# OOBE from unattend-clone.xml, which Packer uploaded before this script.

$sysprepDir   = "$env:SystemRoot\System32\Sysprep"
$cloneAnswers = "$sysprepDir\unattend-clone.xml"
if (-not (Test-Path $cloneAnswers)) {
    Write-Error "missing $cloneAnswers (uploaded by the Packer file provisioner)"
    exit 1
}

# Windows Setup caches the answer file it installed from in C:\Windows\Panther.
# A generalized image looks there before anywhere else, so every clone would
# replay the build's settings: the build computer name, AutoLogon, and the
# FirstLogonCommands that turn Basic auth and unencrypted WinRM back on.
Remove-Item -Path "$env:SystemRoot\Panther\unattend.xml", "$env:SystemRoot\Panther\Unattend\*.xml" `
    -Force -ErrorAction SilentlyContinue

# The build talks to the VM over unencrypted WinRM with Basic auth (see the
# answer files). Turning that off here would drop Packer's own session, so
# instead have each clone switch it off on first boot: Windows Setup runs
# SetupComplete.cmd as SYSTEM once OOBE finishes. The HTTP listener on 5985
# stays up for Kerberos/NTLM (which encrypt the WinRM payload themselves).
# It also deletes the clone answer file (it holds the build password) and the
# copy Windows cached of it, then writes the marker the deploy repo waits for
# before it configures the VM over the guest agent.
$setupScripts = "$env:SystemRoot\Setup\Scripts"
New-Item -ItemType Directory -Path $setupScripts -Force | Out-Null
@'
@echo off
call winrm set winrm/config/service/auth @{Basic="false"}
call winrm set winrm/config/service @{AllowUnencrypted="false"}
del /f /q "%SystemRoot%\System32\Sysprep\unattend-clone.xml" "%SystemRoot%\Panther\unattend.xml" 2>nul
del /f /q "%SystemRoot%\Panther\Unattend\*.xml" 2>nul
echo %DATE% %TIME% > "%SystemRoot%\Setup\Scripts\SetupComplete.done"
'@ | Set-Content -Path "$setupScripts\SetupComplete.cmd" -Encoding Ascii

# Clear the build-time AutoLogon (answer file's oobeSystem pass) so clones
# don't inherit a leftover AutoLogonCount or a stored DefaultPassword.
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '0'
Remove-ItemProperty -Path $winlogon -Name AutoLogonCount, DefaultPassword -ErrorAction SilentlyContinue

# sysprep.exe is a GUI-subsystem app: invoked with & PowerShell neither
# waits for it nor sets $LASTEXITCODE, so wait on the process explicitly.
$sysprep = Start-Process -FilePath "$sysprepDir\sysprep.exe" `
    -ArgumentList '/generalize', '/oobe', '/quit', '/quiet', "/unattend:$cloneAnswers" -Wait -PassThru
# sysprep can exit 0 without generalizing (it logs the failure instead), and the builder would then convert an
# ungeneralized VM into a template whose clones keep the build's name and never run specialize or OOBE. A
# generalized image waiting for its first OOBE has this ImageState; fail the build with sysprep's errors otherwise.
# Polled for a while in case sysprep's process returns before generalize has finished.
$deadline = (Get-Date).AddMinutes(15)
do {
    $imageState = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState
    if ($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break }
    Start-Sleep -Seconds 10
} while ((Get-Date) -lt $deadline)
if ($sysprep.ExitCode -ne 0 -or $imageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
    Write-Output "sysprep exit code $($sysprep.ExitCode), ImageState $imageState. Last lines of setuperr.log:"
    Get-Content "$sysprepDir\Panther\setuperr.log" -Tail 40 -ErrorAction SilentlyContinue
    Write-Error "sysprep did not generalize the image; see $sysprepDir\Panther\setuperr.log"
    exit 1
}
Write-Output "sysprep generalized the image (ImageState $imageState)"
