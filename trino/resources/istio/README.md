
Exposing Trino via Istio Ingress Gateway
========================================

The *istio-ingressgateway* can terminate TLS and forward 
HTTP internally within k8s to the trino service. 

If the environment has *TRINO_DOMAINNAME* set, then the setup 
script will create the *params.env* file from the template 
in *base/*. 

The TLS key pair (as PEM) should be places in the *tls/* path 
as it is needed to generate the secret used by the ingress 
controller. This secret must be exist in the Istio namespace,
thus the separate path to define the *istio-system* namespace.

This currently is not set up for kustomize overlays.
