# Global settings
$UserName = 'TemplatedLocalAcct'
$Password = 'p4ssw0rd'

$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

function Start-ElevatedPS {
    param (
        [Parameter(Mandatory)] $Arguments,
        [Parameter(Mandatory)] $OutputFile
    )

    $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecurePassword
    
    # Call powershell with local account credentials
    Start-Process powershell.exe `
        -ArgumentList $Arguments `
        -Credential $Credential `
        -RedirectStandardOutput $OutputFile `
        -RedirectStandardError $OutputFile
}

function Get-LocalAccount {
    Get-LocalUser -Name $UserName > $null 2>&1
}

function Add-LocalAccount {
    New-LocalUser -Name $UserName -Password $SecurePassword | Out-Null
}