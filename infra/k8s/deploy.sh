#!/bin/bash

# Deployment script for DigitalOcean Kubernetes
# This script deploys the Task Manager application to a Kubernetes cluster

set -e

echo "=================================="
echo "Task Manager K8s Deployment Script"
echo "=================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if we're connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Not connected to a Kubernetes cluster. Please configure kubectl first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"

# Apply manifests in order
echo ""
echo "Deploying Task Manager to Kubernetes..."
echo ""

echo "1. Creating namespace..."
kubectl apply -f namespace.yaml

echo "2. Creating secrets..."
kubectl apply -f secrets.yaml
echo -e "${YELLOW}⚠ WARNING: Make sure to update the secrets in production!${NC}"

echo "3. Creating ConfigMaps..."
kubectl apply -f configmap.yaml
kubectl apply -f postgres-configmap.yaml

echo "4. Creating Persistent Volume Claim for database..."
kubectl apply -f postgres-pvc.yaml

echo "5. Deploying PostgreSQL database..."
kubectl apply -f postgres-statefulset.yaml
kubectl apply -f postgres-service.yaml

echo "6. Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n taskmanager --timeout=300s

echo "7. Deploying API service..."
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml

echo "8. Waiting for API pods to be ready..."
kubectl wait --for=condition=ready pod -l app=taskmanager-api -n taskmanager --timeout=300s

echo "9. Deploying Ingress..."
# Check if user wants basic or full ingress
if [ -f "ingress-basic.yaml" ]; then
    echo -e "${YELLOW}Using basic ingress without SSL. Edit ingress.yaml for production setup with domain and SSL.${NC}"
    kubectl apply -f ingress-basic.yaml
else
    kubectl apply -f ingress.yaml
fi

echo ""
echo -e "${GREEN}=================================="
echo "Deployment Complete!"
echo "==================================${NC}"
echo ""
echo "To check the status of your deployment:"
echo "  kubectl get all -n taskmanager"
echo ""
echo "To get the LoadBalancer IP address:"
echo "  kubectl get ingress -n taskmanager"
echo ""
echo "To view logs:"
echo "  kubectl logs -f -l app=taskmanager-api -n taskmanager"
echo ""
echo "To access the database (for debugging):"
echo "  kubectl exec -it postgres-0 -n taskmanager -- psql -U taskapp -d taskdb"
echo ""

