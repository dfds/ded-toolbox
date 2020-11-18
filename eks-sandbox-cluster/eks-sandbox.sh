#!/bin/bash
set -e

# Print usage notice, if no arguments passed
if [[ $# -eq 0 ]] ; then
    echo -e "Usage:\n$(basename "$0") CLUSTER_NAME [SANDBOX_ROOT]"
    exit 0
fi
EKS_CLUSTER_NAME=$1

# Dtermine root dirs
SCRIPT_ROOT=$(dirname "$0")
if [[ -n $2 ]]; then
    SANDBOX_ROOT=$2
else
    SANDBOX_ROOT=$PWD
fi
TEMPLATE_ROOT=${SCRIPT_ROOT}/.eks-sandbox-template

# Load variables
VARS_FILE=${SANDBOX_ROOT}/sandbox-vars-${EKS_CLUSTER_NAME}.sh
. "${VARS_FILE}"

# Define paths to template and sandbox
TEMPLATE_DIR=${TEMPLATE_ROOT}/oxygen-account/eu-west-1/k8s-hellman/
SANDBOX_DIR=${SANDBOX_ROOT}/k8s-${EKS_CLUSTER_NAME}
SANDBOX_CLUSTER_MANIFEST=${SANDBOX_DIR}/cluster/terragrunt.hcl
SANDBOX_SERVICES_MANIFEST=${SANDBOX_DIR}/services/terragrunt.hcl

# Clone EKS pipeline
git clone git@github.com:dfds/eks-pipeline.git "$TEMPLATE_ROOT"

# Create dirs if missing
mkdir -p "${SANDBOX_DIR}"

# Copy all manifest files
cp -r "${TEMPLATE_DIR}"/* "${SANDBOX_DIR}/"

# Remove template dir
rm -rf "${TEMPLATE_ROOT}"


# --------------------------------------------------
# Common
# Static token replacements
# --------------------------------------------------

# Set cluster name
sed -i "s|\(eks_cluster_name\s*=\s*\)\".*\"|\1\"${EKS_CLUSTER_NAME}\"|" "${SANDBOX_CLUSTER_MANIFEST}"
sed -i "s|\(eks_cluster_name\s*=\s*\)\".*\"|\1\"${EKS_CLUSTER_NAME}\"|" "${SANDBOX_SERVICES_MANIFEST}"

# Set eks_is_sandobx = true
sed -i "s|\(inputs\s*=\s*{\)|\1\\n\n  eks_is_sandbox = true\n|" "${SANDBOX_CLUSTER_MANIFEST}"
sed -i "s|\(inputs\s*=\s*{\)|\1\\n\n  eks_is_sandbox = true\n|" "${SANDBOX_SERVICES_MANIFEST}"

# Do not create aliases in Core account
sed -i "s|\(traefik_alb_anon_core_alias\s*=.*\)|# \1|" "${SANDBOX_SERVICES_MANIFEST}"
sed -i "s|\(traefik_alb_auth_core_alias\s*=.*\)|# \1|" "${SANDBOX_SERVICES_MANIFEST}"


# --------------------------------------------------
# Cluster
# Simple token replacements
# --------------------------------------------------

[[ -n $EKS_CLUSTER_VERSION ]] && sed -i "s|\(eks_cluster_version\s*=\s*\)\".*\"|\1\"${EKS_CLUSTER_VERSION}\"|" "${SANDBOX_CLUSTER_MANIFEST}"

[[ -n $EKS_WORKER_SSH_IP_WHITELIST ]] && sed -i "s|\(eks_worker_ssh_ip_whitelist\s*=\s*\)\\[.*\]|\1${EKS_WORKER_SSH_IP_WHITELIST}|" "${SANDBOX_CLUSTER_MANIFEST}"

[[ -n $EKS_WORKER_SSH_PUBLIC_KEY ]] && sed -i "s|\(eks_worker_ssh_public_key\s*=\s*\)\".*\"|\1\"${EKS_WORKER_SSH_PUBLIC_KEY}\"|" "${SANDBOX_CLUSTER_MANIFEST}"

[[ -n $EKS_WORKER_CLOUDWATCH_AGENT_CONFIG_DEPLOY ]] && sed -i "s|\(eks_worker_cloudwatch_agent_config_deploy\s*=\s*\).*|\1${EKS_WORKER_CLOUDWATCH_AGENT_CONFIG_DEPLOY}|" "${SANDBOX_CLUSTER_MANIFEST}"

[[ -n $KIAM_CHART_VERSION ]] && sed -i "s|\(kiam_chart_version\s*=\s*\)\".*\"|\1\"${KIAM_CHART_VERSION}\"|" "${SANDBOX_CLUSTER_MANIFEST}"


# --------------------------------------------------
# Cluster
# Other token replacements
# --------------------------------------------------

# If not explicitly defined in vars, default Prometheus retention to 7d
if [[ -n $EKS_CLUSTER_LOG_RETENTION_DAYS ]]; then
    sed -i "s|\(eks_cluster_log_retention_days\s*=\s*\).*|\1${EKS_CLUSTER_LOG_RETENTION_DAYS}|" "${SANDBOX_CLUSTER_MANIFEST}"
else
    sed -i "s|\(eks_cluster_log_retention_days\s*=\s*\).*|\114|" "${SANDBOX_CLUSTER_MANIFEST}"
fi

# If configmap bucket not specified, comment out line
if [[ -n $BLASTER_CONFIGMAP_BUCKET ]]; then
    sed -i "s|\(blaster_configmap_bucket\s*=\s*\)\".*\"|\1${EKS_WORKER_CLOUDWATCH_AGENT_CONFIG_DEPLOY}|" "${SANDBOX_CLUSTER_MANIFEST}"
else
    sed -i "s|\(blaster_configmap_bucket\s*=.*\)|# \1|" "${SANDBOX_CLUSTER_MANIFEST}"
fi

# If not explicitly define in vars, default instance size to t3.medium
if [[ -n $EKS_NODEGROUP1_INSTANCE_TYPES ]]; then
    sed -i "s|\(eks_nodegroup1_instance_types\s*=\s*\)\[.*\]|\1${EKS_NODEGROUP1_INSTANCE_TYPES}|" "${SANDBOX_CLUSTER_MANIFEST}"
else
    sed -i "s|\(eks_nodegroup1_instance_types\s*=\s*\)\[.*\]|\1\[\"t3.medium\"\]|" "${SANDBOX_CLUSTER_MANIFEST}"
fi

# If not explicitly defined in vars, default ASG size to 1
if [[ -n $EKS_NODEGROUP1_DESIRED_SIZE_PER_SUBNET ]]; then
    sed -i "s|\(eks_nodegroup1_desired_size_per_subnet\s*=\s*\).*|\1${EKS_NODEGROUP1_DESIRED_SIZE_PER_SUBNET}|" "${SANDBOX_CLUSTER_MANIFEST}"
else
    sed -i "s|\(eks_nodegroup1_desired_size_per_subnet\s*=\s*\).*|\11|" "${SANDBOX_CLUSTER_MANIFEST}"
fi


# --------------------------------------------------
# Services
# Simple token replacements
# --------------------------------------------------

[[ -n $ALARM_NOTIFIER_DEPLOY ]] && sed -i "s|\(alarm_notifier_deploy\s*=\s*\).*|\1${ALARM_NOTIFIER_DEPLOY}|" "${SANDBOX_SERVICES_MANIFEST}"

[[ -n $CLOUDWATCH_ALARM_ALB_TARGETS_HEALTH_DEPLOY ]] && sed -i "s|\(cloudwatch_alarm_alb_targets_health_deploy\s*=\s*\).*|\1${CLOUDWATCH_ALARM_ALB_TARGETS_HEALTH_DEPLOY}|" "${SANDBOX_SERVICES_MANIFEST}"

[[ -n $MONITORING_KUBE_PROMETHEUS_STACK_DEPLOY ]] && sed -i "s|\(monitoring_kube_prometheus_stack_deploy\s*=\s*\).*|\1${MONITORING_KUBE_PROMETHEUS_STACK_DEPLOY}|" "${SANDBOX_SERVICES_MANIFEST}"



# --------------------------------------------------
# Services
# Other token replacements
# --------------------------------------------------

# Toggle TRAEFIK_ALB_AUTH_DEPLOY off if not explicitly enabled in vars
[[ "${TRAEFIK_ALB_AUTH_DEPLOY}" != "true" ]] && sed -i "s|\(traefik_alb_auth_deploy\s*=\s*\).*|\1false|" "${SANDBOX_SERVICES_MANIFEST}"

# Toggle TRAEFIK_OKTADEPLOY off if not explicitly enabled in vars
if [[ "${TRAEFIK_OKTA_DEPLOY}" != "true" ]]; then
    sed -i "s|\(traefik_okta_deploy\s*=\s*\).*|\1false|" "${SANDBOX_SERVICES_MANIFEST}"
    sed -i "s|\(traefik_alb_okta_deploy\s*=\s*\).*|\1false|" "${SANDBOX_SERVICES_MANIFEST}"
fi

# Clear Slack webhook if not explicitly set
if [[ -n $SLACK_WEBHOOK_URL ]]; then
    sed -i "s|\(slack_webhook_url\s*=\s*\).*|\1${SLACK_WEBHOOK_URL}|" "${SANDBOX_SERVICES_MANIFEST}"
else
    sed -i "s|\(slack_webhook_url\s*=\s*\).*|# \1 \"\"|" "${SANDBOX_SERVICES_MANIFEST}"
fi

# If not explicitly defined in vars, default Prometheus storage to 20Gi
if [[ -n $MONITORING_KUBE_PROMETHEUS_STACK_PROMETHEUS_STORAGE_SIZE ]]; then
    sed -i "s|\(monitoring_kube_prometheus_stack_prometheus_storage_size\s*=\s*\)\".*\"|\"\1${MONITORING_KUBE_PROMETHEUS_STACK_PROMETHEUS_STORAGE_SIZE}\"|" "${SANDBOX_SERVICES_MANIFEST}"
else
    sed -i "s|\(monitoring_kube_prometheus_stack_prometheus_storage_size\s*=\s*\)\".*\"|\"\1200Gi\"|" "${SANDBOX_SERVICES_MANIFEST}"
fi

# If not explicitly defined in vars, default Prometheus retention to 7d
if [[ -n $MONITORING_KUBE_PROMETHEUS_STACK_PROMETHEUS_RETENTION ]]; then
    sed -i "s|\(monitoring_kube_prometheus_stack_prometheus_retention\s*=\s*\)\".*\"|\"\1${MONITORING_KUBE_PROMETHEUS_STACK_PROMETHEUS_RETENTION}\"|" "${SANDBOX_SERVICES_MANIFEST}"
else
    sed -i "s|\(monitoring_kube_prometheus_stack_prometheus_retention\s*=\s*\)\".*\"|\1 \"7d\"|" "${SANDBOX_SERVICES_MANIFEST}"
fi

# Clear Slack webhook if not explicitly set
if [[ -n $MONITORING_KUBE_PROMETHEUS_STACK_SLACK_WEBHOOK ]]; then
    sed -i "s|\(monitoring_kube_prometheus_stack_slack_webhook\s*=\s*\).*|\1${MONITORING_KUBE_PROMETHEUS_STACK_SLACK_WEBHOOK}|" "${SANDBOX_SERVICES_MANIFEST}"
else
    sed -i "s|\(monitoring_kube_prometheus_stack_slack_webhook\s*=\s*\).*|# \1 \"\"|" "${SANDBOX_SERVICES_MANIFEST}"
fi

# Clear Slack webhook if not explicitly set
if [[ -n $MONITORING_KUBE_PROMETHEUS_STACK_SLACK_CHANNEL ]]; then
    sed -i "s|\(monitoring_kube_prometheus_stack_slack_channel\s*=\s*\).*|\1${MONITORING_KUBE_PROMETHEUS_STACK_SLACK_CHANNEL}|" "${SANDBOX_SERVICES_MANIFEST}"
else
    sed -i "s|\(monitoring_kube_prometheus_stack_slack_channel\s*=\s*\).*|# \1 \"\"|" "${SANDBOX_SERVICES_MANIFEST}"
fi

# Clear Slack webhook if not explicitly set
if [[ -n $MONITORING_ALERTMANAGER_SILENCE_NAMESPACES ]]; then
    sed -i "s|\(monitoring_alertmanager_silence_namespaces\s*=\s*\).*|\1${MONITORING_ALERTMANAGER_SILENCE_NAMESPACES}|" "${SANDBOX_SERVICES_MANIFEST}"
else
    sed -i "s|\(monitoring_alertmanager_silence_namespaces\s*=\s*\).*|# \1 \"\"|" "${SANDBOX_SERVICES_MANIFEST}"
fi


# --------------------------------------------------
# End
# --------------------------------------------------

echo -e "\nSandbox manifests generated in:\n${SANDBOX_DIR}"
