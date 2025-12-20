
Building a Hive Image
======================

Building a hive image involves installing core hadoop dependencies and any 
additional JDBC Drivers. The provided *Containerfile* shows this and 
allows for the source repository to be provided as a build argument to 
Docker. This is recommended as the Apache site heavily rate-limits connections.

An example build command:

```bash
repo="https://$HOSTNAME/pub"
image_repo="quay.io/$USER/"

#--build-arg mysql_uri=${repo}/mysql \
docker build . --rm \
  --build-arg hadoop_uri=${repo}/hadoop \
  --build-arg hive_uri=${repo}/hive \
  --build-arg pgsql_uri=${repo}/pgsql \
  --build-arg aws_sdk_uri=${repo}/aws-java-sdk-bundle \
  -f Containerfile \
  -t ${image_repo}/hive:v3.1.3-aegir-2512.20
```

## Prebuilt Hive Images

|  Name   |  Version / Image Tag  |  Image Base     | Java Ver | AWS SDK  | Hadoop  | Pg JDBC |
|---------|-----------------------|-----------------|----------|----------|---------|---------|
| aegir   | v3.1.3-aegir-2512.20  | zulu-openjdk    |  21-jdk  | 2.40.12  |  3.4.2  | 42.7.5  |
| skoll   | v3.1.3-skoll-2510.30  | zulu-openjdk    |  21-jdk  | 2.32.20  |  3.4.1  | 42.7.4  |
| ymir    | v3.1.3-ymir-2508.14   | eclipse-temurin |  17-jre  | 2.32.20  |  3.4.1  | 42.7.4  |
| fenrir  | v3.1.3-fenrir-2506.10 | eclipse-temurin |  17-jre  | 1.12.782 |  3.3.4  | 42.7.4  |
| mimas   | v3.1.3-mimas-2504.15  | eclipse-temurin |  17-jre  | 1.12.780 |  3.3.4  | 42.7.4  |
