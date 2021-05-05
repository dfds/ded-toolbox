# Microsoft Ubuntu Powershell container

Used to interact with powershell clis on multiple OS hosts.

Current CLI module support:

- MSGraph
- Azure.Standard.Preview

## Usage

### Build & Run container

```
docker build -t microsoft-ubuntu-powershell .
docker run --name microsoft-ubuntu-powershell-host -it -v \msgraph microsoft-ubuntu-powershell

NOTE: Remove container via docker rm microsoft-ubuntu-powershell-host -f
```

### PS Scripts

```
#MSGraph
./scripts/register_extension_schema.ps1 -AzureADApplicationId 66def2fd-0451-4719-8d00-4a925c746ee2  -ExtensionName "CustomExtension" -ExtensionDataType "string"

#AzureAD
./scripts/register_directory_extension_property.ps1 -AzureADApplicationId 66def2fd-0451-4719-8d00-4a925c746ee2 -ExtensionName "CustomExtension" -ExtensionDataType "string"
```
