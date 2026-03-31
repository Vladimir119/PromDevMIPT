$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$imageName = 'custom-app:latest'
Write-Host "Building Docker image: $imageName"
docker build -t $imageName -f app/Dockerfile app

Write-Host 'Applying Kubernetes manifests...'
kubectl apply -f k8s/app-configmap.yaml
kubectl apply -f k8s/app-pod.yaml
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml
kubectl apply -f k8s/log-agent-daemonset.yaml
kubectl apply -f k8s/app-statefulset-headless-service.yaml
kubectl apply -f k8s/app-statefulset.yaml
kubectl apply -f k8s/app-cronjob.yaml

Write-Host 'Waiting for test Pod to become ready...'
kubectl wait --for=condition=Ready pod/app-pod --timeout=120s

Write-Host 'Waiting for Deployment to become ready...'
kubectl rollout status deployment/app-deployment --timeout=120s
kubectl wait --for=condition=available deployment/app-deployment --timeout=120s

Write-Host 'Waiting for DaemonSet log-agent to become ready...'
kubectl rollout status daemonset/log-agent --timeout=120s

Write-Host 'Waiting for StatefulSet to become ready...'
kubectl rollout status statefulset/app-stateful --timeout=120s

Write-Host 'Ready.'
Write-Host "Use 'kubectl port-forward svc/app-service 5000:5000' to access the application on localhost:5000."
