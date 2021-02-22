# Global settings
$UserName = 'TemplatedLocalAcct'
$Password = 'p4ssw0rd'

$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

function Start-ElevatedPS {
    param (
        [String] $Arguments,
        [String] $OutputFile
    )

    $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecurePassword
    
    # Call powershell with local account credentials
    Start-Process powershell.exe `
        -Arguments $Arguments `
        -Credential $Credential `
        -RedirectStandardOutput $OutputFile `
        -RedirectStandardError $OutputFile
}

function Get-LocalAccount {
    Get-LocalUser -Name $UserName
}

function Add-LocalAccount {
    New-LocalUser -Name $UserName -Password $SecurePassword
}