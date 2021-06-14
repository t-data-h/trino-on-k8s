Hive on Kubernetes
===================

Kustomize and supporting scripts for running a Hive Metastore in Kubernetes using S3 
and MySQL. 


## Deploying the Hive Metastore to K8s

The project depends on a number of environment variables for deploying the 
necessary configuration via a setup script. S3 Credentials are the primary 
vars that are required, with others having default values if not provided.  The
following table defines the list of variables used by the `./bin/setup.sh` script.

| Environment Variable |    Description   |  Default Setting |
| -------------------- | -------------------------------| ---------------|
| S3_ENDPOINT          |  The S3 endpoint url |  n/a  |
| S3_ACCESS_KEY        |  Corresponding access_key for S3 access | n/a |
| S3_SECRET_KEY        |  The S3 secret key |  n/a  |
| HIVE_NAMESPACE       |  Namespace for deploying the metastore | `hive-metastore`  |
| MYSQLD_USER          |  Name of the hive mysql db user  | `hive` |
| MYSQLD_ROOT_PASSWORD |  Password for the mysql root user |  *randomized password* |




