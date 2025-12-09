# Kubernetes Deployment Guide for DigitalOcean

This guide will walk you through deploying the Task Manager application to DigitalOcean Kubernetes (DOKS).

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [DigitalOcean Setup](#digitalocean-setup)
3. [Building and Pushing Docker Image](#building-and-pushing-docker-image)
4. [Deploying to Kubernetes](#deploying-to-kubernetes)
5. [Accessing Your Application](#accessing-your-application)
6. [Updating Your Application](#updating-your-application)
7. [Troubleshooting](#troubleshooting)
8. [Cost Optimization](#cost-optimization)

## Prerequisites

Before starting, ensure you have:

- A DigitalOcean account
- `kubectl` installed on your local machine
- `doctl` (DigitalOcean CLI) installed
- Docker installed locally (for building images)
- A domain name (optional, but recommended for production)

### Install Required Tools

**kubectl:**
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Windows (using Chocolatey)
choco install kubernetes-cli
```

**doctl:**
```bash
# macOS
brew install doctl

# Linux/Windows: Download from https://github.com/digitalocean/doctl/releases
```

## DigitalOcean Setup

### 1. Create a Kubernetes Cluster

**Via DigitalOcean Web Console:**
1. Go to https://cloud.digitalocean.com/kubernetes/clusters
2. Click "Create Cluster"
3. Choose your settings:
   - **Region**: Choose closest to your users
   - **Kubernetes version**: Latest stable version
   - **Node pool**: Start with 2-3 nodes (2GB RAM, 1 vCPU each)
   - **Name**: `taskmanager-cluster`
4. Click "Create Cluster"

**Via doctl CLI:**
```bash
# Authenticate with DigitalOcean
doctl auth init

# List available Kubernetes versions
doctl kubernetes options versions

# Create cluster
doctl kubernetes cluster create taskmanager-cluster \
  --region nyc1 \
  --version 1.28.2-do.0 \
  --node-pool "name=worker-pool;size=s-2vcpu-4gb;count=2"
```

### 2. Configure kubectl

```bash
# Get cluster credentials
doctl kubernetes cluster kubeconfig save taskmanager-cluster

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 3. Create Container Registry (Recommended)

```bash
# Create a registry via web console or CLI
doctl registry create taskmanager-registry

# Login to registry
doctl registry login
```

## Building and Pushing Docker Image

### 1. Build the Docker Image

From the project root:

```bash
cd api

# Build the image
docker build -t taskmanager-api:latest .

# Tag for DigitalOcean Container Registry
docker tag taskmanager-api:latest registry.digitalocean.com/taskmanager-registry/taskmanager-api:latest

# Or tag with version
docker tag taskmanager-api:latest registry.digitalocean.com/taskmanager-registry/taskmanager-api:v1.0.0
```

### 2. Push to Container Registry

```bash
# Push the image
docker push registry.digitalocean.com/taskmanager-registry/taskmanager-api:latest
docker push registry.digitalocean.com/taskmanager-registry/taskmanager-api:v1.0.0

# Verify
doctl registry repository list-v2
```

### 3. Update Kubernetes Manifest

Edit `infra/k8s/api-deployment.yaml` and replace:

```yaml
image: REPLACE_WITH_YOUR_IMAGE_REGISTRY/taskmanager-api:latest
```

With:

```yaml
image: registry.digitalocean.com/taskmanager-registry/taskmanager-api:latest
```

## Deploying to Kubernetes

### 1. Update Secrets (IMPORTANT!)

Before deploying, edit `infra/k8s/secrets.yaml` and change the default passwords and secrets:

```yaml
stringData:
  postgres-password: YOUR_STRONG_PASSWORD_HERE
  session-secret: YOUR_SESSION_SECRET_HERE
  jwt-secret: YOUR_JWT_SECRET_HERE
```

Generate strong secrets using:
```bash
# Generate random secrets
openssl rand -base64 32
```

### 2. Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/do/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 3. Deploy Application

Navigate to the k8s directory:

```bash
cd infra/k8s

# Make scripts executable
chmod +x *.sh

# Run deployment script
./deploy.sh
```

Or deploy manually:

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Create secrets and configs
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml
kubectl apply -f postgres-configmap.yaml

# Deploy database
kubectl apply -f postgres-pvc.yaml
kubectl apply -f postgres-statefulset.yaml
kubectl apply -f postgres-service.yaml

# Wait for database
kubectl wait --for=condition=ready pod -l app=postgres -n taskmanager --timeout=300s

# Deploy API
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml

# Wait for API
kubectl wait --for=condition=ready pod -l app=taskmanager-api -n taskmanager --timeout=300s

# Deploy Ingress
kubectl apply -f ingress-basic.yaml
```

### 4. Verify Deployment

```bash
# Check all resources
kubectl get all -n taskmanager

# Check pods status
kubectl get pods -n taskmanager

# Check logs
kubectl logs -f -l app=taskmanager-api -n taskmanager
```

## Accessing Your Application

### Get LoadBalancer IP

```bash
kubectl get ingress -n taskmanager

# Or get the LoadBalancer service directly
kubectl get svc -n ingress-nginx
```

You should see output like:
```
NAME                       CLASS    HOSTS   ADDRESS          PORTS   AGE
taskmanager-ingress-basic  <none>   *       157.245.xxx.xxx  80      2m
```

Access your application at: `http://157.245.xxx.xxx`

### Configure Domain (Optional)

1. Add an A record in your DNS settings:
   ```
   Type: A
   Name: taskmanager
   Value: 157.245.xxx.xxx (your LoadBalancer IP)
   ```

2. Update `infra/k8s/ingress.yaml`:
   ```yaml
   spec:
     rules:
     - host: taskmanager.yourdomain.com
   ```

3. Apply the updated ingress:
   ```bash
   kubectl apply -f ingress.yaml
   ```

### Setup SSL/TLS (Recommended for Production)

Install cert-manager:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

Create ClusterIssuer:
```yaml
# cert-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply and use `ingress.yaml` instead of `ingress-basic.yaml`.

## Updating Your Application

### Update to New Version

```bash
# Build new version
cd api
docker build -t taskmanager-api:v1.0.1 .
docker tag taskmanager-api:v1.0.1 registry.digitalocean.com/taskmanager-registry/taskmanager-api:v1.0.1
docker push registry.digitalocean.com/taskmanager-registry/taskmanager-api:v1.0.1

# Update deployment
cd ../infra/k8s
./update.sh v1.0.1
```

### Rollback to Previous Version

```bash
./rollback.sh
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n taskmanager
kubectl describe pod <pod-name> -n taskmanager
```

### View Logs
```bash
# API logs
kubectl logs -f -l app=taskmanager-api -n taskmanager

# Database logs
kubectl logs -f postgres-0 -n taskmanager

# Previous container logs (if crashed)
kubectl logs <pod-name> -n taskmanager --previous
```

### Access Database
```bash
kubectl exec -it postgres-0 -n taskmanager -- psql -U taskapp -d taskdb
```

### Common Issues

**Pods stuck in Pending:**
- Check if PVC is bound: `kubectl get pvc -n taskmanager`
- Check node resources: `kubectl describe nodes`

**Pods CrashLoopBackOff:**
- Check logs: `kubectl logs <pod-name> -n taskmanager`
- Check secrets/configmaps are correct

**Can't connect to database:**
- Verify database is running: `kubectl get pods -n taskmanager -l app=postgres`
- Check database logs: `kubectl logs postgres-0 -n taskmanager`
- Verify service exists: `kubectl get svc postgres-service -n taskmanager`

**Ingress not working:**
- Check NGINX controller: `kubectl get pods -n ingress-nginx`
- Check ingress: `kubectl describe ingress -n taskmanager`
- Verify LoadBalancer IP: `kubectl get svc -n ingress-nginx`

## Cost Optimization

### Reduce Node Count
For development/testing, you can use 1 node:
```bash
doctl kubernetes cluster node-pool update taskmanager-cluster worker-pool --count=1
```

### Use Smaller Nodes
Start with smaller droplets:
- `s-1vcpu-2gb` for development
- `s-2vcpu-4gb` for production

### Use DigitalOcean Managed Database (Alternative)
Instead of running PostgreSQL in cluster:
1. Create Managed PostgreSQL database in DigitalOcean
2. Update `configmap.yaml` with database connection details
3. Remove `postgres-*.yaml` files from deployment
4. This is more reliable but costs more

### Enable Cluster Autoscaling
```bash
doctl kubernetes cluster update taskmanager-cluster \
  --auto-upgrade=true \
  --surge-upgrade=true
```

## Clean Up

To completely remove the application:

```bash
cd infra/k8s
./cleanup.sh
```

To delete the entire cluster:
```bash
doctl kubernetes cluster delete taskmanager-cluster
```

## Next Steps

- Set up monitoring with Prometheus/Grafana
- Configure backup for PostgreSQL data
- Set up CI/CD pipeline (GitHub Actions, GitLab CI)
- Implement horizontal pod autoscaling
- Add resource limits and requests tuning
- Set up logging aggregation (ELK stack)

## Support

For issues specific to:
- **DigitalOcean Kubernetes**: https://docs.digitalocean.com/products/kubernetes/
- **Kubernetes**: https://kubernetes.io/docs/
- **This Application**: Check the main README.md

