#Requires -Module ActiveDirectory 

<#
.SYNOPSIS
    Patch properties of AD groups matching defined filters. Adjust filters and patches as needed.
.DESCRIPTION
    Patch properties of AD groups matching defined filters. Adjust filters and patches as needed.
#>

# Define variables
$Domain = "dfds.root"
$SearchBase = "OU=AWS,OU=Permissions,OU=Groups,DC=dfds,DC=root"
$GroupNameFilter = "*"
$GroupNameRegEx = "^P AWS ([\w-]+-\w{5}) Oxygen$"
$OxygenAccountId = "738063116313"

# Get domeain controller
$DC = Get-ADDomainController -DomainName $Domain -Discover | Select -Expand HostName | Select -First 1

# Get groups matching filter and regex
$Groups = Get-ADGroup -Server $DC -SearchBase $SearchBase -Filter "Name -like '$GroupNameFilter'" -Properties mail |
Where Name -match $GroupNameRegEx | Sort Name

# Patch group email
ForEach ($Group in $Groups) {
    If ($Group.Name -match $GroupNameRegEx) {

        Write-Host $Group.name
        $RootId = $Matches[1]
        $Email = "capabilities/${RootId}@${OxygenAccountId}"

        # Modify group object
        Write-Host "mail --> $Email"
        $Group.mail = $Email
        
        # Write changes
        Set-ADGroup -Instance $Group
    }
}
