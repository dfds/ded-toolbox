from kubernetes import config, client
from kubernetes.client.api.apps_v1_api import AppsV1Api
from kubernetes.client.api.batch_v1_api import BatchV1Api
from kubernetes.client.api.core_v1_api import CoreV1Api
from kubernetes.client.models.v1_pod_list import V1PodList
from src.kubernetes.pod_resources import PodResource

# Kubernetes
config.load_kube_config()
v1: CoreV1Api = client.CoreV1Api()
apps: AppsV1Api = client.AppsV1Api()
batch: BatchV1Api = client.BatchV1Api()

# Actual freaking program
if __name__ == "__main__":

    # Fetch all pods from all namespaces
    pods: V1PodList = v1.list_pod_for_all_namespaces()

    for item in pods.items:

        # Analyse Pod item
        pod: PodResource = PodResource(apps, batch, item)

        # Check if there any violations
        if pod.check_violations():

            # Fetch Pod owner kind and name
            pod.get_pod_owner_kind_from_owner_reference()

            # Print for limit range analysis
            pod.print_limit_range_analysis()
