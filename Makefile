
uri = "postgresql://insight:insight@localhost:5432/insight?sslmode=disable&x-migrations-table=\"private\".\"schema_migrations\"&x-migrations-table-quoted=1"

build:
	docker build . --tag=insight-migrate

up:
	docker run -e POSTGRES_URI=$(uri) insight-migrate

shell:
	docker run -it -v ./migrations:/migrations -u $$(id -u):$$(id -g) --entrypoint=/bin/sh insight-migrate
