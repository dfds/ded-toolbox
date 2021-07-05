.PHONY: install run

install:
	poetry install

run:
	saml2aws login --role="arn:aws:iam::738063116313:role/CloudEngineer" --force
	poetry run python violate-limitranges.py

lint:
	poetry run mypy .
	poetry run flake8 .
