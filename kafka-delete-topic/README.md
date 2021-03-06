# kafka-delete-topic

This is a tool for deleting Kafka topics from both the capability service, and from Confluent Kafka.

## Usage

### Define topics to delete

- Create file topics.list from topics.sample
- Add one topic name per line in topics.sample

### Environment variables

Use the sample_env.txt file to create a .env file, and fill it out with the cluster details.
The only value that changes at regular intervals is the BLASTER_BEARER_TOKEN.

You can generate the BLASTER_BEARER_TOKEN using the 'ded' tool.

```bash
ded token -a capsvc
```

You must also specify a value for KAFKA_ENV in .env file prior to deleting topics. Valid values are DEV and PROD depending on which environment you want to delete topics from. You can only delete topics from one environment at a time.

### Confluent API keys

In Confluent Kafka generate an API key for each of the two clusters. Save these keys in a secure vault.

### Download ccloud

```bash
curl -L --http1.1 https://cnfl.io/ccloud-cli | sh -s -- -b /usr/local/bin
```

For Windows you can either download using curl in Windows Subsystem for Linux, or you can download the
lastest ccloud binary for Windows from <https://s3-us-west-2.amazonaws.com/confluent.cloud/ccloud-cli/archives/latest/ccloud_latest_windows_amd64.zip>. If you do the latter, then unzip the archive, and place the ccloud executable somewhere in your %PATH%.

### Configure ccloud

```bash
ccloud login --save # Login using your normal credentials.
ccloud environment use <env-id-for-dev>
ccloud kafka cluster use <cluster-id-for-dev>
ccloud api-key store --resource <cluster-id-for-dev> # Login using API key for dev
ccloud environment use <env-id-for-prod>
ccloud kafka cluster use <cluster-id-for-prod>
ccloud api-key store --resource <cluster-id-for-prod> # Login using API key for prod
```

### Delete topics

See below in _Development Practices_ how to create the virtual environment.

```bash
cd ce-toolbox/kafka-delete-topic
poetry shell
poetry install
./delete_topics.py
```

## Development practices

Guidelines for developing and testing the scripts.

### Install Poetry

Poetry is a project management tool for Python, which among other things can be used to:

- Create Python projects
- Manage dependencies
- Create virtual environments.

**Linux/macOS:**

```bash
curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -
```

**Windows:**

```ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py -UseBasicParsing).Content | python -
```

More information: <https://python-poetry.org/docs/#installation>

### Virtual environment

```bash
cd ce-toolbox/kafka-delete-topic
poetry shell
poetry install
```

### Testing and code coverage

There are currently no test cases, but this is how testing would look like:

```bash
poetry shell
black *.py
black capability_service/*.py
tox -e flake8
```
