Trino and Hive on Kubernetes
============================

Kustomize and supporting scripts for running Trinodb (prestosql) and 
a Hive Metastore in Kubernetes using S3 and MySQL. 


## Deploying the Hive Metastore to K8s

The project depends on a number of environment variables for deploying the 
necessary configuration via a setup script. S3 Credentials are the primary 
vars that are required, with others having default values if not provided.  The
following table defines the list of variables used by the `./bin/setup.sh` script.

| Environment Variable |    Description   |  Default Setting |
| -------------------- | -------------------------------| ---------------|
| S3_ENDPOINT          |  The S3 endpoint url |  ""  |
| S3_ACCESS_KEY        |  Corresponding access_key for S3 access | "" |
| S3_SECRET_KEY        |  The S3 secret key |  ""  |
| HIVE_NAMESPACE       |  Namespace for deploying the metastore | `hive-metastore`  |
| TRINO_NAMESPACE      |  Namespace for deploying Trino (prestosql) | `trino`  |
| MYSQLD_USER          |  Name of the hive mysql db user  | `root` |
| MYSQLD_ROOT_PASSWORD |  Password for the mysql root user |  *randomized-password* |


## Initialization

Run the setup script to configure the environment and various yaml templates
```
./bin/setup.sh
```

Provision the MySQL Server.
```sh
kustomize build mysql-server/ | kubectl apply -f -
kubectl create -f hive-init-schema.yaml
kubectl delete -f hive-init-schema.yaml -n $HIVE_NAMESPACE
```

Load the metastore
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

### Creating ConfigMaps or Secrets
```
( cat $metacfg | envsubst > $metatmp )
( cat $corecfg | envsubst > $coretmp )

( kubectl create configmap hive-metastore-cm \
  --dry-run \
  --namespace $HIVE_NS \
  --from-file=$metatmp \
  --from-file=$coretmp -o yaml > hive-metastore-cm.yaml )

( rm -f $metatmp $coretmp )

( kubectl create secret generic hive-secrets \
  --from-literal=access-key="$S3_ACCESS_KEY" \
  --from-literal=secret-key="$S3_SECRET_KEY" \
  -n $HIVE_NS )
```

testing:
```
kubectl run --namespace hive-metastore curl --image=radial/busyboxplus:curl -i --tty 
```