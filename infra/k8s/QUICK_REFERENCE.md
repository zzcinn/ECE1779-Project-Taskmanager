# Kubernetes Quick Reference Guide

Quick commands for managing your Task Manager deployment on DigitalOcean Kubernetes.

## 🚀 Deployment

```bash
# Deploy everything
./deploy.sh          # Linux/Mac
./deploy.ps1         # Windows PowerShell

# Or using kustomize
kubectl apply -k .

# Deploy manually (step by step)
kubectl apply -f namespace.yaml
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml
kubectl apply -f postgres-configmap.yaml
kubectl apply -f postgres-pvc.yaml
kubectl apply -f postgres-statefulset.yaml
kubectl apply -f postgres-service.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml
kubectl apply -f ingress-basic.yaml
```

## 📊 Monitoring

```bash
# View all resources
kubectl get all -n taskmanager

# Watch pod status
kubectl get pods -n taskmanager -w

# Check pod details
kubectl describe pod <pod-name> -n taskmanager

# View events
kubectl get events -n taskmanager --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n taskmanager
kubectl top nodes
```

## 📝 Logs

```bash
# View API logs (all pods)
kubectl logs -f -l app=taskmanager-api -n taskmanager

# View specific pod logs
kubectl logs -f <pod-name> -n taskmanager

# View previous container logs (if crashed)
kubectl logs <pod-name> -n taskmanager --previous

# View database logs
kubectl logs -f postgres-0 -n taskmanager

# Tail last 100 lines
kubectl logs --tail=100 -l app=taskmanager-api -n taskmanager
```

## 🔧 Debugging

```bash
# Execute shell in pod
kubectl exec -it <pod-name> -n taskmanager -- /bin/sh

# Access database
kubectl exec -it postgres-0 -n taskmanager -- psql -U taskapp -d taskdb

# Port forward to local machine (access without ingress)
kubectl port-forward -n taskmanager svc/taskmanager-api-service 3000:3000

# Copy files from pod
kubectl cp taskmanager/<pod-name>:/app/file.txt ./file.txt

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgres-service.taskmanager.svc.cluster.local
```

## 🔄 Updates & Rollbacks

```bash
# Update to new image version
kubectl set image deployment/taskmanager-api api=registry.digitalocean.com/your-registry/taskmanager-api:v1.0.1 -n taskmanager

# Check rollout status
kubectl rollout status deployment/taskmanager-api -n taskmanager

# View rollout history
kubectl rollout history deployment/taskmanager-api -n taskmanager

# Rollback to previous version
kubectl rollout undo deployment/taskmanager-api -n taskmanager

# Rollback to specific revision
kubectl rollout undo deployment/taskmanager-api --to-revision=2 -n taskmanager

# Restart deployment (without changing image)
kubectl rollout restart deployment/taskmanager-api -n taskmanager

# Pause/Resume rollout
kubectl rollout pause deployment/taskmanager-api -n taskmanager
kubectl rollout resume deployment/taskmanager-api -n taskmanager
```

## ⚙️ Scaling

```bash
# Scale API replicas
kubectl scale deployment/taskmanager-api --replicas=3 -n taskmanager

# Autoscale based on CPU
kubectl autoscale deployment/taskmanager-api --cpu-percent=70 --min=2 --max=10 -n taskmanager

# View autoscaler status
kubectl get hpa -n taskmanager
```

## 🔐 Secrets & ConfigMaps

```bash
# View secrets (base64 encoded)
kubectl get secret taskmanager-secrets -n taskmanager -o yaml

# Decode secret
kubectl get secret taskmanager-secrets -n taskmanager -o jsonpath='{.data.postgres-password}' | base64 --decode

# Update secret
kubectl create secret generic taskmanager-secrets \
  --from-literal=postgres-password=newpassword \
  --dry-run=client -o yaml | kubectl apply -f -

# Edit configmap
kubectl edit configmap taskmanager-config -n taskmanager

# Restart pods to pick up config changes
kubectl rollout restart deployment/taskmanager-api -n taskmanager
```

## 🌐 Networking

