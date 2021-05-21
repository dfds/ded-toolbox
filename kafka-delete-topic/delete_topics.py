#!/usr/bin/env python3
import logging
import os

from dotenv import load_dotenv

from capability_service.kafka import Topic


def main():
    load_dotenv()

    blaster_bearer_token: str = os.environ.get('BLASTER_BEARER_TOKEN')
    blaster_topics_api_url: str = os.environ.get('BLASTER_TOPICS_API_URL')
    blaster_cluster_uuid_prod: str = os.environ.get('BLASTER_CLUSTER_UUID_PROD')
    blaster_cluster_uuid_dev: str = os.environ.get('BLASTER_CLUSTER_UUID_DEV')

    confluent_env_id_prod: str = os.environ.get('CONFLUENT_ENV_ID_PROD')
    confluent_env_id_dev: str = os.environ.get('CONFLUENT_ENV_ID_DEV')
    confluent_cluster_id_prod: str = os.environ.get('CONFLUENT_CLUSTER_ID_PROD')
    confluent_cluster_id_dev: str = os.environ.get('CONFLUENT_CLUSTER_ID_DEV')

    topic: Topic = Topic(blaster_bearer_token=blaster_bearer_token,
                         blaster_topics_api_url=blaster_topics_api_url,
                         blaster_cluster_uuid_prod=blaster_cluster_uuid_prod,
                         blaster_cluster_uuid_dev=blaster_cluster_uuid_dev,
                         confluent_env_id_prod=confluent_env_id_prod,
                         confluent_env_id_dev=confluent_env_id_dev,
                         confluent_cluster_id_prod=confluent_cluster_id_prod,
                         confluent_cluster_id_dev=confluent_cluster_id_dev,
                         level=logging.DEBUG)

    # This is where you need to add the topics you want to delete.
    topics_data: dict = {'pub.sandbox-aunes-kkpbj.foo': 'dev',
                         'pub.sandbox-aunes-kkpbj.bar': 'dev'}

    topic.delete_topics(topics_data)


if __name__ == "__main__":
    main()
