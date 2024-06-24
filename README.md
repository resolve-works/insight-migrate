
# Insight Migrate

Schema migrations for the [postgrest](https://postgrest.org/) based insight API.

### Generate a migration

Replace `[NAME]` with the name of your migration
```
make shell
migrate create -ext sql -dir /migrations -seq [NAME]
```

### Get a psql shell

```
make psql
```

### Run migrations

View the `Makefile` for some examples.
```
make up
```
