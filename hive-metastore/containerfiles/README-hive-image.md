
Building a Hive Image
======================

Building a hive image involves installing core hadoop dependencies and any 
additional JDBC Drivers. The provided *hive3/Containerfile* shows this and 
allows for the source repository to be provided as a build argument to 
Docker. This is recommended as the Apache site heavily rate-limits connections.

An example build command:

```bash

repo="https://myhostserver/pub"
image_repo="quay.io/$USER/"

docker build . \
  --build-arg hadoop_uri=${repo}/hadoop \
  --build-arg hive_uri=${repo}/hive \
  --build-arg mysql_uri=${repo}/mysql \
  --rm --network=host \
  -f Containerfile \
  -t ${image_repo}/hive:v3.1.3-mimas-2309.01
```
