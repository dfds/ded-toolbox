#!/usr/bin/env python3
import sys
import getopt
import os
import re
import logging
import tempfile
import subprocess
import requests

from github.repo import Repo

GITHUB_ORGANIZATION = 'dfds'
TFREGISTRY_BASEAPI = 'https://registry.terraform.io/v1/providers/'


# define a custom class to hold the providers we locate
class TerraformProvider:
    """
    This class defines a Terraform provider
    """

    def __init__(self, repository_name: str, file_path: str, provider_name: str, provider_version: str, latest_provider_version: str = "", comment: str = ""):
        self.repository_name = repository_name
        self.file_path = file_path
        self.provider_name = provider_name
        self.provider_version = provider_version
        self.latest_provider_version = latest_provider_version
        self.comment = comment


class TerraformProviders:
    """
    This class defines a collection of Terraform providers
    """

    def __init__(self):
        self.terraform_providers: list = []

    def __iter__(self):
        return iter(self.terraform_providers)

    def append(self, new_item):
        self.terraform_providers.append(new_item)

    def count(self):
        return len(self.terraform_providers)

    def get_json(self):
        """
        Get the data from the collection elements and return them in JSON format.
        """
        json_string: str = '['
        for provider in self.terraform_providers:
            json_string += ('{"repository_name":')
            json_string += (f'"{provider.repository_name}",')
            json_string += (f'"terraform_file":"{provider.file_path}",')
            json_string += (f'"provider_name":"{provider.provider_name}",')
            json_string += (f'"version_used":"{provider.provider_version}",')
            json_string += (f'"latest_version":"{provider.latest_provider_version}",')
            json_string += (f'"comment":"{provider.comment}"')
            json_string += ('},')
        json_string = json_string.strip(',')+']'
        json_string = json_string.replace("\\", "\\\\")
        return json_string

    def get_latest_versions(self):
        """
        Retrieve the latest Provider versions for the elements in the collection
        from the Terraform Registry.
        """
        for provider in self.terraform_providers:
            query_url: str = (f'{TFREGISTRY_BASEAPI}{provider.provider_name}')
            resp = requests.get(query_url)
            if resp.status_code != 200:
                logging.error(f'RestAPI call to {query_url} returned HTTP status {resp.status_code}')
            else:
                latest_provider_version: str = resp.json()["version"].strip()
                provider.latest_provider_version = latest_provider_version
                if re.search('^>=', provider.provider_version) or provider.provider_version == 'Latest':
                    provider.comment = 'Latest version will be used.'
                if re.search('^~>', provider.provider_version):
                    locked_version = provider.provider_version.replace('~>', '').strip(' ').split('.')
                    latest_version = provider.latest_provider_version.split('.')
                    if locked_version[0] == latest_version[0] and locked_version[1] == latest_version[1] and locked_version[2] != latest_version[2]:
                        provider.comment = 'Patch update only.'
                    else:
                        if locked_version[1] != latest_version[1]:
                            provider.comment = 'Minor version update available.'
                        if locked_version[0] != latest_version[0]:
                            provider.comment = 'Major version update available.'


# function to parse .tf files for provider versions
def parse_terraform_file(temp_folder: str, repository_name: str, file_path: str, used_providers: TerraformProviders) -> TerraformProviders:

    logging.info(f'\tParsing the Terraform file {file_path}.')

    provider_matching: bool = False
    brace_count: int = 0
    current_provider_name: str = ""
    current_provider_version: str = ""

    with open(file_path, "r") as reader:

        for line in reader:
            current_line: str = line.strip()
            if provider_matching:
                if current_line.find("{") > -1:
                    brace_count = brace_count + (current_line.count("{"))
                if current_line.find("}") > -1:
                    brace_count = brace_count - (current_line.count("}"))
                if brace_count <= 0:
                    provider_matching = False
                    break
                if re.search('^source *= *".*"', current_line.strip()):
                    current_provider_name = (
                        current_line.split("=")[1].replace('"', "").strip()
                    )
                if re.search('^version *= *".*"', current_line.strip()):
                    current_provider_version = (
                        current_line[current_line.find("=") + 1:]
                        .replace('"', "")
                        .strip()
                    )
                if re.search("}", current_line):
                    if current_provider_version == "":
                        current_provider_version = "Latest"
                    new_used_provider = TerraformProvider(
                        repository_name, file_path.replace(
                            temp_folder, ""), current_provider_name, current_provider_version
                    )

                    used_providers.append(new_used_provider)
            if current_line.startswith('#') is False:
                if re.search("required_providers", current_line):
                    provider_matching = True
                    brace_count = brace_count + (current_line.count("{"))
    return used_providers


