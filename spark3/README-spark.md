Spark3 on Kubernetes
====================

The provided Dockerfile is for building a custom Spark Image which includes the 
Hive3 libraries. Spark uses `builtin` libraries for Hive 2.3.7 by default, but 
can be instructed to use Hive3 using the *spark.sql.hive.metastore.jars* options.
```
[ spark-submit ...]
   --conf spark.hadoop.metastore.catalog.default=hive \
   --conf spark.sql.hive.metastore.dir=s3a://hive/warehouse \
   --conf spark.sql.hive.metastore.version=3.1.2 \
   --conf spark.sql.hive.metastore.jars=path \
   --conf spark.sql.hive.metastore.jars.path=file:///opt/hive/lib/*.jar \
   --conf spark.hadoop.hive.metastore.uris=thrift://hive-metastore.trino.svc.cluster.local:9083
```

Note that a Java8 container is still required for Spark3 pulling in Hive libs, or Java
introspection errors will occur with the HiveMetastoreClient.
