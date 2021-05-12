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
./scripts/register_extension_schema.ps1 -AzureADApplicationId 00000000-0000-0000-0000-000000000000  -ExtensionName "CustomExtension" -ExtensionDataType "string"

#AzureAD
./scripts/register_directory_extension_property.ps1 -AzureADApplicationId 00000000-0000-0000-0000-000000000000 -ExtensionName "CustomExtension" -ExtensionDataType "string"
```
