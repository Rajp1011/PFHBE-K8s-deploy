@echo off
setlocal

REM =========================================================
REM PUBLISH (Release)
REM =========================================================
REM IMPORTANT:
REM For a clean + fresh start, delete these folders before running:
REM   - GEService\publish
REM   - GEWeb\publish
REM (If you don't delete them, old files can remain and cause confusion.)
REM =========================================================

echo =========================================================
echo == PUBLISHING PROJECTS (Release)
echo =========================================================

dotnet publish GEService/GEService.csproj -c Release -o GEService/publish/ /p:UseAppHost=false
if %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Publish failed for GEService.
  exit /b 1
)

dotnet publish GEWeb/GEWeb.csproj -c Release -o GEWeb/publish/ /p:UseAppHost=false
if %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Publish failed for GEWeb.
  exit /b 1
)

echo.
echo [DONE] Publish completed successfully.

echo =========================================================
echo SCRIPT OVERVIEW
echo =========================================================
echo publish.bat        ^> Build Release DLLs (GEService / GEWeb)
echo setup.bat          ^> Start Minikube + fix Grafana locks + check monitoring
echo monitoring.bat     ^> Setup monitoring (Prometheus, Grafana, Loki) 
echo deploy.bat         ^> Build Docker images + deploy K8s + show status
echo =========================================================

endlocal
