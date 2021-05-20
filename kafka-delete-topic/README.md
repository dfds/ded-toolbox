# kafka-delete-topic

This is a tool for deleting Kafka topics from both the capability service, and from Confluent Kafka.

## Development practices

Guidelines for developing and testing the scripts.

### Virtual environment

```bash
mkdir -p ~/.virtualenvs
virtualenv ~/.virtualenvs/housekeeping
source ~/.virtualenvs/housekeeping/bin/activate
python3 -m pip -r requirements_dev.txt
```

### Testing and code coverage

There are currently no test cases, but this is how testing would look like:

```bash
tox -e flake8
tox
```

## Usage

### Delete topics

```bash
source ~/.virtualenvs/housekeeping/bin/activate
export BLASTER_BEARER_TOKEN=<REDACTED>
./delete_topics.py
```
