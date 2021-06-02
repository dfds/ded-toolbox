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
        confluent_cluster_id=config.confluent_cluster_id
    )

    topics_data: list = []
    with open("topics.list", "r") as topics_file:
        all_lines: list = topics_file.readlines()
        for line in all_lines:
            topics_data.append(line.strip())  # This is to remove linebreaks
    topic.delete_topics(topics_data)


if __name__ == "__main__":
    main()
