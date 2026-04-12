#!/bin/bash
clear

HOSTNAME=localhost
CLUSTER_PORT=81
CLUSTER_PORT_HTTPS=444
CLUSTER_NAME=test-kind

BLUE='\033[1;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --------------------------------------
# Useful functions and definition
# --------------------------------------

log() {
  echo -e "\n$(date +%T) - $@\n"
}

info() {
  log "${BLUE}[INFO]${NC} $@"
}

error() {
  log "${RED}[ERROR]${NC} $@"
}

validate_variable() {
  var_name=$1
  var_value=$(echo ${!var_name})
  if [ -z "$var_value" ]; then
    error "missing required environment variable $var_name"
    exit 1
  else
    if [ "" = "$var_value" ]; then
      error "empty required environment variable $var_name"
    fi
  fi
}

validate_status_code() {
  local url="$1"
  local expected=$2
  local additional_curl_options=$3
  local attempts=120
  log "⏱️ Checking status code for ${url}"
  for i in $(seq 1 ${attempts}); do
    status_code=$(curl -o /dev/null -s -w "%{http_code}\n" ${additional_curl_options} ${url})
    if [[ "$status_code" = "$expected" ]]; then
      info "✅ Received expected status code ${expected} from ${url}"
      break
    fi
    if [[ $i -eq ${attempts} ]]; then
      error "❌ Expected status code ${expected} from ${url}, but got ${status_code} after ${attempts} attempts"
      exit 1
    fi
    sleep 1
  done
}

titlecat() {
  echo -e "\n$YELLOW"; cat $1; echo -e "$NC\n"
}

# --------------------------------------

REGISTRY_NAME="ghcr.io/cdfcrew"
REGISTRY_USERNAME=${REGISTRY_USERNAME:-$GITHUB_ACTOR}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD:-$GITHUB_TOKEN}

validate_variable "REGISTRY_PASSWORD"
validate_variable "REGISTRY_USERNAME"

# --------------------------------------

titlecat <<EOF
░█▀▀░█▀▄░█▀▀░█▀█░▀█▀░█▀▀░░░█▀▀░█░░░█░█░█▀▀░▀█▀░█▀▀░█▀▄
░█░░░█▀▄░█▀▀░█▀█░░█░░█▀▀░░░█░░░█░░░█░█░▀▀█░░█░░█▀▀░█▀▄
░▀▀▀░▀░▀░▀▀▀░▀░▀░░▀░░▀▀▀░░░▀▀▀░▀▀▀░▀▀▀░▀▀▀░░▀░░▀▀▀░▀░▀
EOF

kind create cluster --wait 300s --name "${CLUSTER_NAME}" --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.33.4
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraMounts:
  - hostPath: ${PWD}/data
    containerPath: /data
  extraPortMappings:
  - containerPort: 443
    hostPort: ${CLUSTER_PORT_HTTPS}
    protocol: TCP
  - containerPort: 80
    hostPort: ${CLUSTER_PORT}
    protocol: TCP
EOF

set -e

rm *.pem 2>/dev/null || true

docker build -t ghcr.io/cdfcrew/website:0.0.0 .
kind load docker-image ghcr.io/cdfcrew/website:0.0.0 --name ${CLUSTER_NAME}

k="kubectl --context kind-$CLUSTER_NAME"
h="helm --kube-context kind-$CLUSTER_NAME"
BASE_PATH="https://$HOSTNAME:$CLUSTER_PORT_HTTPS"

titlecat <<EOF
░▀█▀░█▀█░█▀▀░█▀▄░█▀▀░█▀▀░█▀▀░░░█▀▀░█▀█░█▀█░▀█▀░█▀▄░█▀█░█░░░█░░░█▀▀░█▀▄
░░█░░█░█░█░█░█▀▄░█▀▀░▀▀█░▀▀█░░░█░░░█░█░█░█░░█░░█▀▄░█░█░█░░░█░░░█▀▀░█▀▄
░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀▀░░░▀▀▀░▀▀▀░▀░▀░░▀░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀
EOF

$k apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
sleep 5
log "⏱️ Waiting for ingress-nginx to be ready..."
if ! $k wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s; then
    error "❌ Timeout waiting for ingress-nginx controller to be ready"
    exit 1
fi

# ---------------------------------------

titlecat <<EOF
░▀█▀░█░░░█▀▀░░░█▀▀░█▀▀░▀█▀░█░█░█▀█
░░█░░█░░░▀▀█░░░▀▀█░█▀▀░░█░░█░█░█▀▀
░░▀░░▀▀▀░▀▀▀░░░▀▀▀░▀▀▀░░▀░░▀▀▀░▀░░
EOF

# create tls secret for https
info "⏱️ Creating TLS secret for HTTPS traffic"

TLS_SECRET_NAME="tls-secret"

openssl req \
  -subj '/CN=${HOSTNAME}/O=Test Keycloak./C=US' \
  -newkey rsa:2048 \
  -nodes \
  -keyout local.key.pem \
  -x509 \
  -days 365 \
  -out local.certificate.pem > /dev/null

$k create \
  secret tls \
  $TLS_SECRET_NAME \
  --cert=local.certificate.pem \
  --key=local.key.pem \
  --dry-run=client -o yaml | $k apply -f - || true

# ---------------------------------------

titlecat <<EOF
░█░█░█▀▀░█▀▄░█▀▀░▀█▀░▀█▀░█▀▀
░█▄█░█▀▀░█▀▄░▀▀█░░█░░░█░░█▀▀
░▀░▀░▀▀▀░▀▀░░▀▀▀░▀▀▀░░▀░░▀▀▀
EOF

info "⏱️ Creating registry secret"

REGISTRY_SECRET_NAME="registry-credentials"

$k create secret docker-registry ${REGISTRY_SECRET_NAME} \
    --docker-server=${REGISTRY_NAME} \
    --docker-username=${REGISTRY_USERNAME} \
    --docker-password=${REGISTRY_PASSWORD} \
    --dry-run=client -o yaml | $k apply -f - || true

$h upgrade -i --wait --timeout 300s cdfcrew chart -f - <<EOF
fullnameOverride: cdfcrew
imagePullSecret: ${REGISTRY_SECRET_NAME}

http:
  hostname: ${HOSTNAME}
  tlsSecret: ${TLS_SECRET_NAME}
EOF