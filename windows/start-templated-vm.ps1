param (
    [Parameter(Mandatory)] $UserPath
)

function PathName-Of {
    param (
        [String] $File
    )

    Join-Path -Path $PSScriptRoot -ChildPath $File
}

$AuthModule = PathName-Of "Auth.psm1"
Import-Module $AuthModule

$OutFile = "C:\Temp\templated.out.log"
$ErrFile = "C:\Temp\templated.err.log"

$Entrypoint = PathName-Of "entrypoint.ps1"
Start-ElevatedPS -Arguments "$Entrypoint -UserPath $UserPath" `
    -OutFile $OutFile `
    -ErrFile $ErrFile
