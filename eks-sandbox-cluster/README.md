# Create sandbox cluster based on production

## Synopsis

The script allows you to easily generate manifests for a sandbox EKS cluster, based off the current manifests for the production cluster.

You can easily override key variables. The script also overrides certain variables with sane defaults, unless the have been explicitly defined - e.g. instance count and type.

Each time the script is run it will:

1. Clone the **current** version of the Hellman manifests
2. Override any (supported) variables specified `sandbox-vars-$CLUSTERNAME.sh`
3. Sets `eks_is_sandbox = true`

In other words: You can re-run the script as many times as you like, keeping your sandbox manifests aligned with production, apart from your overrides. You could even make it a habbit of running the script before running `terragrunt apply-all` on your cluster.

## Syntax

```bash
./eks-sandbox.sh CLUSTER_NAME [SANDBOX_ROOT]
```

**Examples:**

To create a manifests directory for a sandbox cluster named `williwanna` in the current directory:

```bash
./eks-sandbox.sh williwanna
```

Create a manifests directory for a sandbox cluster named `darkside` in the directory `/code/terraform/eu-west-1`:

```bash
./eks-sandbox.sh darkside /code/terraform/eu-west-1
```
