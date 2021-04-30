<###################################################################################################################################
Check-Terraform-Providers.ps1
####################################################################################################################################
A simple script that will search the specified folder for Terraform files.  The search is recursive so it will also search all 
sub-folders.  The retrieved Terraform files are then parsed for provider definition blocks and the used providers and versions
are pulled and stored.  Finally the script will query Terraform Registry for the latest versions of the providers before
displaying a table that shows which providers are up to date, which are behind and which are configured to always use the most
recent version of the provider.
####################################################################################################################################
Parameters
Path            The path where your Terraform files are located.  Typically this will be the location where you clone your Git Repos
                If ommitted then the current directory will be presumed.
OutputFormat    The desired output format.  If not specified it will default to CSV.  You can also specify PSTable to have a
                PowerShell Table displayed.
####################################################################################################################################
Written by: Peter West
Date:       27th April 2021
####################################################################################################################################
Revision History
30th April 2021     Added option to output both CSV and PSTable
                    Changed from Write-Host to using Write-Verbose with flags so minimal output is shown natively, but the -Verbose
                    flag can be used if you need more information.
                    Tweaks to ensure it runs in PowerShell Core under 
                    General code tidy
####################################################################################################################################>
[CmdletBinding()]
Param(
    [string]$Path=(Get-Location),
    [ValidateSet("CSV","PSTable")][string]$OutputFormat="CSV"
)

Function GetTerraformFiles{
Param([string]$Path,[System.Collections.ArrayList]$FileCollection)

    # get all child items for the specified path
    $directoryItems = Get-ChildItem -Path $Path -Include *.tf -Recurse -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # buidl the path match based on the directory seperator
    [string]$pathExclusionFilter = "*" + $dSep + ".*" + $dSep + "*"

    # remove any found in the terragrunt-cache
    $directoryItems = ($directoryItems | Where-Object { $_.FullName -notlike $pathExclusionFilter })
    
    # return the found items
    return $directoryItems

}

# clear display
Clear-Host

# define required variables
[System.Collections.ArrayList]$usedProviders = New-Object -TypeName System.Collections.ArrayList
[string]$baseURL = "https://registry.terraform.io"

# get the directory seperator character to use
$dSep = [System.IO.Path]::DirectorySeparatorChar

# validate the path specified exists and throw an error if not
if (!(Test-Path $Path -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)) { Throw "The path specified does not exist.  The script will now terminate." }

# display status
Write-Verbose "Retrieving all Terraform files in the specified path: " -Verbose

# get all .tf files from the path specified and recursive folders
$terraformFiles = GetTerraformFiles -Path $Path

# display status
Write-Verbose "Done" -Verbose

# display status
Write-Verbose "" -Verbose
Write-Verbose "Processing Terraform Files:" -Verbose

