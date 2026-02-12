#!/bin/bash

# ==========================
# CONFIG
# ==========================
NAMESPACE="ge-dev"
K8S_DIR="k8s"
WAIT_STORAGE=15

echo "========================================================="
echo "== AKS BASH DEPLOYMENT: $NAMESPACE"
echo "========================================================="

# [0/4] AKS CONNECTION CHECK
echo "Checking AKS connection..."
CURRENT_CONTEXT=$(kubectl config current-context)
if [ $? -ne 0 ]; then
    echo "ERROR: Not connected to AKS. Run 'az aks get-credentials' first."
    exit 1
fi
echo "Using context: $CURRENT_CONTEXT"

# [1/4] INFRASTRUCTURE (Secrets & Storage)
echo -e "\n[1/4] Applying Storage and Secrets..."
kubectl apply -f $K8S_DIR/sentry-secret.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/ge-pvc.yaml -n $NAMESPACE

echo "Waiting ${WAIT_STORAGE}s for Azure File Share binding..."
sleep $WAIT_STORAGE

# [2/4] CONFIG SEEDING
echo -e "\n[2/4] Seeding Configuration..."
kubectl delete job ge-config -n $NAMESPACE --ignore-not-found
kubectl apply -f $K8S_DIR/ge-config.yaml -n $NAMESPACE
echo "Waiting for Config Job to complete..."
kubectl wait --for=condition=complete job/ge-config -n $NAMESPACE --timeout=100s

# [3/4] DEPLOY EVERYTHING ELSE
echo -e "\n[3/4] Deploying Redis, Shards, and Web..."
# Using a single apply for the rest to be efficient
kubectl apply -f $K8S_DIR/redis-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/redis-service.yaml -n $NAMESPACE
sleep $WAIT_STORAGE
kubectl apply -f $K8S_DIR/geservice-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/geservice-service.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/geservice-hpa.yaml -n $NAMESPACE
sleep $WAIT_STORAGE
sleep $WAIT_STORAGE
kubectl apply -f $K8S_DIR/geweb-deployment.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/geweb-service.yaml -n $NAMESPACE
kubectl apply -f $K8S_DIR/geweb-hpa.yaml -n $NAMESPACE
sleep $WAIT_STORAGE
sleep $WAIT_STORAGE
kubectl apply -f $K8S_DIR/ge-ingress.yaml -n $NAMESPACE

# [4/4] STATUS
echo -e "\n[4/4] FINAL STATUS"
echo "---------------------------------------------------------"
kubectl get pods -n $NAMESPACE

echo "GE-Web Ingress URL > http://20.104.176.217/swagger/index.html "
echo "GE-Service1 Ingress URL > http://20.104.176.217/shard1/swagger/index.html "
echo "GE-Service2 Ingress URL > http://20.104.176.217/shard2/swagger/index.html "
echo "GE-Service3 Ingress URL > http://20.104.176.217/shard3/swagger/index.html "
echo "GE-Service4 Ingress URL > http://20.104.176.217/shard4/swagger/index.html "
echo "GE-Service5 Ingress URL > http://20.104.176.217/shard5/swagger/index.html "
echo -e "\nUpdated..! Wait couple more seconds to restart..."
