#!/bin/bash
set -e

if [[ $# -lt 2 ]] ; then
    echo -e "\nQuery Kubernetes resources where last applied configuration targets the specified deprecated API version."
    echo -e "Optionally specify a JSON file to query, instead of getting data directly via Kubectl.\n"
    echo -e "Usage:\n$(basename "$0") KIND DEPRECATED_API_VERSION [JSON_FILE]\n"
    exit 0
fi

KIND=$1
DEPRECATED_API_VERSION=$2

if [[ -n $3 ]]; then
    JSON_FILE=$3
fi


if [[ -n $JSON_FILE ]]; then
    cat $JSON_FILE | jq --arg DEPRECATED_API_VERSION "${DEPRECATED_API_VERSION}" '.items[].metadata | try (select(.annotations."kubectl.kubernetes.io/last-applied-configuration" | fromjson | .apiVersion==$DEPRECATED_API_VERSION)) | {namespace: .namespace, name: .name, lastAppliedApiVersion: (.annotations."kubectl.kubernetes.io/last-applied-configuration" | fromjson | .apiVersion)}'
else
    kubectl get $KIND -A -o json | jq --arg DEPRECATED_API_VERSION "${DEPRECATED_API_VERSION}" '.items[].metadata | try (select(.annotations."kubectl.kubernetes.io/last-applied-configuration" | fromjson | .apiVersion==$DEPRECATED_API_VERSION)) | {namespace: .namespace, name: .name, lastAppliedApiVersion: (.annotations."kubectl.kubernetes.io/last-applied-configuration" | fromjson | .apiVersion)}'
fi