# loop through the retrieved files
foreach($file in $terraformFiles)
{
    # reset variables
    [bool]$providerMatching = $false
    
    # display current file we're processing
    Write-Verbose (" File: " + $file.FullName)

    # import the file
    $terraformFile = Get-Content $file.FullName
    
    # if it includes a required_providers statement then...
    if ($terraformFile -match "required_providers") 
    { 
        [int]$braceCount = 0
        [string]$currentProviderName = ""
        [string]$currentProviderVersion = ""

        # loop through the lines of the file
        foreach($line in $terraformFile)
        {           
            # if we're in the required_providers block
            if ($providerMatching)
            {
                # count braces and use some logic so we break out of provider matching when we exit the block
                if ($line -match "{") { $braceCount = $braceCount + ($line.ToCharArray() | Where-Object { $_ -eq '{' } | Measure-Object).Count }
                if ($line -match "}") { $braceCount = $braceCount - ($line.ToCharArray() | Where-Object { $_ -eq '}' } | Measure-Object).Count }
                if ($braceCount -lt 0 ) { $providerMatching = $false ; break }
                
                # note the current provider name
                if ($line.Trim(" ") -match '^source *= *".*"') { $currentProviderName = $line.Split("=")[1].Replace("""","").Trim(" ") }

                # if the line contains a version label then note the current provider version
                if ($line.Trim(" ") -match '^version *= *".*"') { $currentProviderVersion = $line.Substring($line.IndexOf("=")+1).Replace("""", "").Trim(" ") }
                
                # if we're exiting the block then
                if ($line -match '}')
                {
                    # if no version was specified then set to Latest
                    if ($currentProviderVersion -eq "") { $currentProviderVersion = "Latest" }

                    # check if this provider is already referenced in the file (it shouldn't be, but just in case)
                    $checkExistingProviders = ($usedProviders | Where-Object { $_.FilePath -eq $file.FullName -and $_.ProviderName -eq $currentProviderName -and $_.ProviderVersion -eq $currentProviderVersion })

                    # if the provider wasn't already declared then create a new object instance and put it into the collection
                    if ($null -eq $checkExistingProviders)
                    {
                        [PSCustomObject]$usedProvider = @{"FilePath" = $file.FullName ; "ProviderName" = $currentProviderName ; "ProviderVersion"  = $currentProviderVersion}
                        [void]$usedProviders.Add($usedProvider)                        
                    }
                }
            }
        
            # set flag true when we hit the appropriate portion of the file
            if ($line -match "required_providers") { $providerMatching = $true }
        }
    } 
}

# display status
Write-Verbose "File Processing Complete" -Verbose
Write-Verbose "" -Verbose
Write-Verbose  "Retrieving Used Provider Information: " -Verbose

# create a unique list of used providers
$providerList = $usedProviders | Select-Object ProviderName | Sort-Object ProviderName -Unique

# now check the used providers to see what versions are available
foreach ($provider in $providerList)
{
    # display status
    Write-Verbose (" Querying Terraform Registry for the Provider '" + $provider.ProviderName + "'")

    # ensure the restData is set to null
    $restData = $null

    # get the provider info from Terraform Registry
    Try { $restData = Invoke-RestMethod -Uri ($baseURL + "/v1/providers/" + $provider.ProviderName) -Method Get -ContentType 'application/json' }

    # don't handle the error; we'll check for null return instead
    Catch {}

    # if the query worked then record the latest version othewise throw an error
    if ($restData -ne $null) { Add-Member -InputObject $provider -MemberType NoteProperty -Name LatestProviderVersion -Value $restData.version }
    else
    { Throw ("The Provider " + $provider.ProviderName + " could not be queried via the Terraform Registry API.") }
}

Write-Verbose "Used Providers check complete" -Verbose
Write-Verbose "" -Verbose
Write-Verbose "Comparing Used Providers with Current Versions: " -Verbose 

foreach($usedProvider in $usedProviders)
{
    # get the available provider
    $availableProvider = ($providerList | Where-Object { $_.ProviderName -eq $usedProvider.ProviderName } )

    # add the latest version to the usedProvider
    Add-Member -InputObject $usedProvider -MemberType NoteProperty -Name LatestVersion -Value $availableProvider.LatestProviderVersion        

    if ($usedProvider.ProviderVersion -match '^>=' -or $usedProvider.ProviderVersion -eq "Latest") { Add-Member -InputObject $usedProvider -MemberType NoteProperty -Name Comment -Value "Latest version will be used" }
    if ($usedProvider.ProviderVersion -match '^~>')
    {
        # convert the version numbers into major, minor and patch
        $lockedProviderVersion = $usedProvider.ProviderVersion.Replace("~>", "").Trim(" ").Split(".")
        $availableProviderVersion = $availableProvider.LatestProviderVersion.Split(".")

        # apply logic to identify appropriate comment
        if ($lockedProviderVersion[0] -eq $availableProviderVersion[0] -and $lockedProviderVersion[1] -eq $availableProviderVersion[1] -and $lockedProviderVersion[2] -ne $availableProviderVersion[2])
        {
            Add-Member -InputObject $usedProvider -MemberType NoteProperty -Name Comment -Value "Patch update only"        
        }
        else
        {
            # blank the comment as the default
            Add-Member -InputObject $usedProvider -MemberType NoteProperty -Name Comment -Value ""

            # set comment based on logic for major or minor version update
            if ($lockedProviderVersion[1] -ne $availableProviderVersion[1]) { $usedProvider.Comment = "Minor version update available" }
            if ($lockedProviderVersion[0] -ne $availableProviderVersion[0]) { $usedProvider.Comment = "Major version update available" }
        }
    }
}

Write-Verbose "Versions Comparison Complete" -Verbose
Write-Verbose ""
Write-Verbose ""

# display the provider information in the required format
if ($OutputFormat -eq 'CSV')
{
    $usedProviders | `
        Select-Object -Property @{Label="File Path";Expression={($_.FilePath)}},            `
            @{Label="Provider Name";Expression={($_.ProviderName)}}, `
            @{Label="Used Version";Expression={($_.ProviderVersion)}}, `
            @{Label="Latest Version";Expression={($_.LatestVersion)}}, `
            @{Label="Status";Expression={($_.Comment)}} | `
            ConvertTo-Csv
}
else {
    $usedProviders | `
        Select-Object -Property @{Label = "File Path"; Expression = { ($_.FilePath) } }, `
        @{Label = "Provider Name"; Expression = { ($_.ProviderName) } }, `
        @{Label = "Used Version"; Expression = { ($_.ProviderVersion) } }, `
        @{Label = "Latest Version"; Expression = { ($_.LatestVersion) } }, `
        @{Label = "Status"; Expression = { ($_.Comment) } } | `
        Format-Table -AutoSize
}
