[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $CapabilityRootId,

    [Parameter()]
    [string]
    $Domain = "dfds.root",

    [Parameter()]
    [string]
    $GroupPath = "OU=AWS,OU=Permissions,OU=Groups,DC=dfds,DC=root",

    [Parameter(Mandatory)]
    [string]
    $AccountId
)

# Determine group names and properties
$CapabilityGroupName = "P AWS $CapabilityRootId Capability"
$LogsGroupName = "P AWS $CapabilityRootId Logs"
$LogsGroupMail = "capabilities/${CapabilityRootId}@${AccountId}"

# Get domain controller
$DC = Get-ADDomainController -DomainName $Domain -Discover | Select -Expand HostName | Select -First 1
Write-Host "Using domain controller $DC"

# Create group
Write-Host "Creating AD group with name ""$LogsGroupName"" and email address $LogsGroupMail"
New-ADGroup -DisplayName $LogsGroupName -Name $LogsGroupName -GroupCategory Security -GroupScope Universal -Path $GroupPath -Description "Grants access to capabilty's log groups in dfds-logs" -Server $DC -OtherAttributes @{'mail' = $LogsGroupMail }

# Copy group members from Capability group
Write-Host "Copying group members from ""$CapabilityGroupName"" to ""$LogsGroupName"""
Add-ADGroupMember -Identity $LogsGroupName -Members (Get-ADGroupMember -Identity $CapabilityGroupName -Server $DC) -Server $DC