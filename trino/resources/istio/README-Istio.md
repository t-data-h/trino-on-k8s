
Exposing Trino via Istio Ingress Gateway
========================================

The *istio-ingressgateway* can terminate TLS and forward 
HTTP internally within k8s to the trino service. 

If the environment has *TRINO_DOMAINNAME* set, then the setup 
script will create the *params.env* file from the template 
in *base/*. Note that *INGRESS_NAMESPACE* should also be set.

The TLS key pair (as PEM) should be places in the *tls/* path 
as it is needed to generate the secret used by the ingress 
controller. This secret must be exist in the Istio namespace,
thus the separate path to define the *istio-system* namespace.

The LoadBalancer IP on the IngressGateway may not be configured 
to the correct or desired IP and may need to be patched accordingly.
Once patched the pod must be restarted to pick up the correct IP.
```sh
kubectl patch svc istio-ingressgateway -n istio-system \
-p '{"spec": {"type": "LoadBalancer", "loadBalancerIP": "172.17.0.210"}}'
```

Secret references by name are not something easily modified in the 
base kustomize for particular Istio manifests. This is due to the 
secret being created by the SecretGenerator in the kusomize **base**, 
so these references must be updated via a kustomize overlay. This is 
also true for the namespace referenced in the ingress virtual service. 
Refer to the overlay example (overlays/example) as a reference on 
updating these fields.
