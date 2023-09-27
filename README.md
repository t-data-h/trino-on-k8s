Trino and Hive on Kubernetes
============================

Kustomize and supporting scripts for running TrinoDb (prestoSQL) and 
a Hive 3 Metastore in Kubernetes using S3 object storage and MySQL. 

Author:  Timothy C. Arland  
Email:  <tcarland@gmail.com> <br> 

<br>

## Prerequisites:

- Kubernetes >= 1.21   - Suggested version: 1.23+
- Kustomize >= v4      - Suggested version: [v5.1.1](https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.1.1/kustomize_v5.1.1_linux_amd64.tar.gz)

<br>

## Configuring the Environment

The project depends on a number of environment variables for deploying the 
necessary configuration via the setup script. S3 Credentials are the primary 
variables required, with others having default values if not provided. 
The following table defines the list of variables used by the setup script.

| Environment Variable |    Description   |  Default Setting |
| -------------------- | -------------------------------| ---------------|
| S3_ENDPOINT          |  The S3 endpoint url | http(s)://minio.minio.svc  | 
| S3_ACCESS_KEY        |  The S3 access key   |      |
| S3_SECRET_KEY        |  The S3 secret key  |       |
|  ----------------    |  -------------------------  |  -------------------  |
| TRINO_NAMESPACE      |  Namespace for deploying the components | `trino`  |
| MYSQLD_USER          |  Name of the hive mysql db user  | `root` |
| MYSQLD_ROOT_PASSWORD |  Password for the mysql root user |  *randomized-password* |

<br>

## Building the Hive Metastore Image

The metastore image is based off of Hive version 3.1.3 and can be  
built using the provided *hive3/Containerfile*. 
```
$ cd containerfiles/hive3 && docker build . project/hive:3.1.3
```

## Setup / Configure the Working Directory.

Ensure all variables above are defined and *exported* to the environment.
Passing an argument to the script will show the configuration only and 
can be used to verify the settings.
```
./bin/trino-k8s-setup.sh -e
```

Run the setup script to configure the various config templates.
```
./bin/trino-k8s-setup.sh
```

Copy the env or inherit all vars to the current environment.
``` 
eval $(./bin/trino-k8s-setup.sh)
```

<br>

## Deploy the MySQL Server

Deploy the MySQL Server via Kustomize.
```
kustomize build mysql-server/ | kubectl apply -f -
```

The same Mysql image can be used as a client.
```
docker run -it --rm mysql mysql -hsome.mysql.host -usome-mysql-user -p
```

<br>

## Deploy the Hive Metastore
We deploy the metastore in the same manner, using Kustomize.
```
kustomize build hive-metastore/ | kubectl apply -f -
```

Note this includes the init job *hive-init-schema.yaml* that was 
generated by the setup script.  This job will run the Hive *schematool* 
for provisioning the database. 

<br>

## TrinoDb

Verify the parameter substitution is correct in *trino/base/configmap.yaml* 
as generated by the *trino-k8s-setup.sh* script.

Load the Trino manifests.
```
kustomize build trino/ | kubectl apply -f -
```

Enable external access to the coordinator via *LoadBalancer*, if necessary (the 
trino-coordinator-service may already be set to `type: LoadBalancer`). 

This requires MetalLB or other ELB support in K8s.
```sh
kubectl patch service trino-coordinator-service -n trino -p '{"spec": {"type": "LoadBalancer"}}'
```

Get the external IP of the Trino Coordinator
```
kubectl get svc trino-coordinator-service -n trino --no-headers | awk '{ print $4 }'
```

## Cleanup

The secrets needed for the components are written to **/base/secrets.env for kustomize 
to consume on *build* and should be cleaned up after deployment by running `make clean`.

## Trino CLI

Trino CLI can be acquired [heUnable to resolve action `tcarland/kustomize-build-action`, repository not foundre](https://repo1.maven.org/maven2/io/trino/trino-cli/427/trino-cli-427-executable.jar)
```
trino-cli --server 172.18.0.202:8080 --catalog hive --schema default
```

## Trino JDBC

The JDBC Driver can be acquired from the [Maven Central Repository](https://repo1.maven.org/maven2/io/trino/trino-jdbc/). 
The current deployment has been tested with [trino-427](https://repo1.maven.org/maven2/io/trino/trino-jdbc/427/trino-jdbc-427.jar).
