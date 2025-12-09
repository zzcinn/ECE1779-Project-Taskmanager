#!/bin/bash

# Script to rollback the API deployment

set -e

echo "Rolling back API deployment..."

kubectl rollout undo deployment/taskmanager-api -n taskmanager

echo "Waiting for rollback to complete..."
kubectl rollout status deployment/taskmanager-api -n taskmanager

echo "Rollback completed successfully!"
echo ""
echo "To see rollout history:"
echo "  kubectl rollout history deployment/taskmanager-api -n taskmanager"

