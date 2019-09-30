Import-Module AWSPowerShell.NetCore
Set-DefaultAWSRegion eu-west-1


# Misc
Get-STSCallerIdentity
$Keyword = 'launch'
Get-Command -Module AWSPowerShell.NetCore *$Keyword*


# Get EKS images
$EksVersion = '1.11'
$EksAmi = Get-EC2Image -Owner amazon -Filter @{Name = "name"; Values = "*eks-node-$($EksVersion)*" } | Sort CreationDate -Descending
$EksAmi[0]


# Get ASG
$AsgName = 'eks'
$Asg = Get-ASAutoScalingGroup -AutoScalingGroupName $AsgName
Get-ASLaunchConfiguration -LaunchConfigurationName $LaunchConfig

# Get launch config
$LaunchConfigName = Get-ASAutoScalingGroup -AutoScalingGroupName $AsgName | Select -Expand LaunchConfigurationName
Get-ASLaunchConfiguration -LaunchConfigurationName $LaunchConfigName


# Update launch config AMI
$NewAmi = $EksAmi[1].ImageId

$NewLaunchConfigName = "$AsgName-$((Get-Date -Format u) -replace "[\s-:Z]", '')"

$LaunchConfig = Get-ASLaunchConfiguration -LaunchConfigurationName $LaunchConfigName

New-ASLaunchConfiguration -AssociatePublicIpAddress $LaunchConfig.AssociatePublicIpAddress -BlockDeviceMapping $LaunchConfig.BlockDeviceMappings -IamInstanceProfile $LaunchConfig.IamInstanceProfile -ImageId $NewAmi -InstanceMonitoring_Enabled $LaunchConfig.InstanceMonitoring.Enabled -InstanceType $LaunchConfig.InstanceType -KeyName $LaunchConfig.KeyName -LaunchConfigurationName $NewLaunchConfigName -SecurityGroup $LaunchConfig.SecurityGroups -UserData $LaunchConfig.UserData

Update-ASAutoScalingGroup -AutoScalingGroupName $AsgName -LaunchConfigurationName $NewLaunchConfigName


# Publish lambda
Publish-AWSPowerShellLambda -ScriptPath .\asg_k8s_rollover_lambda.ps1 -Name "ASGRollOver" -Region eu-west-1

# Invoke lambda
$Payload = [PSCustomObject]@{
    EksClusterName   = "eks"
    AutoScalingGroup = "eks"
    Region           = "eu-west-1"
}
$PayloadJson = $Payload | ConvertTo-Json

Invoke-LMFunction -FunctionName ASGRollOver -LogType Tail -Payload $PayloadJson | Select -Expand LogResult | b64 -d