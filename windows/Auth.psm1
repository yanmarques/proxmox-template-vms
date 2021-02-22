# Global settings
$UserName = 'Administrator'
$Password = 'p4ssw0rd'

$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

function Start-ElevatedPS {
    param (
        [Parameter(Mandatory)] $Arguments,
        [Parameter(Mandatory)] $OutFile,
        [Parameter(Mandatory)] $ErrFile
    )

    $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecurePassword
    
    # Call powershell with local account credentials
    Start-Process powershell.exe `
        -ArgumentList $Arguments `
        -Credential $Credential `
        -RedirectStandardOutput $OutFile `
        -RedirectStandardError $ErrFile `
        -Wait
}

function Set-AdminLocalPassword {
    Set-LocalUser -Name $UserName -Password $SecurePassword | Out-Null
}

function Get-IsAdmin {
    $CurrentSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().Owner.Value
    "S-1-5-32-544" -eq $CurrentSID
}

function Set-WinAutoLogon {
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    New-ItemProperty -Path $RegPath -Name DefaultUserName -Value $UserName -PropertyType String | Out-Null
    New-ItemProperty -Path $RegPath -Name DefaultPassword -Value $Password -PropertyType String | Out-Null
    New-ItemProperty -Path $RegPath -Name AutoAdminLogon -Value 1 -PropertyType String | Out-Null
}