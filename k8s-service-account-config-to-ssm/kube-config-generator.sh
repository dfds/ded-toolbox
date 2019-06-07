# Check if variables is there
if [[ -z $ROOT_ID || -z $ACCOUNT_ID ]]; then
    echo 'required environment variables missing'
    exit 1
fi

# Define variables
CAPABILITY_ROOT_ID=$ROOT_ID
NAMESPACE=$CAPABILITY_ROOT_ID
SERVICE_ACCOUNT_NAME="$CAPABILITY_ROOT_ID-vstsuser"
KUBE_ROLE="$CAPABILITY_ROOT_ID-fullaccess"
CAPABILITY_AWS_ACCOUNT_ID=$ACCOUNT_ID
CAPABILITY_AWS_ROLE_SESSION="kube-config-paramstore"

# Generate kube toke and config for service account
kubectl create serviceaccount --namespace kube-system $SERVICE_ACCOUNT_NAME
kubectl create rolebinding $SERVICE_ACCOUNT_NAME --role=$KUBE_ROLE --serviceaccount=kube-system:$SERVICE_ACCOUNT_NAME -n $NAMESPACE
KUBE_TOKEN=$(kubectl -n kube-system get secret $(kubectl -n kube-system get secret | grep $SERVICE_ACCOUNT_NAME | awk '{print $1}') -o json | jq '.data.token' | tr -d '"' | base64 --decode)
KUBE_CONFIG=$(sed "s/KUBE_TOKEN/${KUBE_TOKEN}/g" config.template | sed "s/NAMESPACE_REPLACE/${NAMESPACE}/g")

# Assume role
AWS_ASSUMED_CREDS=( $(aws sts assume-role \
    --role-arn "arn:aws:iam::${CAPABILITY_AWS_ACCOUNT_ID}:role/OrgRole" \
    --role-session-name ${CAPABILITY_AWS_ROLE_SESSION} \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text
) )
AWS_ASSUMED_ACCESS_KEY_ID=${AWS_ASSUMED_CREDS[0]}
AWS_ASSUMED_SECRET_ACCESS_KEY=${AWS_ASSUMED_CREDS[1]}
AWS_ASSUMED_SESSION_TOKEN=${AWS_ASSUMED_CREDS[2]}


# Push to AWS parameter store
AWS_ACCESS_KEY_ID=${AWS_ASSUMED_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_ASSUMED_SECRET_ACCESS_KEY} AWS_SESSION_TOKEN=${AWS_ASSUMED_SESSION_TOKEN} \
    aws ssm put-parameter --name "/managed/kubeconfig" --value "$KUBE_CONFIG" --type "SecureString" --overwrite --region eu-central-1
