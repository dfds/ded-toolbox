#!/bin/bash

set -euo pipefail

aws s3 cp s3://dfds-oxygen-k8s-hellman/capability-role.yaml ./capability-role.yaml

ROLES=$(kubectl get roles --all-namespaces -o=custom-columns='DATA:metadata.name' | grep 'fullaccess')

for ROLE in $ROLES
do
	NAMESPACE=${ROLE%*-fullaccess}
	echo "Applying role updates in namespace $NAMESPACE"
	sed "s/CAPABILITY_ROOT_ID/${NAMESPACE}/g" capability-role.yaml | kubectl replace -f -
done
