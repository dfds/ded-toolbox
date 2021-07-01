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

    function Write-TestDescription ($TestDescription) {
        $DescriptionLength = 50
        $WriteString = " - ${TestDescription}: ".PadRight($DescriptionLength)
        Write-Host $WriteString -NoNewline -ForegroundColor Gray
    }

    function Write-TestResult ($TestResult, $ActualValue) {

        Switch ($TestResult) {
            "Problem" { $ResultColor = 'Red'; $ResultString = $_ }
            "Warning" { $ResultColor = 'Yellow'; $ResultString = $_ }
            Default { $ResultColor = 'Green'; $ResultString = $_ }
        }

        Write-Host $ResultString -ForegroundColor $ResultColor -NoNewline
        Write-Host " (is '$ActualValue')" -ForegroundColor Gray 

    }

    # Discover a domain controller
    Write-Host "`r"
    $Dc = Get-ADDomainController -Discover | Select -Expand HostName | Select -First 1
    Write-Verbose "Domain controller: $Dc"
    
}

process {

    ForEach ($Name in $UserName) {

        # Get user objects
        Write-Verbose "Searching for username '$Name'"
        $Users = @(Get-ADUser -filter "SamAccountName -eq '$Name' -or UserPrincipalName -eq '$Name' -or Mail -eq '$Name' -or Mail -like '${Name}@*'" -Server "${Dc}:3268" -Properties Mail, MemberOf, CanonicalName)
        Write-Verbose "$($Users.Count) user(s) found"

        ForEach ($User in $Users) {

            Write-Host "$($User.DistinguishedName)"

            # Mail address is present
            Write-TestDescription "User Principal Name field must be populated"
            Switch ($User.UserPrincipalName) {
                { $_ -match "^.*@\w*\.\w*" } { Write-TestResult -TestResult OK -ActualValue $_ }
                Default { Write-TestResult -TestResult Problem -ActualValue $_ }
            }

            # UPN suffix is @dfds.com
            Write-TestDescription "UPN suffix should be 'dfds.com'"
            Switch ($User.UserPrincipalName.Split('@')[1]) {
                'dfds.com' { Write-TestResult -TestResult OK -ActualValue $_ }
                Default { Write-TestResult -TestResult Problem -ActualValue $_ }
            }

            # Mail address is present
            Write-TestDescription "Mail address field must be populated"
            Switch ($User.Mail) {
                { $_ -match "^.*@\w*\.\w*" } { Write-TestResult -TestResult OK -ActualValue $_ }
                Default { Write-TestResult -TestResult Problem -ActualValue $_ }
            }

            # Mail address is same as UPN
            Write-TestDescription "Email address and UPN should match"
            Switch ($User.UserPrincipalName -eq $User.Mail) {
                $true { Write-TestResult -TestResult OK -ActualValue $_ }
                Default { Write-TestResult -TestResult Warning -ActualValue $_ }
            }

            # Account in DK domain
            Write-TestDescription "Account should probably be in DK domain"
            Switch ($User.CanonicalName.Split('/')[0]) {
                'dk.dfds.root' { Write-TestResult -TestResult OK -ActualValue $_ }
                Default { Write-TestResult -TestResult Warning -ActualValue $_ }
            }

            Write-Host "`r"

        }

    }

}

end {
    
    Write-Host "See " -NoNewline -ForegroundColor White
    Write-Host "https://wiki.dfds.cloud/documentation/support/user-accounts" -NoNewline -ForegroundColor Cyan
    Write-Host " for more info.`n"
    
}