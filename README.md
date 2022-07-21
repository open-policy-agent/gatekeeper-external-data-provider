# External Data Provider

XXX

A template repository for building external data providers for Gatekeeper.

## Prerequisites

- [ ] [`docker`](https://docs.docker.com/get-docker/)
- [ ] [`helm`](https://helm.sh/)
- [ ] [`kind`](https://kind.sigs.k8s.io/)
- [ ] [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)

## Quick Start

1. Clone the Gatekeeper repository.

```bash
git clone https://github.com/open-policy-agent/gatekeeper.git
cd gatekeeper
```

2. Create a kind cluster.

```bash
./third_party/github.com/tilt-dev/kind-local/kind-with-registry.sh
```

3. Install the latest version of Gatekeeper and enable the external data feature.

```bash
# TODO: pin to v3.9.0 once it's available
helm install gatekeeper manifest_staging/charts/gatekeeper \
    --set image.release=dev \
    --set enableExternalData=true \
    --namespace gatekeeper-system \
    --create-namespace
```

4. Build and deploy the external data provider.

```bash
git clone https://github.com/open-policy-agent/gatekeeper-external-data-provider.git
cd external-data-provider

# if you are not planning to establish mTLS between the provider and Gatekeeper,
# deploy the provider to a separate namespace. Otherwise, do not run the following command
# and deploy the provider to the same namespace as Gatekeeper.
export NAMESPACE=provider-system

# generate a self-signed certificate for the external data provider
./scripts/generate-tls-cert.sh

# build the image via docker buildx
make docker-buildx

# load the image into kind
make kind-load-image

# Choose one of the following ways to deploy the external data provider:

# 1. client and server auth enabled (recommended)
helm install external-data-provider charts/external-data-provider \
    --set provider.tls.caBundle="$(cat certs/ca.crt | base64 | tr -d '\n\r')" \
    --namespace "${NAMESPACE:-gatekeeper-system}"

# 2. client auth disabled and server auth enabled
helm install external-data-provider charts/external-data-provider \
    --set clientCAFile="" \
    --set provider.tls.caBundle="$(cat certs/ca.crt | base64 | tr -d '\n\r')" \
    --namespace "${NAMESPACE:-gatekeeper-system}" \
    --create-namespace

# 3. client and server auth disabled
helm install external-data-provider charts/external-data-provider \
    --set clientCAFile="" \
    --set provider.tls.enabled=false \
    --set provider.tls.skipVerify=true \
    --namespace "${NAMESPACE:-gatekeeper-system}" \
    --create-namespace
```

5a. Install constraint template and constraint.

```bash
kubectl apply -f validation/external-data-provider-constraint-template.yaml
kubectl apply -f validation/external-data-provider-constraint.yaml
```

5b. Test the external data provider by dry-running the following command:

```bash
kubectl run nginx --image=error_nginx --dry-run=server -ojson
```

Gatekeeper should deny the pod admission above because the image field has an `error_nginx` prefix.

```
Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request: [deny-images-with-invalid-suffix] invalid response: {"errors": [["error_nginx", "error_nginx_invalid"]], "responses": [], "status_code": 200, "system_error": ""}
```

6a. Install Assign mutation.

```bash
kubectl apply -f mutation/external-data-provider-mutation.yaml
```

6b. Test the external data provider by dry-running the following command:

```bash
kubectl run nginx --image=nginx --dry-run=server -ojson
```

The expected JSON output should have the following image field with `_valid` appended by the external data provider:

```json
"containers": [
    {
        "name": "nginx",
        "image": "nginx_valid",
        ...
    }
]
```

7. Uninstall the external data provider and Gatekeeper.

```bash
kubectl delete -f validation/
kubectl delete -f mutation/
helm uninstall external-data-provider --namespace "${NAMESPACE:-gatekeeper-system}"
helm uninstall gatekeeper --namespace gatekeeper-system
```
