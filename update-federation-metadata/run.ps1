#PowerShell version of script for easier object orrineted troubleshooting of output.


(bash -c "curl https://adfs.dfds.com/FederationMetadata/2007-06/FederationMetadata.xml > FederationMetadata.xml")

$Accounts = (bash -c "aws organizations list-accounts --profile saml") | ConvertFrom-Json

foreach ($Account in $Accounts.Accounts) {

	$ARN = "arn:aws:iam::$($Account.ID):role/OrgRole"
    $AWS_ROLE = (bash -c "aws sts assume-role --role-arn $ARN --role-session-name Temp --profile saml") | ConvertFrom-Json

	$KEY = $AWS_ROLE.Credentials.AccessKeyId
	$SECRET = $AWS_ROLE.Credentials.SecretAccessKey
    $TOKEN = $AWS_ROLE.Credentials.SessionToken
    $SAML_ARN = "arn:aws:iam::$($Account.ID):-provider/ADFS"
    
    Write-Output "Updating SAML for Account ID: $($Account.ID)"
    Write-Output "Account Name: $($Account.Name)"

    (bash -c "AWS_ACCESS_KEY_ID=$KEY AWS_SECRET_ACCESS_KEY=$SECRET AWS_SESSION_TOKEN=$TOKEN aws iam update-saml-provider --saml-metadata-document file://FederationMetadata.xml --saml-provider-arn $SAML_ARN")
}