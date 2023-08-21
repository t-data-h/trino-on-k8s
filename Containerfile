FROM ubuntu:22.04
ARG kustomize_version=v5.1.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    tini

RUN curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${kustomize_version}/kustomize_${kustomize_version}_linux_amd64.tar.gz \
    | tar xz -C /usr/local/bin

RUN mkdir -p /opt/tdh-k8s
COPY . /opt/tdh-k8s/

ENTRYPOINT ["tini", "--"]