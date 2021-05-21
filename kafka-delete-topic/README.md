# kafka-delete-topic

This is a tool for deleting Kafka topics from both the capability service, and from Confluent Kafka.

## Usage

### Environment variables

Use the sample_env.txt file to create a .env file, and fill it out with the cluster details. 
The only value that changes at regular intervals is the BLASTER_BEARER_TOKEN. 

You can generate the BLASTER_BEARER_TOKEN using the 'ded' tool.

```bash
ded token -a capsvc
```

### Confluent API keys

In Confluent Kafka generate an API key for each of the two clusters. Save these keys in a secure vault.

### Download ccloud 

```bash
curl -L --http1.1 https://cnfl.io/ccloud-cli | sh -s -- -b /usr/local/bin
```

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
source ~/.virtualenvs/housekeeping/bin/activate
./delete_topics.py
```

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
