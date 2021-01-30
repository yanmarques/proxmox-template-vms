# global vars
$serviceName = "Start templated"

# retrieve service binary path
# maybe this is easiest and more stable way to do
$psPath = Join-Path -Path $PSScriptRoot -ChildPath start-templated-vm.ps1

# remove any existing service
Invoke-Command -ScriptBlock {nssm remove $serviceName confirm}

# get absolute path powershell.exe
$psWinPath= (Get-Command powershell).Source

# service arguments with our ps1
$args = '-ExecutionPolicy Bypass -NoProfile -File "{0}"' -f $psPath

# install service
Invoke-Command -ScriptBlock {nssm install $serviceName $psWinPath $args}