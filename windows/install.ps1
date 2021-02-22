param (
    $script,
    [String] $userPath='C:\Users\Administrator'
)

Import-Module .\Auth.psm1

# try to obtain default script from PowerShell variables
if ($script -eq $null) {
    $script = Join-Path -Path $PSScriptRoot -ChildPath start-templated-vm.ps1
}

function RegisterGPOStartupScript {
    param (
        $gpoPath,
        [Boolean] $setIsPowershell=$true
    )
       
    # ensure registry exists and configured
    #
    # the configuration comes from the registry when a new script is appended
    # in the group policy editor
    if (!(Test-Path -Path $gpoPath)) {
        # create the whole path
        New-Item -Force -Path $gpoPath | Out-Null

        # default settings
        New-ItemProperty -Path $gpoPath -Name DisplayName -Value "Local Group Policy" -PropertyType String | Out-Null
        New-ItemProperty -Path $gpoPath -Name FileSysPath -Value "C:\Windows\System32\GroupPolicy\Machine" -PropertyType String | Out-Null
        New-ItemProperty -Path $gpoPath -Name GPO-ID -Value "LocalGPO" -PropertyType String | Out-Null
        New-ItemProperty -Path $gpoPath -Name SOM-ID -Value "Local" -PropertyType String | Out-Null

        # set to execute powershell scripts first
        New-ItemProperty -Path $gpoPath -Name PSScriptOrder -Value 2 -PropertyType DWord | Out-Null
    }

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

    if ($setIsPowershell) {
        New-ItemProperty -Path $regPath -Name IsPowershell -Value 1 -PropertyType DWord | Out-Null    
    }

    # then configure with the required properties
    New-ItemProperty -Path $regPath -Name ExecTime -Value 0 -PropertyType Qword | Out-Null
    New-ItemProperty -Path $regPath -Name Parameters -Value $parameters -PropertyType String | Out-Null
    New-ItemProperty -Path $regPath -Name Script -Value $script -PropertyType String | Out-Null

    Write-Output "[+] Startup script registered"
}

# don't know why, but group policy needs these two registries filled with our configuration
RegisterGPOStartupScript "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0"
RegisterGPOStartupScript -SetIsPowershell $false "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0"

# ensure local account exists
if (Get-LocalAccount) {
    Write-Output "[+] Local account already exists"
} else {
    Add-LocalAccount
    Write-Output "[+] Local account was created with success"
}

Write-Output "[+] Done"