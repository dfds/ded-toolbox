#!/usr/bin/env python3
import csv
import time

from manage_unused_replicasets.deployment import Deployment
from manage_unused_replicasets.namespace import Namespace
from manage_unused_replicasets.replicaset import ReplicaSet


def get_num_of_delete_candidates(num: int) -> int:
    if num <= 10:
        return 0
    else:
        return num - 10


if __name__ == '__main__':
    ns: Namespace = Namespace()
    # namespaces: list = ns.get_namespaces()

    rs: ReplicaSet = ReplicaSet()

    dp: Deployment = Deployment()
    # dp.print_deployments_with_high_revision_history_limit()

    deployments: list = dp.get_deployments_with_high_revision_history_limit()
    print(len(deployments))

    # Create CSV file with report
    # with open('problematic-deployments.csv.tmp', 'w', newline='') as csvfile:
    #     dp_writer = csv.writer(csvfile, delimiter=',')
    #     dp_writer.writerow(['Namespace', 'Deployment name', 'API version', 'Limit', 'Replicasets#', 'Over quota#'])
    #     for deployment in deployments:
    #         namespace: str = deployment.get('namespace')
    #         name: str = deployment.get('name')
    #         api_version: str = deployment.get('api_version')
    #         revision_history_limit: str = deployment.get('revision_history_limit')
    #         count: int = rs.get_number_of_unused_replicasets_per_deployment(namespace, name)
    #         dp_writer.writerow([namespace, name, api_version, revision_history_limit, count, get_num_of_delete_candidates(count)])

    # Create file with commands
    with open('problematic-deployments.txt.tmp', 'w') as writer:
        writer.write('!#/bin/bash\n')
        patch: str = '\'[{"op": "replace", "path": "/spec/revisionHistoryLimit", "value": 10}]\''
        for deployment in deployments:
            namespace: str = deployment.get('namespace')
            name: str = deployment.get('name')
            writer.write(f'kubectl patch deployment -n {namespace} {name} --type=json -p={patch}\n')
