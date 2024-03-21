FROM migrate/migrate:v4.17.0

COPY ./migrations /migrations

ENTRYPOINT []
CMD migrate -verbose -path=/migrations -database $POSTGRES_URI up
