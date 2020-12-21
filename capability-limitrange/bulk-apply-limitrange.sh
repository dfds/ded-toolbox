#!/bin/bash

set -euo pipefail

# Get all namespaces, but exclude kube-system and monitoring
NAMESPACES=$(kubectl get ns --no-headers=true | awk '!/kube-system|monitoring/{print $1}')

for NS in $NAMESPACES
do
	echo "Applying limitrange in namespace: $NS"
	kubectl -n $NS apply -f limitrange.yaml
done