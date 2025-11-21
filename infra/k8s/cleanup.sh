#!/bin/bash

# Script to completely remove the Task Manager application from Kubernetes

set -e

echo "=================================="
echo "Task Manager Cleanup Script"
echo "=================================="
echo ""
echo "WARNING: This will delete ALL resources in the taskmanager namespace,"
echo "including the database and all data!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Deleting all resources..."

# Delete in reverse order
kubectl delete -f ingress.yaml --ignore-not-found=true 2>/dev/null || true
kubectl delete -f ingress-basic.yaml --ignore-not-found=true 2>/dev/null || true
kubectl delete -f api-service.yaml --ignore-not-found=true
kubectl delete -f api-deployment.yaml --ignore-not-found=true
kubectl delete -f postgres-service.yaml --ignore-not-found=true
kubectl delete -f postgres-statefulset.yaml --ignore-not-found=true
kubectl delete -f postgres-pvc.yaml --ignore-not-found=true
kubectl delete -f postgres-configmap.yaml --ignore-not-found=true
kubectl delete -f configmap.yaml --ignore-not-found=true
kubectl delete -f secrets.yaml --ignore-not-found=true

# Wait a bit for resources to be deleted
sleep 5

# Delete the namespace (this will delete any remaining resources)
kubectl delete namespace taskmanager --ignore-not-found=true

echo ""
echo "Cleanup complete!"

