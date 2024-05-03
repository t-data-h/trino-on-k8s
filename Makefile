all: setup 

setup:
	( ./bin/trino-k8s-setup.sh -e )

clean: distclean

distclean:
	( rm -f hive-metastore/base/hive-init-schema.yaml \
	  hive-metastore/base/core-site.xml \
	  hive-metastore/base/hive-site.xml \
	  trino/base/trino-configmap.yaml \
	  mysql-server/base/secrets.env \
	  hive-metastore/base/secrets.env \
	  trino/base/secrets.env )