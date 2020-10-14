#Requires -Modules @{ ModuleName = 'AWSPowerShell.NetCore'; ModuleVersion = '4.0.0' }
[CmdletBinding()]

param (
    [Parameter(Mandatory)]
    [string]
    $RootId,

    [Parameter(Mandatory)]
    [string]
    $AccountId
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
$CapabilityAwsRoleArn = "arn:aws:iam::${CapabilityAwsAccountId}:role/OrgRole"
$CapabilityAwsRoleSession = "kube-config-paramstore"
$AwsRegion = 'eu-central-1'
$AwsParameterName = '/managed/deploy/kube-config'
$AwsProfile = "saml"

# SAML2AWS Connection
$SamlRole = "arn:aws:iam::738063116313:role/CloudAdmin"
saml2aws login --role=$SamlRole --force

# Generate kube toke and config for service account
$ENV:AWS_PROFILE = $AwsProfile
kubectl --namespace $ServiceAccountNamespace create serviceaccount $ServiceAccountName
kubectl --namespace $Namespace create rolebinding $ServiceAccountName --role=$Kuberole --serviceaccount=${ServiceAccountNamespace}:${ServiceAccountName}

# Extract token and generate kubeconfig
$KubeSecretName = $((kubectl --namespace $ServiceAccountNamespace get secret -o name | Select-String $ServiceAccountName) -replace 'secret/', '')
$KubeToken = $(kubectl --namespace $ServiceAccountNamespace get secret $KubeSecretName -o=jsonpath="{.data.token}" | base64 -decode)
$KubeConfigTemplate = Get-Content (Join-Path $ScriptRoot 'config.template') -Raw
$KubeConfig = $KubeConfigTemplate -replace 'NAMESPACE_REPLACE', $Namespace -replace 'KUBE_TOKEN', $KubeToken

# SAML2AWS Connection
$SamlRole = "arn:aws:iam::454234050858:role/ADFS-Admin"
saml2aws login --role=$SamlRole --force

# Assume role
Set-DefaultAWSRegion -Region $AwsRegion
Set-AWSCredential -ProfileName $AwsProfile
Try { $Creds = Use-STSRole -RoleArn $CapabilityAwsRoleArn -RoleSessionName $CapabilityAwsRoleSession | Select-Object -Expand Credentials}
Catch {Throw "Failed to assume role: ($_.Message)"}
Set-AWSCredential -AccessKey $Creds.AccessKeyId -SecretKey $Creds.SecretAccessKey -SessionToken $Creds.SessionToken

# Push to AWS parameter store
Write-SSMParameter -Name $AwsParameterName -Value $KubeConfig -Type SecureString -Overwrite:$true | Out-Null
Get-SSMParameter -Name $AwsParameterName | Select Name, LastModifiedDate, Value