Trino with the Hive-Metastore on Kubernetes
===========================================

Kustomize manifests and supporting scripts for running TrinoDb and
a Hive3 Metastore in Kubernetes using S3 object storage and Postgres.

Author:  Timothy C. Arland
Email:  <tcarland at gmail dot com>

<br>

## Prerequisites:

- Kubernetes  > 1.32 - Suggested version: 1.34+
- Kustomize  >= v5   - Suggested version: [v5.8.0](https://github.com/kubernetes-sigs/kustomize)
- yq         >= v4+  - Suggested version: [v4.49.2](https://github.com/mikefarah/yq)
- bash       >= v4+  - System package

<br>

## Configuring the Environment

The project depends on a number of environment variables for deploying the
necessary configuration via the setup script. S3 Credentials are the primary
variables required, with others having default values if not provided.
The following table defines the list of variables used by the setup script.

| Environment Variable |       Description        |    Default Setting     |
| -------------------- | -------------------------| ---------------------- |
| S3_ENDPOINT          |  The S3 endpoint url     | http(s)://minio.minio.svc  |
| S3_REGION            |  The S3 region name      |       |
| S3_ACCESS_KEY        |  The S3 access key       |       |
| S3_SECRET_KEY        |  The S3 secret key       |       |
|  ----------------    |  ------------------------------  |  -------------------  |
| TRINO_NAMESPACE      |  Namespace for deploying the components  | `trino`  |
| HIVE_NAMESPACE       |  To deploy Hive in a different namespace | `trino` |
| HIVE_DBHOST          |  The service name for the metadb         | `postgres-service.trino.svc` |
| HIVE_DBNAME          |  The schema/db name for the metadb       | `metastore_db` |
| HIVE_DBUSER          |  Name of the hive metastore db user      | `root` |
| HIVE_DBPASSWORD      |  Password for the hive metastore user    |  *randomized-password* |
| HIVE_S3_BUCKET       |  The root bucket name for the warehouse  | `hive` |
|  ----------------    |  ---------------------------  |  -------------------  |
| TRINO_USER           |  Name of the admin Trino user | `trino` |
| TRINO_PASSWORD       |  Password for the trino admin user | `trinoadmin` |
| TRINO_DOMAINNAME     |  TLS Endpoint used in ingress manifests |  --  |

The environment path is supported by the setup script for adding additional
catalog configs and support files such as kerberos keytabs for traditional
Hadoop-Hive integration, Trino rules customization, and the password database,
if applicable. Environments are contained in their own subdirectory to
easily support an *overlay* technique to allow obtaining the assets from a
secrets manager. As a result, the env path is masked from git to avoid
committing any such secrets to the repository.
```sh
mkdir env/envname
cp env/env.template env/envname/name.env
mkdir env/envname/auth
mkdir env/envname/files
```

<br>

## Building the Hive Metastore Image

The metastore image is based off of Hive version 3.1.3 and can be
built using the provided *hive-metastore/resources/Containerfile*.
Refer to the following [Readme](./hive-metastore/resources/README-hive.md)
for build details.


## Setup / Configure the Working Directory.

Ensure all variables above are defined and *exported* to the environment.
Passing an argument to the script will show the configuration only and
can be used to verify the settings.
```sh
./bin/trino-k8s-setup.sh -e
```

Run the setup script to configure the various config templates.
```sh
source env/envname/name.env
./bin/trino-k8s-setup.sh <envname>
```

Typically, using multiple environments, and when providing an environment
name to the setup, a *kustomize* overlay directory is created. While the
example below show running kustomize against the base kustomize path,
typically overlay directories are created and used instead. Example
overlays are provided in each component to serve as a template for
creating additional overlays.

### Environment Configuration

Trino configurations can get complicated considering secrets, certificates,
additional catalogs, authorization rules, etc. This project uses an
environment approach to automating the configuration of a given trino
instance. A separate repository is used to hold an encrypted version
of the environment given that secrets exist at many different levels
such ingress certificate pairs, passwords, grants/rules, keytabs. Some
secrets are applied to the main trino configmap which is always placed
in `<component>/base/`, however secrets related to additional catalogs
must be added to an *overlay*. The structure of the *environment*
path, determines where files are placed by the setup script.

The configs are stored in *env/$TRINO_ENV/*. The main *.env* file holds
most of the configuration save for additional files needed by various
catalogs or configurations. This file is always *env/$TRINO_ENV/$TRINO_ENV.env*
```
env/
   /envname1
   /envname2
   /.../auth      # trino auth files placed in /base (trino-rules|groups)
     . /certs     # certificates for trino/resource/<ingresstype>/base/
     . /configs   # additional catalog configurations
     . /files     # files to be added to a given overlay (keytabs, etc)
```

<br>

## Deploy the Postgresql Server

Using Postgres for the *metastore_db* follows a slightly different path
than MySQL. Rather than using the Hive *schematool* to initialize the db,
a custom postgres container images is built in order to inject admin RBAC
and the metastore DDL. Refer to the [README](postgresdb/resources/README-postgres.md)
for details on building the image.  The *hive-init-schema.yaml* is
still able to be used when adjusted for postgres, but the postgres
image would still need roles applied.

Note, support for using the MySQL Server was **DEPRECATED** as of `v25.10.31`
and removed following that. Refer to tag `v25.10.04` for last supported mysql 
manifests.

<br>

## Deploy the Hive Metastore

We deploy the metastore in the same manner, using Kustomize.
```sh
kustomize build hive-metastore/ | kubectl apply -f -
```

Image override as well as other config items are customized for a given
instance by use of an overlay, which is  used as the *kustomize* target.
```sh
kustomize build hive-metastore/overlays/myenv/ | kubectl apply -f -
```

<br>

## TrinoDb

Verify the parameter substitution is correct in *trino/base/trino-configmap.yaml*
as generated by the *trino-k8s-setup.sh* script.

Load the Trino manifests.
```sh
kustomize build trino/ | kubectl apply -f -
```

or for a more direct use of an environment instance:
```sh
kustomize build trino/overlays/$envname/ | kubectl apply -f -
```

Trino will create mutual TLS connections internally between the Coordinator and
the workers, as well as using a randomized PreShared Key to authenticate
workers.

By virtue of running in K8s, Trino makes it easier to enable TLS and not have to
configure keys, certifcates, and trust across containers, and supports using an
ingress gateway to terminate TLS. This setup requires configuring Trino to use
forwarded headers to validate that HTTPS was used and terminated by the
controller. This setting is `http-server.process-forwarded=true`.

Ingress resources are provided for exposing TLS using either *Istio* or *Nginx*
as the ingress gateway. Refer to the *Readme* in the corresponding *trino/resources*
directory. The configuration variable *INGRESS_NAMESPACE* configures the two,
currently supported ingress controllers and should have either `istio` or `nginx`
as part of the namespace name.


## Cleanup

The secrets needed for the components are written to **/base/secrets.env** for
kustomize to consume on *build* and should be cleaned up after deployment by
running `make clean`.


## Trino CLI

Trino CLI can be acquired [here](https://repo1.maven.org/maven2/io/trino/trino-cli/479/trino-cli-479-executable.jar)
```sh
trino-cli --server 172.17.0.210:8080 --user trino --password --catalog hive --schema default
```

## Trino JDBC

The JDBC Driver can be acquired from the [Maven Central Repository](https://repo1.maven.org/maven2/io/trino/trino-jdbc/).
The current deployment has been tested with [trino-479](https://repo1.maven.org/maven2/io/trino/trino-jdbc/479/trino-jdbc-479.jar).


## LDAP

In addition to changing the *password-authenticator.properties* with the
appropriate ldap settings, the *truststore* file must be added as a kustomize
secret and the coordinator deployment must mount the trust store at the path
defined below.
```bash
export LDAP_SERVER="ldaps://ldap-host.domain.com:689"
export LDAP_USER_BIND_PATTERN="\${USER}@ad.domain.com"
export LDAP_BIND_DN="ldapadmin@ad.domain.com"
export LDAP_BIND_PW="password"
export LDAP_USER_BASE_DN="ou=MyOrg,dc=ad,dc=domain,dc=com"
export LDAP_GROUP_AUTH="(&(objectClass=person)(sAMAccountName=\${USER}(memberOf=CN=TRINO_USERS_GROUPNAME,OU=DataOrgGroups,OU=DataOrg,DC=ad,DC=domain,DC=com))"
export LDAP_TRUSTSTORE_PASSWORD="changeit"

# adjust trino-configmap.yaml.template accordingly
#ldap.url=ldap://ldap-host.domain.com:389
#ldap.allow-insecure=true
ldap.url=ldaps://ldap-host.domain.com:686
ldap.user-bind-pattern=${LDAP_USER_BIND_PATTERN}
ldap.bind-dn=${LDAP_BIND_DN}
ldap.bind-password=${LDAP_BIND_PW}
ldap.user-base-dn=${LDAP_USER_BASE_DN}
ldap.group-auth-pattern=${LDAP_GROUP_AUTH}
```

## Private CA signed TLS Certificates

For self-signed certificates, one can set a truststore just for LDAP in
the authenticator properties.
```
ldap.ssl.truststore.path=/etc/trino/truststore.jks
ldap.ssl.truststore.password=${LDAP_TRUSTSTORE_PASSWORD}
```

Alternatively, it may be better to mount the truststore to the various
deployments directly as the default java *cacerts*  file. This is useful
if, for example, the underlying S3 endpoint is secured with a private CA
TLS certificate. Typically this involves mounting a *JKS* truststore to
the hive-metastore and both the trino-coordinator and all workers.

Add the truststore secret to each *kustomization.yaml*
```yaml
secretGenerator:
- name: hive-metastore-secrets
  envs:
  - secrets.env
- name: truststore
  file:
  - truststore.jks
```

And add the mounts to the deployments. This is a partial patch
demonstrating the volume mount for *hive*.
```yaml
  spec:
    template:
      spec:
        containers:
        - name: hive-metastore
          volumeMounts:
          - name: truststore-vol
            mountPath: /opt/java/openjdk/lib/security/cacerts
            subPath: truststore.jks
        volumes:
          - name: truststore-vol
            secret:
              secretName: truststore
```

For Trino, the same would apply to both the *deployment* manifest and
the *statefulset*. Note that Java path should be verified from the
trino image.
```yaml
  spec:
    template:
      spec:
        containers:
        - name: trino
          volumeMounts:
          - name: truststore-vol
            mountPath: /usr/lib/jvm/temurin/jdk-25.0.1+8/lib/security/cacerts
            subPath: truststore.jks
        volumes:
          - name: truststore-vol
            secret:
              secretName: truststore
```

Note that JDK Locations are often updated with each Trino Release.
- *trino-476*  :  /usr/lib/jvm/temurin/jdk-24.0.1+9
- *trino-477*  :  /usr/lib/jvm/temurin/jdk-24.0.2+12
- *trino-478*  :  /usr/lib/jvm/jdk-25+36
- *trino-479*  :  /usr/lib/jvm/jkd-25.0.1+8
