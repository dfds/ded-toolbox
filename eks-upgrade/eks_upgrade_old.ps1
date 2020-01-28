$oldNodes = kubectl.exe get node --no-headers -o custom-columns=POD:metadata.name

ForEach ($node in $oldNodes) {

    kubectl.exe drain --ignore-daemonsets --delete-local-data --force $node

    if ($?) {
        $instance_id = aws.exe --profile oxygen --region $region ec2 describe-instances --filters "Name=private-dns-name,Values=$node" --query "Reservations[].Instances[].InstanceId" --output text
        aws.exe --profile oxygen --region $region autoscaling set-instance-health --instance-id $instance_id --health-status Unhealthy
    } Else {
       Throw "Failed to drain node"
    }
}

<#
autoscaling describe-auto-scaling-groups
autoscaling describe-auto-scaling-instances
ec2 describe-instances
autoscaling set-instance-health
#>


# Check health
aws.exe --profile oxygen --region $region autoscaling describe-auto-scaling-instances --instance-ids $instance_id


function Write-Message ([string]$Message) {
    Write-Host "[$(Get-Date -Format u)] " -ForegroundColor Blue -NoNewLine
    Write-Host $Message
}


$autoScalingGroup = 'hellman'
$region = 'eu-west-1'

$launchConfig = aws --profile oxygen --region $region autoscaling describe-auto-scaling-groups --auto-scaling-group-names $autoScalingGroup --query "AutoScalingGroups[0].LaunchConfigurationName" --output text
Write-Message "The current launch config for autoscaling group '$autoScalingGroup' in region '$region' is '$launchConfig'"
$rolloverInstanceQuery = aws.exe --profile oxygen --region $region autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?AutoScalingGroupName==``$autoScalingGroup`` && LaunchConfigurationName!=``$launchConfig``].InstanceId" --output text


If ($rolloverInstanceQuery) {
    $rolloverInstanceIds = $rolloverInstanceQuery.Split()
    Write-Message "$($rolloverInstanceIds.Count) instance(s) in autoscaling group '$autoScalingGroup' in region '$region' are not using current launch config"
} Else {
    Write-Message "All instances in autoscaling group '$autoScalingGroup' in region '$region' appears to be using the current launch config - Nothing to do"
    Return
}


$rolloverInstances = @()
ForEach ($instanceId in $rolloverInstanceIds) {

    # Attempt to resolve each EC2 instance's private DNS name (which corresponds to Kubernetes node name)
    $nodeName = aws.exe --profile oxygen --region $region ec2 describe-instances --instance-ids $instanceId --filter "Name=private-dns-name,Values=*.*" --query "Reservations[].Instances[].PrivateDnsName" --output text 2>&1

    If (-Not($?)) {
        Write-Message "WARNING: Failed to get private DNS name of EC2 instance '$instanceId': $($Error[0].Exception.Message)"
    }

    $rolloverInstances += [PSCustomObject]@{
        InstanceId = $instanceId
        NodeName = "Error"
    }
}



$rolloverNodeNames = ($rolloverInstanceIds | % {aws.exe --profile oxygen --region $region ec2 describe-instances --instance-ids $_ --filter "Name=private-dns-name,Values=*.*" --query "Reservations[].Instances[].PrivateDnsName" --output text}).Split()

ForEach ($node in $rolloverNodeNames) {

    # Check that node exists in cluster
    kubectl.exe get node $node 2>&1 | Out-Null

    If ($?) {

        # Drain Kubernetes node
        kubectl.exe drain --ignore-daemonsets --delete-local-data --force $node

        if ($?) {

            $instance_id = aws.exe --profile oxygen --region $region ec2 describe-instances --filters "Name=private-dns-name,Values=$node" --query "Reservations[].Instances[].InstanceId" --output text
            aws.exe --profile oxygen --region $region autoscaling set-instance-health --instance-id $instance_id --health-status Unhealthy

        } Else {

            Throw "Failed to drain node"

        }

    }

}