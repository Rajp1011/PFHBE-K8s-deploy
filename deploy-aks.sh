#!/bin/bash

# ==========================
# CONFIG
# ==========================
NAMESPACE="ge-dev"
K8S_DIR="k8s"
WAIT_STORAGE=15

echo "========================================================="
echo "== AKS UNIVERSAL DEPLOYMENT: $NAMESPACE"
echo "========================================================="

# [0/4] AKS CONNECTION CHECK
echo "Checking AKS connection..."
if ! kubectl config current-context >/dev/null 2>&1; then
    echo "ERROR: Not connected to AKS. Run 'az aks get-credentials' first."
    exit 1
fi

# [1/4] INFRASTRUCTURE (Secrets & Storage)
echo -e "\n[1/4] Applying Storage and Secrets..."
kubectl apply -f $K8S_DIR/sentry-secret.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/ge-pvc.yaml -n $NAMESPACE

echo "Waiting ${WAIT_STORAGE}s for Azure File Share binding..."
sleep $WAIT_STORAGE

# [2/4] CONFIG RESOLUTION & WHITEBOARD UPDATE
echo -e "\n[2/4] Resolving latest release path from PVC..."

# This command follows the symlink and extracts the real folder name
REAL_PATH=$(kubectl run get-path --image=alpine --rm -i --restart=Never -n $NAMESPACE --overrides='
{
  "spec": {
    "containers": [{
      "name": "c", "image": "alpine", 
      "command": ["sh", "-c", "readlink -f /mnt/pvc/current | sed \"s|/mnt/pvc/||\""],
      "volumeMounts": [{"name": "v", "mountPath": "/mnt/pvc"}]
    }],
    "volumes": [{"name": "v", "persistentVolumeClaim": {"claimName": "ge-pvc"}}]
  }
}' 2>/dev/null | tr -d '\r' | grep "releases/GE-")

if [[ $REAL_PATH == releases/GE-* ]]; then
    echo "SUCCESS: Found Real Path: $REAL_PATH"
    
    # UPDATE THE CONFIGMAP (The Whiteboard)
    # This command creates it if it's missing, or updates it if it exists.
    echo "Updating ConfigMap 'ge-config-version' with path: $REAL_PATH"
    kubectl create configmap ge-config-version \
      --from-literal=path="$REAL_PATH" \
      -n $NAMESPACE -o yaml --dry-run=client | kubectl apply -f -
else
    echo "ERROR: Could not resolve symlink. Path detected: '$REAL_PATH'"
    exit 1
fi

# [3/4] DEPLOY EVERYTHING ELSE
echo -e "\n[3/4] Deploying Redis, Shards, and Web..."
# Since YAMLs are now universal (using subPathExpr), we just apply them as-is
kubectl apply -f $K8S_DIR/redis-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/redis-service.yaml -n $NAMESPACE
sleep 5

kubectl apply -f $K8S_DIR/geservice-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/geservice-service.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/geservice-hpa.yaml -n $NAMESPACE
sleep 5

kubectl apply -f $K8S_DIR/geweb-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/geweb-service.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/geweb-hpa.yaml -n $NAMESPACE

kubectl apply -f $K8S_DIR/ge-ingress.yaml -n $NAMESPACE

# [4/4] STATUS
echo -e "\n[4/4] FINAL STATUS"
echo "---------------------------------------------------------"
kubectl get pods -n $NAMESPACE

echo -e "\nDeployment complete. Everything is now pointing to: $REAL_PATH"
echo "GE-Web Ingress URL > http://4.248.65.130/swagger/index.html"

echo "\n========================================================="