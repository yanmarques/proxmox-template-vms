param (
    [Parameter(Mandatory)] $UserPath
)

# Default logging targets
$LogFile = "C:\Temp\templated\log"
$OutFile = "C:\Temp\templated\out.log"

# ensure directory exists
New-Item -Path "C:\Temp\templated\" -ItemType Directory -Force

Write-Output "pre-starting templated-vm" > $LogFile

function Get-FullPath {
    param (
        [String] $File
    )

    Join-Path -Path "C:\Program Files\proxmox-template-vms\windows" -ChildPath $File
}

function Now {
    Get-Date -UFormat "%d-%m-%Y %H:%M:%S"
}

$AuthModule = Get-FullPath "Auth.psm1"
Write-Output "importing module: $AuthModule" >> $LogFile
Import-Module $AuthModule

Write-Output "starting templated-vm" >> $LogFile

$Functions = Get-FullPath "Functions.ps1"
$Arguments = "-UserPath '{1}'" -f $UserPath

Write-Output "starting process at: $(Now)" >> $LogFile

Start-ElevatedPS -File $Functions -ArgumentList $Arguments -OutFile $OutFile

Write-Output "ending process at: $(Now)" >> $LogFile
