
#This script gets the Client CA certificate file from the Hellman Cluster.
$Accounts = ((aws organizations list-accounts --profile saml) | ConvertFrom-Json)

$Account = $Accounts.Accounts | Where-Object {$_.name -eq 'dfds-oxygen'} 

$ARN = "arn:aws:iam::$($Account.ID):role/OrgRole"
$AWS_ROLE = (aws sts assume-role --role-arn $ARN --role-session-name Temp --profile saml) | ConvertFrom-Json

$Env:AWS_ACCESS_KEY_ID = $AWS_ROLE.Credentials.AccessKeyId
$Env:AWS_SECRET_ACCESS_KEY = $AWS_ROLE.Credentials.SecretAccessKey
$Env:AWS_SESSION_TOKEN = $AWS_ROLE.Credentials.SessionToken

Write-Output "Getting RDS for Account ID: $($Account.ID)"
Write-Output "Account Name: $($Account.Name)"

$EncryptedCert = (aws eks describe-cluster --name hellman --region eu-west-1 --output=text --query 'cluster.{certificateAuthorityData: certificateAuthority.data}')

Write-Output "client-ca-file: |"

[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($EncryptedCert))