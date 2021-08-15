IMAGE_TAG="tarland/hive:3.1.2"

all: setup 

setup:
	( ./bin/trino-k8s-setup.sh )

docker:
	( cd docker/hive3 && ../../bin/docker_build.sh $(IMAGE_TAG) ) 

clean: distclean

distclean:
	( rm -f hive-metastore/base/hive-init-schema.yaml \
	  hive-metastore/base/core-site.xml \
	  hive-metastore/base/metastore-site.xml \
	  trino/base/trino-configmap.yaml )