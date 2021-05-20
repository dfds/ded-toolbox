import logging
import os

import requests
from dotenv import load_dotenv
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
                 confluent_api_token_prod: str,
                 confluent_api_token_dev: str,
                 confluent_cluster_id_prod: str,
                 confluent_cluster_id_dev: str,
                 level: int = logging.INFO) -> None:
        """Class constructor.
        :param blaster_bearer_token: A Bearer token which can authenticate with the capability service.
        :param blaster_topics_api_url: The full URL to the Topic API, for instance https://<hostname>/capability/api/v1/topics # noqa 501
        :param blaster_cluster_uuid_prod: The UUID for the Kafka production cluster.
        :param blaster_cluster_uuid_dev: The UUID for the Kafka development cluster.
        :param confluent_api_token_prod: A Confluent Kafka API token for the production cluster.
        :param confluent_api_token_dev: A Confluent Kafka API token for the development cluster.
        :param confluent_cluster_id_prod: The ID for the Confluent Kafka production cluster.
        :param confluent_cluster_id_dev: The ID for the Confluent Kafka development cluster.
        :param level: A valid log level from the logging module. Default: logging.INFO
        :type blaster_bearer_token: str
        :type blaster_topics_api_url: str
        :type blaster_cluster_uuid_prod: str
        :type blaster_cluster_uuid_dev: str
        :type confluent_api_token_prod: str
        :type confluent_api_token_dev: str
        :type confluent_cluster_id_prod: str
        :type confluent_cluster_id_dev: str
        :type level: int
        """
        logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=level)
        self.blaster_bearer_token: str = blaster_bearer_token
        self.blaster_topics_api_url: str = blaster_topics_api_url
        self.blaster_cluster_uuid_prod: str = blaster_cluster_uuid_prod
        self.blaster_cluster_uuid_dev: str = blaster_cluster_uuid_dev
        self.confluent_api_token_prod = confluent_api_token_prod
        self.confluent_api_token_dev = confluent_api_token_dev
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
        # self._delete_blaster_topics(topics)
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

    @staticmethod
    def _delete_confluent_topics(topics: dict) -> None:
        """Delete topics from Confluent cloud using the ccloud tool.
        :param topics: A dictionary of topics and uuids (from the capability service)
        :type topics: dict
        """
        logging.warning('Deleting topics from Confluent Cloud is not yet implemented.')

    @staticmethod
    def _delete_confluent_topics_using_broker(topics: dict, broker: str) -> None:
        """Delete topics from Confluent cloud using the confluent Python API.
        :param topics: A dictionary of topics and uuids (from the capability service)
        :type topics: dict

        TODO: Not currently used, because I need to figure out what to pass in as the value for broker.
        """
        logging.warning('Deleting topics from Confluent Cloud is not yet implemented.')
        admin_client: AdminClient = AdminClient({'bootstrap.servers': broker})
        futures: dict = admin_client.delete_topics(list(topics.keys()), operation_timeout=30)

        for topic_name, future in futures.items():
            try:
                future.result()
                logging.info(f'Topic {topic_name} deleted')
            except Exception as e:
                logging.error(f'Failed to delete topic {topic_name}: {e}')


if __name__ == "__main__":
    load_dotenv()

    blaster_bearer_token: str = os.environ.get('BLASTER_BEARER_TOKEN')
    blaster_topics_api_url: str = os.environ.get('BLASTER_TOPICS_API_URL')
    blaster_cluster_uuid_prod: str = os.environ.get('BLASTER_CLUSTER_UUID_PROD')
    blaster_cluster_uuid_dev: str = os.environ.get('BLASTER_CLUSTER_UUID_DEV')

    confluent_api_token_prod: str = os.environ.get('CONFLUENT_API_TOKEN_PROD')
    confluent_api_token_dev: str = os.environ.get('CONFLUENT_API_TOKEN_DEV')
    confluent_cluster_id_prod: str = os.environ.get('CONFLUENT_CLUSTER_ID_PROD')
    confluent_cluster_id_dev: str = os.environ.get('CONFLUENT_CLUSTER_ID_DEV')

    topic: Topic = Topic(blaster_bearer_token=blaster_bearer_token,
                         blaster_topics_api_url=blaster_topics_api_url,
                         blaster_cluster_uuid_prod=blaster_cluster_uuid_prod,
                         blaster_cluster_uuid_dev=blaster_cluster_uuid_dev,
                         confluent_api_token_prod=confluent_api_token_prod,
                         confluent_api_token_dev=confluent_api_token_dev,
                         confluent_cluster_id_prod=confluent_cluster_id_prod,
                         confluent_cluster_id_dev=confluent_cluster_id_dev,
                         level=logging.DEBUG)
    topics_data: dict = {'pub.sandbox-aunes-kkpbj.foo': 'dev',
                         'pub.sandbox-aunes-kkpbj.bar': 'dev'}

    topic.delete_topics(topics_data)
