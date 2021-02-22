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

$Functions = PathName-Of "Functions.psm1"
$Arguments = '-Command "Import-Module {0} ; Start-Templated -UserPath {1}"' -f $Functions,$UserPath
Start-ElevatedPS -Arguments $Arguments -OutFile $OutFile -ErrFile $ErrFile
