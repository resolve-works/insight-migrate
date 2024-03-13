FROM migrate/migrate:v4.17.0

COPY ./migrations /migrations

ENTRYPOINT ["/bin/sh", "-c", "migrate -path=/migrations -database $POSTGRES_URI up"]
