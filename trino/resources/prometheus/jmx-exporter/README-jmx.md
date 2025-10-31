README-jmx-exporter
===================

Given that the *Bitnami* repository images have been locked down,
as well as the *jmx-exporter* image being quite old, this 
ReadMe provides the steps needed to build the *jmx-exporter* and a 
corresponding container image.


## Building the JMX Exporter

First clone the source repository from GitHub.
```sh
cd ..  # from project root 
git clone https://github.com/prometheus/jmx_exporter.git
```

The project provides its own *Maven* wrapper for building the project.
```sh
git checkout <tag>  # eg 1.5.0
./mvnw package
```

Once built, we can create a container from the root of the project.
Copy the provided `Containerfile` and `entrypoint.sh` files to the 
*jmx-exporter* project directory and build the container image.
```sh
cp ../trino-on-k8s/trino/resources/prometheus/jmx-exporter/Containerfile .
cp ../trino-on-k8s/trino/resources/prometheus/jmx-exporter/entrypoint.sh .
docker build . --build-arg "app_version=1.5.0" \
    -f Containerfile -t quay.io/tcarland/jmx-exporter:1.5.0_yymmdd
```

This will copy the *jmx_prometheus_standalone* jars into the container.

Java executed via a shell can cause some odd issues with how *ENTRYPOINT* 
works along with the args, especially when needing k8s overrides using the 
corresponding `command: []` and `args: []` statements. Simply using an 
*entrypoint.sh* script to launch the java app solves the problem and 
allows for ENV variables to be used (eg. semver reference ).
