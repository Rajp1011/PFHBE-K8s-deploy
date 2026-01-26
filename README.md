# Pong Game Studios – GE Platform Deployment Guide

This guide explains how to deploy the **GE Platform** using **prebuilt Docker images** and **Kubernetes manifests**, without requiring source code.

---

## 1. What Is Included

You will be provided with:

### Docker Images (prebuilt)

* `ghcr.io/rajp1011/pfhbe/geservice:<tag>`
* `ghcr.io/rajp1011/pfhbe/geweb:<tag>`
* `ghcr.io/rajp1011/pfhbe/geconfig:<tag>`

These images already contain:

* Compiled binaries (DLLs)
* Runtime dependencies
* Configuration seeding logic (via `geconfig` job)

### Kubernetes Manifests

* `ge-service.yaml` (GE Service deployments + services)
* `ge-web.yaml` (Web deployment + service)
* `ge-config.yaml` (Job to seed PVC)
* `ge-service-pvc.yaml` (PersistentVolumeClaim)
* `redis-deployment.yaml` (Redis)
* Optional: HPA, monitoring manifests

> **Source code is NOT required to run the system.**

---

## 2. High-Level Architecture

* **GE Config Job** seeds configuration data into a shared PVC
* **GE Service shards (1–5)** read config from PVC (read-only)
* **GE Web** routes requests to GE Service shards
* **Redis** is used for shared state / caching
* All workloads run inside Kubernetes

---

## 3. Prerequisites

### Kubernetes Cluster

One of the following:

* Minikube (single node)
* AKS / managed Kubernetes (single node or pinned workloads)

### Tools

* `kubectl`
* Container runtime (Docker / containerd)

### Registry Access

Images may be:

* **Public** → no authentication required
* **Private (GHCR)** → requires registry credentials

---

## 4. Registry Authentication (If Images Are Private)

Create a GitHub token **on your own account** with:

* `read:packages`

Then create a Kubernetes pull secret:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-token> \
  --docker-email=<your-email>
```

Ensure all Deployments and Jobs reference:

```yaml
imagePullSecrets:
- name: ghcr-pull-secret
```

> ⚠️ Do NOT use or share another person’s PAT.

---

## 5. Storage Requirements (Important)

### Persistent Volume Claim

The platform requires a PVC named:

```
ge-service-config-pvc
```

Requirements:

* Access mode: `ReadWriteOnce`
* Size: minimum **2–5 GB** (recommend 10+ GB for growth)
* Single-node attachment

### Notes

* Only the **config job** writes to the PVC
* All GE Service pods mount it **read-only**
* On multi-node clusters, pods must be pinned to the same node

---

## 6. Redis Requirement

GE Services expect Redis at:

```
redis.default.svc.cluster.local:6379
```

Options:

* Deploy provided `redis-deployment.yaml`
* Or update environment variables to point to an external Redis

If Redis is unavailable, GE Service pods will fail startup.

---

## 7. Deployment Order (Critical)

Apply manifests **in this exact order**:

```bash
kubectl apply -f ge-pvc.yaml

kubectl delete job ge-config --ignore-not-found
kubectl apply -f ge-config.yaml
kubectl wait --for=condition=complete job/ge-config --timeout=180s

kubectl apply -f redis-deployment.yaml
kubectl apply -f redis-service.yaml

kubectl apply -f geservice-deployment.yaml
kubectl apply -f geservice-service.yaml
kubectl apply -f geservice-hpa.yaml

kubectl apply -f geweb-deployment.yaml
kubectl apply -f geweb-service.yaml
kubectl apply -f geweb-hpa.yaml

kubectl apply -f filemanager.yaml

```

---

## 8. Verifying Deployment

Check pod status:

```bash
kubectl get pods
```

Expected:

* `ge-config` → **Completed**
* All GE Service pods → **Running**
* `ge-web` → **Running**
* Redis → **Running**

If a pod is stuck:

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

---

## 9. Accessing the Application

### Minikube

```bash
minikube service ge-web
```

### Cloud (AKS / others)

* Use `Service: LoadBalancer` or
* Configure Ingress + DNS + TLS

---

## 10. Common Failure Causes

| Issue            | Cause                             |
| ---------------- | --------------------------------- |
| ImagePullBackOff | Missing / invalid registry secret |
| CrashLoopBackOff | Redis unavailable or bad config   |
| Pods stuck Init  | PVC not mounted or empty          |
| PVC Pending      | StorageClass mismatch             |

---
