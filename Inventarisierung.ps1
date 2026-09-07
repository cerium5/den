# =====================================================
#  Inventarisierung - Erfassung vor Ort
#  CSV-Spalten passen zum Snipe-IT Export
#  Modi:
#    1) Rechner des Users steht bereit
#    2) User nicht da - eigenes Notebook am Monitor
#    3) Alles manuell (Tower aus, Drucker, Lager)
# =====================================================

$ErrorActionPreference = "SilentlyContinue"

$Basis   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CsvPfad = Join-Path $Basis "Inventar.csv"

# Panel-Hersteller interner Notebook-Displays (werden uebersprungen)
$InterneDisplays = @("LGD","AUO","BOE","CMN","SHP","IVO","CSO","SDC","LEN","PNP")

function Neue-Zeile {
    param(
        $AssetTag, $AssetName, $Serial, $Modell, $Kategorie,
        $Standort, $Raum, $Hostname, $Hersteller, $Benutzer,
        $OS, $Ram, $Mac, $Ip, $Notiz
    )
    [PSCustomObject]@{
        "Asset Tag"        = $AssetTag
        "Asset Name"       = $AssetName
        "Seriennummer"     = $Serial
        "Modell"           = $Modell
        "Kategorie"        = $Kategorie
        "Status"           = "Einsetzbar"
        "Herausgegeben an" = ""
        "Standort"         = $Standort
        "Einkaufspreis"    = ""
        "Aktueller Wert"   = ""
        "Raum"             = $Raum
        "Hostname"         = $Hostname
        "Hersteller"       = $Hersteller
        "Benutzer"         = $Benutzer
        "Betriebssystem"   = $OS
        "RAM_GB"           = $Ram
        "MAC"              = $Mac
        "IP"               = $Ip
        "Notiz"            = $Notiz
        "Erfasst"          = (Get-Date -Format "yyyy-MM-dd HH:mm")
    }
}

# Fragt einen Wert ab und schlaegt dabei einen Vorschlag vor
# (z.B. automatisch ausgelesene Daten), den man per Enter uebernimmt
# oder ueberschreibt, wenn er falsch/unzuverlaessig ist.
function Wert-Bestaetigen {
    param([string]$Prompt, [string]$Vorschlag)
    if ($Vorschlag) {
        $Eingabe = (Read-Host "$Prompt [$Vorschlag]").Trim()
        if ([string]::IsNullOrWhiteSpace($Eingabe)) { return $Vorschlag }
        return $Eingabe
    }
    return (Read-Host $Prompt).Trim()
}

Clear-Host
Write-Host ""
Write-Host " INVENTARISIERUNG " -ForegroundColor Black -BackgroundColor Cyan
Write-Host ""
Write-Host " 1  Rechner des Users erfassen  (Rechner + Monitore)"
Write-Host " 2  Nur Monitore                (mein Notebook angeschlossen)"
Write-Host " 3  Manuell erfassen            (Tower aus, Drucker, Lager)"
Write-Host ""
$Modus = (Read-Host "Modus").Trim()
if ($Modus -notin @("1","2","3")) { $Modus = "1" }

# --- Raum / Standort (werden gemerkt) -----------------
$MerkDatei    = Join-Path $Basis ".letzter_raum"
$MerkStandort = Join-Path $Basis ".letzter_standort"

$LetzterRaum = ""
if (Test-Path $MerkDatei) { $LetzterRaum = (Get-Content $MerkDatei -Raw).Trim() }
Write-Host ""
$Raum = Wert-Bestaetigen "Raum" $LetzterRaum
$Raum | Out-File $MerkDatei -Encoding UTF8 -Force

$LetzterStandort = ""
if (Test-Path $MerkStandort) { $LetzterStandort = (Get-Content $MerkStandort -Raw).Trim() }
$Standort = Wert-Bestaetigen "Standort (z.B. IT-Service Geschichte)" $LetzterStandort
$Standort | Out-File $MerkStandort -Encoding UTF8 -Force

$Alle = @()

