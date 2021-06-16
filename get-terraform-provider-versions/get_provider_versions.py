import sys
import getopt
import os
import tempfile
import subprocess
import logging

from get_terraform_provider_versions.get_tf_provider_versions import (
    TerraformProviders,
    show_usage,
    parse_terraform_file,
)
from github.repo import Repo

GITHUB_ORGANIZATION = "dfds"


def main(argv):

    logging.basicConfig(
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        level=logging.INFO,
    )

    plain_output: bool = False
    excluded_repos: list = []
    process_repository: list = []
    local_path: str = ""
    output_format: str = "csv"
    COLOUR_END_CODE = "\033[0m"

    try:
        opts, args = getopt.getopt(
            argv,
            "hr:o:l:e:p:",
            ["repository=", "output=", "local=", "exlude=", "plain"],
        )
    except getopt.GetoptError:
        show_usage()
        sys.exit(2)

    for opt, arg in opts:
        if opt == "-h":
            show_usage()
            sys.exit()
        elif opt in ("-e", "--exclude"):
            excluded_repos: list = arg.split(",")
        elif opt in ("-l", "--local"):
            local_path: str = arg
        elif opt in ("-r", "--repository"):
            process_repository: list = arg.split(",")
        elif opt in ("-o", "--output"):
            output_format: str = arg
        elif opt in ("-p", "--plain"):
            if arg.lower() == "true":
                plain_output: bool = True

    used_providers: TerraformProviders = TerraformProviders()

    if local_path != "":
        source_base: str = local_path
        sub_directories = os.listdir(source_base)
        for sub_directory in sub_directories:
            if sub_directory in excluded_repos:
                info_msg: str = (
                    f"Skipping repository {sub_directory}, because it"
                    " has been explicitely excluded using the -e parameter."
                )
                logging.info(info_msg)
            else:
                if len(process_repository) == 0 or sub_directory in process_repository:
                    sub_directory_path = os.path.join(source_base, sub_directory)
                    for root, dirs, files in os.walk(sub_directory_path):
                        for filename in files:
                            file_path: str = os.path.join(root, filename)
                            if (
                                file_path.find(".terragrunt-cache") == -1
                                and file_path.find(".git") == -1
                            ):
                                if file_path.endswith(".tf"):
                                    used_providers: TerraformProviders = (
                                        parse_terraform_file(
                                            sub_directory_path,
                                            sub_directory,
                                            file_path,
                                            used_providers,
                                        )
                                    )
                                else:
                                    continue
    else:
        token: str = os.environ.get("GITHUB_OAUTH2_TOKEN")
        if token is None:
            logging.error(
                "A GitHub OAUTH2 Token has not been defined in the \
GITHUB_OAUTH2_TOKEN environment variable."
            )
            logging.error("The script cannot continue and will now terminate.")
            sys.exit(3)
        repo: Repo = Repo(token=token, owner=GITHUB_ORGANIZATION)

        if len(process_repository) == 0:
            repo_list: list = repo.get_all_repos()
        else:
            repo_list: list = []
            for github_repository in process_repository:
                repo_exist: bool = repo.does_repo_exist(github_repository)
                if repo_exist is False:
                    logging.error(
                        "The script cannot continue because the Repository \
                        specified using the -r parameter could not be found at Github."
                    )
                    sys.exit(4)
                else:
                    repo_list.append(repo.get_repo(github_repository))

        for repos in repo_list:
            for r in repos:
                name: str = r.get("name")

                if name in excluded_repos:
                    logging.info(
                        f"Skipping repository {name}, because it has been explicitely excluded \
                            using the -e parameter."
                    )
                else:
                    is_archived: bool = r.get("archived", False)
                    is_disabled: bool = r.get("disabled", False)

                    if is_archived:
                        logging.info(
                            f"Skipping repository {name}, \
because this repo has been archived."
                        )
                    elif is_disabled:
                        logging.info(
                            f"Skipping repository {name}, \
because this repo has been disabled."
                        )
                    else:
                        repo_has_hcl = repo.does_repo_contain_hcl(name)
                        if repo_has_hcl:
                            logging.info(
                                f"Performing Terraform provider \
analysis on the repository {name}."
                            )

                            f = tempfile.TemporaryDirectory()

                            repository_name: str = r.get("name")

                            clone_url: str = r.get("clone_url")
                            clone_command: str = f"git clone {clone_url} {f.name} -q"
                            logging.info(
                                "\tCreating a local Clone of the GitHub repository."
                            )
                            subprocess.run(clone_command.split(" "), shell=True)
                            logging.info("\tClone complete.")

                            source_base: str = f.name
                            for root, dirs, files in os.walk(source_base):
                                for filename in files:
                                    file_path: str = os.path.join(root, filename)
                                    if (
                                        file_path.find(".terragrunt-cache") == -1
                                        and file_path.find(".git") == -1
                                    ):
                                        if file_path.endswith(".tf"):
                                            used_providers: TerraformProviders = (
                                                parse_terraform_file(
                                                    f.name,
                                                    repository_name,
                                                    file_path,
                                                    used_providers,
                                                )
                                            )
                                        else:
                                            continue
                        else:
                            logging.info(
                                f"Skipping Terraform provider analysis \
on the repository {name} because it does not \
contain HCL code."
                            )

    used_providers.get_latest_versions()

    if output_format == "csv":
        out_str: str = (
            "Repository Name,Terraform File,Provider Name"
            ",Version Used,Latest Version,Comment"
        )
        print(out_str)
        for provider in used_providers:
            print_str: str = (
                f"{provider.repository_name},{provider.file_path},"
                f"{provider.provider_name},{provider.provider_version},"
                f"{provider.latest_provider_version},{provider.comment}"
            )
            print(print_str)

    if output_format == "json":
        json_string: str = used_providers.get_json()
        print(json_string)

    if output_format == "table":
        print("")
        print("Used Providers")
        print("")
        print("Provider Count: ", used_providers.count())
        print("")
        print_str: str = (
            f'\033[1m{"Repository Name" : <30}{"Terraform File" : <60}'
            f'{"Provider Name" : <30}{"Version Used" : <15}'
            f'{"Latest Version" : <20}{"Comment" : <20}{"" : <1}\033[0m'
        )
        if plain_output:
            print_str = print_str.replace("\033[1m", "").replace("\033[0m", "")
        print(print_str)
        for provider in used_providers:
            colour_code: str = ""
            if provider.comment == "Latest version will be used.":
                colour_code = "\033[32m"
            if provider.comment == "Major version update available.":
                colour_code = "\033[31m"
            if provider.comment == "Minor version update available.":
                colour_code = "\033[93m"
            if provider.comment == "Patch update only.":
                colour_code = "\033[36m"
            if plain_output:
                colour_code = ""
            print_str: str = (
                f"{colour_code}{provider.repository_name : <30}"
                f"{provider.file_path : <60}{provider.provider_name : <30}"
                f"{provider.provider_version : <15}"
                f"{provider.latest_provider_version : <20}"
                f"{provider.comment : <30}"
            )
            if plain_output is False:
                print_str += f"{COLOUR_END_CODE}"
            print(print_str)


if __name__ == "__main__":
    main(sys.argv[1:])
