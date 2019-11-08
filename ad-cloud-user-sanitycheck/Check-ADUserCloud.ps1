#Requires -Module ActiveDirectory 

<#
.SYNOPSIS
    Check for common issues for user accounts that are meant to be used in AWS, Azure DevOps etc.
.DESCRIPTION
    Check for common issues for user accounts that are meant to be used in AWS, Azure DevOps etc.
.EXAMPLE
    PS C:\> ./Check-ADUserCloud.ps1 raras, wicar, hemor, ruabr
    Explanation of what the example does
.LINK
    https://wiki.build.dfds.com/infrastructure/user-accounts
#>

[CmdletBinding()]

param (
    [Parameter()]
    [string[]]
    $UserName
)

begin {

    # Discover a domain controller
    Write-Host "`r"
    $Dc = Get-ADDomainController -Discover | Select -Expand HostName | Select -First 1
    Write-Verbose "Domain controller: $Dc"
    
}

process {

    ForEach ($Name in $UserName) {

        # Get user objects
        Write-Verbose "Searching for username '$Name'"
        $Users = @(Get-ADUser -filter "samAccountName -eq '$Name'" -Server "${Dc}:3268" -Properties mail, memberOf)
        Write-Verbose "$($Users.Count) user(s) found"

        ForEach ($User in $Users) {

            Write-Host "$($User.DistinguishedName)"

            # UPN suffix is @dfds.com
            Write-Host " - User Principal Name suffix (UPN-suffix) should be 'dfds.com': " -NoNewline -ForegroundColor Gray
            Switch ($User.UserPrincipalName.Split('@')[1]) {
                'dfds.com' { Write-Host "OK" -ForegroundColor Green -NoNewline; Write-Host " (is '$_')" -ForegroundColor Gray }
                Default { Write-Host "Problem" -ForegroundColor Red -NoNewline; Write-Host " (is '$_')" -ForegroundColor Gray }
            }

            # Mail address is present
            Write-Host " - Mail address field must be populated: " -NoNewline -ForegroundColor Gray
            Switch ($User.Mail) {
                { $_ -match "^\w*@\w*\.\w*" } { Write-Host "OK" -ForegroundColor Green -NoNewline; Write-Host " (is '$_')" -ForegroundColor Gray }
                Default { Write-Host "Problem" -ForegroundColor Red -NoNewline; Write-Host " (is '$_')" -ForegroundColor Gray }
            }

            # Mail address is same as UPN
            Write-Host " - Email address and UPN should match: " -NoNewline -ForegroundColor Gray
            Switch ($User.UserPrincipalName -eq $User.Mail) {
                $true { Write-Host "OK" -ForegroundColor Green -NoNewline; Write-Host " (UPN: $($User.UserPrincipalName), Mail: $($User.Mail))" -ForegroundColor Gray }
                Default { Write-Host "Warning" -ForegroundColor Yellow -NoNewline; Write-Host " (UPN: $($User.UserPrincipalName), Mail: $($User.Mail))" -ForegroundColor Gray }
            }

            # Mail address is same as UPN
            Write-Host " - Email address and UPN should match: " -NoNewline -ForegroundColor Gray
            Switch ($User.UserPrincipalName -eq $User.Mail) {
                $true { Write-Host "OK" -ForegroundColor Green -NoNewline; Write-Host " (UPN: $($User.UserPrincipalName), Mail: $($User.Mail))" -ForegroundColor Gray }
                Default { Write-Host "Warning" -ForegroundColor Yellow -NoNewline; Write-Host " (UPN: $($User.UserPrincipalName), Mail: $($User.Mail))" -ForegroundColor Gray }
            }

            Write-Host " - Account should probably be in DK domain: " -NoNewline -ForegroundColor Gray
            Switch ($User.DistinguishedName) {
                $true { Write-Host "OK" -ForegroundColor Green -NoNewline; Write-Host " (UPN: $($User.UserPrincipalName), Mail: $($User.Mail))" -ForegroundColor Gray }
                Default { Write-Host "Warning" -ForegroundColor Yellow -NoNewline; Write-Host " (UPN: $($User.UserPrincipalName), Mail: $($User.Mail))" -ForegroundColor Gray }
            }



            # Number of groups
            # DK domain

            Write-Host "`r"

        }

    }

}

end {
    
    Write-Host "See " -NoNewline -ForegroundColor White
    Write-Host "https://wiki.build.dfds.com/infrastructure/user-accounts" -NoNewline -ForegroundColor Cyan
    Write-Host " for more info.`n"
    
}