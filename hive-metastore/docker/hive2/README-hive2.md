
Running Hive2 Metastore on Kubernetes
=====================================

Hive 2.3.9 is the lastest Hive 2 release, and is the compatible metastore 
for use with Spark 2 or 3.

## Building the Hive image

Use the wrapper script for docker build.
```
cd hive2
../bin/docker_build.sh gcr.io/project/hive:2.3.9
```

Or build the image for a private repository
```
DOCKER_REPOSITORY="harbor.pvtdomain.com" ../bin/docker_build.sh tarland/hive:2.3.9
```

## Hive2 Schema Initialization

Schema initialization works differently in Hive2 (schematool does not accept 
the jdbc -url parameter).  The *schematool* requires a *hive-site.xml* with 
`hive.metastore.uris` configured. We mount the config volumes to the init Job 
just as we do the Metastore Deployment. The init schema job template is used 
to create the file for Hive3, so the following should be adjusted accordingly
and placed as `hive-metastore/base/hive-init-schema.yaml`.
```yaml
---
apiVersion: batch/v1
kind: Job
metadata:
  name: hive-init-schema
  namespace: ${TRINO_NAMESPACE}
spec:
  template:
    spec:
      containers:
      - name: hive-schematool
        image: tarland/hive:2.3.9
        volumeMounts:
        - name: metastore-cfg-vol
          mountPath: /opt/hive/conf/hive-site.xml
          subPath: metastore-site.xml
        - name: metastore-cfg-vol
          mountPath: /opt/hadoop/etc/hadoop/core-site.xml
          subPath: core-site.xml
        command: ["/opt/hive/bin/schematool"]
        args: ["-dbType", "mysql", "-initSchema", "-userName", "root", "-passWord", "${MYSQLD_ROOT_PASSWORD}"]
      restartPolicy: Never
      volumes:
        - name: metastore-cfg-vol
          configMap:
            name: hive-metastore-cm
  backoffLimit: 3
  ```

However, *schematool* does **not** create the database or schema name first, which 
normally is resolved by using the JDBC driver.  For Hive2, we need to first connect 
to the mysql-server and run `CREATE DATABASE metastore_db` manually.
