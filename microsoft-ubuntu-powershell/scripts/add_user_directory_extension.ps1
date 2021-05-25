#Requires -Modules AzureAD.Standard.Preview

param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$UserObjectId,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$ExtensionName,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$ExtensionValue
)

# Connect to AzureAD 
Connect-AzureAD

# Add extension property value to user
Set-AzureADUserExtension -ObjectId $UserObjectId -ExtensionName $ExtensionName -ExtensionValue $ExtensionValue