def show_usage():
    print('get-terraform-provider-versions.py')
    print('')
    print('Performs analysis of Terraform code files and identifies any used providers.  The script will then')
    print('query the Terraform Registry for the latest version of the providers and present output data that')
    print('identifies instances where the code is locked to out-dated providers.')
    print('')
    print('All parameters are optional')
    print('')
    print('     -o <output format>')
    print('        Specify csv, json or table.  CSV format is the default')
    print('')
    print('     -l <local path>')
    print('        If you use this parameter to specify a local path then the cloned copies of Repositorys')
    print('        at that location will be used instead of cloning the Repository.')
    print('')
    print('     -r <github repository names to include>')
    print('        Provide the names of one or more repositorys that should be analysed.')
    print('        If specifying multiple then they should be seperated by commas.')
    print('')
    print('     -e <github repository names to exclude>')
    print('        Provide the names of one or more repositorys that should be excluded from the analysis.')
    print('        If specifying multiple then they should be seperated by commas.')
    print('')
    print('     -p True/False')
    print('        Flag to denote if output should be plain or not.  This is only relevent if outputting')
    print('        in table format.  In this instance the deafult is for colour coding to be applied. If')
    print('        you don \'t want the colour then use this flag with a value of True.')
    print('')
    print('     -h')
    print('        Display this help information.')
    print('')


