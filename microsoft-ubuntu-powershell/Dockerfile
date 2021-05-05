FROM mcr.microsoft.com/powershell

WORKDIR /msgraphpwsh

COPY ./scripts/register_extension_schema.ps1 ./scripts

#Set default SHELL to pwsh
SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]

#Microsoft modules from PSGallery
RUN Install-Module Microsoft.Graph -Force

#TODO: Test if Windows authentication with gMSA will sort out the device code challenges for each single API call to MS Graph
#https://www.axians-infoma.de/techblog/setting-up-windows-authentication-with-containers-connect-to-azure-ad-domain-services/

ENTRYPOINT [ "pwsh" ]