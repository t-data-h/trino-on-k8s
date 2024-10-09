PostgresDb Container Build
==========================

Created as an alternative to the *hive schema tool* since the 
Postgres container init makes schema and roles injection 
fairly easy. Disadvantage being that we are building the 
container with the admin credentials build in.

## Container initialization configs
The roles file relies on the environment configs for db admin
user and password as a template, so it should be processed 
first, before building the container.
```
source env/devtest.env
cd postgresdb/resources
cat 03-roles.sql.template | envsubst > 03-roles.sql
```

## Building the container

The example here uses *containerd* **nerdctl** to build the 
container, but the command is the same using *docker*.
```sh
nerdctl build . -t repo/postgres:16.4-hive -f Containerfile
```

