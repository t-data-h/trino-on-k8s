
Building a Hive Image
======================

Building a hive image involves installing core hadoop dependencies and any 
additional JDBC Drivers. The provided *Containerfile* shows this and 
allows for the source repository to be provided as a build argument to 
Docker. This is recommended as the Apache site heavily rate-limits connections.

An example build command:

```bash
repo="https://myhostserver/pub"
image_repo="quay.io/$USER/"

docker build . --rm \
--build-arg hadoop_uri=${repo}/hadoop \
--build-arg hive_uri=${repo}/hive \
--build-arg mysql_uri=${repo}/mysql \
--build-arg pgsql_uri=${repo}/pgsql \
-f resource/Containerfile \
-t ${image_repo}/hive:v3.1.3-fenrir-2410.02
```

## Prebuilt Hive Images

|  Name     |  Hive Version / Image Tag       |  Image Base           | Java Version   |  MySql JDBC | Pg JDBC |
|-----------|---------------------------------|-----------------------|----------------|-------------|---------|
| fenrir    | v3.1.3-fenrir-2410.02           | eclipse-temurin       |  17-jre        |    8.4.1    | 42.7.4  |
| mimas     | v3.1.3-mimas-2407.14            | eclipse-temurin       |  17-jre        |    8.4.1    |  n/a    |
| aegir     | v3.1.3-aegir-2405.10            | eclipse-temurina      |  21-jre        |    8.4.0    |  n/a    |

