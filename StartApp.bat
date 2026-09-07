@echo off
REM pushd statt cd - kann im Gegensatz zu cd auch mit Netzlaufwerk-Pfaden
REM (UNC, z.B. \\ad.uni-hamburg.de\...) umgehen, indem es kurzzeitig einen
REM Laufwerksbuchstaben zuweist. Ohne das faellt cmd.exe sonst auf
REM C:\Windows zurueck und das Script findet seinen eigenen Ordner nicht.
pushd "%~dp0"
powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0InventarApp.ps1"
popd
