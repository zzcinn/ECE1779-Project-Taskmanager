#!/bin/bash

# Script to update the API deployment with a new image

set -e

if [ -z "$1" ]; then
    echo "Usage: ./update.sh <image-tag>"
    echo "Example: ./update.sh v1.0.1"
    exit 1
fi

IMAGE_TAG=$1
IMAGE_REGISTRY="REPLACE_WITH_YOUR_IMAGE_REGISTRY"

echo "Updating API deployment with image: ${IMAGE_REGISTRY}/taskmanager-api:${IMAGE_TAG}"

kubectl set image deployment/taskmanager-api api=${IMAGE_REGISTRY}/taskmanager-api:${IMAGE_TAG} -n taskmanager

echo "Waiting for rollout to complete..."
kubectl rollout status deployment/taskmanager-api -n taskmanager

echo "Deployment updated successfully!"

