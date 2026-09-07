# Baut InventarApp.exe aus Launcher.cs mit dem C#-Compiler, der bei
# jedem Windows mit .NET Framework 4 (praktisch immer) schon dabei ist -
# kein Download, keine Installation noetig. Einmal ausfuehren, danach
# einfach InventarApp.exe verwenden (Doppelklick, kein sichtbares
# PowerShell-Fenster mehr, echtes .exe-Icon).

$Basis  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Quelle = Join-Path $Basis "Launcher.cs"
$Ziel   = Join-Path $Basis "InventarApp.exe"

$Csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $Csc)) { $Csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" }

if (-not (Test-Path $Csc)) {
    Write-Host "C#-Compiler (csc.exe) nicht gefunden - .NET Framework 4 pruefen." -ForegroundColor Red
    Read-Host "Taste druecken zum Schliessen"
    exit
}

& $Csc /nologo /target:winexe /out:"$Ziel" /reference:System.Windows.Forms.dll "$Quelle"

if (Test-Path $Ziel) {
    Write-Host "Fertig: $Ziel" -ForegroundColor Green
    Write-Host "Ab jetzt einfach InventarApp.exe doppelklicken." -ForegroundColor Green
} else {
    Write-Host "Fehlgeschlagen - Fehlermeldung oben pruefen." -ForegroundColor Red
}
Read-Host "Taste druecken zum Schliessen"
