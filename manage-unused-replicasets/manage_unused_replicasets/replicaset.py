import json
import os
import subprocess
from typing import TextIO


class ReplicaSet:
    """
    A class that represent a ReplicaSet
    """

    def __init__(self) -> None:
        """
        Class constructor.
        """

    @staticmethod
    def _get_replicasets_spec(namespace: str) -> list:
        """
        Get all replicasets in a namespace and return a list with all the
        specifications in JSON format.

        :param namespace: The namespace in which we want to check the replicasets.
        :type namespace: str

        :return: list
        """
        os.environ.get('KUBECONFIG')
        command: str = f'kubectl get rs -n {namespace} -o json'
        command_list: list = command.split(' ')
        out_file: TextIO = open("replicasets.json.tmp", "w")
        subprocess.run(command_list, stdout=out_file)
        with open('replicasets.json.tmp') as json_file:
            data: dict = json.load(json_file)
            items: list = data.get('items')
        return items

    def get_replicasets(self, namespace: str) -> list:
        """
        Get all replicasets in a namespace and return a list their names.

        :param namespace: The namespace in which we want to check the replicasets.
        :type namespace: str

        :return: list
        """
        replicasets_spec = self._get_replicasets_spec(namespace)
        replicasets: list = []
        for item in replicasets_spec:
            item_with_type_hints: dict = item
            metadata: dict = item_with_type_hints.get('metadata')
            name: str = metadata.get('name')
            replicasets.append(name)
        return replicasets

    def get_unused_replicasets(self, namespace: str, deployment_name: str) -> list:
        """
        Get all a list of replicasets in a namespace that belongs to a named
        deployment, and that are currently unused.

        :param namespace: The namespace in which we want to check the replicasets.
        :param deployment_name: A deployment name that owns replicasets.
        :type namespace: str
        :type deployment_name: str

        :return: list
        """
        replicasets_spec = self._get_replicasets_spec(namespace)
        replicasets: list = []
        for item in replicasets_spec:
            item_with_type_hints: dict = item
            metadata: dict = item_with_type_hints.get('metadata')
            status: dict = item_with_type_hints.get('status')
            # This will only have a value if there are available replicas
            available_replicas: int = status.get('availableReplicas', 0)
            # This will only have a value if there are ready replicas
            ready_replicas: int = status.get('readyReplicas', 0)
            replicas: int = status.get('replicas')  # This will always have a value
            if available_replicas == 0 and ready_replicas == 0 and replicas == 0:
                try:
                    owner_references: list = metadata.get("ownerReferences")
                    application: str = owner_references[0]['name']
                    if (application == deployment_name):
                        name: str = metadata.get('name')
                        replicasets.append(name)
                except TypeError:
                    print('The ownerReferences field is empty. Skipping.')
        return replicasets

    def get_number_of_unused_replicasets_per_deployment(self, namespace: str, deployment_name: str) -> int:
        """
        Get a count of unused replicasets in a namespace that belongs to a named deployment.

        :param namespace: The namespace in which we want to check the replicasets.
        :param deployment_name: A deployment name that owns replicasets.
        :type namespace: str
        :type deployment_name: str

        :return: int
        """
        unused_replicasets: list = self.get_unused_replicasets(namespace, deployment_name)
        return len(unused_replicasets)
