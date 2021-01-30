# global vars
$name = "Start templated"

# retrieve service binary path
# maybe this is easiest and more stable way to do
$psPath = Join-Path -Path $PSScriptRoot -ChildPath start-templated-vm.ps1

# try to get any existing service with our name
$oldService = Get-WmiObject -Class Win32_Service -Filter "Name='$name'"

# maybe remove it
if ($oldService -neq $null) {
    $oldService.Delete()
}

# register the templated service
New-Service -Name $name -BinaryPathName "powershell.exe -File $psPath"