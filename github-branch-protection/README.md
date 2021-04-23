# Housekeeping

This repository contains various Python modules and utility scripts for housekeeping tasks.

## Development practices

Guidelines for developing and testing the housekeeping scripts.

### Virtual environment

```bash
mkdir -p ~/.virtualenvs
virtualenv ~/.virtualenvs/housekeeping
source ~/.virtualenvs/housekeeping/bin/activate
python3 -m pip -r requirements_dev.txt
```

### Testing and code coverage

There are currently no test cases, but this is how testing would look like:

```bash
tox -e flake8
tox
```

## Usage

### Set branch protection rules

```bash
source ~/.virtualenvs/housekeeping/bin/activate
cd ~/git/housekeeping
export GITHUB_OAUTH2_TOKEN=<REDACTED>
./manage_branch_protection_rules.py
```