# =====================================================
#  MODUS 1 - Rechner des Users
# =====================================================
if ($Modus -eq "1") {

    Write-Host ""
    Write-Host "Barcode scannen oder Enter, wenn kein Aufkleber da ist." -ForegroundColor DarkGray
    $AssetTag = (Read-Host "Asset Tag Rechner").Trim()
    $Notiz    = (Read-Host "Notiz (optional)").Trim()

    Write-Host ""
    Write-Host "Lese Geraetedaten..." -ForegroundColor Gray

    $bios = Get-CimInstance Win32_BIOS
    $sys  = Get-CimInstance Win32_ComputerSystem
    $os   = Get-CimInstance Win32_OperatingSystem
    $enc  = Get-CimInstance Win32_SystemEnclosure

    $Kategorie = "Sonstiges"
    switch -Regex ([string]$enc.ChassisTypes) {
        "^(8|9|10|11|12|14|18|21|30|31|32)$" { $Kategorie = "Notebook" }
        "^(3|4|5|6|7|15|16)$"                { $Kategorie = "PC"       }
        "^(17|23|28)$"                       { $Kategorie = "Server"   }
    }

    $Macs = (Get-CimInstance Win32_NetworkAdapter |
             Where-Object { $_.PhysicalAdapter -eq $true -and $_.MACAddress } |
             Select-Object -ExpandProperty MACAddress) -join " / "

    $Ip = (Get-CimInstance Win32_NetworkAdapterConfiguration |
           Where-Object { $_.IPEnabled -eq $true } |
           Select-Object -ExpandProperty IPAddress |
           Where-Object { $_ -notlike "*:*" } | Select-Object -First 1)

    $RamGb = [math]::Round($sys.TotalPhysicalMemory / 1GB, 0)

    # Win32_BIOS.SerialNumber ist bei Desktops/Notebooks zuverlaessig die
    # Seriennummer (bei Dell heisst das Feld "Service Tag", ist aber
    # dasselbe wie die Seriennummer - keine separate Nummer noetig).
    $Serial = $bios.SerialNumber

    # Kein Asset Tag vorhanden? Dann Seriennummer verwenden
    if (-not $AssetTag) { $AssetTag = $Serial }

    $Alle += Neue-Zeile $AssetTag $env:COMPUTERNAME $Serial $sys.Model $Kategorie `
                        $Standort $Raum $env:COMPUTERNAME $sys.Manufacturer $env:USERNAME `
                        $os.Caption $RamGb $Macs $Ip $Notiz

    Write-Host ("  {0} {1}   SN {2}" -f $sys.Manufacturer, $sys.Model, $Serial) -ForegroundColor Green
}

# =====================================================
#  MODUS 1 + 2 - Monitore auslesen
# =====================================================
if ($Modus -eq "1" -or $Modus -eq "2") {

    if ($Modus -eq "2") {
        Write-Host ""
        Write-Host "Monitor per Kabel anschliessen und einschalten." -ForegroundColor Yellow
        Write-Host "Der eigene Rechner wird NICHT gespeichert." -ForegroundColor DarkGray
        Write-Host ""
        Read-Host "Enter, wenn bereit"
    }

    Write-Host ""
    Write-Host "Suche Monitore..." -ForegroundColor Gray

    try {
        $mons = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop
        $i = 0
        foreach ($m in $mons) {
            $mHersteller = -join ($m.ManufacturerName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_})
            $mModell     = -join ($m.UserFriendlyName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_})
            $mEdidSerial = -join ($m.SerialNumberID   | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_})

            if ($InterneDisplays -contains $mHersteller) { continue }

            $i++
            Write-Host ""
            Write-Host ("  Monitor {0}: {1} {2}" -f $i, $mHersteller, $mModell) -ForegroundColor Green

            # Das EDID-Feld heisst zwar "Serial Number", manche Hersteller
            # (z.B. Dell) hinterlegen dort aber den Service Tag statt der
            # laengeren Seriennummer vom Aufkleber. Daher hier nur als
            # Vorschlag anzeigen und am Geraet gegenpruefen lassen statt
            # blind zu uebernehmen.
            if ($mEdidSerial) {
                Write-Host ("    EDID liefert: {0}  (kann bei manchen Herstellern der Service Tag statt der Seriennummer sein - Aufkleber pruefen!)" -f $mEdidSerial) -ForegroundColor DarkYellow
            } else {
                Write-Host "    Keine Seriennummer im EDID gefunden - bitte vom Aufkleber ablesen." -ForegroundColor DarkYellow
            }
            $mSerial = Wert-Bestaetigen "    Seriennummer (vom Aufkleber)" $mEdidSerial
            if (-not $mSerial) { continue }

            $mTag = Wert-Bestaetigen "    Asset Tag (Enter = Seriennummer verwenden)" $mSerial

            $Alle += Neue-Zeile $mTag $mModell $mSerial $mModell "Monitor" `
                                $Standort $Raum "" $mHersteller $env:USERNAME `
                                "" "" "" "" ""
        }
        if ($i -eq 0) { Write-Host "  Kein externer Monitor gefunden." -ForegroundColor Yellow }
    } catch {
        Write-Host "  Monitore konnten nicht ausgelesen werden." -ForegroundColor Yellow
    }
}

