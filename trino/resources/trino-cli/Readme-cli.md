
Building the trino-cli container image (using nerdctl or docker)
```sh
nerdctl build . -f Containerfile.trino-cli -t quay.io/tcarland/trino-cli:474
```

Example running the container in k8s
```sh
kubectl run -n spark -i --tty trino-cli \
--restart=Never \
--image quay.io/tcarland/trino-cli:474 \
--env="TRINO_CATALOG=hive"
--env="TRINO_USER=tdh"
--env="TRINO_PASSWORD=tdhadmin"
```
