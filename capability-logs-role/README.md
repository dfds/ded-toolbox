# Capability AWS IAM role and associated AD group for central logs account

## Introduction

Logs in our Kubernetes clusters are shipped to CloudWatch Logs in our `dfds-logs` account (id `736359295931`). At the beginning, we allowed capabilities to assume a shared role (`Capability`), granting access to view all log groups (except a few).

To allow capabilities to enable subscription filters, this script will create a capability-specific role with additional permissions to their own log groups. These permissions can easily be extended by modifying `capability-logs-policy.json` accordingly.

The script can be run multiple times, and will create the IAM role if missing. The referenced policy will be attached, or updated if a policy with the same is already attached.

## Token replacement in template files

The script uses two template files:

- capability-logs-policy.json
- trust-policy.json

The following tokens are replaced:

| Token              | Replaced with                                                                       |
| ------------------ | ----------------------------------------------------------------------------------- |
| CAPABILITY_ROOT_ID | The capability root id from the first argument to `create-logs-capability-role.sh`  |
| ACCOUNT_ID         | The account id of the logs account, which is extracted from the current AWS context |

## Usage

### AWS profile prerequisite

Setup an AWS profile assuming the `OrgRole` in the logs account, using the credentials from the `saml` profile (which is updated by `saml2aws`).

This is done by adding a block like this to `~/.aws/config`:

```ini
[profile dfds-logs-orgrole]
role_arn = arn:aws:iam::736359295931:role/OrgRole
source_profile = saml
```

### Steps

1. Login as admin to the main AWS account using `saml2aws`
2. Export the `AWS_PROFILE` environment variable setting it to the name used above (e.g. `dfds-logs-orgrole`)
3. Execute the bash script to create the AWS IAM role and attach the policy, specifying the capability root id, e.g.: `./create-logs-capability-role.sh dynamic-forms-dxp-enxjg` (no validation on capability root id)
4. Execute the PowerShell command as output by the script above, on a computer with AD PoSH module installed, e.g. `./create-logs-capability-adgroup.ps1 -CapabilityRootId dynamic-forms-dxp-enxjg -AccountId 736359295931`
