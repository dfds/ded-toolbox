#Requires -Modules AzureAD.Standard.Preview

param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$AzureADApplicationId,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$ExtensionName,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [ValidateSet('String', 'string', 'Integer', 'integer')]
    [string]$ExtensionDataType = "string"
)

# Support functions
function GetExtensionProperty{
    Param( 
        [Parameter(Mandatory=$true)]
        [String]$ExtensionName,

        [Parameter(Mandatory=$true)]
        [String]$OwnerId
    )

    $extension = (Get-AzureADApplicationExtensionProperty -ObjectId $OwnerId).Where( { $_.Name.endsWith($ExtensionName)})[0]

    return @{ 
        "JwtClaimType" = $ExtensionName 
        "ExtensionId"  = $extension.Name
    }
}

# Connect to AzureAD 
Connect-AzureAD

# Fetch app registration
$AppRegistration = Get-AzureADApplication -Filter "AppId eq '$AzureADApplicationId'"

# Fetch extension property meta data
$AppExtensionProperty = GetExtensionProperty -ExtensionName $ExtensionName -OwnerId $AppRegistration.ObjectId

# If meta data does not contain an Id the extension property needs to be created
if($AppExtensionProperty.ExtensionId -eq $null){
    # Create a new extension property in Azure AD Graph
    New-AzureADApplicationExtensionProperty -ObjectId $AppRegistration.ObjectId -Name $ExtensionName -DataType $ExtensionDataType -TargetObjects @("User")

    # Reacquire extension property meta data to populate ExtensionId
    $AppExtensionProperty = GetExtensionProperty -ExtensionName $ExtensionName -OwnerId $AppRegistration.ObjectId

    # Configure claims mapping policy for app registration service principal
    $ClaimsMappingPolicy = [ordered]@{
      "ClaimsMappingPolicy" = [ordered]@{
        "Version"              = 1
        "IncludeBasicClaimSet" = $true
        "ClaimsSchema"         = @(
          [ordered]@{
            "Source"       = "User"
            "ExtensionID"  = $ExtensionReference.ExtensionId
            "JwtClaimType" = $ExtensionReference.JwtClaimType
          }
        )
      }
    }

    # Fetch service principal of app registration
    $SecurityPrincipal = (Get-AzureADServicePrincipal -Filter "AppId eq '$AzureADApplicationId'") 
    
    # Convert hashtable to json
    $PolicyDefinition = $ClaimsMappingPolicy | ConvertTo-Json -Depth 99 -Compress

    # Create new Azure AD policy object with new policy
    $Policy = New-AzureADPolicy -Type "ClaimsMappingPolicy" -DisplayName $AppRegistration.DisplayName -Definition $PolicyDefinition

    # Add policy to app registration service principal
    Add-AzureADServicePrincipalPolicy -Id $SecurityPrincipal.ObjectId -RefObjectId $Policy.Id
}