def main(argv):

    logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)

    plain_output: bool = False
    excluded_repos: list = []
    process_repository: list = []
    local_path: str = ""
    output_format: str = "csv"
    COLOUR_END_CODE = '\033[0m'

    try:
        opts, args = getopt.getopt(argv, "hr:o:l:e:p:", ["repository=", "output=", "local=", "exlude=", "plain"])
    except getopt.GetoptError:
        show_usage()
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            show_usage()
            sys.exit()
        elif opt in ("-e", "--exclude"):
            excluded_repos: list = arg.split(',')
        elif opt in ("-l", "--local"):
            local_path: str = arg
        elif opt in ("-r", "--repository"):
            process_repository: list = arg.split(',')
        elif opt in ("-o", "--output"):
            output_format: str = arg
        elif opt in ("-p", "--plain"):
            if arg.lower() == 'true':
                plain_output: bool = True

    used_providers: TerraformProviders = TerraformProviders()

    if local_path != '':
        source_base: str = local_path
        sub_directories = os.listdir(source_base)
        for sub_directory in sub_directories:
            if sub_directory in excluded_repos:
                logging.info(f'Skipping repository {sub_directory}, because it has been explicitely excluded using the -e parameter.')
            else:
                if (len(process_repository) == 0 or sub_directory in process_repository):
                    sub_directory_path = os.path.join(source_base, sub_directory)
                    for root, dirs, files in os.walk(sub_directory_path):
                        for filename in files:
                            file_path: str = os.path.join(root, filename)
                            if file_path.find(".terragrunt-cache") == -1 and file_path.find(".git") == -1:
                                if file_path.endswith(".tf"):
                                    used_providers: TerraformProviders = parse_terraform_file(sub_directory_path, sub_directory, file_path, used_providers)
                                    break
                                else:
                                    continue
    else:
        token: str = os.environ.get('GITHUB_OAUTH2_TOKEN')
        if token is None:
            logging.error('A GitHub OAUTH2 Token has not been defined in the GITHUB_OAUTH2_TOKEN environment variable.')
            logging.error('The script cannot continue and will now terminate.')
            sys.exit(3)
        repo: Repo = Repo(token=token, owner=GITHUB_ORGANIZATION)

        if (len(process_repository) == 0):
            repo_list: list = repo.get_all_repos()
        else:
            repo_list: list = []
            for github_repository in process_repository:
                repo_exist: bool = (repo.does_repo_exist(github_repository))
                if repo_exist is False:
                    logging.error('The script cannot continue because the Repository specified using the -r parameter could not be found at Github.')
                    sys.exit(4)
                else:
                    repo_list.append(repo.get_repo(github_repository))

        for repos in repo_list:
            for r in repos:
                name: str = r.get('name')

                if name in excluded_repos:
                    logging.info(
                        f'Skipping repository {name}, because it has been explicitely excluded using the -e parameter.')
                else:
                    is_archived: bool = r.get('archived', False)
                    is_disabled: bool = r.get('disabled', False)

                    if is_archived:
                        logging.info(f'Skipping repository {name}, because this repo has been archived.')
                    elif is_disabled:
                        logging.info(f'Skipping repository {name}, because this repo has been disabled.')
                    else:
                        repo_has_hcl = repo.does_repo_contain_hcl(name)
                        if repo_has_hcl:
                            logging.info(f'Performing Terraform provider analysis on the repository {name}.')

                            f = tempfile.TemporaryDirectory()

                            repository_name: str = r.get('name')

                            clone_url: str = r.get('clone_url')
                            clone_command: str = f'git clone {clone_url} {f.name} -q'
                            logging.info('\tCreating a local Clone of the GitHub repository.')
                            subprocess.call(clone_command, shell=True)
                            logging.info('\tClone complete.')

                            source_base: str = f.name
                            for root, dirs, files in os.walk(source_base):
                                for filename in files:
                                    file_path: str = os.path.join(root, filename)
                                    if file_path.find(".terragrunt-cache") == -1 and file_path.find(".git") == -1:
                                        if file_path.endswith(".tf"):
                                            used_providers: TerraformProviders = parse_terraform_file(f.name, repository_name, file_path, used_providers)
                                        else:
                                            continue
                        else:
                            logging.info(f'Skipping Terraform provider analysis on the repository {name} because it does not contain HCL code.')

    used_providers.get_latest_versions()

    if output_format == 'csv':
        print('Repository Name,Terraform File,Provider Name,Version Used,Latest Version,Comment')
        for provider in used_providers:
            print_str: str = (f'{provider.repository_name},{provider.file_path},{provider.provider_name},')
            print_str += (f'{provider.provider_version},{provider.latest_provider_version},{provider.comment}')
            print(print_str)

    if output_format == 'json':
        json_string: str = used_providers.get_json()
        print(json_string)

    if output_format == 'table':
        print("")
        print("Used Providers")
        print("")
        print("Provider Count: ", used_providers.count())
        print("")
        print_str: str = (
            f'\033[1m{"Repository Name" : <30}{"Terraform File" : <60}{"Provider Name" : <30}{"Version Used" : <15}')
        print_str += (
            f'{"Latest Version" : <20}{"Comment" : <20}{"" : <1}\033[0m')
        if plain_output:
            print_str = print_str.replace('\033[1m', '').replace('\033[0m', '')
        print(print_str)
        for provider in used_providers:
            if provider.comment == 'Latest version will be used.':
                colour_code = '\033[32m'
            if provider.comment == 'Major version update available.':
                colour_code = '\033[31m'
            if provider.comment == 'Minor version update available.':
                colour_code = '\033[93m'
            if provider.comment == 'Patch update only.':
                colour_code = '\033[36m'
            if plain_output:
                colour_code = ''
            print_str: str = (
                f'{colour_code}{provider.repository_name : <30}{provider.file_path : <60}{provider.provider_name : <30}')
            print_str += (f'{provider.provider_version : <15}{provider.latest_provider_version : <20}{provider.comment : <30}')
            if plain_output is False:
                print_str += (f'{COLOUR_END_CODE}')
            print(print_str)


if __name__ == "__main__":
    main(sys.argv[1:])
