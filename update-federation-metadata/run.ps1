#PowerShell version of script for easier object orrineted troubleshooting of output.
Invoke-WebRequest -Uri "https://adfs.dfds.com/FederationMetadata/2007-06/FederationMetadata.xml" -OutFile "FederationMetadata.xml"

$Accounts = (aws organizations list-accounts --profile saml) | ConvertFrom-Json

foreach ($Account in $Accounts.Accounts) {

	$ARN = "arn:aws:iam::$($Account.ID):role/OrgRole"
    $AWS_ROLE = (aws sts assume-role --role-arn $ARN --role-session-name Temp --profile saml) | ConvertFrom-Json

	$Env:AWS_ACCESS_KEY_ID = $AWS_ROLE.Credentials.AccessKeyId
	$Env:AWS_SECRET_ACCESS_KEY = $AWS_ROLE.Credentials.SecretAccessKey
    $Env:AWS_SESSION_TOKEN = $AWS_ROLE.Credentials.SessionToken
    $SAML_ARN = "arn:aws:iam::$($Account.ID):-provider/ADFS"
    
    Write-Output "Updating SAML for Account ID: $($Account.ID)"
    Write-Output "Account Name: $($Account.Name)"

    (aws iam update-saml-provider --saml-metadata-document file://FederationMetadata.xml --saml-provider-arn $SAML_ARN)
}