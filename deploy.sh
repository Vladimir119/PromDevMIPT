#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="custom-app:latest"

echo "Building Docker image: ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" -f app/Dockerfile app

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/app-configmap.yaml
kubectl apply -f k8s/app-pod.yaml
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml
kubectl apply -f k8s/log-agent-daemonset.yaml
kubectl apply -f k8s/app-statefulset-headless-service.yaml
kubectl apply -f k8s/app-statefulset.yaml
kubectl apply -f k8s/app-cronjob.yaml

echo "Waiting for test Pod to become ready..."
kubectl wait --for=condition=Ready pod/app-pod --timeout=120s

echo "Waiting for Deployment to become ready..."
kubectl rollout status deployment/app-deployment --timeout=120s
kubectl wait --for=condition=available deployment/app-deployment --timeout=120s

echo "Waiting for DaemonSet log-agent to become ready..."
kubectl rollout status daemonset/log-agent --timeout=120s

echo "Waiting for StatefulSet to become ready..."
kubectl rollout status statefulset/app-stateful --timeout=120s

echo "Ready."

echo "Use 'kubectl port-forward svc/app-service 5000:5000' to access the application on localhost:5000."
