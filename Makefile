
uri = "postgresql://insight:insight@postgres:5432/insight?sslmode=disable&x-migrations-table=\"private\".\"schema_migrations\"&x-migrations-table-quoted=1"

build:
	docker build . --tag=insight-migrate

up:
	docker run --network=insight_default -e POSTGRES_URI=$(uri) insight-migrate

shell:
	docker run -it --network=insight_default --entrypoint=/bin/sh insight-migrate
