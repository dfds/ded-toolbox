#Requires -Modules Microsoft.Graph

param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$AzureADApplicationId,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [string]$ExtensionName,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [ValidateSet('String', 'string', 'Integer', 'integer')]
    [string]$ExtensionDataType = "string"
)

# Connect to the Graph as user and request the following permissions:
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"

# Create a new ArrayList
$SchemaProperties = New-Object -TypeName System.Collections.ArrayList

# Add prop to schema coll
[void]$SchemaProperties.Add(@{
    'name' = $ExtensionName;
    'type' = $ExtensionDataType;
})

# Create the new schema extension for all resources
$SchemaExtension = New-MgSchemaExtension -TargetTypes  @('Group', 'User') `
    -Properties $SchemaProperties `
    -Id 'DeveloperAutomation' `
    -Description 'DeveloperAutomation ABAC properties' `
    -Status 'Available' `
    -Owner $AzureADApplicationId

# Show extension schema meta data
Get-MgSchemaExtension -SchemaExtensionId $SchemaExtension.Id