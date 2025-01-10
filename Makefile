all: setup 

setup:
	( ./bin/trino-k8s-setup.sh -e )

clean: distclean

distclean:
	( rm -f hive-metastore/base/hive-init-schema.yaml \
	  hive-metastore/base/core-site.xml \
	  hive-metastore/base/hive-site.xml \
	  hive-metastore/base/secrets.env \
	  postgresdb/base/secrets.env \
	  mysql-server/base/secrets.env \
	  trino/base/secrets.env \
	  trino/base/password.db \
	  trino/base/trino-configmap.yaml \
	  trino/base/trino-groups.txt \
	  trino/base/trino-rules.json \
	  trino/resources/istio/tls/*.key \
	  trino/resources/nginx/*.key )
