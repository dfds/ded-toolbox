import base64
import boto3
import getopt
import sys
import re
import subprocess
import logging
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# define constants
AWS_ROLE_CLOUD_ADMIN = "arn:aws:iam::738063116313:role/CloudAdmin"
AWS_ROLE_ADFS_ADMIN = "arn:aws:iam::454234050858:role/ADFS-Admin"
AWS_PARAMETER_NAME = "/managed/deploy/kube-config"
AWS_PROFILE = "saml"
AWS_REGION = "eu-central-1"
CAPABILITY_AWS_ROLE_SESSION = "kube-config-paramstore"
KUBERNETES_CONTEXT = "hellman-saml"
SERVICE_ACCOUNT_NAMESPACE = "kube-system"


def assume_saml_role(role_to_assume: str) -> bool:
    """
    Use the saml2aws utility to assume a specific SAML role in the AWS environment
    """
    logging.info(f"Assuming the SAML Role {role_to_assume}.")
    exec_command: str = f"saml2aws login --role={role_to_assume} --force --skip-prompt"
    proc_result: subprocess.CompletedProcess = subprocess.run(
        exec_command.split(" "), stdout=subprocess.DEVNULL
    )
    if proc_result.returncode == 0:
        logging.info("Role assumed succesfully.")
    else:
        logging.warn("Role failed to be assumed.")
    return proc_result.returncode == 0


def create_k8s_kube_config(service_account_name: str, namespace: str) -> str:
    """
    Create a string hold the kubeconfig definition.
    """
    kube_token_b64: str = ""
    kube_api = client.CoreV1Api()
    list_secrets = kube_api.list_namespaced_secret(SERVICE_ACCOUNT_NAMESPACE)
    for secret in list_secrets.items:
        if re.search(f"^{service_account_name}", secret.metadata.name):
            kube_token_b64: str = secret.data["token"]
            break

    if kube_token_b64 != "":
        kube_token_decoded: str = base64.b64decode(kube_token_b64).decode("utf-8")
        kube_config_template_file = open("config.template")
        kube_config_template: str = kube_config_template_file.read()
        kube_config_template_file.close()
        kube_config = kube_config_template.replace(
            "NAMESPACE_REPLACE", namespace
        ).replace("KUBE_TOKEN", kube_token_decoded)

    return kube_config


def create_k8s_role_binding(
    service_account_name: str, namespace: str, role_name: str
) -> bool:
    """
    Create a RoleBinding in Kubernetes that assigns the -FullAccess role to the specific Service Account
    """
    info_msg: str = f"Creating Kubernetes Role Binding for: {service_account_name}"
    logging.info(info_msg)
    rbac_api = client.RbacAuthorizationV1Api()
    try:
        rbac_api.read_namespaced_role_binding(service_account_name, namespace)
        logging.info("The required Role Binding already exists.")
        return True
    except ApiException as ex:
        if ex.status == 404:
            logging.info("The Role Binding was not found.  It will be created now.")
            metadata = client.V1ObjectMeta(name=service_account_name)
            role_ref = client.V1RoleRef(
                api_group="rbac.authorization.k8s.io",
                kind="Role",
                name=role_name,
            )
            subject = client.V1Subject(
                kind="ServiceAccount",
                namespace=SERVICE_ACCOUNT_NAMESPACE,
                name=service_account_name,
            )
            api_body = client.V1RoleBinding(
                metadata=metadata, role_ref=role_ref, subjects=[subject]
            )
            rbac_api.create_namespaced_role_binding(
                namespace=namespace, body=api_body, pretty="true"
            )
            return True
        else:
            return False


def create_k8s_service_account(name: str, namespace: str) -> bool:
    """
    Create a new Kubernetes ServiceAccount
    """
    info_msg: str = f"Creating Kubernetes Service Account: {name}"
    logging.info(info_msg)
    kube_api = client.CoreV1Api()
    try:
        kube_api.read_namespaced_service_account(name, namespace)
        logging.info("The required Service Account already exists.")
        return True
    except ApiException as ex:
        if ex.status == 404:
            logging.info("The Service Account was not found.  It will be created now.")
            api_body = {"metadata": {"name": name}}
            kube_api.create_namespaced_service_account(
                namespace, api_body, pretty="true"
            )
            return True
        else:
            logging.error(
                "An error occurred whilst determine if the Service Account exists or"
                " not."
            )
            return False


