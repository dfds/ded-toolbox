# Update federation metadata
This repo contains a script for bulk update federation metadata for all accounts.

# Quick start
Login with saml2aws
```bash
saml2aws login --force
export AWS_PROFILE=saml
```
Execute update script
```bash
bash run.sh
```
It will fail on some legacy accounts, it self and some others.