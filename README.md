
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

### Run a down migration

To run `[N]` down migrations, you can use the included shell:
```
make shell
migrate -verbose -path=/migrations -database $POSTGRES_URI down [N]
```
