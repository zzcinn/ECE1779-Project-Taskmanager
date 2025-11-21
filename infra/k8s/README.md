# Kubernetes Configuration Files

This directory contains all Kubernetes manifests and deployment scripts for the Task Manager application.

## 📁 File Structure

```
k8s/
├── README.md                      # This file
├── KUBERNETES_DEPLOYMENT.md       # Complete deployment guide
├── QUICK_REFERENCE.md            # Quick command reference
├── DEMO_SETUP.md                 # Demo users and data setup guide
│
├── namespace.yaml                # Namespace definition
├── secrets.yaml                  # Sensitive data (passwords, keys)
├── configmap.yaml                # Application configuration
├── postgres-configmap.yaml       # Database initialization script
│
├── postgres-pvc.yaml             # Persistent storage for database
├── postgres-statefulset.yaml     # PostgreSQL database
├── postgres-service.yaml         # Database service
│
├── api-deployment.yaml           # API application deployment
├── api-service.yaml              # API service
│
├── ingress.yaml                  # Ingress with SSL/domain support
├── ingress-basic.yaml            # Simple ingress without SSL
│
├── kustomization.yaml            # Kustomize configuration
│
├── deploy.sh                     # Deployment script (Linux/Mac)
├── deploy.ps1                    # Deployment script (Windows)
├── update.sh                     # Update script
├── rollback.sh                   # Rollback script
├── cleanup.sh                    # Cleanup script
├── demo-realtime.ps1             # Real-time events demo (Windows)
└── demo-realtime.sh              # Real-time events demo (Linux/Mac)
```

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster running (DigitalOcean recommended)
- `kubectl` configured and connected to your cluster
- Docker image built and pushed to a registry

### Deploy

**Linux/Mac:**
```bash
chmod +x *.sh
./deploy.sh
```

**Windows PowerShell:**
```powershell
.\deploy.ps1
```

**Using kubectl directly:**
```bash
kubectl apply -k .
```

## ⚙️ Configuration

### Before Deploying

1. **Update Secrets** (`secrets.yaml`):
   - Change all default passwords
   - Generate new session secrets
   - Never commit real secrets to git!

2. **Update Image Registry** (`api-deployment.yaml`):
   - Replace `REPLACE_WITH_YOUR_IMAGE_REGISTRY` with your actual registry URL
   - Example: `registry.digitalocean.com/your-registry/taskmanager-api:latest`

3. **Update Domain** (optional, `ingress.yaml`):
   - Replace `taskmanager.yourdomain.com` with your actual domain
   - Or use `ingress-basic.yaml` for IP-based access

## 📖 Documentation

- **[KUBERNETES_DEPLOYMENT.md](./KUBERNETES_DEPLOYMENT.md)** - Complete step-by-step deployment guide
- **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** - Quick command reference

## 🔧 Common Tasks

### Check Status
```bash
kubectl get all -n taskmanager
```

### View Logs
```bash
kubectl logs -f -l app=taskmanager-api -n taskmanager
```

### Update Application
```bash
./update.sh v1.0.1
```

### Rollback
```bash
./rollback.sh
```

### Access Database
```bash
kubectl exec -it postgres-0 -n taskmanager -- psql -U taskapp -d taskdb
```

### Get LoadBalancer IP
```bash
kubectl get ingress -n taskmanager
```

### Test Real-time Features
```bash
# Windows
.\demo-realtime.ps1

# Linux/Mac
chmod +x demo-realtime.sh
./demo-realtime.sh
```

This will demonstrate Socket.IO real-time events by opening the realtime.html page and performing various task operations. Watch as events appear instantly!

## 🆘 Troubleshooting

See [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) for debugging commands and solutions to common issues.

## 🗑️ Cleanup

To completely remove the application:
```bash
./cleanup.sh
```

## 📝 Notes

- The database uses a PersistentVolumeClaim for data persistence
- The API is configured for 2 replicas by default
- Socket.IO is configured with sticky sessions for proper WebSocket support
- All resources are deployed in the `taskmanager` namespace

## 🔐 Security Reminders

- ⚠️ Always update default passwords in production
- ⚠️ Use SSL/TLS for production deployments
- ⚠️ Never commit secrets to version control
- ⚠️ Regularly update Docker images for security patches
- ⚠️ Consider using a managed database service for production

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [DigitalOcean Kubernetes](https://docs.digitalocean.com/products/kubernetes/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

