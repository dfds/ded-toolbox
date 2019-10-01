
    [CmdletBinding(DefaultParameterSetName = 'DeployScript')]
    param
    (
        [Parameter(Mandatory = $true,
            ParameterSetName = 'DeployScript',
            HelpMessage = 'The name of the AWS Lambda function that will execute the PowerShell script.')]
        [Parameter(ParameterSetName = 'DeployProject')]
        [string]$Name,

        [Parameter(Mandatory = $true,
            ParameterSetName = 'DeployScript',
            HelpMessage = 'The path to the PowerShell script to be published to AWS Lambda.')]
        [string]$ScriptPath,

        [Parameter(ParameterSetName = 'DeployScript')]
        [string]$StagingDirectory,

        [Parameter(Mandatory = $true,
            ParameterSetName = 'DeployProject',
            HelpMessage = 'The path to the PowerShell project to be published to AWS Lambda.')]
        [string]$ProjectDirectory,

        [Parameter(ParameterSetName = 'DeployProject')]
        [string]$Handler,

        [Parameter(ParameterSetName = 'DeployProject')]
        [switch]$DisableModuleRestore,

        [Parameter()]
        [string]$PowerShellFunctionHandler,

        [Parameter()]
        [string]$ProfileName,

        [Parameter()]
        [string]$Region,

        [Parameter()]
        [string]$IAMRoleArn,

        [Parameter()]
        [int]$Memory,

        [Parameter()]
        [int]$Timeout,

        [Parameter()]
        [Switch]$PublishNewVersion,

        [Parameter()]
        [Hashtable]$EnvironmentVariable,

        [Parameter()]
        [string]$KmsKeyArn,

        [Parameter()]
        [string[]]$Subnet,

        [Parameter()]
        [string[]]$SecurityGroup,

        [Parameter()]
        [string]$DeadLetterQueueArn,

        [Parameter()]
        [ValidateSet('Active', 'PassThrough')]
        [string]$TracingMode,

        [Parameter()]
        [string]$S3Bucket,

        [Parameter()]
        [string]$S3KeyPrefix,

        [Parameter()]
        [Hashtable]$Tag,

        [Parameter()]
        [string[]]$ModuleRepository,

        [Parameter(ParameterSetName = 'DeployScript')]
        [string]$PowerShellSdkVersion,

        [Parameter()]
        [Switch]$DisableInteractive
    )

    _validateDotnetInstall

    # If staging directory is a new temp directory then delete the stage directory after publishing completes
    $deleteStagingDirectory = $false

    if ($PSCmdlet.ParameterSetName -eq 'DeployScript')
    {
        if (!(Test-Path -Path $ScriptPath))
        {
            throw "Script $ScriptPath does not exist."
        }

        if (!($StagingDirectory))
        {
            $deleteStagingDirectory = $true
        }

        # Creates and returns an updated StagingDirectory with the ScriptName inside it
        $_name = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
        $stagingSplat = @{
            Name             = $_name
            StagingDirectory = $StagingDirectory
        }
        $StagingDirectory = _createStagingDirectory @stagingSplat

        $_scriptPath = (Resolve-Path -Path $ScriptPath).Path
        $_buildDirectory = (Resolve-Path -Path $StagingDirectory).Path

        $splat = @{
            ProjectName = $Name
            ScriptFile  = [System.IO.Path]::GetFileName($_scriptPath)
            Directory   = $_buildDirectory
            QuietMode   = $false
            PowerShellSdkVersion = $PowerShellSdkVersion
        }
        _addPowerShellLambdaProjectContent @splat

        Write-Host 'Copying PowerShell script to staging directory'
        Copy-Item -Path $_scriptPath -Destination $_buildDirectory

        $splat = @{
            Script           = $_scriptPath
            ProjectDirectory = $_buildDirectory
            ClearExisting    = $true
            ModuleRepository = $ModuleRepository
        }
        _prepareDependentPowerShellModules @splat

        $namespaceName = _makeSafeNamespaceName $Name
        $_handler = "$Name::$namespaceName.Bootstrap::ExecuteFunction"
    }
    else
    {
        if (!($ProjectDirectory))
        {
            $ProjectDirectory = $pwd.Path
        }

        if (!(Test-Path -Path $ProjectDirectory))
        {
            throw "Project directory $ProjectDirectory does not exist."
        }

        if (!($DisableModuleRestore))
        {
            $clearExisting = $true
            Get-ChildItem -Path $ProjectDirectory\*.ps1 | ForEach-Object {
                $splat = @{
                    Script           = $_.FullName
                    ProjectDirectory = $ProjectDirectory
                    ClearExisting    = $clearExisting
                    ModuleRepository = $ModuleRepository
                }
                _prepareDependentPowerShellModules @splat
                $clearExisting = $false
            }
        }

        $_buildDirectory = $ProjectDirectory
        $_handler = $Handler
    }

    Write-Host "Deploying to AWS Lambda"
    $splat = @{
        FunctionName           = $Name
        FunctionHandler        = $_handler
        PowerShellFunction     = $PowerShellFunctionHandler
        Profile                = $ProfileName
        Region                 = $Region
        FunctionRole           = $IAMRoleArn
        FunctionMemory         = $Memory
        FunctionTimeout        = $Timeout
        PublishNewVersion      = $PublishNewVersion
        EnvironmentVariables   = $EnvironmentVariable
        KmsKeyArn              = $KmsKeyArn
        FunctionSubnets        = $Subnet
        FunctionSecurityGroups = $SecurityGroup
        DeadLetterQueueArn     = $DeadLetterQueueArn
        TracingMode            = $TracingMode
        S3Bucket               = $S3Bucket
        S3KeyPrefix            = $S3KeyPrefix
        Tags                   = $Tag
        DisableInteractive     = $DisableInteractive
        BuildDirectory         = $_buildDirectory
    }
    _deployProject @splat

    if($deleteStagingDirectory)
    {
        Write-Verbose -Message "Removing staging directory $_buildDirectory"
        Remove-Item -Path $_buildDirectory -Recurse -Force
    }

