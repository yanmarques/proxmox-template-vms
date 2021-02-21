param (
    [Parameter(Mandatory)] $userPath
)

$username = 'Administrator'
$password = 'password'

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword

# send error and output to log files
Invoke-Command -FilePath "C:\Program Files\proxmox-template-vms\windows\entrypoint.ps1" -Credential $credential > C:\Temp\templated.log 2>&1