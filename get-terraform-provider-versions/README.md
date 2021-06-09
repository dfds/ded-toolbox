# get-terraform-provider-versions

This folder contains a Python script that will audit Terraform code files.  It will parse these files to look for required_provider statements and use the associated information to build a matrix of used providers.  It will then query the Terraform Registry to find the most recent version available for those providers before finally building output data which helps to identify out-dated and version locked providers.

The default behaviour is to clone all repositories owned by the DFDS organization and perform the analysis on each.  However, some logic is applied as follows:

- Archived repositories will automatically be skipped.
- Disabled repositories will automatically be skipped.
- Repositories which do not have HCL listed in their languages section will also be skipped.

## Requirements

A valid GitHub OAuth2 Token needs to be obtained and set using the environment variable named GITHUB_OAUTH2_TOKEN.

### Testing and code coverage

There are currently no test cases, but this is how testing would look like:

```bash
tox -e flake8
tox
```

## Usage

### Audit all GitHub Repositories containing Terraform Code

```bash
export GITHUB_OAUTH2_TOKEN=<REDACTED>
./get-tf-provider-versions.py
```

### Optional Parameters
| Parameter  | Description | Detail | 
| --- | --- | --- | 
| -o | output format | Specifies the output format.  Valid parameter values are csv, json or table.  If not specified then CSV is the default |
| -l | local path | Allows you to point to a local folder which holds clones instances of the repositories you wish to analyse.  If you use this option then only the repositories you have cloned at the path specified will be analysed. |
| -r | github repositories to include | You can use this parameter to specify one or more GitHub repository names that should be scanned.  In the case of specifying multiple each name should be seperated with a comma.  The option allows you to target specific repositories for analysis rather than then all being analysed. |
| -e | github repositories to exclude | This option is the inverse of -r and allows you to exclude specific repository names from the analysis. |
| -p | plain output | Use this option with the value of True to have the output in plain format.  This option is only relevent if you are outputing in table format.  In that instance the table is usually colour coded, but executing with this property set to true will strip out the colour control codes and just output in plain format. |
| -h | help | Displays the help information for the script |
