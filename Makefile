
uri = "postgresql://insight:insight@localhost:5432/insight"
migrate_uri = "$(uri)?sslmode=disable&x-migrations-table=\"private\".\"schema_migrations\"&x-migrations-table-quoted=1"

pg_format:
	pg_format ./migrations/*.sql -i

up:
	docker run --network=host -v ./migrations:/migrations -e POSTGRES_URI=$(migrate_uri) ghcr.io/followthemoney/insight-migrate

shell:
	docker run -it -v ./migrations:/migrations -u $$(id -u):$$(id -g) insight-migrate /bin/sh

dump_schema:
	pg_dump --schema-only $(uri)
