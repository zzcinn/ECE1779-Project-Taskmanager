# PowerShell deployment script for Windows
# Deploy Task Manager to DigitalOcean Kubernetes

$ErrorActionPreference = "Stop"

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Task Manager K8s Deployment Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Check if kubectl is installed
try {
    kubectl version --client | Out-Null
} catch {
    Write-Host "kubectl is not installed. Please install kubectl first." -ForegroundColor Red
    exit 1
}

# Check if we're connected to a cluster
try {
    kubectl cluster-info | Out-Null
    Write-Host "✓ Connected to Kubernetes cluster" -ForegroundColor Green
} catch {
    Write-Host "Not connected to a Kubernetes cluster. Please configure kubectl first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deploying Task Manager to Kubernetes..." -ForegroundColor Yellow
Write-Host ""

Write-Host "1. Creating namespace..." -ForegroundColor White
kubectl apply -f namespace.yaml

Write-Host "2. Creating secrets..." -ForegroundColor White
kubectl apply -f secrets.yaml
Write-Host "⚠ WARNING: Make sure to update the secrets in production!" -ForegroundColor Yellow

Write-Host "3. Creating ConfigMaps..." -ForegroundColor White
kubectl apply -f configmap.yaml
kubectl apply -f postgres-configmap.yaml

Write-Host "4. Creating Persistent Volume Claim for database..." -ForegroundColor White
kubectl apply -f postgres-pvc.yaml

Write-Host "5. Deploying PostgreSQL database..." -ForegroundColor White
kubectl apply -f postgres-statefulset.yaml
kubectl apply -f postgres-service.yaml

Write-Host "6. Waiting for PostgreSQL to be ready..." -ForegroundColor White
kubectl wait --for=condition=ready pod -l app=postgres -n taskmanager --timeout=300s

Write-Host "7. Deploying API service..." -ForegroundColor White
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml

Write-Host "8. Waiting for API pods to be ready..." -ForegroundColor White
kubectl wait --for=condition=ready pod -l app=taskmanager-api -n taskmanager --timeout=300s

Write-Host "9. Deploying Ingress..." -ForegroundColor White
if (Test-Path "ingress-basic.yaml") {
    Write-Host "Using basic ingress without SSL. Edit ingress.yaml for production setup." -ForegroundColor Yellow
    kubectl apply -f ingress-basic.yaml
} else {
    kubectl apply -f ingress.yaml
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""
Write-Host "To check the status of your deployment:"
Write-Host "  kubectl get all -n taskmanager"
Write-Host ""
Write-Host "To get the LoadBalancer IP address:"
Write-Host "  kubectl get ingress -n taskmanager"
Write-Host ""
Write-Host "To view logs:"
Write-Host "  kubectl logs -f -l app=taskmanager-api -n taskmanager"
Write-Host ""

