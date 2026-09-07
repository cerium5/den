@echo off
pushd "%~dp0"
echo Starte InventarApp.ps1 ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0InventarApp.ps1" > "%~dp0diagnose.log" 2>&1
echo.
echo ============================================
echo  Inhalt von diagnose.log:
echo ============================================
type "%~dp0diagnose.log"
echo ============================================
popd
echo.
echo Dieses Fenster bleibt offen. diagnose.log liegt im selben Ordner -
echo bitte den Text oben (oder die Datei diagnose.log) weitergeben.
pause
