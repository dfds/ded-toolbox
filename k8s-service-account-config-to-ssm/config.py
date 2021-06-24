import os

from dotenv import load_dotenv


class Config:
    """Class for environment configurations. Load from .env file
    with environment specific variables prefixed with environment name.

    Example: AWS_ROLE_CLOUD_ADMIN=<REDACTED>
    """

    def __init__(self) -> None:
        load_dotenv()
        self.aws_role_cloud_admin: str = os.environ.get("AWS_ROLE_CLOUD_ADMIN")
        self.aws_role_adfs_admin: str = os.environ.get("AWS_ROLE_ADFS_ADMIN")

    def __str__(self) -> str:
        """Beautify when printing the class

        :return: str
        """
        output = (
            f"AWS Cloud Admin Role ARN: {self.aws_role_cloud_admin}\n"
            f"AWS ADFS Admin Role ARN: {self.aws_role_adfs_admin}"
        )
        return output
