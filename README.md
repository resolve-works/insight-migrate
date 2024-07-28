
# Insight Migrate

Schema migrations for the [postgrest](https://postgrest.org/) based insight API.

### Generate a migration

Replace `[NAME]` with the name of your migration
```
make shell
migrate create -ext sql -dir /migrations -seq [NAME]
```

### Run migrations

View the `Makefile` for some examples.
```
make up
```

### Making manual changes

You can start a sql shell with:
```
make psql
```

For example, when you want to change the database migration table:
```
update private.schema_migrations set dirty=False, version='1';
```

