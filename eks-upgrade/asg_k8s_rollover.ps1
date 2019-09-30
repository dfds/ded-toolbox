<#
To do:
- Add TestRun switch to switch between bogus dry-run
- Timeout handling in loops
    - Message
    - Warning or Throw?
- Tee kubectl drain output
- Count instances not using current launch config: Only included healthy
#>

[CmdletBinding()]

param (

    [Parameter(Mandatory = $true)]
    [String]$AutoScalingGroup,

    [Parameter(Mandatory = $false)]
    [String]$Region = 'eu-west-1',

    [Parameter(Mandatory = $false)]
    [String]$NodeLiveTimeout = 300,

    [Parameter(Mandatory = $false)]
    [String]$NodeReadyTimeout = 300,

    [switch]$TestRun

)

function Write-Message ([string]$Message) {
    Write-Host "$(Get-Date -Format u)  " -ForegroundColor Blue -NoNewLine
    Write-Host $Message
}

function Get-ASGLaunchConfig {

    param (

        [Parameter(Mandatory = $true)]
        [String]$AutoScalingGroup,

        [Parameter(Mandatory = $true)]
        [String]$Region

    )

    $LaunchConfig = aws --region $Region autoscaling describe-auto-scaling-groups --auto-scaling-group-names $AutoScalingGroup --query "AutoScalingGroups[0].LaunchConfigurationName" --output text
    Write-Message "The current launch config for autoscaling group '$AutoScalingGroup' in region '$Region' is '$LaunchConfig'"
    Return $LaunchConfig

}


function Get-ASGInstancesOutdatedLaunchConfig {

    param (

        [Parameter(Mandatory = $true)]
        [String]$AutoScalingGroup,

        [Parameter(Mandatory = $true)]
        [String]$LaunchConfig,

        [Parameter(Mandatory = $true)]
        [String]$Region

    )

    $RolloverInstanceQuery = aws --region $Region autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?AutoScalingGroupName==``$AutoScalingGroup`` && LaunchConfigurationName!=``$LaunchConfig``].InstanceId" --output text
    # $RolloverInstanceQuery = aws --region $Region autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?AutoScalingGroupName==``$AutoScalingGroup`` && LaunchConfigurationName==``$LaunchConfig``].InstanceId" --output text # debug

    If ($RolloverInstanceQuery) {
        $RolloverInstanceIds = $RolloverInstanceQuery.Split()
        Write-Message "$($RolloverInstanceIds.Count) instance(s) in autoscaling group '$AutoScalingGroup' in region '$Region' are not using current launch config"
        Return $RolloverInstanceIds
    }
    Else {
        Write-Message "All instances in autoscaling group '$AutoScalingGroup' in region '$Region' appears to be using the current launch config - Nothing to do"
        Return
    }

}


function Get-InstancePrivateDnsName {

    param (

        [Parameter(Mandatory = $true)]
        [String]$Id,

        [Parameter(Mandatory = $true)]
        [String]$Region

    )

    $PrivateDnsName = aws --region $Region ec2 describe-instances --instance-ids $InstanceId --filter "Name=private-dns-name,Values=*.*" --query "Reservations[].Instances[].PrivateDnsName" --output text 2>&1

    If ($?) {
        Write-Message "Instance '$InstanceId' in region '$Region' has a private DNS name of '$PrivateDnsName'"
        Return $PrivateDnsName
    }
    Else {
        Write-Message "WARNING: Failed to get private DNS name of EC2 instance '$InstanceId': $($Error[0].Exception.Message)"
        Return
    }
}


function Get-KubernetesNodes {
    kubectl get node --no-headers -o custom-columns=POD:metadata.name
}

function Get-KubernetesNodeReady {
    
    param (

        [Parameter(Mandatory = $true)]
        [String[]]$Name

    )

    $Name | ForEach {
        [PSCustomObject]@{
            Node  = $_
            Ready = (kubectl get nodes -o json | jq -r --arg NODENAME $_ '[.items[] | {id: .metadata.name,status: (.status.conditions[] | select(.type==\"Ready\").status)}] | .[] | select( .id | contains("$NODENAME")).status') -eq 'True'
        }
    }

}

