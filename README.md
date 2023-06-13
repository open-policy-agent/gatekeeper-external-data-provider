# External Data Provider

A template repository for building external data providers for Gatekeeper.

## Prerequisites

- [ ] [`docker`](https://docs.docker.com/get-docker/)
- [ ] [`helm`](https://helm.sh/)
- [ ] [`kind`](https://kind.sigs.k8s.io/)
- [ ] [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)

## Quick Start

1. Create a [kind cluster](https://kind.sigs.k8s.io/docs/user/quick-start/).

2. Install the latest version of Gatekeeper and enable the external data feature.

```bash
# Add the Gatekeeper Helm repository
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

# Install the latest version of Gatekeeper with the external data feature enabled.
helm install gatekeeper/gatekeeper \
    --set enableExternalData=true \
    --name-template=gatekeeper \
    --namespace gatekeeper-system \
    --create-namespace
```

3. Build and deploy the external data provider.

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
```

4a. Install constraint template and constraint.

```bash
kubectl apply -f validation/external-data-provider-constraint-template.yaml
kubectl apply -f validation/external-data-provider-constraint.yaml
```

4b. Test the external data provider by dry-running the following command:

```bash
kubectl run nginx --image=error_nginx --dry-run=server -ojson
```

Gatekeeper should deny the pod admission above because the image field has an `error_nginx` prefix.

```console
Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request: [deny-images-with-invalid-suffix] invalid response: {"errors": [["error_nginx", "error_nginx_invalid"]], "responses": [], "status_code": 200, "system_error": ""}
```

5a. Install Assign mutation.

```bash
kubectl apply -f mutation/external-data-provider-mutation.yaml
```

5b. Test the external data provider by dry-running the following command:

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

6. Uninstall the external data provider and Gatekeeper.

```bash
kubectl delete -f validation/
kubectl delete -f mutation/
helm uninstall external-data-provider --namespace "${NAMESPACE:-gatekeeper-system}"
helm uninstall gatekeeper --namespace gatekeeper-system
```
