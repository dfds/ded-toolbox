# Generate a service connection kubernetes configuration and push to AWS Systems Manager Parameter Store
This tool allows for easy creation of a kubernetes configuration file based on a pre-defined template.

After creation of the file the tool automatically provisions the configuration inside of the AWS account specified as the root

## Prerequisites
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* Admin Kubeconfig for Hellman cluster 
* [jq](https://stedolan.github.io/jq/)
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* AWS CLI Credentials for Prime AWS Account

### Getting Kubeconfig for Hellman cluster
The Kubeconfig file for the Hellman cluster can be found in DFDS 1Password account.
It is saved as a note with the name: **K8s config Hellman Admin**

1. Find the K8s config Hellman Admin inside of 1Password, and select **edit**.
2. Copy the content of the **notes** field.
3. Create an empty file called *hellman_config*
4. Paste the content from the clipboard into *hellman_config* and save the file.
5. Make `kubectl` use the config file with: `export KUBECONFIG=config_hellman`

**NOTE:**  
This approach only sets `kubectl` to use the configuration file for the current terminal session you are running. Re-run step five or make sure to export the full path of the `KUBECONFIG` inside your shell of choices rc file (.bashrc / .zshrc)

## How to use

1. `git clone` the repository to your local machine
2. `cd` to the *ded-toolbox/k8s-service-account-config-to-ssm* directory
3. Get and set the local variables information from **ded-aesir** slack channel
4. Execute the `./kube-config-generator.sh` script

The script requires two environment variables set.  
`ROOT_ID`: Can be found from the **capabilityRootId** field from Harald-notify app in **ded-aesir** slack channel.

`ACCOUNT_ID`: Can be found after the **Tax settings for AWS Account** field from Harald-notify app in **ded-aesir** slack channel. 

The syntax for running the script is:  
`ROOT_ID=YOUR_CAPABILITY_ROOT_ID ACCOUNT_ID=YOUR_CAPABILITY_AWS_ACCOUNT_ID ./kube-config-generator.sh`

Sample script execution:
``` bash
ROOT_ID=capabilityplayground-312312 \
ACCOUNT_ID=123456789123 \
./kube-config-generator.sh
```