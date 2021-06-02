#!/usr/bin/env python3
import logging

from config import Config

from capability_service.kafka import Topic


def main():
    config: Config = Config()

    topic: Topic = Topic(
        blaster_bearer_token=config.blaster_bearer_token,
        blaster_topics_api_url=config.blaster_topics_api_url,
        blaster_cluster_uuid=config.blaster_cluster_uuid,
        confluent_env_id=config.confluent_env_id,
        confluent_cluster_id=config.confluent_cluster_id,
        level=logging.DEBUG,
    )

    # This is where you need to add the topics you want to delete.
    topics_data: list = ["pub.sandbox-aunes-kkpbj.foo", "pub.sandbox-aunes-kkpbj.bar"]

    topic.delete_topics(topics_data)


if __name__ == "__main__":
    main()
