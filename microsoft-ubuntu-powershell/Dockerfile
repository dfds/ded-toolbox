FROM mcr.microsoft.com/powershell:preview

WORKDIR /pwsh

COPY ./scripts/ ./scripts/

# Set default SHELL to use powershell (pwsh)
SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]

# Install MS Graph module from PSGallery
RUN Install-Module Microsoft.Graph -Force

# Install AzureAD.Standard.Preview module from PoshTestGallery
RUN Register-PackageSource -Trusted -Name PoshTestGallery -Location https://www.poshtestgallery.com/api/v2/ -ProviderName PowerShellGet && \
    Install-Module -Name AzureAD.Standard.Preview -Force

#TODO: Test if Windows authentication with gMSA will sort out the device code challenges for each single API call to MS Graph
#https://www.axians-infoma.de/techblog/setting-up-windows-authentication-with-containers-connect-to-azure-ad-domain-services/

CMD pwsh -NoExit -Command { Import-Module -Name /root/.local/share/powershell/Modules/AzureAD.Standard.Preview/0.1.599.7/AzureAD.Standard.Preview.psm1 }