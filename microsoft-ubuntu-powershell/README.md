# Microsoft Graph Register Extension Schema 

Used to interact with Microsoft Graph using Powershell

## Usage


### Build & Run container workload

```
docker build -t ubuntu-powershell-msgraph-cli .
docker run --name ubuntu-powershell-host -it -v \msgraph ubuntu-powershell-msgraph-cli
```

### Execute script in container shell

```
.\register_extension_schema.ps1 66def2fd-0451-4719-8d00-4a925c746ee2
```
