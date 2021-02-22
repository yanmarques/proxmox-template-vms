param (
    [Parameter(Mandatory)] $UserPath
)

# Default logging targets
$LogFile = "C:\Temp\templated\log"
$OutFile = "C:\Temp\templated\out.log"
$ErrFile = "C:\Temp\templated\err.log"

# ensure directory exists
New-Item -Path "C:\Temp\templated\" -ItemType Directory -Force

Write-Output "pre-starting templated-vm" > $LogFile

function Get-FullPath {
    param (
        [String] $File
    )

    Join-Path -Path "C:\Program Files\proxmox-template-vms\windows" -ChildPath $File
}

$AuthModule = Get-FullPath "Auth.psm1"
Write-Output "importing module: $AuthModule" >> $LogFile
Import-Module $AuthModule

Write-Output "starting templated-vm" >> $LogFile

$Functions = Get-FullPath "Functions.psm1"
$Arguments = "-Command `"Import-Module '{0}' ; Start-Templated -UserPath '{1}'`"" -f $Functions,$UserPath

$Now = Get-Date -UFormat "%d-%m-%Y %H:%M:%S"
Write-Output "starting process at: $Now" >> $LogFile

Start-ElevatedPS -Arguments $Arguments -OutFile $OutFile -ErrFile $ErrFile

$Now = Get-Date -UFormat "%d-%m-%Y %H:%M:%S"
Write-Output "ending process at: $Now" >> $LogFile
