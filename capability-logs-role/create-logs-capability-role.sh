#!/bin/bash
set -eo pipefail

if [ "$1" = "" ]; then
    echo -e "\nUsage:"
    echo -e "$0 CAPABILITY_ROOT_ID\n"
    exit
fi

# Args
CAPABILITY_ROOT_ID=$1

# Variables
ROLE_PATH=/capabilities/
TRUST_POLICY_FILE=trust-policy.json
ROLE_POLICY_FILE=capability-logs-policy.json

# Calculated vars
ACCOUNT_ID=$(aws sts get-caller-identity --output json | jq -r '.Account')
TRUST_POLICY=$(sed "s/ACCOUNT_ID/${ACCOUNT_ID}/g" $TRUST_POLICY_FILE)
ROLE_POLICY=$(sed "s/ACCOUNT_ID/${ACCOUNT_ID}/g" $ROLE_POLICY_FILE | sed "s/CAPABILITY_ROOT_ID/${CAPABILITY_ROOT_ID}/g")

# Create role - if missing
aws iam get-role --role-name $CAPABILITY_ROOT_ID 2>/dev/null || aws iam create-role --path $ROLE_PATH --role-name $CAPABILITY_ROOT_ID --max-session-duration 28800 --assume-role-policy-document "${TRUST_POLICY}"

# Put CWL policy (overwrite existing inline policy with that name)
aws iam put-role-policy --role-name $CAPABILITY_ROOT_ID --policy-name CloudWatchLogs --policy-document "${ROLE_POLICY}"

# Create AD group
echo -e "\nRun the PowerShell script with the following arguments on a computer with Active Directory PowerShell modules installed:"
echo -e "./create-logs-capability-adgroup.ps1 -CapabilityRootId $CAPABILITY_ROOT_ID -AccountId $ACCOUNT_ID\n"