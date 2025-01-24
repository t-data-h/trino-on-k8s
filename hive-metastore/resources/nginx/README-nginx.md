Exposing the hive-metatore with NGINX
=====================================

This is typically not recommended due to the lack of security 
around direct connections to the hive-metastore.

## Configuring NGINX for TCP

By default, NGINX is configure only for http(s) protocols, but 
TCP can be enabled with the following steps:

- The nginx *Service* object must be updated to include the tcp port.
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: ingress-nginx-controller
    namespace: ingress-nginx
  spec:
    ports:
    - appProtocol: thrift
      name: thrift
      port: 9083
      protocol: TCP
      targetPort: 9083
  ```
- The manifests should be deployed to include the ingress TCP *ConfigMap*. 
  Note this would overwrite any existing configmap, in which case an 
  overlay to patch the configmap should be used instead.
  ```yaml
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: hive-tcp-services
    namespace: $(ingress_namespace) 
  data:
    "9083": "trino/hive-metastore:9083"
  ```
  The manfiests are provided in *hive-metastore/resources/nginx* or 
  this directory.
  ```sh
  kustomize build . | kubectl apply -f -
  ```
- The NGINX *Deployment* should be modified to add *--tcp-services-configmap* 
  argument to the container
  ```yaml
  args:
    - /nginx-ingress-controller
    - --tcp-services-configmap=ingress-nginx/hive-tcp-services
  ```

