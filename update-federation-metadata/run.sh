#!/bin/bash

curl https://adfs.dfds.com/FederationMetadata/2007-06/FederationMetadata.xml > FederationMetadata.xml

IDS=$(aws organizations list-accounts --profile saml | jq -r '.Accounts[].Id')
#NAME=$(aws organizations list-accounts --profile saml | jq -r '.Accounts[].Name')

#aws sts assume-role --role-arn "arn:aws:iam::585490351997:role/OrgRole" --role-session-name "Test" --profile saml

#aws iam update-saml-provider --saml-metadata-document file://FederationMetadata.xml --saml-provider-arn arn:aws:iam::585490351997:saml-provider/ADFS --profile saml

for id in $IDS
do
	ARN="arn:aws:iam::$id:role/OrgRole"
	aws sts assume-role --role-arn "$ARN" --role-session-name "Temp" --profile saml > temp.txt

	KEY=$(cat temp.txt | jq -r '.Credentials.AccessKeyId')
	SECRET=$(cat temp.txt | jq -r '.Credentials.SecretAccessKey')
	TOKEN=$(cat temp.txt | jq -r '.Credentials.SessionToken')

	AWS_ACCESS_KEY_ID=$KEY AWS_SECRET_ACCESS_KEY=$SECRET AWS_SESSION_TOKEN=$TOKEN aws iam update-saml-provider --saml-metadata-document file://FederationMetadata.xml --saml-provider-arn arn:aws:iam::$id:saml-provider/ADFS

	rm temp.txt
done
