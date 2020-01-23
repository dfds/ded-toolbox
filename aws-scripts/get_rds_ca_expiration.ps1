[CmdletBinding()]

param(    
  [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)]
  [switch]
  $SaveToJson = $false,

  [Parameter(Mandatory = $False, Position = 1, ValueFromPipeline = $false)]
  [string]
  $OutputPath = "."
)

# This script is hardcoded to get the client-ca from hellman
$Accounts = (aws organizations list-accounts --profile saml) | ConvertFrom-Json 

#$Accounts = $Accounts.Accounts | Where-Object {$_.Name -eq "emcla-sandbox"}
$Accounts = $Accounts.Accounts
$Regions = "eu-central-1", "eu-west-1", "eu-west-2", "eu-west-3", "eu-north-1"
$AllExpiredInstances = [System.Collections.ArrayList]@()


foreach ($Account in $Accounts) {

  $ARN = "arn:aws:iam::$($Account.ID):role/OrgRole"
  $AWS_ROLE = (aws sts assume-role --role-arn $ARN --role-session-name Temp --profile saml) | ConvertFrom-Json

  $Env:AWS_ACCESS_KEY_ID = $AWS_ROLE.Credentials.AccessKeyId
  $Env:AWS_SECRET_ACCESS_KEY = $AWS_ROLE.Credentials.SecretAccessKey
  $Env:AWS_SESSION_TOKEN = $AWS_ROLE.Credentials.SessionToken

  foreach ($Region in $Regions) {
    $RDS_INSTANCES = aws rds describe-db-instances --region $Region | ConvertFrom-Json
    $instances = $RDS_INSTANCES.DbInstances | Select-Object CACertificateIdentifier, DBInstanceIdentifier
    $instances = $instances | Where-Object { $_.CACertificateIdentifier -eq "rds-ca-2015" }
    
    foreach ($Instance in $instances) {
      if ($null -ne $instance) {
        $instance | Add-Member -Name "Region" -Value $Region -MemberType NoteProperty
        $instance | Add-Member -Name "AccountId" -Value $Account.ID -MemberType NoteProperty
        $instance | Add-Member -Name "AccountName" -Value $Account.Name -MemberType NoteProperty
        $AllExpiredInstances.Add($instance) | Out-Null
  
        $instance
      }
    }
  }
}

if ($SaveToJson) {
  $AllExpiredInstances | ConvertTo-Json | New-Item -Path $OutputPath -Name "rds_ca_expirations.json" -ItemType "file" -Force
}