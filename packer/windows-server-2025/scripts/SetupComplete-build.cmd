@echo off
rem Build-time SetupComplete.cmd for the Windows Server 2025 templates. The answer file's specialize pass copies it
rem from the build CD to %WINDIR%\Setup\Scripts, and Windows Setup runs it as SYSTEM once setup finishes, before the
rem logon screen. It does not depend on a logon: FirstLogonCommands did, and on Desktop Experience they never ran
rem when explorer.exe crashed at the first logon (the 24H2/2025 first-logon bug), so the build waited forever for
rem the guest agent. sysprep.ps1 replaces this file with the clones' SetupComplete.cmd before generalizing.
rem
rem Output goes to %WINDIR%\Temp\vm-templates-setupcomplete.log.

set LOG=%WINDIR%\Temp\vm-templates-setupcomplete.log
echo %DATE% %TIME% build SetupComplete.cmd started >> "%LOG%"

rem VirtIO guest tools: NetKVM and the other drivers, and the QEMU guest agent, which Packer needs to find the VM's
rem IP address for WinRM. The virtio ISO's drive letter isn't fixed (SATA CDs), so probe.
for %%i in (D E F G) do if exist %%i:\virtio-win-guest-tools.exe (
    echo Installing %%i:\virtio-win-guest-tools.exe >> "%LOG%"
    start "" /wait %%i:\virtio-win-guest-tools.exe /install /quiet /norestart /log "%WINDIR%\Temp\virtio-win-guest-tools.log"
    call echo virtio-win-guest-tools.exe exited with %%ERRORLEVEL%% >> "%LOG%"
)

rem WinRM over HTTP with Basic auth, for Packer and Ansible during the build only. sysprep.ps1 has each clone turn
rem Basic auth and unencrypted traffic off again.
call winrm quickconfig -quiet >> "%LOG%" 2>&1
call winrm set winrm/config/service/auth @{Basic="true"} >> "%LOG%" 2>&1
call winrm set winrm/config/service @{AllowUnencrypted="true"} >> "%LOG%" 2>&1
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow >> "%LOG%" 2>&1

rem Remote Desktop, so a stalled build can be inspected. windows_common enables it again.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >> "%LOG%" 2>&1
netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes >> "%LOG%" 2>&1

echo %DATE% %TIME% build SetupComplete.cmd finished >> "%LOG%"
