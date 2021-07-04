Spark3 on Kubernetes
====================

The provided Dockerfile is for building a custom Spark Image which includes 
the Hive3 libraries. Spark uses `builtin` libraries for Hive 2.3.7 by default, 
but can be configured to use Hive3 using the *spark.sql.hive.metastore.jars* options.
```
   --conf spark.hadoop.metastore.catalog.default=hive \
   --conf spark.sql.hive.metastore.dir=s3a://hive/warehouse \
   --conf spark.sql.hive.metastore.version=3.1.2 \
   --conf spark.sql.hive.metastore.jars=path \
   --conf spark.sql.hive.metastore.jars.path=file:///opt/hive/lib/*.jar \
   --conf spark.hadoop.hive.metastore.uris=thrift://hive-metastore.${namespace}.svc.cluster.local:9083
```

Note that a Java8 container is still required for Spark3 pulling in Hive libs, or Java
introspection errors will occur with the HiveMetastoreClient.

## Building the Spark image.

Typically the spark image is built using Spark's *docker-image-tool.sh* script, 
which is essentially the same as the following:
```sh
cd /opt/spark   # 3.1.2
export SPARK_HOME=/opt/spark
docker build -t myrepo/spark:3.1.2 -f kubernetes/dockerfiles/spark/Dockerfile .
```
We don't cover building an appropriate spark distribution, but one can 
grab the binary distribution with Hadoop 3.2 dependencies and add other 
dependencies to $SPARK_HOME/jars/ (eg. odbc/jdbc drivers, aws/s3 libs, gcs libs, etc).
Use the custom Dockerfile in place of the distribution file.
Note the image tool from spark assumes an image name of 'spark'. 
```
cd /opt/spark
./bin/docker-image-tool.sh -r gcr.io/project -t 3.1.2 build
[...]
Successfully built f07cd00df877
Successfully tagged gcr.io/project/spark:3.1.2
```
