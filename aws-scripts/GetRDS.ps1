# This script is hardcoded to get the client-ca from hellman
$Accounts = (aws organizations list-accounts --profile saml) | ConvertFrom-Json 

$Accounts = $Accounts.Accounts


foreach ($Account in $Accounts) {

	$ARN = "arn:aws:iam::$($Account.ID):role/OrgRole"
    $AWS_ROLE = (aws sts assume-role --role-arn $ARN --role-session-name Temp --profile saml) | ConvertFrom-Json

	$Env:AWS_ACCESS_KEY_ID = $AWS_ROLE.Credentials.AccessKeyId
	$Env:AWS_SECRET_ACCESS_KEY = $AWS_ROLE.Credentials.SecretAccessKey
    $Env:AWS_SESSION_TOKEN = $AWS_ROLE.Credentials.SessionToken
    
    Write-Output "Getting RDS for Account ID: $($Account.ID)"
    Write-Output "Account Name: $($Account.Name)"

    aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceArn,Engine,DBInstanceIdentifier]'
}