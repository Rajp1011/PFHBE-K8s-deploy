@echo off
setlocal enableDelayedExpansion

REM ==========================
REM CONFIG
REM ==========================
set VERSION=v1.0.1

REM GHCR settings (MUST be lowercase)
set GHCR_REG=ghcr.io
set GHCR_OWNER=rajp1011
set GHCR_REPO=pfhbe
set GHCR_PATH=%GHCR_REG%/%GHCR_OWNER%/%GHCR_REPO%

set SERVICE_IMAGE=%GHCR_PATH%/geservice:%VERSION%
set WEB_IMAGE=%GHCR_PATH%/geweb:%VERSION%
set CONFIG_IMAGE=%GHCR_PATH%/geconfig:%VERSION%

set K8S=k8s
set WAIT_AFTER_PVC_APPLY=5

echo =========================================================
echo == DOCKER BUILD + PUSH (GHCR) + K8S APPLY (MINIKUBE)
echo =========================================================

REM ==========================
REM 1) BUILD IMAGES (LOCAL DOCKER)
REM ==========================
echo.
echo [1/6] Building Docker images locally...
docker build -t %SERVICE_IMAGE% -f Dockerfile .
if errorlevel 1 exit /b 1

docker build -t %WEB_IMAGE% -f Dockerfile.GEWeb .
if errorlevel 1 exit /b 1

docker build -t %CONFIG_IMAGE% -f GEService\Dockerfile.Config GEService
if errorlevel 1 exit /b 1

REM ==========================
REM 2) PUSH TO GHCR
REM ==========================
echo.
echo [2/6] Pushing images to GHCR...
docker push %SERVICE_IMAGE%
if errorlevel 1 exit /b 1

docker push %WEB_IMAGE%
if errorlevel 1 exit /b 1

docker push %CONFIG_IMAGE%
if errorlevel 1 exit /b 1

REM ==========================
REM 3) APPLY K8S (ORDERED)
REM ==========================
echo.
echo [3/6] Applying Kubernetes manifests (ordered)...

echo   - PVC
kubectl apply -f %K8S%\ge-pvc.yaml
timeout /t %WAIT_AFTER_PVC_APPLY% /nobreak >nul
kubectl get pvc

echo   - Config seed job
kubectl delete job ge-config --ignore-not-found >nul 2>&1
kubectl apply -f %K8S%\ge-config.yaml
kubectl wait --for=condition=complete job/ge-config --timeout=150s
kubectl logs job/ge-config

echo   - Redis
kubectl apply -f %K8S%\redis-deployment.yaml
kubectl apply -f %K8S%\redis-service.yaml

echo   - GE Service shards
kubectl apply -f %K8S%\geservice-deployment.yaml
kubectl apply -f %K8S%\geservice-service.yaml
kubectl apply -f %K8S%\geservice-hpa.yaml

echo   - GE Web
kubectl apply -f %K8S%\geweb-deployment.yaml
kubectl apply -f %K8S%\geweb-service.yaml
kubectl apply -f %K8S%\geweb-hpa.yaml

echo   - File Manager
kubectl apply -f %K8S%\filemanager.yaml
timeout /t %WAIT_AFTER_PVC_APPLY% /nobreak >nul

REM ==========================
REM 4) STATUS
REM ==========================
echo.
echo [4/6] STATUS
kubectl get pods
echo.
kubectl get svc

REM ==========================
REM 5) ACCESS
REM ==========================
echo.
echo [5/6] ACCESS INSTRUCTIONS
echo =========================================================
echo File Manager : minikube service filemanager-service
echo GE Web       : minikube service ge-web
echo.
echo == MONITORING URLs (Port-Forward) ======================
echo Grafana:    kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80
echo Prometheus: kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090
echo =========================================================

echo.
echo [6/6] DONE
endlocal
