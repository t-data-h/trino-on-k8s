Trino and Hive on Kubernetes
============================

Kustomize manifests and supporting scripts for running TrinoDb and 
a Hive3 Metastore in Kubernetes using S3 object storage and MySQL (or Postgres).

Author:  Timothy C. Arland  
Email:  <tcarland@gmail.com> <br> 

<br>

## Prerequisites:

- Kubernetes >= 1.23 - Suggested version: 1.25+
- Kustomize  >= v5   - Suggested version: [v5.4.2](https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.4.2/kustomize_v5.4.2_linux_amd64.tar.gz)

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
| TRINO_DBUSER         |  Name of the hive backend db user   | `root` |
| TRINO_DBPASSWORD     |  Password for the backend root user |  *randomized-password* |
|  ----------------    |  -------------------------  |  -------------------  |
| TRINO_USER           |  Name of the admin Trino user | `trino` |
| TRINO_PASSWORD       |  Password for the trino admin user | `trinoadmin` |
| TRINO_DOMAINNAME     |  TLS Endpoint used in ingress manifest |  --  |

The environment path is supported by the setup script for adding additional
catalog configs and support files such as ldap truststore, kerberos keytabs 
for hive integration, trino rules customization, and the password database, 
if applicable. Environments are contained in their only subdirectory to 
easily support an *overlay* technique to allow obtaining assets from a 
secrets manager.
```sh
mkdir env/envname
cp env/env.template env/envname/name.env
mkdir env/envname/auth
mkdir env/envname/files
```

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
source env/envname/name.env
./bin/trino-k8s-setup.sh <envname>
```

<br>

## Deploy the Postgresql Server

Using Postgres for the *metastore_db* follows a slightly different path 
than MySQL. Rather than using *schematool* to initialize the db, a 
custom postgres container images is built in order to inject admin rbac 
and the metastore schema. Refer to the [README.md](postgresdb/resources/README.md) 
for details on build the image.  The *hive-init-schema.yaml* is 
still able to be used when adjusted for postgres, but the postgres 
image would still need roles applied.

## <ALTERNATIVE>  Deploy the MySQL Server

MySQL used to be the default for the *TDH* platform, but recent directions 
have put Postgres on top. By making a few changes to the configs, the deployment 
can easily switch back to the MySQL Server. Enable the *hive-init-schema.yaml* 
and deploy via Kustomize .
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

Trino CLI can be acquired [here](https://repo1.maven.org/maven2/io/trino/trino-cli/457/trino-cli-457-executable.jar)
```
trino-cli --server 172.17.0.210:8080 --catalog hive --schema default
```

## Trino JDBC

The JDBC Driver can be acquired from the [Maven Central Repository](https://repo1.maven.org/maven2/io/trino/trino-jdbc/). 
The current deployment has been tested with [trino-457](https://repo1.maven.org/maven2/io/trino/trino-jdbc/457/trino-jdbc-457.jar).


## LDAP

In addition to changing the *password-authenticator.properties* with the appropriate
ldap settings, the *truststore* file must be added as a kustomize secret and the 
coordinator deployment must mount the trust store at the path defined below.
```
export LDAP_SERVER="ldaps://ldap-host.domain.com:689"
export LDAP_USER_BIND_PATTERN="\${USER}@ad.domain.com"
export LDAP_BIND_DN="ldapadmin@ad.domain.com"
export LDAP_BIND_PW="password"
export LDAP_USER_BASE_DN="ou=MyOrg,dc=ad,dc=domain,dc=com"
export LDAP_GROUP_AUTH="(&(objectClass=person)(sAMAccountName=\${USER}(memberOf=CN=TRINO_USERS_GROUPNAME,OU=DataOrgGroups,OU=DataOrg,DC=ad,DC=domain,DC=com))"
export LDAP_TRUSTSTORE_PASSWORD="changit"

#ldap.url=ldap://ldap-host.domain.com:389
#ldap.allow-insecure=true
ldap.url=ldaps://ldap-host.domain.com:686
ldap.ssl.truststore.path=/etc/trino/truststore.jks
ldap.ssl.truststore.password=${LDAP_TRUSTSTORE_PASSWORD}
ldap.user-bind-pattern=${LDAP_USER_BIND_PATTERN}
ldap.bind-dn=${LDAP_BIND_DN}
ldap.bind-password=${LDAP_BIND_PW}
ldap.user-base-dn=${LDAP_USER_BASE_DN}
ldap.group-auth-pattern=${LDAP_GROUP_AUTH}
```
