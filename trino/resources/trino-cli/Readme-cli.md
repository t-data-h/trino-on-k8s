
Building the trino-cli container image (using nerdctl or docker)
```sh
nerdctl build . -f Containerfile.trino-cli -t tcarland/trino-cli:471
```

Example running the container in k8s
```sh
kubectl run -n spark -i --tty trino-cli \
--restart=Never \
--image harbor.charltontechnology.net/tcarland/trino-cli:471 \
--env="TRINO_CATALOG=hive"
```

