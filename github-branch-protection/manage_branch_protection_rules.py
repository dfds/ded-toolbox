#!/usr/bin/env python3
import logging
import os

from github.branch_protection import Repo, Branch, Rule

GITHUB_ORGANIZATION = 'dfds'


def main():
    token: str = os.environ.get('GITHUB_OAUTH2_TOKEN')
    repo: Repo = Repo(token=token, owner=GITHUB_ORGANIZATION)
    repo_list: list = repo.get_all_repos()

    branch: Branch = Branch(token=token, owner=GITHUB_ORGANIZATION)
    rule: Rule = Rule()

    for repos in repo_list:
        for r in repos:
            name: str = r.get('name')
            default_branch: str = r.get('default_branch')
            is_archived: bool = r.get('archived', False)
            is_disabled: bool = r.get('disabled', False)

            has_rules: bool = branch.has_branch_protection_rules(name, default_branch)
            if is_archived:
                logging.info(f'Skipping repository {name}, because this repo has been archived.')
            elif is_disabled:
                logging.info(f'Skipping repository {name}, because this repo has been disabled.')
            elif has_rules:
                logging.info(f'Skipping repository {name}, because it already has some branch protection rules set.')
            else:
                if name not in repo.get_protected_repos():
                    logging.info(f'Set branch protection rules for repository {name}')
                    branch.set_branch_protection_rules(name,
                                                       default_branch,
                                                       rule.get_default_branch_protection_rules())
                else:
                    logging.info(f'Repository {name} will not be updated, because it is on the protected repo list.')


if __name__ == "__main__":
    main()
