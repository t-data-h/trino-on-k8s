Hive Metastore Tests
====================

This is typically unnecessary as the *hive-metastore* **v3.1.3**
is stable and essentially just works. Issues that may occur would 
involve access/credentials either to the backing metastore db or 
to the S3 bucket. Still, in complicated environments with other 
policies or service meshes in place, it may be desirable to 
validate the operations.

Two scripts are provided here that use an older python library 
that wraps the Hive *thrift* protocol and will list the available 
schemas, and create a schema, testing both read and write capabilities.
These can be used external to the cluster if hive has been exposed, 
or a python container can be used to run the tests.

The scripts currently default to using the internal service name 
and thus, are more suited for testing from a container.

## Using the Container

Build the container and push to a registry that the cluster can use
```sh
imagename="quay.io/$USER/dev-python:3.11"
nerdctl build . -f Containerfile -t $imagename
nerdctl push $imagename
```

Run and attach to the container in Kubernetes.
```sh
kubectl run -i --tty --rm hmspytest -n trino --image $imagename -- /bin/bash
```
