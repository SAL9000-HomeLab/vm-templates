# Generalizes the image (new SID/machine identity on every clone). Run by Packer's powershell provisioner over
# WinRM; the proxmox-iso builder does an ACPI shutdown as soon as the provisioners finish and converts the VM into
# a template, so this script must not return until the image is generalized. The next boot (a clone's) runs
# specialize and OOBE from unattend-clone.xml, which Packer uploaded before this script.
#
# sysprep runs as a SYSTEM scheduled task, not as a child of this script: generalize resets the network stack,
# which can drop the WinRM session, and WinRM kills every process the session started when it goes. That left a
# half-generalized template once (GeneralizationState 3, clones stuck as the build machine). The script is safe to
# re-run, so the provisioner's max_retries reconnects and resumes waiting instead of starting sysprep again.

$ErrorActionPreference = 'Stop'
$sysprepDir   = "$env:SystemRoot\System32\Sysprep"
$cloneAnswers = "$sysprepDir\unattend-clone.xml"
$started      = "$env:SystemRoot\Temp\packer-sysprep.started"
$taskName     = 'Packer sysprep'
$stateKey     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State'
$generalized  = 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE'

function Get-ImageState { (Get-ItemProperty $stateKey).ImageState }

function Stop-WithSysprepLog([string]$Reason) {
    Write-Output "$Reason Last lines of $sysprepDir\Panther\setuperr.log:"
    Get-Content "$sysprepDir\Panther\setuperr.log" -Tail 40 -ErrorAction SilentlyContinue
    Write-Error "sysprep did not generalize the image; see $sysprepDir\Panther\setupact.log"
    exit 1
}

if ((Get-ImageState) -eq $generalized) {
    Write-Output 'Image already generalized'
    exit 0
}

if (-not (Test-Path $started)) {
    if (-not (Test-Path $cloneAnswers)) {
        Write-Error "missing $cloneAnswers (uploaded by the Packer file provisioner)"
        exit 1
    }

    # Windows Setup caches the answer file it installed from in C:\Windows\Panther. A generalized image looks
    # there before anywhere else, so every clone would replay the build's settings: the build computer name,
    # AutoLogon, and the FirstLogonCommands that turn Basic auth and unencrypted WinRM back on.
    Remove-Item -Path "$env:SystemRoot\Panther\unattend.xml", "$env:SystemRoot\Panther\Unattend\*.xml" `
        -Force -ErrorAction SilentlyContinue

    # The build talks to the VM over unencrypted WinRM with Basic auth (see the answer files). Turning that off
    # here would drop Packer's own session, so instead have each clone switch it off on first boot: Windows Setup
    # runs SetupComplete.cmd as SYSTEM once OOBE finishes. The HTTP listener on 5985 stays up for Kerberos/NTLM
    # (which encrypt the WinRM payload themselves). It also deletes the clone answer file (it holds the build
    # password), the copy Windows cached of it and this script's scheduled task, then writes the marker the
    # deploy repo waits for before it configures the VM over the guest agent.
    $setupScripts = "$env:SystemRoot\Setup\Scripts"
    New-Item -ItemType Directory -Path $setupScripts -Force | Out-Null
    @"
@echo off
call winrm set winrm/config/service/auth @{Basic="false"}
call winrm set winrm/config/service @{AllowUnencrypted="false"}
del /f /q "%SystemRoot%\System32\Sysprep\unattend-clone.xml" "%SystemRoot%\Panther\unattend.xml" 2>nul
del /f /q "%SystemRoot%\Panther\Unattend\*.xml" 2>nul
schtasks /delete /tn "$taskName" /f >nul 2>&1
echo %DATE% %TIME% > "%SystemRoot%\Setup\Scripts\SetupComplete.done"
"@ | Set-Content -Path "$setupScripts\SetupComplete.cmd" -Encoding Ascii

    # Clear the build-time AutoLogon (answer file's oobeSystem pass) so clones don't inherit a leftover
    # AutoLogonCount or a stored DefaultPassword.
    $winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '0'
    Remove-ItemProperty -Path $winlogon -Name AutoLogonCount, DefaultPassword -ErrorAction SilentlyContinue

    # /mode:vm: the clones run on the same (Proxmox) virtual hardware, so skip the hardware generalization.
    $action = New-ScheduledTaskAction -Execute "$sysprepDir\sysprep.exe" `
        -Argument "/generalize /oobe /mode:vm /quit /quiet /unattend:$cloneAnswers"
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings `
        -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    New-Item -ItemType File -Path $started -Force | Out-Null
    Write-Output 'sysprep started (scheduled task as SYSTEM)'
} else {
    Write-Output 'sysprep already started; waiting for it to finish'
}

# Wait for generalize to finish. Fail fast if sysprep exits without generalizing.
$seenRunning = $false
$deadline = (Get-Date).AddMinutes(30)
while ((Get-Date) -lt $deadline) {
    $state = Get-ImageState
    if ($state -eq $generalized) {
        Write-Output "sysprep generalized the image (ImageState $state)"
        exit 0
    }
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    $running = ($task -and $task.State -eq 'Running') -or (Get-Process -Name sysprep -ErrorAction SilentlyContinue)
    if ($running) { $seenRunning = $true }
    # Right after Start-ScheduledTask the task can still be queued, so only treat "not running" as an exit once
    # sysprep has been seen running, or two minutes after it was started (e.g. on a retry after it finished).
    $startedLongAgo = ((Get-Date) - (Get-Item $started).LastWriteTime).TotalMinutes -gt 2
    if (-not $running -and ($seenRunning -or $startedLongAgo)) {
        Start-Sleep -Seconds 5  # the state can lag the process by a moment
        if ((Get-ImageState) -eq $generalized) { continue }
        $result = if ($task) { (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult } else { 'n/a' }
        Stop-WithSysprepLog "sysprep exited (task result $result) with ImageState $(Get-ImageState)."
    }
    Start-Sleep -Seconds 10
}
Stop-WithSysprepLog "sysprep still not finished after 30 minutes (ImageState $(Get-ImageState))."
