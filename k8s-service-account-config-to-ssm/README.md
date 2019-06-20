# Generate a service connection kube config and push to SSM

## Prereqs
* kubectl and Hellman admin config
* jq
* aws cli
* prime aws creds

# Usage
``` bash
#ROOT_ID=YOUR_CAPABILITY_ROOT_ID ACCOUNT_ID=YOUR_CAPABILITY_AWS_ACCOUNT_ID ./kube-config-generator.sh
ROOT_ID=capabilityplayground-312312 ACCOUNT_ID=123456789123 ./kube-config-generator.sh
```
