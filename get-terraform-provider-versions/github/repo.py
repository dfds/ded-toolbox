import logging

import requests
from requests import Response

API_URL: str = "https://api.github.com"


class HttpUtil:
    """A utility class for HTTP verbs."""

    def __init__(self, token: str, level: int = logging.INFO) -> None:
        """Class constructor.
        :param token: An OAUTH2 token which can authenticate with GitHub.
        :param level: A valid log level from the logging module. Default: logging.INFO
        :type token: str
        :type level: int
        """
        logging.basicConfig(
            format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=level
        )
        self.token: str = token

    def get(self, url: str, params: dict = None) -> dict:
        """Utility method for doing HTTP GET.
        :param url: The full url to the REST API endpoint.
        :param params: Query parameters to the REST API endpoint. Default: None
        :type url: str
        :type params: dict
        :return: dict
        """
        headers: dict = {
            "Accept": "application/vnd.github.v3+json",
            "Authorization": f"token {self.token}",
        }
        response: Response = requests.get(url=url, headers=headers, params=params)
        return response.json()

    def post(self, url: str, payload: dict) -> Response:
        """Utility method for doing HTTP POST.
        :param url: The full url to the REST API endpoint.
        :param payload: A dictionary which can be serialized into a JSON payload.
        :type url: str
        :type payload: dict
        :return: requests.Response
        """
        headers: dict = {
            "Accept": "application/vnd.github.luke-cage-preview+json",
            "Authorization": f"token {self.token}",
        }
        response: Response = requests.post(url=url, headers=headers, json=payload)
        return response

    def put(self, url: str, payload: dict) -> Response:
        """Utility method for doing HTTP PUT.
        :param url: The full url to the REST API endpoint.
        :param payload: A dictionary which can be serialized into a JSON payload.
        :type url: str
        :type payload: dict
        :return: requests.Response
        """
        headers: dict = {
            "Accept": "application/vnd.github.luke-cage-preview+json",
            "Authorization": f"token {self.token}",
        }
        response: Response = requests.put(url=url, headers=headers, json=payload)
        return response


class Repo:
    """A class that represent a GitHub repository."""

    def __init__(self, token: str, owner: str, level: int = logging.INFO) -> None:
        """Class constructor.
        :param token: An OAUTH2 token which can authenticate with GitHub.
        :param owner: The GitHub Enterprise organization name.
        :param level: A valid log level from the logging module. Default: logging.INFO
        :type token: str
        :type owner: str
        :type level: int
        """
        logging.basicConfig(
            format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=level
        )
        self.http_utils: HttpUtil = HttpUtil(token)
        self.owner: str = owner

    def _get_number_of_private_repos(self) -> int:
        """Private method for counting the number of private repositories in the organization.
        :return: int
        """
        data: dict = self.http_utils.get(url=f"{API_URL}/orgs/{self.owner}")
        count: int = data.get("total_private_repos")
        return count

    def _get_number_of_public_repos(self) -> int:
        """Private method for counting the number of public repositories in the organization.
        :return: int
        """
        data: dict = self.http_utils.get(url=f"{API_URL}/orgs/{self.owner}")
        count: int = data.get("public_repos")
        return count

    def _get_number_of_repos(self) -> int:
        """Private method for counting the total number of repositories in the organization.
        :return: int
        """
        count: int = (
            self._get_number_of_public_repos() + self._get_number_of_private_repos()
        )
        return count

    def get_all_repos(self, limit: int = None) -> list:
        """Get a list of all the repositories in the organization.
        :param limit: Instead of fetching all repositories, you can opt to just
        fetch the 'n' first repositories sorted alphabetically. This is useful
        during development or diagnostics. Default: None.
        :return: list
        """
        all_repos: list = []
        page_counter: int = 0
        page_limit: int = 50
        number_of_repos_left: int = self._get_number_of_repos()
        if limit is not None:
            number_of_repos_left = limit
        while number_of_repos_left > 0:
            page_counter += 1
            if number_of_repos_left < page_limit:
                page_limit = number_of_repos_left
            params: dict = {
                "type": "all",
                "sort": "full_name",
                "per_page": page_limit,
                "page": page_counter,
            }
            fragment: dict = self.http_utils.get(
                url=f"{API_URL}/orgs/{self.owner}/repos", params=params
            )
            all_repos.append(fragment)
            if number_of_repos_left >= page_limit:
                number_of_repos_left -= page_limit
        return all_repos

    def does_repo_exist(self, name: str) -> bool:
        repo_data: dict = self.http_utils.get(
            url=f"{API_URL}/repos/{self.owner}/{name}"
        )
        if "message" in repo_data:
            return False
        else:
            return True

    def does_repo_contain_hcl(self, name: str) -> bool:
        repo_data: dict = self.http_utils.get(
            url=f"{API_URL}/repos/{self.owner}/{name}"
        )
        language_url: str = repo_data["languages_url"]
        language_data: dict = self.http_utils.get(url=language_url)
        if "HCL" in language_data:
            return True
        else:
            return False

    def get_repo(self, name: str) -> list:
        """Retrieve the parameters of a specific named Github repository.
        :param name: The name of the Github repository to retrieve data for.
        :return: list
        """
        repos: list = []
        fragment: dict = self.http_utils.get(url=f"{API_URL}/repos/{self.owner}/{name}")
        repos.append(fragment)
        return repos

    def get_default_branch(self, repo_name: str) -> str:
        """Find the default branch for a given repository.
        :param repo_name: The name of a GitHub repository under the organization.
        :type repo_name: str
        :return: str
        """
        data: dict = self.http_utils.get(f"{API_URL}/repos/{self.owner}/{repo_name}")
        return data.get("default_branch")

    def is_repo_archived(self, repo_name: str) -> bool:
        """
        Check if a repository has been archived.
        :param repo_name: The name of the repository we want to check.
        :type repo_name: str
        :return: bool
        """
        data: dict = self.http_utils.get(f"{API_URL}/repos/{self.owner}/{repo_name}")
        is_archived: bool = data.get("archived", False)
        return is_archived

    def is_repo_disabled(self, repo_name: str) -> bool:
        """
        Check if a repository has been disabled.
        :param repo_name: The name of the repository we want to check.
        :type repo_name: str
        :return: bool
        """
        data: dict = self.http_utils.get(f"{API_URL}/repos/{self.owner}/{repo_name}")
        is_disabled: bool = data.get("disabled", False)
        return is_disabled
