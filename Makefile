
IMAGE_TAG="tarland/hive-metastore:3.0.0"

all: setup docker

setup:
	( ./bin/setup.sh )
docker:
	( ./bin/docker_build.sh $(IMAGE_TAG) ) 

clean: distclean

distclean:
	( rm -f hive-init-schema.yaml hive-metastore/base/core-site.xml \
	  hive-metastore/base/metastore-site.xml trino/base/configmap.yaml )