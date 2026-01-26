@echo off
setlocal enableDelayedExpansion

REM ==========================
REM CONFIG
REM ==========================
set WAIT_AFTER_MINIKUBE_START=30

echo =========================================================
echo == MINIKUBE + MONITORING SETUP (EDGE-KUBERNETES / GHCR)
echo =========================================================

REM ==========================
REM 1) MINIKUBE
REM ==========================
echo.
echo [1/4] Starting Minikube...
minikube start --driver=docker --cpus=2 --memory=4000
if %ERRORLEVEL% NEQ 0 (
  echo [ERROR] minikube start failed.
  exit /b 1
)

echo.
echo [WAIT] %WAIT_AFTER_MINIKUBE_START%s for disks...
timeout /t %WAIT_AFTER_MINIKUBE_START% /nobreak >nul

echo.
echo [REPAIR] Grafana PVC locks (safe to run anytime)...
minikube ssh "sudo mkdir -p /var/lib/grafana"
minikube ssh "sudo rm -f /var/lib/grafana/grafana.db-lock /var/lib/grafana/grafana.db-journal"
minikube ssh "sudo chmod -R 777 /var/lib/grafana"
minikube ssh "sudo chown -R 472:472 /var/lib/grafana"

REM ==========================
REM 2) MONITORING (OPTIONAL)
REM ==========================
echo.
echo [2/4] Monitoring stack check...
kubectl get namespace monitoring >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Monitoring namespace not found.
    set /p SH_MON="Run monitoring.bat now? (Y/N): "
    if /I "!SH_MON!"=="Y" call monitoring.bat
) else (
    echo Monitoring detected. Restarting Grafana...
    kubectl rollout restart deployment prometheus-stack-grafana -n monitoring
)

REM ==========================
REM 3) DOCKER CONTEXT CHECK (EDGE-KUBERNETES)
REM ==========================
echo.
echo [3/4] Docker context check()... Should Be 'docker-desktop'
docker info | findstr "Name"

echo.
echo [4/4] DONE
echo [DONE] Setup completed.

echo =========================================================
echo SCRIPT OVERVIEW
echo =========================================================
echo publish.bat        ^> Build Release DLLs (GEService / GEWeb)
echo setup.bat          ^> Start Minikube + fix Grafana locks + check monitoring
echo monitoring.bat     ^> Setup monitoring (Prometheus, Grafana, Loki)
echo deploy.bat         ^> Build+Push GHCR images + deploy K8s + show status
echo =========================================================

endlocal