function Set-KubernetesNodeDrain {

    param (

        [Parameter(Mandatory = $true)]
        [String]$Name

    )

    Write-Message "Draining Kubernetes node '$Name'"
    
    kubectl drain --ignore-daemonsets --delete-local-data --force $Name 2>&1 | Tee-Object -Variable Result | Write-Verbose -Verbose
    # $Result = kubectl drain $Name 2>&1 #debug
    # $Result = kubectl version --client #debug

    If ($LASTEXITCODE -ne 0) {

        Write-Message "WARNING: Failed to drain node '$Name': $Result"

        Write-Message "Uncordoning node '$Name'"
        $Result = kubectl uncordon $Name 2>&1

        If ($LASTEXITCODE -ne 0) {
            Throw "Failed to uncordon, after failing to drain, Kubernetes node '$Name': $Result"
        }

        Return $false

    }

    Return $true

}

function Set-InstanceHealthStatus {

    param (
        [Parameter(Mandatory = $true)]
        [String]$Id,

        [Parameter(Mandatory = $true)]
        [String]$Region,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Unhealthy")]
        [String]$Status

    )

    Write-Message "Setting instance '$Id' in region '$Region' to 'Unhealthy'"
    aws --region $Region autoscaling set-instance-health --instance-id $Id --health-status $Status

}


$LaunchConfig = Get-ASGLaunchConfig -AutoScalingGroup $AutoScalingGroup -Region $Region

$RolloverInstanceIds = Get-ASGInstancesOutdatedLaunchConfig -AutoScalingGroup $AutoScalingGroup -LaunchConfig $LaunchConfig -Region $Region

$RolloverInstances = @()
ForEach ($InstanceId in $RolloverInstanceIds) {

    # Attempt to resolve each EC2 instance's private DNS name (which corresponds to Kubernetes node name)
    $NodeName = Get-InstancePrivateDnsName -Id $InstanceId -Region $Region

    If ($NodeName) {
        $RolloverInstances += [PSCustomObject]@{
            Id       = $InstanceId
            NodeName = $NodeName
        }
    }

}


ForEach ($Instance in $RolloverInstances) {

    # Get current Kubernets nodes
    $PreviousNodes = Get-KubernetesNodes

    # Drain Kubernetes node
    If (Set-KubernetesNodeDrain -Name $Instance.NodeName) {
   
        # Set EC2 instance health to unhealthy to trigger replacement
        Set-InstanceHealthStatus -Id $Instance.Id -Region $Region -Status Unhealthy

        # Wait for new Kubernetes node to appear
        $i = 0
        Do {
            Start-Sleep 1 # 10
            $CurrentNodes = Get-KubernetesNodes
            $NewNodes = Compare-Object -ReferenceObject $PreviousNodes -DifferenceObject $CurrentNodes -PassThru
            # $NewNodes = Compare-Object -ReferenceObject $PreviousNodes -DifferenceObject ($CurrentNodes + 'ip-99-99-99-99.eu-west-1.compute.internal') -PassThru # debug
            # $Newnodes = @('ip-10-0-1-237.eu-west-1.compute.internal', 'ip-10-0-1-9.eu-west-1.compute.internal') #debug
        }
        Until ($NewNodes -or ($i++ -ge 3))
        Write-Message "New Kubernetes node joined: $($NewNodes -join ', ')"
    
        # Wait for new Kubernetes node to be ready
        Do {
            Start-Sleep 1 # 10
            $NodeStatus = Get-KubernetesNodeReady -Name $NewNodes
        }
        Until ($NodeStatus.Ready -notcontains $false)
        Write-Message "Kubernetes node '$($NewNodes -join ', ')' is now ready"
   
    }

}


Get-ASGInstancesOutdatedLaunchConfig -AutoScalingGroup $AutoScalingGroup -LaunchConfig $LaunchConfig -Region $Region | Out-Null