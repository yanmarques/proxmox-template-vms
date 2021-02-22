param (
    [Parameter(Mandatory)] $UserPath
)

# Default logging targets
$OutFile = "C:\Temp\templated\out.log"
$ErrFile = "C:\Temp\templated\err.log"

Write-Output "pre-starting templated-vm" > $OutFile

function Get-FullPath {
    param (
        [String] $File
    )

    Join-Path -Path "C:\Program Files\proxmox-template-vms\windows" -ChildPath $File
}

$AuthModule = Get-FullPath "Auth.psm1"
Write-Output "importing module: $AuthModule" >> $OutFile
Import-Module $AuthModule

Write-Output "starting templated-vm" >> $OutFile

$Functions = Get-FullPath "Functions.psm1"
$Arguments = "-Command `"Import-Module '{0}' ; Start-Templated -UserPath '{1}'`"" -f $Functions,$UserPath
Start-ElevatedPS -Arguments $Arguments -OutFile $OutFile -ErrFile $ErrFile
