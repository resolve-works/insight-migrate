
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
		ghcr.io/resolve-works/insight-migrate
	docker run -it --network host postgres psql $(uri) -c "NOTIFY pgrst, 'reload schema';"

up_one: 
	docker run --network=host \
		-v ./migrations:/migrations \
		-e POSTGRES_URI=$(migrate_uri) \
		ghcr.io/resolve-works/insight-migrate \
		/bin/sh -c 'migrate -verbose -path=/migrations -database $$POSTGRES_URI up 1'
	docker run -it --network host postgres psql $(uri) -c "NOTIFY pgrst, 'reload schema';"

down_one:
	docker run --network=host \
		-v ./migrations:/migrations \
		-e POSTGRES_URI=$(migrate_uri) \
		ghcr.io/resolve-works/insight-migrate \
		/bin/sh -c 'migrate -verbose -path=/migrations -database $$POSTGRES_URI down 1'
	docker run -it --network host postgres psql $(uri) -c "NOTIFY pgrst, 'reload schema';"

shell:
	docker run -it --network=host \
		-v ./migrations:/migrations \
		-e POSTGRES_URI=$(migrate_uri) \
		-u $$(id -u):$$(id -g) \
		ghcr.io/resolve-works/insight-migrate \
		/bin/sh

dump_schema:
	docker run -it --network=host postgres pg_dump --schema-only $(uri)

dump_db:
	docker run -it --network=host postgres pg_dump $(uri)
