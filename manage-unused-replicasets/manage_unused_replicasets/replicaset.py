#!/usr/bin/env python3
import json
import os
import subprocess
from typing import TextIO

from tabulate import tabulate


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
        replicasets_spec = self._get_replicasets_spec(namespace)
        replicasets: list = []
        for item in replicasets_spec:
            item_with_type_hints: dict = item
            metadata: dict = item_with_type_hints.get('metadata')
            name: str = metadata.get('name')
            replicasets.append(name)
        return replicasets

    def get_unused_replicasets(self, namespace: str) -> list:
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
                name: str = metadata.get('name')
                replicasets.append(name)
        return replicasets

    def get_unused_replicasets_for_deployment(self, namespace: str, deployment_name: str) -> list:
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
                owner_references: list = metadata.get("ownerReferences")
                application: str = owner_references[0]['name']
                if (application == deployment_name):
                    name: str = metadata.get('name')
                    replicasets.append(name)
        return replicasets

    def get_number_of_unused_replicasets_per_deployment(self, namespace: str, deployment_name: str) -> int:
        unused_replicasets: list = self.get_unused_replicasets_for_deployment(namespace, deployment_name)
        return len(unused_replicasets)

    def print_number_of_unused_replicasets_per_deployment(self, namespace: str, deployment_name: str) -> int:
        replicasets: list = []