# =====================================================
#  MODUS 3 und Nachtrag in allen Modi
# =====================================================
Write-Host ""
if ($Modus -eq "3") {
    Write-Host "Seriennummer vom Aufkleber scannen oder eintippen." -ForegroundColor DarkGray
} else {
    Write-Host "Weitere Geraete im Raum? (Drucker, Dock, Tower...)" -ForegroundColor DarkGray
}

do {
    Write-Host ""
    $s = (Read-Host "Seriennummer (Enter = fertig)").Trim()
    if ($s) {
        $k   = (Read-Host "  Kategorie (Notebook / PC / Monitor / Drucker / Sonstiges)").Trim()
        if (-not $k) { $k = "Sonstiges" }
        $tag = Wert-Bestaetigen "  Asset Tag (Enter = Seriennummer verwenden)" $s
        $mod = (Read-Host "  Modell (optional)").Trim()
        $her = (Read-Host "  Hersteller (optional)").Trim()
        $nz  = (Read-Host "  Notiz (optional)").Trim()

        $Alle += Neue-Zeile $tag $mod $s $mod $k `
                            $Standort $Raum "" $her $env:USERNAME `
                            "" "" "" "" $nz
        Write-Host "  gespeichert." -ForegroundColor Green
    }
} while ($s)

# =====================================================
#  Speichern
# =====================================================
if ($Alle.Count -eq 0) {
    Write-Host ""
    Write-Host "Nichts erfasst." -ForegroundColor Yellow
    Write-Host "Taste druecken..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$Vorhanden = @()
if (Test-Path $CsvPfad) {
    $Vorhanden = @(Import-Csv $CsvPfad -Delimiter ";").Seriennummer
}

$Neu = $Alle | Where-Object { $Vorhanden -notcontains $_.Seriennummer }
$Doppelt = $Alle.Count - $Neu.Count

if ($Neu.Count -gt 0) {
    if (Test-Path $CsvPfad) {
        $Neu | Export-Csv $CsvPfad -Delimiter ";" -NoTypeInformation -Encoding UTF8 -Append
    } else {
        $Neu | Export-Csv $CsvPfad -Delimiter ";" -NoTypeInformation -Encoding UTF8
    }
}

Write-Host ""
Write-Host "-------------------------------------------" -ForegroundColor DarkGray
Write-Host (" Raum: {0}" -f $Raum)
foreach ($z in $Alle) {
    Write-Host ("  {0,-9} SN {1,-20} Tag {2}" -f $z.Kategorie, $z.Seriennummer, $z."Asset Tag")
}
Write-Host "-------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
if ($Neu.Count -gt 0) { Write-Host (" {0} neu gespeichert." -f $Neu.Count) -ForegroundColor Green }
if ($Doppelt  -gt 0) { Write-Host (" {0} schon vorhanden, uebersprungen." -f $Doppelt) -ForegroundColor Yellow }

$Gesamt = @(Import-Csv $CsvPfad -Delimiter ";").Count
Write-Host (" Gesamt: {0} Geraete" -f $Gesamt) -ForegroundColor Cyan
Write-Host ""
Write-Host "Taste druecken zum Beenden..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
