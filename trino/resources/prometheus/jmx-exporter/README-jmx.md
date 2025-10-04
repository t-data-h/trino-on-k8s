README-jmx-exporter
===================

Given that the *Bitnami* repository images may not be available
soon, as well as the *jmx-exporter* image being quite old, this 
ReadMe provides the steps needed to build the jmx-exporter and a 
corresponding container image.


## Building the JMX Exporter

First clone the source repository from GitHub.
```sh
git clone https://github.com/prometheus/jmx_exporter.git
```

The project provides its own *Maven* wrapper for building the project.
```sh
git checkout <tag=1.4.0>
./mvnw package
```

Once built, we can create a container from the root of the project.
Copy the provided `Containerfile` and  `entrypoint.sh` files to the 
*jmx-exporter* project directory and build the container image.
```sh
cp ../trino-on-k8s/trino/resources/prometheus/jmx-exporter/Containerfile .
cp ../trino-on-k8s/trino/resources/prometheus/jmx-exporter/entrypoint.sh .
docker build . -f Containerfile -t quay.io/tcarland/jmx-exporter:1.4.0_yymmdd
```

This will copy the *jmx_prometheus_standalone* jars into the container.
Note the manifest args will correctly override the container *CMD* args
with the use of the *entrypoint.sh* scxript
