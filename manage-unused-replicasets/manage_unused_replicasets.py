#!/usr/bin/env python3


from manage_unused_replicasets.deployment import Deployment
from manage_unused_replicasets.namespace import Namespace
from manage_unused_replicasets.replicaset import ReplicaSet

if __name__ == '__main__':
    ns: Namespace = Namespace()
    # namespaces: list = ns.get_namespaces()

    dp: Deployment = Deployment()
    dp.print_deployments_with_high_revision_history_limit()

    rs: ReplicaSet = ReplicaSet()
    replicasets: list = rs.get_unused_replicasets_for_deployment(namespace='selfservice', deployment_name='kafka-janitor')
    print(replicasets)
    print(len(replicasets))
