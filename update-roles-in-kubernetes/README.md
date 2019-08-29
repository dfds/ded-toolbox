# Update set of Roles in Kubernetes
This repository implements a simple way of adding a Kubernetes Policy to all roles ending with "-fullaccess" in its name.
The code iterates over all namespaces, finding the correct roles to alter and finally patches to role.

Connection to Kubernetes is setup by means of the default config file, and for this code to work, a config-file with proper rights should be present.

# Quick start
Open code in favorite editor and run.