Exposing the hive-metatore with NGINX
=====================================

This is not recommended due to the lack of security around direct 
connections to the hive-metastore.

## Configuring NGINX for TCP

By default, NGINX is configured only for http(s) protocols, but 
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

- The *kustomize* provided here includes a manifest for setting the nginx
  *tcp-services* ConfigMap, but the manifest should really be deployed 
  as part of the *nginx* deployment. Deploying from here would overwrite 
  any existing ConfigMap. An alternative would be to use an overlay to
  patch the ConfigMap instead since only one ConfigMap is used for all 
  TCP Services exposed via NGINX.
  ```yaml
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: tcp-services
    namespace: $(ingress_namespace) 
  data:
    "9083": "trino/hive-metastore:9083"
  ```

- The *ConfigMap* and *Ingress* manifests are provided here under 
  *hive-metastore/resources/nginx/* (this directory) and can be 
  applied once the controller service has been updated to include port 
  9083 (the first step above).
  ```sh
  kustomize build . | kubectl apply -f -
  ```

- Finally, the NGINX *Deployment* manifest should be modified to add 
  the *--tcp-services-configmap* argument to the controller.
  ```yaml
  args:
    - /nginx-ingress-controller
    - --tcp-services-configmap=ingress-nginx/tcp-services
  ```
