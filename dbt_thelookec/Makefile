local-auth:
	gcloud auth application-default login \
	  --scopes=https://www.googleapis.com/auth/bigquery,\
	https://www.googleapis.com/auth/drive.readonly,\
	https://www.googleapis.com/auth/iam.test

setup-project:
	cp profiles.yml.sample profiles.yml

deps:
	poetry run dbt deps

run:
	poetry run dbt run

test:
	poetry run dbt test

# run + test + seed + snapshot
build:
	poetry run dbt build

docs-gen:
	poetry run dbt docs generate

docs-serve: docs-gen
	poetry run dbt docs serve

format:
	poetry run sqlfluff fix

lint:
	poetry run sqlfluff lint
