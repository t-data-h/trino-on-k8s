Trino and Hive on Kubernetes
============================

Kustomize and supporting scripts for running Trinodb (prestosql) and 
a Hive 3 Metastore in Kubernetes using S3 object storage and MySQL. 


Author:  Timothy C. Arland  
Email:   <tcarland@gmail.com>, <tarland@trace3.com>  <br> 

<br>

## Prerequisites:

- Kubernetes >= 1.18  Suggested minimum version: 1.19
- Kustomize >= v3.4.0  - Suggested version: [v3.10.0](https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.10.0/kustomize_v3.10.0_linux_amd64.tar.gz)
- Bash >= v4.x
- Docker >= 19.03  

<br>

## Configuring the Environment

The project depends on a number of environment variables for deploying the 
necessary configuration via a setup script. S3 Credentials are the primary 
variables that are required, with others having default values if not provided. 
The following table defines the list of variables used by the setup script.

| Environment Variable |    Description   |  Default Setting |
| -------------------- | -------------------------------| ---------------|
| S3_ENDPOINT          |  The S3 endpoint url |       | 
| S3_ACCESS_KEY        |  The S3 access key  |     |
| S3_SECRET_KEY        |  The S3 secret key |       |
|  ----------------    |  ------------------------  |  -------------------  |
| TRINO_NAMESPACE      |  Namespace for deploying the components | `trino`  |
| MYSQLD_USER          |  Name of the hive mysql db user  | `root` |
| MYSQLD_ROOT_PASSWORD |  Password for the mysql root user |  *randomized-password* |

<br>

## Building the Hive Metastore image

The metastore image is based off of Hive version 3.1.2 and can be  
built using the provided *hive3/Dockerfile*. 
```
$ cd docker/hive3 && ../../bin/docker_build.sh myrepo/hive:3.1.2
```

To use a private registry, set the var DOCKER_REPOSITORY first.
```sh
export DOCKER_REPOSITORY="gcr.io/myproject"
../bin/docker_build.sh myrepo/hive:3.1.2
docker push ${DOCKER_REGISTRY}/myrepo/hive:3.1.2
```

## Setup / configure the local repository.

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

## Trino (trino-363)

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

## Trino CLI

Trino CLI can be acquired (here)[https://repo1.maven.org/maven2/io/trino/trino-cli/363/trino-cli-363-executable.jar]
```
trino --server 172.19.0.203:8080 --catalog hive --schema default
```

## Trino JDBC

The JDBC Driver can be acquired from the [Maven Central Repository](https://repo1.maven.org/maven2/io/trino/trino-jdbc/). The current deployment has been tested with [trino-363](https://repo1.maven.org/maven2/io/trino/trino-jdbc/363/trino-jdbc-363.jar).

<br>

---

<br>

### Creating ConfigMaps or Secrets example
```sh
( cat conf/metastore-site.xml.template | envsubst > metastore-site.xml )
( cat conf/core-site.xml.template | envsubst > core-site.xml )

( kubectl create configmap hive-metastore-cm \
  --dry-run \
  --namespace $TRINO_NAMESPACE \
  --from-file=metastore-site.xml \
  --from-file=core-site.xml -o yaml > hive-metastore-cm.yaml )

( rm -f metastore-site.xml core-site.xml )

( kubectl create secret generic hive-secrets \
  --from-literal=access-key="$S3_ACCESS_KEY" \
  --from-literal=secret-key="$S3_SECRET_KEY" \
  -n $TRINO_NAMESPACE )
```

testing:
```sh
kubectl run --namespace $TRINO_NAMESPACE curl --image=radial/busyboxplus:curl -i --tty 
```

