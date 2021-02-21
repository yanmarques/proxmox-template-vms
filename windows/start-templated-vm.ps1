param (
    [Parameter(Mandatory)] $userPath
)

$username = 'Administrator'
$password = 'password'

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword

$logFile = "C:\Temp\templated.log"

# send error and output to log files
Start-Process powershell.exe `
    -Arguments "C:\Program Files\proxmox-template-vms\windows\entrypoint.ps1 $userPath" `
    -Credential $credential `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $logFile
