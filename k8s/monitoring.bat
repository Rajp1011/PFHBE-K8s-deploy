@echo off
setlocal enableDelayedExpansion

REM === CONFIGURATION ===
set MONITOR_NAMESPACE=monitoring
set GRAFANA_FIX_FILE=grafana-fix.yaml
set MONITOR_MANIFEST=monitor.yaml

echo =========================================================
echo == MONITORING STACK DEPLOYMENT STARTING                ==
echo =========================================================

:: -----------------------------------------------------------
:: STEP 1: NAMESPACE SETUP
:: -----------------------------------------------------------
echo [1/4] Ensuring %MONITOR_NAMESPACE% namespace exists...
:: This checks if namespace exists; if not, it creates it.
kubectl get namespace %MONITOR_NAMESPACE% >nul 2>&1
if ERRORLEVEL 1 (
    kubectl create namespace %MONITOR_NAMESPACE%
) else (
    echo Namespace already exists. Keeping existing data.
)

:: -----------------------------------------------------------
:: STEP 2: INSTALL PROMETHEUS & GRAFANA
:: -----------------------------------------------------------
echo [2/4] Installing Prometheus stack (Persistence: 2Gi)...
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack ^
 --namespace %MONITOR_NAMESPACE% ^
 -f %GRAFANA_FIX_FILE% ^
 --set grafana.adminPassword=admin ^
 --set grafana.persistence.enabled=true ^
 --set grafana.persistence.storageClass=standard ^
 --set grafana.persistence.size=2Gi ^
 --set grafana.podSecurityContext.fsGroup=472 ^
 --set grafana.containerSecurityContext.runAsUser=472

if ERRORLEVEL 1 (
    echo ! ERROR: Prometheus installation failed.
    exit /b 1
)

:: -----------------------------------------------------------
:: STEP 3: INSTALL LOKI & PROMTAIL
:: -----------------------------------------------------------
echo [3/4] Installing Loki stack (Persistence: 2Gi)...
helm upgrade --install loki grafana/loki-stack ^
 --namespace %MONITOR_NAMESPACE% ^
 --set loki.image.tag=2.9.7 ^
 --set loki.persistence.enabled=true ^
 --set loki.persistence.storageClass=standard ^
 --set loki.persistence.size=2Gi ^
 --set loki.config.common.ring.kvstore.store=inmemory ^
 --set promtail.enabled=true ^
 --set promtail.config.clients[0].url=http://loki:3100/loki/api/v1/push

if ERRORLEVEL 1 (
    echo ! ERROR: Loki installation failed.
    exit /b 1
)

:: -----------------------------------------------------------
:: STEP 4: APPLY SERVICEMONITOR
:: -----------------------------------------------------------
echo [4/4] Applying ServiceMonitor for App metrics...
kubectl apply -f %MONITOR_MANIFEST%
echo.

:: ===========================================================
:: MONITORING MAINTENANCE COMMANDS (For Manual Use)
:: ===========================================================

:: 1. TO RESTART (Refresh pods without changing any data)
:: kubectl rollout restart deployment/prometheus-stack-grafana -n monitoring

:: 2. TO SEE HISTORY (See every time you ran your script)
:: helm history prometheus-stack -n monitoring

:: 3. TO ROLLBACK (Go back to a previous stable setup)
:: helm rollback prometheus-stack [REVISION_NUMBER] -n monitoring

:: 4. TO CHECK STATUS (Real-time view of your rollout)
:: kubectl rollout status deployment/prometheus-stack-grafana -n monitoring

:: 5. TO CHECK STATUS (Monitoring Pods) - wait for 30-60 seconds
:: kubectl get pods -n monitoring

endlocal