import logging
import subprocess

import requests
from confluent_kafka.admin import AdminClient
from requests import Response


class InvalidKafkaCluster(Exception):
    """Exception raised if trying to use a non-existing Kafka cluster."""

    def __init__(self, environment, message="Environment is not a valid Kafka cluster. Use 'dev' or 'prod'"):
        self.environment = environment
        self.message = message
        super().__init__(self.message)

    def __str__(self):
        return f'{self.environment} -> {self.message}'


class Topic:
    """A class that represent a Kafka topic."""

    def __init__(self,
                 blaster_bearer_token: str,
                 blaster_topics_api_url: str,
                 blaster_cluster_uuid_prod: str,
                 blaster_cluster_uuid_dev: str,
                 confluent_env_id_prod: str,
                 confluent_env_id_dev: str,
                 confluent_cluster_id_prod: str,
                 confluent_cluster_id_dev: str,
                 level: int = logging.INFO) -> None:
        """Class constructor.
        :param blaster_bearer_token: A Bearer token which can authenticate with the capability service.
        :param blaster_topics_api_url: The full URL to the Topic API, for instance https://<hostname>/capability/api/v1/topics # noqa 501
        :param blaster_cluster_uuid_prod: The UUID for the Kafka production cluster.
        :param blaster_cluster_uuid_dev: The UUID for the Kafka development cluster.
        :param confluent_env_id_prod: A Confluent Kafka environment id for production.
        :param confluent_env_id_dev: A Confluent Kafka environment id for development.
        :param confluent_cluster_id_prod: The ID for the Confluent Kafka production cluster.
        :param confluent_cluster_id_dev: The ID for the Confluent Kafka development cluster.
        :param level: A valid log level from the logging module. Default: logging.INFO
        :type blaster_bearer_token: str
        :type blaster_topics_api_url: str
        :type blaster_cluster_uuid_prod: str
        :type blaster_cluster_uuid_dev: str
        :type confluent_env_id_prod: str
        :type confluent_env_id_dev: str
        :type confluent_cluster_id_prod: str
        :type confluent_cluster_id_dev: str
        :type level: int
        """
        logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=level)
        self.blaster_bearer_token: str = blaster_bearer_token
        self.blaster_topics_api_url: str = blaster_topics_api_url
        self.blaster_cluster_uuid_prod: str = blaster_cluster_uuid_prod
        self.blaster_cluster_uuid_dev: str = blaster_cluster_uuid_dev
        self.confluent_env_id_prod = confluent_env_id_prod
        self.confluent_env_id_dev = confluent_env_id_dev
        self.confluent_cluster_id_prod = confluent_cluster_id_prod
        self.confluent_cluster_id_dev = confluent_cluster_id_dev
        self.log_level: int = level

    def _get_cluster_uuid(self, environment_name: str) -> str:
        """
        :param environment_name: A valid Kafka environment name. Currently only dev and prod clusters exist.
        :type environment_name: str
        :return: str
        """
        if environment_name.upper() in ['PROD', 'PRODUCTION']:
            return self.blaster_cluster_uuid_prod
        elif environment_name.upper() in ['DEV', 'DEVELOP', 'DEVELOPMENT']:
            return self.blaster_cluster_uuid_dev
        else:
            raise InvalidKafkaCluster(environment_name)

    def _get_confluent_environment_id(self, environment_name: str) -> str:
        """
        :param environment_name: A valid Confluence Kafka environment name. Currently only dev and prod clusters exist.
        :type environment_name: str
        :return: str
        """
        if environment_name.upper() in ['PROD', 'PRODUCTION']:
            return self.confluent_env_id_prod
        elif environment_name.upper() in ['DEV', 'DEVELOP', 'DEVELOPMENT']:
            return self.confluent_env_id_dev
        else:
            raise InvalidKafkaCluster(environment_name)

    def _get_confluent_cluster_id(self, environment_name: str) -> str:
        """
        :param environment_name: A valid Confluence Kafka environment name. Currently only dev and prod clusters exist.
        :type environment_name: str
        :return: str
        """
        if environment_name.upper() in ['PROD', 'PRODUCTION']:
            return self.confluent_cluster_id_prod
        elif environment_name.upper() in ['DEV', 'DEVELOP', 'DEVELOPMENT']:
            return self.confluent_cluster_id_dev
        else:
            raise InvalidKafkaCluster(environment_name)

    def delete_topics(self, topics: dict) -> None:
        """A wrapper method for deleting topics both from the capability service and from Confluent cloud
        :param topics: A dictionary of topics and uuids (from the capability service)
        :type topics: dict
        """
        self._delete_blaster_topics(topics)
        self._delete_confluent_topics(topics)

    def _delete_blaster_topics(self, topics: dict) -> None:
        headers: dict = {'Authorization': f'Bearer {self.blaster_bearer_token}'}
        for topic_name, environment_name in topics.items():
            uuid: str = self._get_cluster_uuid(environment_name)
            url: str = f'{self.blaster_topics_api_url}/{topic_name}?clusterId={uuid}'
            logging.debug(f'Calling {url}')
            response: Response = requests.delete(url=url, headers=headers)
            if response.status_code == 200:
                logging.info(f'Topic {topic_name} was deleted from capability service.')
            elif response.status_code == 400:
                logging.warning(f'Topic {topic_name} was not found on capability service.')
            elif response.status_code == 401:
                logging.warning('You are not authenticated to the capability service. '
                                'Please check the value of your BLASTER_BEARER_TOKEN')
            else:
                logging.error(f'The capability service returned status code {response.status_code}')

    def _delete_confluent_topics(this, topics: dict) -> None:
        """Delete topics from Confluent cloud using the ccloud tool.
        :param topics: A dictionary of topics and uuids (from the capability service)
        :type topics: dict
        """
        logging.info('Delete topics on Confluent Cloud.')
        subprocess.run(['ccloud', 'login'])
        for topic_name, environment_name in topics.items():
            env_id: str = this._get_confluent_environment_id(environment_name)
            cluster_id: str = this._get_confluent_cluster_id(environment_name)
            delete_topic_cmd: list = ['ccloud', 'kafka', 'topic', 'delete',
                                      topic_name, '--environment', env_id, '--cluster', cluster_id]
            logging.info(f'{" ".join(delete_topic_cmd)}')
            subprocess.run(delete_topic_cmd)

    @staticmethod
    def _delete_confluent_topics_using_broker(topics: dict, config: dict) -> None:
        """Delete topics from Confluent cloud using the confluent Python API.
        :param topics: A dictionary of topics and uuids (from the capability service)
        :type topics: dict
        """
        admin_client: AdminClient = AdminClient(config)
        futures: dict = admin_client.delete_topics(list(topics.keys()), operation_timeout=30)

        for topic_name, future in futures.items():
            try:
                future.result()
                logging.info(f'Topic {topic_name} deleted')
            except Exception as e:
                logging.error(f'Failed to delete topic {topic_name}: {e}')
