Exposing the Hive-Metastore with Istio
======================================

The current implementation is intended to keep the metastore
internal to K8s and fronted by Trino for authorization, thus
it is not recommended to expose hive as no auth controls are 
configured.

The *istio-operator.yaml* provides an install resource for 
*istioctl*.
```sh
istioctl install -f istio-operator.yaml
```

Alternatively, edit the *istio-ingressgateway* Service manifest 
to add the TCP 9083 port definition and ensure the port is 
exposed.
```
kubectl get svc istio-ingressgateway -n istio-system

NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                                                     AGE
istio-ingressgateway   LoadBalancer   10.96.37.218   172.17.0.210   15021:31633/TCP,80:31451/TCP,443:32433/TCP,9083:31359/TCP   92m
```

Prior to deploying Hive, ensure the namespace is labeled for 
Istio Injection.
```sh
kubectl label namespace trino istio-injection=enabled
```

Then deploy the hive-metastore
```sh
kustomize build hive-metastore/ | k apply -f -
```

Finally apply the *VirtualService* followed by the *Gateway* manifests.
```sh
kubectl apply -f hive-virtualservice.yaml
kubectl apply -f hive-gateway.yaml
```