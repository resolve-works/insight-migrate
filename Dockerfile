FROM migrate/migrate:v4.18.2

COPY ./migrations /migrations

ENTRYPOINT []
CMD migrate -verbose -path=/migrations -database $POSTGRES_URI up
