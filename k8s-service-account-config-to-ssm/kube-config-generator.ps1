#Requires -Modules @{ ModuleName = 'AWSPowerShell.NetCore'; ModuleVersion = '4.0.0' }
[CmdletBinding()]

param (
    [Parameter(Mandatory)]
    [string]
    $RootId,

    [Parameter(Mandatory)]
    [string]
    $AccountId,

    [Parameter()]
    [string]
    $AwsProfile
)

# Load include file
If ($PSScriptRoot) {
    $ScriptRoot = $PSScriptRoot
} Else {
    $ScriptRoot = './'
}
. (Join-Path $ScriptRoot 'include.ps1')

# Define variables
$CapabilityRootId = $RootId
$Namespace = $CapabilityRootId
$ServiceAccountName = "${CapabilityRootId}-vstsuser"
$ServiceAccountNamespace = 'kube-system'
$KubeRole = "${CapabilityRootId}-fullaccess"
$CapabilityAwsAccountId = $AccountId
$CapabilttiAwsRoleArn = "arn:aws:iam::${CapabilityAwsAccountId}:role/OrgRole"
$CapabilityAwsRoleSession = "kube-config-paramstore"
$AwsRegion = 'eu-central-1'
$AwsParameterName = '/managed/deploy/kube-config'

# Generate kube toke and config for service account
kubectl --namespace $ServiceAccountNamespace create serviceaccount $ServiceAccountName
kubectl --namespace $Namespace create rolebinding $ServiceAccountName --role=$Kuberole --serviceaccount=${ServiceAccountNamespace}:${ServiceAccountName}

# Extract token and generate kubeconfig
$KubeSecretName = $((kubectl --namespace $ServiceAccountNamespace get secret -o name | Select-String $ServiceAccountName) -replace 'secret/', '')
$KubeToken = $(kubectl --namespace $ServiceAccountNamespace get secret $KubeSecretName -o=jsonpath="{.data.token}" | base64 -decode)
$KubeConfigTemplate = Get-Content (Join-Path $ScriptRoot 'config.template') -Raw
$KubeConfig = $KubeConfigTemplate -replace 'NAMESPACE_REPLACE', $Namespace -replace 'KUBE_TOKEN', $KubeToken

# Assume role
Set-DefaultAWSRegion -Region $AwsRegion
If ($AwsProfile) {    
    Set-AWSCredential -ProfileName $AwsProfile
}
Try {$Creds = Use-STSRole -RoleArn $CapabilttiAwsRoleArn -RoleSessionName Push-KubeConfig | Select-Object -Expand Credentials}
Catch {Throw "Failed to assume role: ($_.Message)"}
Set-AWSCredential -AccessKey $Creds.AccessKeyId -SecretKey $Creds.SecretAccessKey -SessionToken $Creds.SessionToken

# Push to AWS parameter store
Write-SSMParameter -Name $AwsParameterName -Value $KubeConfig -Type SecureString -Overwrite:$true | Out-Null
Get-SSMParameter -Name $AwsParameterName | Select Name, LastModifiedDate, Value