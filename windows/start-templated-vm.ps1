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

$logFile = "C:\Temp\templated.log"

$Entrypoint = PathName-Of "entrypoint.ps1"
Start-ElevatedPS -Arguments "$Entrypoint -UserPath $UserPath" `
    -OutputFile $logFile
