#Requires -Modules @{ModuleName='AWSPowerShell.NetCore';ModuleVersion='3.3.590.0'}

[CmdletBinding()]


param (

    [Parameter(Mandatory = $true)]
    [String]$AutoScalingGroup,

    [Parameter(Mandatory = $false)]
    [String]$Region = 'eu-west-1'

)

<#
To do:
- Count instances not using current launch config: Only included healthy
- Wait for node: Use ASG instead of Kubectl
#>


# --------------------------------------------------------------------------------
# Define variables and oonstants
# --------------------------------------------------------------------------------

New-Variable -Name NodeLiveTimeout -Value 300 -Option Constant
New-Variable -Name NodeReadyTimeout -Value 300 -Option Constant

# --------------------------------------------------------------------------------
# Functions
# --------------------------------------------------------------------------------

function Write-Message ([string]$Message) {
    Write-Host "$(Get-Date -Format u)  $Message"
}

function Get-ASGLaunchConfig {

    param (

        [Parameter(Mandatory = $true)]
        [String]$AutoScalingGroup,

        [Parameter(Mandatory = $true)]
        [String]$Region

    )

    $LaunchConfig = Get-ASAutoScalingGroup -AutoScalingGroupName $AutoScalingGroup -Region $Region | Select -Expand LaunchConfigurationName
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

    # Get ASG instances not using current launch config
    $RolloverInstances = Get-ASAutoScalingInstance -Region $Region |
        Where-Object { $_.AutoScalingGroupName -eq $AutoScalingGroup -and $_.LaunchConfigurationName -ne $LaunchConfig }

    If ($RolloverInstances) {
        Write-Message "$($RolloverInstances.Count) instance(s) in autoscaling group '$AutoScalingGroup' in region '$Region' are not using current launch config"
        Return $RolloverInstances
    }
    Else {
        Write-Message "All instances in autoscaling group '$AutoScalingGroup' in region '$Region' appears to be using the current launch config - nothing to do"
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

    $PrivateDnsName = Get-EC2Instance -InstanceId $Id -Region eu-west-1 | Select -Expand Instances | Select -Expand PrivateDnsName

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
    
    kubectl drain --ignore-daemonsets --delete-local-data --grace-period=30 --timeout=2m --force $Name 2>&1 | Tee-Object -Variable Result | Write-Verbose -Verbose

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
    Set-ASInstanceHealth -InstanceId $Id -Region $Region -HealthStatus $Status

}


# --------------------------------------------------------------------------------
# Begin script
# --------------------------------------------------------------------------------

$LaunchConfig = Get-ASGLaunchConfig -AutoScalingGroup $AutoScalingGroup -Region $Region

$RolloverInstances = Get-ASGInstancesOutdatedLaunchConfig -AutoScalingGroup $AutoScalingGroup -LaunchConfig $LaunchConfig -Region $Region

$RolloverInstanceMap = @()
ForEach ($InstanceId in ($RolloverInstances.InstanceId)) {

    # Attempt to resolve each EC2 instance's private DNS name (which corresponds to Kubernetes node name)
    $NodeName = Get-InstancePrivateDnsName -Id $InstanceId -Region $Region

    If ($NodeName) {
        $RolloverInstanceMap += [PSCustomObject]@{
            Id       = $InstanceId
            NodeName = $NodeName
        }
    }

}


ForEach ($Instance in $RolloverInstanceMap) {

    # Get current Kubernets nodes
    $PreviousNodes = Get-KubernetesNodes

    # Drain Kubernetes node
    If (Set-KubernetesNodeDrain -Name $Instance.NodeName) {
   
        # Set EC2 instance health to unhealthy to trigger replacement
        Set-InstanceHealthStatus -Id $Instance.Id -Region $Region -Status Unhealthy

        # Wait for new Kubernetes node to appear
        $DoStart = Get-Date
        Do {

            If ((New-TimeSpan $DoStart (Get-Date) | Select -Expand TotalSeconds) -ge $NodeLiveTimeout) {
                Throw "ERROR: Timeout expired waiting for new Kubernets node to join cluster"
            }

            Start-Sleep 5
            $CurrentNodes = Get-KubernetesNodes
            $NewNodes = Compare-Object -ReferenceObject $PreviousNodes -DifferenceObject $CurrentNodes | ? { $_.SideIndicator -eq '=>' } | Select -Expand InputObject

        }
        Until ($NewNodes)
        Write-Message "New Kubernetes node joined: $($NewNodes -join ', ')"
    
        # Wait for new Kubernetes node to be ready
        $DoStart = Get-Date
        Do {

            If ((New-TimeSpan $DoStart (Get-Date) | Select -Expand TotalSeconds) -ge $NodeReadyTimeout) {
                Throw "ERROR: Timeout expired waiting for new Kubernets node to become Ready"
            }

            Start-Sleep 5
            $NodeStatus = Get-KubernetesNodeReady -Name $NewNodes
        }
        Until ($NodeStatus.Ready -notcontains $false)
        Write-Message "Kubernetes node '$($NewNodes -join ', ')' is now ready"
   
    }

}


Get-ASGInstancesOutdatedLaunchConfig -AutoScalingGroup $AutoScalingGroup -LaunchConfig $LaunchConfig -Region $Region | Out-Null