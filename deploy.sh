#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PATH="${HOME}/.istioctl/bin:${PATH}"
export PATH

IMAGE_NAME="custom-app:latest"

setup_istio() {
  echo "Configuring Istio service mesh..."
  if ! command -v istioctl >/dev/null 2>&1; then
    echo "Installing istioctl into ~/.istioctl/bin..."
    curl -sL https://istio.io/downloadIstioctl | sh -
    PATH="${HOME}/.istioctl/bin:${PATH}"
    export PATH
  fi
  if ! kubectl get deployment istiod -n istio-system >/dev/null 2>&1; then
    istioctl install -y
  fi
  kubectl rollout status deployment/istiod -n istio-system --timeout=300s
  kubectl rollout status deployment/istio-ingressgateway -n istio-system --timeout=300s
  kubectl label namespace default istio-injection=enabled --overwrite
}

setup_istio

echo "Building Docker image: ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" -f app/Dockerfile app

echo "Recreating standalone test pod so Istio sidecar is injected..."
kubectl delete pod app-pod --ignore-not-found

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/app-configmap.yaml
kubectl apply -f k8s/app-pod.yaml
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml
kubectl apply -f k8s/log-service.yaml
kubectl apply -f k8s/log-agent-daemonset.yaml
kubectl apply -f k8s/app-statefulset-headless-service.yaml
kubectl apply -f k8s/app-statefulset.yaml
kubectl apply -f k8s/app-cronjob.yaml

echo "Applying Istio networking resources..."
kubectl apply -f k8s/gateway.yaml
kubectl apply -f k8s/virtual-service.yaml
kubectl apply -f k8s/destination-rule-app-service.yaml
kubectl apply -f k8s/destination-rule-log-service.yaml

echo "Restarting workloads so sidecars are injected where needed..."
kubectl rollout restart deployment/app-deployment
kubectl rollout restart daemonset/log-agent
kubectl rollout restart statefulset/app-stateful

echo "Waiting for test Pod to become ready..."
kubectl wait --for=condition=Ready pod/app-pod --timeout=120s

echo "Waiting for Deployment to become ready..."
kubectl rollout status deployment/app-deployment --timeout=180s
kubectl wait --for=condition=available deployment/app-deployment --timeout=120s

echo "Waiting for DaemonSet log-agent to become ready..."
kubectl rollout status daemonset/log-agent --timeout=180s

echo "Waiting for StatefulSet to become ready..."
kubectl rollout status statefulset/app-stateful --timeout=180s

echo "Ready."

INGRESS_IP="$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
INGRESS_HOST="$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
echo "Istio Ingress gateway: kubectl get svc istio-ingressgateway -n istio-system"
if [[ -n "${INGRESS_IP}" ]]; then
  echo "HTTP via Istio (port 80): curl -s \"http://${INGRESS_IP}/\""
elif [[ -n "${INGRESS_HOST}" ]]; then
  echo "HTTP via Istio (port 80): curl -s \"http://${INGRESS_HOST}/\""
else
  echo "Expose port 80, e.g.: kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
  echo "Then: curl -s http://127.0.0.1:8080/"
fi
echo "Local app port-forward (no Istio): kubectl port-forward svc/app-service 5000:5000"
