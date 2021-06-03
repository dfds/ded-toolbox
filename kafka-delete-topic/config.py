import os

from dotenv import load_dotenv


class Config:
    """Class for environment configurations. Load from .env file
    with environment specific variables prefixed with environment name.

    Example: DEV_BLASTER_CLUSTER_UUID=<REDACTED>
    """

    def __init__(self) -> None:
        load_dotenv()
        self.env_prefix: str = os.environ.get("KAFKA_ENV")
        self.blaster_bearer_token: str = os.environ.get("BLASTER_BEARER_TOKEN")
        self.blaster_topics_api_url: str = os.environ.get("BLASTER_TOPICS_API_URL")
        self.blaster_cluster_uuid: str = os.environ.get(
            f"{self.env_prefix}_BLASTER_CLUSTER_UUID"
        )
        self.confluent_env_id: str = os.environ.get(
            f"{self.env_prefix}_CONFLUENT_ENV_ID"
        )
        self.confluent_cluster_id: str = os.environ.get(
            f"{self.env_prefix}_CONFLUENT_CLUSTER_ID"
        )

    def __str__(self) -> str:
        """Beautify when printing the class

        :return: str
        """
        output = (
            f"Runtime environment: {self.env_prefix}\n"
            f"Blaster API URL: {self.blaster_topics_api_url}\n"
            f"Blaster Cluster UUID: {self.blaster_cluster_uuid}\n"
            f"Confluent environment id: {self.confluent_env_id}\n"
            f"Confluent cluster id: {self.confluent_cluster_id}"
        )
        return output
