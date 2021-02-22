param (
    [Parameter(Mandatory)] $UserPath
)

# Default logging targets
$OutFile = "C:\Temp\templated\out.log"
$ErrFile = "C:\Temp\templated\err.log"

function PathName-Of {
    param (
        [String] $File
    )

    Join-Path -Path "C:\Program Files\proxmox-template-vms\windows" -ChildPath $File
}

Write-Output "pre-starting templated-vm" > $OutFile

$AuthModule = PathName-Of "Auth.psm1"
Write-Output "importing module: $AuthModule" >> $OutFile
Import-Module $AuthModule

Write-Output "starting templated-vm" >> $OutFile

$Functions = PathName-Of "Functions.psm1"
$Arguments = "-Command `"Import-Module '{0}' ; Start-Templated -UserPath '{1}'`"" -f $Functions,$UserPath
Start-ElevatedPS -Arguments $Arguments -OutFile $OutFile -ErrFile $ErrFile
