# Registers the system app packages explorer.exe depends on for the user
# who is logging in, if they aren't already. Works around a Windows 24H2 /
# Server 2025 (build 26100) bug: on a new profile's first logon these can
# still be unregistered when the shell starts, so explorer.exe fail-fasts
# (0xc0000409) and the desktop stays black. Runs from a logon scheduled
# task. Winlogon doesn't restart a shell that crashed during startup, so
# after registering, start explorer.exe ourselves if it isn't running in
# this session (with no shell running, it starts as the shell).
$ErrorActionPreference = 'Continue'
$registered = $false
$packages = @(
    'MicrosoftWindows.Client.CBS_cw5n1h2txyewy'
    'Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe'
    'MicrosoftWindows.Client.Core_cw5n1h2txyewy'
)
foreach ($package in $packages) {
    $name = $package.Split('_')[0]
    $manifest = "$env:SystemRoot\SystemApps\$package\appxmanifest.xml"
    if ((Test-Path $manifest) -and -not (Get-AppxPackage -Name $name)) {
        Add-AppxPackage -Register -Path $manifest -DisableDevelopmentMode
        $registered = $true
    }
}

if ($registered) {
    # Let the shell's own startup attempt finish (or crash) first, so a
    # healthy shell doesn't get a second explorer.exe (a stray window).
    Start-Sleep -Seconds 10
    $session = (Get-Process -Id $PID).SessionId
    $shell = Get-Process -Name explorer -ErrorAction SilentlyContinue |
        Where-Object SessionId -eq $session
    if (-not $shell) {
        Start-Process -FilePath "$env:SystemRoot\explorer.exe"
    }
}
