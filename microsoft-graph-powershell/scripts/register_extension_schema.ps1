# Connect to the Graph as user and request the following permissions:
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"

# Configure script variables
$appId = "66def2fd-0451-4719-8d00-4a925c746ee2"

# Create a new ArrayList
$SchemaProperties = New-Object -TypeName System.Collections.ArrayList

# Add prop to schema coll
[void]$SchemaProperties.Add(@{
    'name' = 'dfdsAccessBitField';
    'type' = 'Integer';
})

# Create the new schema extension for all resources
$SchemaExtension = New-MgSchemaExtension -TargetTypes  @('Group', 'User') `
    -Properties $SchemaProperties `
    -Id 'DeveloperAutomation' `
    -Description 'DeveloperAutomation ABAC properties' `
    -Owner $appId

# Get the new schema extension object
Get-MgSchemaExtension -SchemaExtensionId $SchemaExtension.Id | fl

#-------------------------------------
# Set the status to Available
# (if needed for production)
#-------------------------------------
# Update-MgSchemaExtension -SchemaExtensionId $SchemaExtension.Id `
#     -Status 'Available' `
#     -Owner $appId 

#-------------------------------------
# Set new data with the appId
#-------------------------------------
# https://graph.microsoft.com/v1.0/users/<userid>
# PATCH
# {
#     "ext2irw6qzw_DeveloperAutomation": {
#       "costcenter": "K100",
#       "pin": 1220,
#       "isdirector": true }
# }

# End.