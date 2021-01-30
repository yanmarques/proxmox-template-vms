# global vars
$defaultUserPath = "C:\Users\Administrator"

# fetch every disk
$disks = Get-Disk

# calls nssm to stop our service since we have no clue to continue running
# it must be called when this script finishes
function StopService {
    $nssm = (Get-Command nssm).Source
    & $nssm stop "Start templated"
}

# ensure we are on a template-based vm
if ($disks.Count -lt 2) {
    StopService
    exit 0
}

# store disk for latter use
$targetDisk = $disks.Get(0)

# store whether this is the first run, because the disk is still raw
$isRaw = $targetDisk.PartitionStyle -eq "RAW"

if ($isRaw) {
    # https://devblogs.microsoft.com/scripting/use-powershell-to-initialize-raw-disks-and-to-partition-and-format-volumes/
    # partition table, then the partiton of the whole disk finally format it with NTFS
    $targetDisk |
        Initialize-Disk -PartitionStyle MBR -PassThru |
        New-Partition -AssignDriveLetter -UseMaximumSize |
        Format-Volume -FileSystem NTFS -Confirm:$false
}

# store volume path to filter the Win32_Volume by DeviceID
$vol = $targetDisk | Get-Partition | Get-Volume

# get full drive directory
$winVolume = Get-WmiObject -Class Win32_Volume | Where DeviceID -eq $vol.Path
$directory = $winVolume.Name

# calculate some file paths
$usersDir = Join-Path -Path $directory -ChildPath Users
$configDir = Join-Path -Path $directory -ChildPath Config
$startupFile = Join-Path -Path $configDir -ChildPath "Startup.ps1"

# first time configuration
if ($isRaw) {
    # copy user directory as skeleton
    # /I - assumes destination is a directory and create for us
    # /H - copy system and hidden files
    # /E - copy directories and subdirectories
    # /C - continue even when something failed
    # /Q - quiet
    Invoke-Command -ScriptBlock {xcopy $defaultUserPath $usersDir /I /H /E /C /Q}

    # create config directory
    New-Item -Path $configDir -ItemType Directory

    # write default content to startup file
    Write-Output "# Write custom script that runs at system initialization`n" > $startupFile
}

# maybe remove user directory
if (Test-Path -Path $defaultUserPath) {
    Remove-Item -Path $defaultUserPath -Recurse -Force
}

# create symbolic link to user directory
$userFromPath = Split-Path -Path $defaultUserPath -Leaf
$userRealPath = Join-Path -Path $usersDir -ChildPath $userFromPath
New-Item -Path $defaultUserPath -ItemType SymbolicLink -Value $userRealPath

# run user startup script
Invoke-Command -ScriptBlock {powershell $startupFile}

StopService