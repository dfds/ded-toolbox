import logging
import subprocess

import requests
from requests import Response


class Topic:
    """A class that represent a Kafka topic."""

    def __init__(
        self,
        blaster_bearer_token: str,
        blaster_topics_api_url: str,
        blaster_cluster_uuid: str,
        confluent_env_id: str,
        confluent_cluster_id: str,
        level: int = logging.INFO,
    ) -> None:
        """Class constructor.

        :param blaster_bearer_token: A Bearer token which can authenticate with the capability service.
        :param blaster_topics_api_url: The full URL to the Topic API, for instance https://<hostname>/capability/api/v1/topics # noqa 501
        :param blaster_cluster_uuid: The UUID for the Kafka cluster.
        :param confluent_env_id: The Confluent Kafka environment id.
        :param confluent_cluster_id: The Confluent Kafka cluster id.
        :param level: A valid log level from the logging module. Default: logging.INFO
        :type blaster_bearer_token: str
        :type blaster_topics_api_url: str
        :type blaster_cluster_uuid: str
        :type confluent_env_id: str
        :type confluent_cluster_id: str
        :type level: int
        """
        logging.basicConfig(
            format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=level
        )
        self.blaster_bearer_token: str = blaster_bearer_token
        self.blaster_topics_api_url: str = blaster_topics_api_url
        self.blaster_cluster_uuid: str = blaster_cluster_uuid
        self.confluent_env_id = confluent_env_id
        self.confluent_cluster_id = confluent_cluster_id
        self.log_level: int = level

    def _get_cluster_uuid(self) -> str:
        """
        Private method for getting the Blaster cluster ID.

        :return: str
        """
        return self.blaster_cluster_uuid

    def _get_confluent_environment_id(self) -> str:
        """
        Private method for getting the Confluent environment ID.

        :return: str
        """
        return self.confluent_env_id

    def _get_confluent_cluster_id(self) -> str:
        """
        Private method for getting the Confluent cluster ID.

        :return: str
        """
        return self.confluent_cluster_id

    def delete_topics(self, topics: list) -> None:
        """A wrapper method for deleting topics both from the capability service
        and from Confluent cloud.

        :param topics: A list of topics to delete from both Blaster and Confluent
        :type topics: list
        """
        self._delete_blaster_topics(topics)
        self._delete_confluent_topics(topics)

    def _delete_blaster_topics(self, topics: list) -> None:
        """Delete topics from Blaster.

        :param topics: A list of topics to delete from Blaster
        :type topics: list
        """
        headers: dict = {"Authorization": f"Bearer {self.blaster_bearer_token}"}
        uuid: str = self._get_cluster_uuid()
        for topic in topics:
            url: str = f"{self.blaster_topics_api_url}/{topic}?clusterId={uuid}"
            logging.debug(f"Calling {url}")
            response: Response = requests.delete(url=url, headers=headers)
            if response.status_code == 200:
                logging.info(f"Topic {topic} was deleted from capability service.")
            elif response.status_code == 400:
                logging.warning(f"Topic {topic} was not found on capability service.")
            elif response.status_code == 401:
                logging.warning(
                    "You are not authenticated to the capability service. "
                    "Please check the value of your BLASTER_BEARER_TOKEN variable."
                )
            else:
                logging.error(
                    f"The capability service returned status code "
                    f"{response.status_code}"
                )

    def _delete_confluent_topics(self, topics: list) -> None:
        """Delete topics from Confluent cloud using the ccloud tool.

        :param topics: A list of topics to delete from Confluent Kafka
        :type topics: list
        """
        logging.info("Delete topics on Confluent Cloud.")
        subprocess.run(["ccloud", "login"])
        for topic in topics:
            delete_topic_cmd: list = [
                "ccloud",
                "kafka",
                "topic",
                "delete",
                topic,
                "--environment",
                self._get_confluent_environment_id(),
                "--cluster",
                self._get_confluent_cluster_id(),
            ]
            logging.info(f'{" ".join(delete_topic_cmd)}')
            subprocess.run(delete_topic_cmd)
