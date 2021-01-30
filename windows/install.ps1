param (
    $script,
    [String] $userPath='C:\Users\Administrator'
)

# try to obtain default script from PowerShell variables
if ($script -eq $null) {
    $script = Join-Path -Path $PSScriptRoot -ChildPath start-templated-vm.ps1
}

function RegisterGPOStartupScript {
    param (
        $gpoPath
    )

    # how many scripts this path have
    $existingScriptsCount = (Get-ChildItem -Path $gpoPath).Length

    # loop through every possible subkey registry
    # remove if the script property matches our script
    for ($count = 0; $count -lt $existingScriptsCount; $count++) {
        $regPath = Join-Path -Path $gpoPath -ChildPath $count.ToString()
        $currentScript = (Get-ItemProperty -Path $regPath).Script
    
        if ($currentScript -eq $script) {
            Write-Output ("[+] Removing existing script at index: {0}" -f $count)
            Remove-Item -Path $regPath
        }
    }

    # the path to our new script
    $regPath = Join-Path -Path $gpoPath -ChildPath $existingScriptsCount.ToString()

    # the script receives the user path as parameter
    $parameters = '-UserPath "{0}"' -f $userPath

    Write-Output ("[+] Creating startup script on: {0}" -f $gpoPath)

    # first create the script registry subkey
    New-Item -Path $regPath | Out-Null

    # then configure with the required properties
    New-ItemProperty -Path $regPath -Name ExecTime -Value 0 -PropertyType Qword | Out-Null
    New-ItemProperty -Path $regPath -Name IsPowershell -Value 1 -PropertyType DWord | Out-Null
    New-ItemProperty -Path $regPath -Name Parameters -Value $parameters -PropertyType String | Out-Null
    New-ItemProperty -Path $regPath -Name Script -Value $script -PropertyType String | Out-Null

    Write-Output "[+] Startup script registered"
}

# don't know why, but group policy needs these two registries filled with our configuration
RegisterGPOStartupScript "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0"
RegisterGPOStartupScript "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0"

Write-Output ("[+] Allowing AUTHORITY\SYSTEM user to delete {0}" -f $userPath)

# give AUTHORITY\SYSTEM user the permission to delete the user directory
$icacls = (Get-Command icacls).Source
& $icacls $userPath /T /C /grant System:D | Out-Null

Write-Output "[+] Done"