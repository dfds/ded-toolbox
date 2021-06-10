import re
import logging
import requests

from github.repo import Repo

GITHUB_ORGANIZATION = "dfds"
TFREGISTRY_BASEAPI = "https://registry.terraform.io/v1/providers/"


# define a custom class to hold the providers we locate
class TerraformProvider:
    """
    This class defines a Terraform provider
    """

    def __init__(
        self,
        repository_name: str,
        file_path: str,
        provider_name: str,
        provider_version: str,
        latest_provider_version: str = "",
        comment: str = "",
    ):
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
        json_string: str = "["
        for provider in self.terraform_providers:
            json_string += '{"repository_name":'
            json_string += f'"{provider.repository_name}",'
            json_string += f'"terraform_file":"{provider.file_path}",'
            json_string += f'"provider_name":"{provider.provider_name}",'
            json_string += f'"version_used":"{provider.provider_version}",'
            json_string += f'"latest_version":"{provider.latest_provider_version}",'
            json_string += f'"comment":"{provider.comment}"'
            json_string += "},"
        json_string = json_string.strip(",") + "]"
        json_string = json_string.replace("\\", "\\\\")
        return json_string

    def get_latest_versions(self):
        """
        Retrieve the latest Provider versions for the elements in the collection
        from the Terraform Registry.
        """
        for provider in self.terraform_providers:
            query_url: str = f"{TFREGISTRY_BASEAPI}{provider.provider_name}"
            resp = requests.get(query_url)
            if resp.status_code != 200:
                logging.error(
                    f"RestAPI call to {query_url} returned HTTP status \
                    {resp.status_code}"
                )
            else:
                latest_provider_version: str = resp.json()["version"].strip()
                provider.latest_provider_version = latest_provider_version
                if (
                    re.search("^>=", provider.provider_version)
                    or provider.provider_version == "Latest"
                ):
                    provider.comment = "Latest version will be used."
                if re.search("^~>", provider.provider_version):
                    locked_version = (
                        provider.provider_version.replace("~>", "")
                        .strip(" ")
                        .split(".")
                    )
                    latest_version = provider.latest_provider_version.split(".")
                    if (
                        locked_version[0] == latest_version[0]
                        and locked_version[1] == latest_version[1]
                        and locked_version[2] != latest_version[2]
                    ):
                        provider.comment = "Patch update only."
                    else:
                        if locked_version[1] != latest_version[1]:
                            provider.comment = "Minor version update available."
                        if locked_version[0] != latest_version[0]:
                            provider.comment = "Major version update available."


# function to parse .tf files for provider versions
def parse_terraform_file(
    temp_folder: str,
    repository_name: str,
    file_path: str,
    used_providers: TerraformProviders,
) -> TerraformProviders:

    logging.info(f"\tParsing the Terraform file {file_path}.")

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
                        repository_name,
                        file_path.replace(temp_folder, ""),  # noqa e501
                        current_provider_name,
                        current_provider_version,
                    )
                    used_providers.append(new_used_provider)
            if current_line.startswith("#") is False:
                if re.search("required_providers", current_line):
                    provider_matching = True
                    brace_count = brace_count + (current_line.count("{"))
    return used_providers


def show_usage():
    out_str: str = """get-terraform-provider-versions.py

Performs analysis of Terraform code files and identifies any used providers.  The script
will then query the Terraform Registry for the latest version of the providers and
present output data that identifies instances where the code is locked to out-dated
providers.

All parameters are optional

     -o <output format>
        Specify csv, json or table.  CSV format is the default

     -l <local path>
        If you use this parameter to specify a local path then the cloned copies of
        Repositorys at that location will be used instead of cloning the Repository.

     -r <github repository names to include>
        Provide the names of one or more repositorys that should be analysed.
        If specifying multiple then they should be seperated by commas.

     -e <github repository names to exclude>')
        Provide the names of one or more repositorys that should be excluded from
        the analysis.  If specifying multiple then they should be seperated by
        commas.

     -p True/False')
        Flag to denote if output should be plain or not.  This is only relevent if
        outputting in table format.  In this instance the deafult is for colour
        coding to be applied. If you don \'t want the colour then use this flag
        with a value of True.

     -h
        Display this help information."""
    print(out_str)


