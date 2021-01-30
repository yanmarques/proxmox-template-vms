# global vars
$serviceName = "Start templated"
$scriptFile = "start-templated-vm.ps1"

# app directory, it's easier to find our powershell script
$appDirectory = $PSScriptRoot

# escape our powershell path with double quotes
$appParams = "-ExecutionPolicy Bypass -NoProfile -File $scriptFile"

# powershell.exe absolute path
$psWinPath= (Get-Command powershell).Source

# nssm absolute path
$nssm = (Get-Command nssm).Source

# remove any existing service
& $nssm stop $serviceName confirm
& $nssm remove $serviceName confirm

# install service
& $nssm install $serviceName $psWinPath

# set the shiny diamond
& $nssm set $serviceName AppDirectory $appDirectory
& $nssm set $serviceName AppParameters $appParams
& $nssm set $serviceName Start SERVICE_AUTO_START