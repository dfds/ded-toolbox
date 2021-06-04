#!/usr/bin/env python3
from manage_unused_replicasets.deployment import Deployment
from manage_unused_replicasets.namespace import Namespace
from manage_unused_replicasets.replicaset import ReplicaSet


if __name__ == "__main__":
    ns: Namespace = Namespace()
    # namespaces: list = ns.get_namespaces()

    dp: Deployment = Deployment()
    # dp.print_deployments_with_high_revision_history_limit()
    deployments: list = dp.get_deployments_with_high_revision_history_limit()
    dp.create_script_to_patch_deployments(deployments)

    rs: ReplicaSet = ReplicaSet()
    rs.create_cvs_report_with_unused_replicasets(deployments)
