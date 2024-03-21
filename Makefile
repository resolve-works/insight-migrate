
uri = "postgresql://insight:insight@localhost:5432/insight?sslmode=disable&x-migrations-table=\"private\".\"schema_migrations\"&x-migrations-table-quoted=1"

pg_format:
	pg_format ./migrations/*.sql -i

build:
	docker build . --tag=insight-migrate

up:
	docker run --network=host -v ./migrations:/migrations -e POSTGRES_URI=$(uri) insight-migrate

shell:
	docker run -it -v ./migrations:/migrations -u $$(id -u):$$(id -g) insight-migrate /bin/sh