```bash
# Get LoadBalancer IP
kubectl get svc -n ingress-nginx

# Get Ingress details
kubectl get ingress -n taskmanager
kubectl describe ingress taskmanager-ingress-basic -n taskmanager

# Test service connectivity
kubectl run -it --rm test --image=busybox --restart=Never -- wget -O- http://taskmanager-api-service.taskmanager.svc.cluster.local:3000/check
```

## 💾 Database Operations

```bash
# Connect to database
kubectl exec -it postgres-0 -n taskmanager -- psql -U taskapp -d taskdb

# Backup database
kubectl exec postgres-0 -n taskmanager -- pg_dump -U taskapp taskdb > backup.sql

# Restore database
cat backup.sql | kubectl exec -i postgres-0 -n taskmanager -- psql -U taskapp -d taskdb

# Check database size
kubectl exec postgres-0 -n taskmanager -- psql -U taskapp -d taskdb -c "SELECT pg_size_pretty(pg_database_size('taskdb'));"

# List tables
kubectl exec postgres-0 -n taskmanager -- psql -U taskapp -d taskdb -c "\dt"
```

## 🗑️ Cleanup

```bash
# Delete specific resources
kubectl delete deployment taskmanager-api -n taskmanager
kubectl delete statefulset postgres -n taskmanager

# Delete everything in namespace
kubectl delete all --all -n taskmanager

# Delete namespace (removes everything)
kubectl delete namespace taskmanager

# Run cleanup script
./cleanup.sh
```

## 🔍 Troubleshooting

```bash
# Pod stuck in Pending
kubectl describe pod <pod-name> -n taskmanager
kubectl get pvc -n taskmanager

# Pod CrashLoopBackOff
kubectl logs <pod-name> -n taskmanager --previous
kubectl describe pod <pod-name> -n taskmanager

# Service not accessible
kubectl get endpoints -n taskmanager
kubectl describe svc taskmanager-api-service -n taskmanager

# Ingress not working
kubectl get svc -n ingress-nginx
kubectl describe ingress -n taskmanager
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Check cluster health
kubectl get componentstatuses
kubectl get nodes
kubectl cluster-info dump
```

## 📦 Image Management

```bash
# Build and push new image
docker build -t taskmanager-api:v1.0.0 ../api/
docker tag taskmanager-api:v1.0.0 registry.digitalocean.com/your-registry/taskmanager-api:v1.0.0
docker push registry.digitalocean.com/your-registry/taskmanager-api:v1.0.0

# Update deployment with new image
./update.sh v1.0.0

# Force pull latest image
kubectl rollout restart deployment/taskmanager-api -n taskmanager
```

## 🔧 Cluster Management

```bash
# Connect to cluster
doctl kubernetes cluster kubeconfig save taskmanager-cluster

# List clusters
doctl kubernetes cluster list

# Get cluster info
doctl kubernetes cluster get taskmanager-cluster

# Upgrade cluster
doctl kubernetes cluster upgrade taskmanager-cluster

# Resize node pool
doctl kubernetes cluster node-pool update taskmanager-cluster worker-pool --count=3

# Delete cluster
doctl kubernetes cluster delete taskmanager-cluster
```

## 📊 Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods -n taskmanager'
alias kgs='kubectl get svc -n taskmanager'
alias kgi='kubectl get ingress -n taskmanager'
alias kl='kubectl logs -f -l app=taskmanager-api -n taskmanager'
alias kd='kubectl describe'
alias ke='kubectl exec -it'
alias kdb='kubectl exec -it postgres-0 -n taskmanager -- psql -U taskapp -d taskdb'
```

## 🆘 Emergency Commands

```bash
# Kill all pods (they will restart)
kubectl delete pods --all -n taskmanager

# Force delete stuck pod
kubectl delete pod <pod-name> -n taskmanager --grace-period=0 --force

# Emergency rollback
kubectl rollout undo deployment/taskmanager-api -n taskmanager

# Scale down everything
kubectl scale deployment/taskmanager-api --replicas=0 -n taskmanager

# Check for crashlooping pods
kubectl get pods -n taskmanager | grep -E 'CrashLoopBackOff|Error|ImagePullBackOff'
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [DigitalOcean Kubernetes Guide](https://docs.digitalocean.com/products/kubernetes/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Full Deployment Guide](./KUBERNETES_DEPLOYMENT.md)

