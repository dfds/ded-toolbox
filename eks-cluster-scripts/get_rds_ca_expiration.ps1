# This script is hardcoded to get the client-ca from hellman
$Accounts = (aws organizations list-accounts --profile saml) | ConvertFrom-Json 

#$Accounts = $Accounts.Accounts | Where-Object {$_.Name -eq "emcla-sandbox"}
$Accounts = $Accounts.Accounts
$Regions = "eu-central-1", "eu-west-1", "eu-west-2", "eu-west-3", "eu-north-1"


foreach ($Account in $Accounts) {

	$ARN = "arn:aws:iam::$($Account.ID):role/OrgRole"
  $AWS_ROLE = (aws sts assume-role --role-arn $ARN --role-session-name Temp --profile saml) | ConvertFrom-Json

	$Env:AWS_ACCESS_KEY_ID = $AWS_ROLE.Credentials.AccessKeyId
	$Env:AWS_SECRET_ACCESS_KEY = $AWS_ROLE.Credentials.SecretAccessKey
  $Env:AWS_SESSION_TOKEN = $AWS_ROLE.Credentials.SessionToken
    
  Write-Output "Getting RDS for Account ID: $($Account.ID)"
  Write-Output "Account Name: $($Account.Name)"

  $accountInstances = [System.Collections.ArrayList]@()

  foreach($Region in $Regions) {
    $RDS_INSTANCES = aws rds describe-db-instances --region $Region | ConvertFrom-Json
    $instances = $RDS_INSTANCES.DbInstances | Select-Object CACertificateIdentifier,DBInstanceIdentifier
    $instances = $instances | Where-Object {$_.CACertificateIdentifier -eq "rds-ca-2015"}
    $instances | Add-Member -Name "Region" -Value $Region -MemberType NoteProperty
    $accountInstances.Add($instances) | Out-Null
  }
  $accountInstances | Format-Table
}