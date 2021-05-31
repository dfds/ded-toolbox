# manage-unused-replicateset

This repo contains 3 Python classes:

- Namespace
  - To get all namespaces from a k8s cluster
- Deployment
  - Get the JSON specification for all deployments in the cluster
  - Get deployments with high revision history limit
  - Print deployments with high revision history limit
- Replicaset
  - Get the JSON specification for all replicatsets in a namespace
  - Get a list if all replicasets in a namespace
  - Get a list of unused replicasets per namespace and deployment
  - Get number of unused replicasets per deployment

It also contains a Python script called manage_unused_replicasets.py that can be used to:
    - Get a list deployments with high revision history limit
    - Create a comma separated report file with the above list
    - Create a text file with commands to reduce the revisionHistoryLimit in deployments to 10
