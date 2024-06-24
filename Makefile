
uri = "postgresql://insight:insight@localhost:5432/insight"
migrate_uri = "$(uri)?sslmode=disable&x-migrations-table=\"private\".\"schema_migrations\"&x-migrations-table-quoted=1"

psql:
	docker run -it --network host postgres psql $(uri)

# TODO - containerize
#pg_format:
	#pg_format ./migrations/*.sql -i

up:
	docker run --network=host \
		-v ./migrations:/migrations \
		-e POSTGRES_URI=$(migrate_uri) \
		ghcr.io/followthemoney/insight-migrate

down:
	docker run --network=host \
		-v ./migrations:/migrations \
		-e POSTGRES_URI=$(migrate_uri) \
		ghcr.io/followthemoney/insight-migrate \
		/bin/sh -c 'migrate -verbose -path=/migrations -database $$POSTGRES_URI down 1'

shell:
	docker run -it --network=host \
		-v ./migrations:/migrations \
		-e POSTGRES_URI=$(migrate_uri) \
		-u $$(id -u):$$(id -g) \
		ghcr.io/followthemoney/insight-migrate \
		/bin/sh

dump_schema:
	docker run -it --network=host postgres pg_dump --schema-only $(uri)
