IMAGE_TAG="tcarland/hive:3.1.3"

all: setup 

setup:
	( ./bin/trino-k8s-setup.sh -e )

clean: distclean

distclean:
	( rm -f hive-metastore/base/hive-init-schema.yaml \
	  hive-metastore/base/core-site.xml \
	  hive-metastore/base/hive-site.xml \
	  trino/base/trino-configmap.yaml \
	  trino/base/secrets.env )