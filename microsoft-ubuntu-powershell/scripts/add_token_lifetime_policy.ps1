#Requires -Modules AzureAD.Standard.Preview

param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$AzureADApplicationId,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$AccessTokenLifetime = "00:00:10"
)

# Connect to AzureAD 
Connect-AzureAD

# Create new TokenLifeTimePolicy
$policy = New-AzureADPolicy -Definition @('{"TokenLifetimePolicy":{"Version":1,"AccessTokenLifetime":"$AccessTokenLifetime"}}') -DisplayName "$AzureADApplicationId-TokenLifetimePolicy" -IsOrganizationDefault $false -Type "TokenLifetimePolicy"

# Fetch service principal of target reg
$servicePrincipal = Get-AzureADServicePrincipal -Filter "AppId eq '$AzureADApplicationId'"

# Assign policy to service principal
Add-AzureADServicePrincipalPolicy -Id $servicePrincipal.ObjectId -RefObjectId $policy.Id