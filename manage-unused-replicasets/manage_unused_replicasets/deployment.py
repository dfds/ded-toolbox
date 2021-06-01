import json
import os
import subprocess
from typing import TextIO

from tabulate import tabulate


class Deployment:
    """
    A class that represent a Deployment
    """

    def __init__(self) -> None:
        """
        Class constructor.
        """

    @staticmethod
    def _get_all_deployments_spec() -> list:
        """
        Get all deployments in all namespaces and return a list with all the
        specifications in JSON format.

        :return: list
        """
        os.environ.get('KUBECONFIG')
        command: str = 'kubectl get deployments -A -o json'
        command_list: list = command.split(' ')
        out_file: TextIO = open("deployments.json.tmp", "w")
        subprocess.run(command_list, stdout=out_file)
        with open('deployments.json.tmp') as json_file:
            data: dict = json.load(json_file)
            items: list = data.get('items')
        return items

    def get_deployments_with_high_revision_history_limit(self) -> list:
        """
        Get deployments with a high value for revisionHistoryLimit.
        In this case 'high' means higher than 10, which is the default.

        :return: list
        """
        deployments_spec = self._get_all_deployments_spec()
        deployments: list = []
        for item in deployments_spec:
            item_with_type_hints: dict = item
            metadata: dict = item_with_type_hints.get('metadata')
            namespace: str = metadata.get('namespace')
            name: str = metadata.get('name')
            api_version: str = item_with_type_hints.get('apiVersion')
            spec: dict = item_with_type_hints.get('spec')
            revision_history_limit: int = spec.get('revisionHistoryLimit', 10)  # Setting to 10 if not specified.
            if revision_history_limit > 10:
                problematic_deployment: dict = {'namespace': namespace,
                                                'name': name,
                                                'api_version': api_version,
                                                'revision_history_limit': revision_history_limit}
                deployments.append(problematic_deployment)
        return deployments

    def print_deployments_with_high_revision_history_limit(self) -> None:
        """
        Print deployments with a high value for revisionHistoryLimit.
        In this case 'high' means higher than 10, which is the default.
        """
        deployments: list = self.get_deployments_with_high_revision_history_limit()
        header = deployments[0].keys()
        rows = [deployment.values() for deployment in deployments]
        print(tabulate(rows, header))

    def create_script_to_patch_deployments(self, deployments: list = None) -> None:
        """
        Create script to use 'kubectl patch deployments' in order to reduce the
        revisionHistoryLimit in deployments with a revisionHistoryLimit higher than
        the default value of 10.

        :param deployments: A list of dictionary objects that contains the namespace,
                            deployment name, api version and revisionHistoryLimit value
                            for deployments that have a high revisionHistoryLimit.
                            If not supplied, it will create the list of its own.
        :type deployments: list
        """
        dp: list = []
        if deployments is None:
            dp = self.get_deployments_with_high_revision_history_limit()
        else:
            dp = deployments
        script_file: str = 'problematic-deployments.sh.tmp'
        with open(script_file, 'w') as writer:
            writer.write('!#/bin/bash\n')
            patch: str = '\'[{"op": "replace", "path": "/spec/revisionHistoryLimit", "value": 10}]\''
            for deployment in dp:
                namespace: str = deployment.get('namespace')
                name: str = deployment.get('name')
                writer.write(f'kubectl patch deployment -n {namespace} {name} --type=json -p={patch}\n')
        print(f'{script_file} was created with "kubectl patch deployments" commands')
        print('You can use this script to change the revisionHistoryLimit.')
        print(f'Usage: export KUBECONFIG=<REDACTED> && chmod +x {script_file} && ./{script_file}')
