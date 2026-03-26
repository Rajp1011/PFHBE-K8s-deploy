#!/bin/bash

# ==========================
# CONFIG
# ==========================
NAMESPACE="ge-qa"
K8S_DIR="qa"
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
kubectl apply -f $K8S_DIR/qa-sentry-secret.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/qa-ge-pvc.yaml -n $NAMESPACE

echo "Waiting ${WAIT_STORAGE}s for Azure File Share binding..."
sleep $WAIT_STORAGE

# [2/4] CONFIG SEEDING - Docker Config Image from GHCR 

echo -e "\n[2/4] Seeding Configuration..."
kubectl delete job ge-config-qa -n $NAMESPACE --ignore-not-found
kubectl apply -f $K8S_DIR/qa-ge-config.yaml -n $NAMESPACE
echo "Waiting for Config Job to complete..."
kubectl wait --for=condition=complete job/ge-config-qa -n $NAMESPACE --timeout=180s

# [3/4] DEPLOY EVERYTHING ELSE
echo -e "\n[3/4] Deploying Redis, Shards, and Web..."
# Since YAMLs are now universal (using subPathExpr), we just apply them as-is
kubectl apply -f $K8S_DIR/qa-redis-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/qa-redis-service.yaml -n $NAMESPACE
sleep 5

kubectl apply -f $K8S_DIR/qa-geservice-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/qa-geservice-service.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/qa-geservice-hpa.yaml -n $NAMESPACE

kubectl apply -f $K8S_DIR/qa-geweb-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/qa-geweb-service.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/qa-geweb-hpa.yaml -n $NAMESPACE

kubectl apply -f $K8S_DIR/qa-ge-ingress.yaml -n $NAMESPACE

# [4/4] STATUS
echo -e "\n[4/4] FINAL STATUS"
echo "---------------------------------------------------------"
kubectl get pods -n $NAMESPACE

echo "For QA>> GE-Web Ingress URL > http://4.248.65.130/qa/swagger/index.html"

echo "\n========================================================="