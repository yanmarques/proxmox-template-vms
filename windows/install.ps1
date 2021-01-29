# retrieve service binary path
# maybe this is easiest and more stable way to do
$binaryPathName = Join-Path -Path $PSScriptRoot -ChildPath start-templated-vm.ps1

# register the templated service
New-Service -Name 'Start templated' -BinaryPathName $binaryPathName