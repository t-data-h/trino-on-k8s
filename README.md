Trino and Hive on Kubernetes
============================

Kustomize and supporting scripts for running Trinodb (prestosql) and 
a Hive Metastore in Kubernetes using S3 object storage and MySQL. 


Author:  Timothy C. Arland <tcarland@gmail.com>  <br>
Version: v21.06

<br>

Prerequisites:
- Kustomize v3.2.0
- Bash >= v4.x
- Docker 20.10+

<br>

## Configuring the environment

The project depends on a number of environment variables for deploying the 
necessary configuration via a setup script. S3 Credentials are the primary 
varables that are required, with others having default values if not provided.  
The following table defines the list of variables used by the `./bin/setup.sh` 
script.

| Environment Variable |    Description   |  Default Setting |
| -------------------- | -------------------------------| ---------------|
| S3_ENDPOINT          |  The S3 endpoint url |       |
| S3_ACCESS_KEY        |  Corresponding access_key for S3 access |     |
| S3_SECRET_KEY        |  The S3 secret key |       |
|  ----------------    |  ------------------------  |  -------------------  |
| HIVE_NAMESPACE       |  Namespace for deploying the metastore | `hive-metastore`  |
| TRINO_NAMESPACE      |  Namespace for deploying Trino (prestosql) | `trino`  |
| MYSQLD_USER          |  Name of the hive mysql db user  | `root` |
| MYSQLD_ROOT_PASSWORD |  Password for the mysql root user |  *randomized-password* |

<br>

## Building the Metastore image

The *hive-metastore* image can be built using the provided *Dockerfile*. 
```
$ make docker 
  # or run the script directly
$ ./bin/docker_build.sh myrepo/hive-metastore:3.0.0
```

To use a private registry, set the var DOCKER_REPOSITORY first.
```sh
export DOCKER_REPOSITORY="comet.charltontechnology.net"
./bin/docker_build.sh myrepo/hive-metastore:3.0.0
docker push comet.charltontechnology.net/myrepo/hive-metastore:3.0.0
```

## Configure the Environment

Ensure all variables above are defined and *exported* to the environment.
Run the setup script to configure the various config templates.
```
./bin/setup.sh
```

A shortcut to inheriting all vars to the current environment:
```
eval $(./bin/setup.sh)
```

## Deply the MySQL Server

Deploy the MySQL Server via Kustomize.
```sh
kustomize build mysql-server/ | kubectl apply -f -
kubectl create -f hive-init-schema.yaml
# verify Job completes successfully
kubectl delete -f hive-init-schema.yaml -n $HIVE_NAMESPACE
```

## Deploy the Hive Metastore
We deploy the metastore using Kustomize in the same way.
```sh
kustomize build hive-metastore/ kubectl apply -f -
```


## Trino

Verify the parameter substitution is correct in *trino/base/configmap.yaml* as 
generated by the *setup.sh* script.

Load the Trino manifests.
```
kustomize build trino/ | kubectl apply -f -
```

Enable external access to the coordinator via *LoadBalancer*. This requires MetalLB or 
other ELB support in K8s.
```
kubectl patch service trino-coordinator-service -n trino -p '{"spec": {"type": "LoadBalancer"}}'
```

## Trino CLI

Trino CLI can be acquired (here)[https://repo1.maven.org/maven2/io/trino/trino-cli/358/trino-cli-358-executable.jar]
```
trino --server 172.19.0.203:8080 --catalog hive --schema default
```

<br>

---

<br>

### Creating ConfigMaps or Secrets example
```
( cat conf/metastore-site.xml.template | envsubst > metastore-site.xml )
( cat conf/core-site.xml.template | envsubst > core-site.xml )

( kubectl create configmap hive-metastore-cm \
  --dry-run \
  --namespace $HIVE_NS \
  --from-file=metastore-site.xml \
  --from-file=core-site.xml -o yaml > hive-metastore-cm.yaml )

( rm -f metastore-site.xml core-site.xml )

( kubectl create secret generic hive-secrets \
  --from-literal=access-key="$S3_ACCESS_KEY" \
  --from-literal=secret-key="$S3_SECRET_KEY" \
  -n $HIVE_NS )
```

testing:
```
kubectl run --namespace hive-metastore curl --image=radial/busyboxplus:curl -i --tty 
```