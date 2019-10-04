Import-Module AWSPowerShell.NetCore
Set-DefaultAWSRegion eu-west-1


# Misc
Get-STSCallerIdentity
$Keyword = 'launch'
Get-Command -Module AWSPowerShell.NetCore *$Keyword*


# Get EKS images
$EksVersion = '1.11'
$EksAmi = Get-EC2Image -Owner amazon -Filter @{Name = "name"; Values = "*eks-node-$($EksVersion)*" } | Sort CreationDate -Descending
$EksAmi[0] | Select ImageId


# Get ASG
$AsgName = 'eks'
$Asg = Get-ASAutoScalingGroup -AutoScalingGroupName $AsgName

# Get launch config
$LaunchConfigName = Get-ASAutoScalingGroup -AutoScalingGroupName $AsgName | Select -Expand LaunchConfigurationName
Get-ASLaunchConfiguration -LaunchConfigurationName $LaunchConfigName | Select ImageId


# Update launch config AMI
$NewAmi = $EksAmi[1].ImageId

$NewLaunchConfigName = "$AsgName-$((Get-Date -Format u) -replace "[\s-:Z]", '')"

$LaunchConfig = Get-ASLaunchConfiguration -LaunchConfigurationName $LaunchConfigName

New-ASLaunchConfiguration -AssociatePublicIpAddress $LaunchConfig.AssociatePublicIpAddress -BlockDeviceMapping $LaunchConfig.BlockDeviceMappings -IamInstanceProfile $LaunchConfig.IamInstanceProfile -ImageId $NewAmi -InstanceMonitoring_Enabled $LaunchConfig.InstanceMonitoring.Enabled -InstanceType $LaunchConfig.InstanceType -KeyName $LaunchConfig.KeyName -LaunchConfigurationName $NewLaunchConfigName -SecurityGroup $LaunchConfig.SecurityGroups -UserData $LaunchConfig.UserData

Update-ASAutoScalingGroup -AutoScalingGroupName $AsgName -LaunchConfigurationName $NewLaunchConfigName


# Build Lambda package, add dependency
# https://github.com/kubernetes-client/csharp
$ScriptPath = 'C:\code\ded-toolbox\eks-upgrade\asg_k8s_rollover_lambda.ps1'
$ProjectName = Split-Path $ScriptPath -LeafBase
$StagingDir = 'C:\temp\staging'
$ProjectDir = Join-Path $StagingDir $ProjectName
$TempPackagePath = "$($env:TEMP)\$ProjectName.zip"
$DotNetPackages = @('KubernetesClient')

# Generate the PowerShell core project and package (which we will not use)
# New-AWSPowerShellLambdaPackage -ScriptPath $ScriptPath -StagingDirectory $StagingDir -OutputPackage $TempPackagePath # fails
# Remove-Item $TempPackagePath
Publish-AWSPowerShellLambda -Name $ProjectName -Region eu-west-1 -ScriptPath $ScriptPath -StagingDirectory $StagingDir

# Add .NET packages
Push-Location $ProjectDir
ForEach ($Package in $DotNetPackages) {
    dotnet add package $Package
}
Pop-Location

# Publish Lambda
Publish-AWSPowerShellLambda -Name $ProjectName -Region eu-west-1 -ProjectDirectory $ProjectDir

# Invoke lambda
$Payload = [PSCustomObject]@{
    EksClusterName   = "eks"
    AutoScalingGroup = "eks"
    Region           = "eu-west-1"
}
$PayloadJson = $Payload | ConvertTo-Json
Invoke-LMFunction -FunctionName $ProjectName -LogType Tail -Payload $PayloadJson | Select -Expand LogResult | b64 -d