def set_k8s_context(context_name: str) -> bool:
    """
    Set the Kubernetes Context to that specified
    """
    logging.info(f"Setting Kubernetes context to '{context_name}':")
    try:
        config.load_kube_config(context=context_name)
        return True
    except Exception as ex:
        logging.error(
            f"The script was unable to select the {context_name} context in Kubernetes."
        )
        logging.error(" The generated exception was:")
        logging.error(f"  {ex}")
        logging.error("The script will now terminate.")
        return False


def show_usage():
    """
    Display parameters and usage instructions for the script
    """
    out_str: str = """
kube-config-generator.py

Takes the provided Root ID and Account ID and will generate a kubeconfig that is then
stored as an AWS Systems Manager parameter.  The script also creates a Kubernetes
service acccount and role binding for which a secure token is also created; this is then
used as part of the generated kubeconfig.

Parameters

     -r <root_id>
        The root id of the account for which a kubeconfig should be generated.

     -a <account_id>
        The account id of the account for which a kubeconfig should be generated.

     -h
        Display this help information."""
    print(out_str)


def main(argv):

    account_id: str = ""
    root_id: str = ""

    logging.basicConfig(
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        level=logging.INFO,
    )

    try:
        opts, args = getopt.getopt(
            argv,
            "hr:a:",
            ["root_id=", "account_id="],
        )
    except getopt.GetoptError:
        show_usage()
        sys.exit(2)

    for opt, arg in opts:
        if opt in ("-h", "--help"):
            show_usage()
            sys.exit()
        elif opt in ("-r", "--root_id"):
            root_id: str = arg
        elif opt in ("-a", "--account_id"):
            account_id: str = arg

    if account_id == "" or root_id == "":
        logging.error(
            "The script cannot continue because the Root ID and Account ID were not"
            " specified using the -r and -a parameters."
        )
        show_usage()
        sys.exit(2)

    capability_root_id: str = root_id
    namespace: str = root_id
    kube_role: str = f"{capability_root_id}-fullaccess"
    service_account_name = f"{capability_root_id}-vstsuser"
    capability_aws_account_id = account_id
    capability_aws_role_arn = f"arn:aws:iam::{capability_aws_account_id}:role/OrgRole"

    ret_val: bool = assume_saml_role(AWS_ROLE_CLOUD_ADMIN)
    if ret_val:
        ret_val: bool = set_k8s_context(KUBERNETES_CONTEXT)
        if ret_val:
            ret_val: bool = create_k8s_service_account(
                name=service_account_name, namespace=SERVICE_ACCOUNT_NAMESPACE
            )

            if ret_val:
                ret_val: bool = create_k8s_role_binding(
                    service_account_name=service_account_name,
                    namespace=namespace,
                    role_name=kube_role,
                )

            if ret_val:
                kube_config: str = create_k8s_kube_config(
                    service_account_name, namespace
                )

                # change saml role to ADFS Admin
                ret_val: bool = assume_saml_role(AWS_ROLE_ADFS_ADMIN)

                if ret_val:
                    # retrieve credentials to assume role in the boto3 client
                    boto_client = boto3.setup_default_session(region_name=AWS_REGION)
                    boto_client = boto3.client("sts")
                    response = boto_client.assume_role(
                        RoleArn=capability_aws_role_arn,
                        RoleSessionName=CAPABILITY_AWS_ROLE_SESSION,
                    )

                    # create boto3 client for SSM using assumed role credentials
                    ssm_client = boto3.client(
                        "ssm",
                        aws_access_key_id=response["Credentials"]["AccessKeyId"],
                        aws_secret_access_key=response["Credentials"][
                            "SecretAccessKey"
                        ],
                        aws_session_token=response["Credentials"]["SessionToken"],
                    )
                    logging.info(
                        f"Creating the AWS SSM Parameter {AWS_PARAMETER_NAME}."
                    )
                    try:
                        # create kubeconfig as an ssm parameter
                        response = ssm_client.put_parameter(
                            Name=AWS_PARAMETER_NAME,
                            Value=kube_config,
                            Type="SecureString",
                            Overwrite=True,
                        )
                        logging.info("Parameter creation completed.")

                    except Exception as ex:
                        logging.error(
                            "An error occurred whilst trying to create the parameter."
                        )
                        logging.error(" The generated exception was:")
                        logging.error(f"  {ex}")


if __name__ == "__main__":
    main(sys.argv[1:])
