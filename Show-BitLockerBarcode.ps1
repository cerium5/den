<#
.SYNOPSIS
    Liest den lokalen BitLocker-Wiederherstellungsschluessel aus und zeigt ihn
    als Code128-Barcode (in Bloecken) UND als QR-Code ueber IrfanView an.
    KOMPLETT OFFLINE - keine Module, kein Internet noetig.

.DESCRIPTION
    - Liest den Recovery-Key der Maschine (Get-BitLockerVolume, Fallback manage-bde)
      inkl. Key-Protector-ID zum Abgleich mit dem Wiederherstellungsbildschirm.
    - Code128 wird selbst gerendert (System.Drawing), keine Schriftart noetig.
    - QR-Code wird ebenfalls selbst gerendert (eingebauter QR-Encoder, nur Ziffern).
      BitLocker-Keys sind immer 48 Ziffern -> QR Version 2, EC-Level M.
    - Ein einziges PNG mit allen Codes wird erzeugt und in IrfanView geoeffnet.

.PARAMETER MountPoint     Laufwerk. Standard: C:
.PARAMETER BlockCount     Anzahl Code128-Bloecke. Standard: 3
.PARAMETER ModuleWidth    Schmalste Balkenbreite (px). Standard: 3
.PARAMETER BarcodeHeight  Balkenhoehe (px). Standard: 110
.PARAMETER IncludeDashes  Bindestriche in Code128 mitkodieren (Set B statt C).
.PARAMETER NoQR           QR-Code NICHT erzeugen.
.PARAMETER QRModulePx     Pixel pro QR-Modul. Standard: 10
.PARAMETER IrfanViewPath  Pfad zu i_view64.exe (sonst Auto-Suche).
.PARAMETER OutputPath     Ziel-PNG. Standard: %TEMP%\BitLockerBarcode.png
.PARAMETER KeepFile       PNG nach Schliessen NICHT loeschen.

.EXAMPLE
    .\Show-BitLockerBarcode.ps1
.EXAMPLE
    .\Show-BitLockerBarcode.ps1 -MountPoint D: -ModuleWidth 4 -QRModulePx 12

.NOTES
    Als Administrator ausfuehren. Scanner-Suffix (Enter/CR) deaktivieren.
#>

[CmdletBinding()]
param(
    [string]$MountPoint     = 'C:',
    [int]   $BlockCount     = 3,
    [int]   $ModuleWidth    = 3,
    [int]   $BarcodeHeight  = 110,
    [switch]$IncludeDashes,
    [switch]$NoQR,
    [int]   $QRModulePx     = 10,
    [string]$IrfanViewPath,
    [string]$OutputPath     = (Join-Path $env:TEMP 'BitLockerBarcode.png'),
    [switch]$KeepFile
)

# ====================== Code128-Mustertabelle (0..106) =======================
$script:C128 = @(
'212222','222122','222221','121223','121322','131222','122213','122312','132212','221213',
'221312','231212','112232','122132','122231','113222','123122','123221','223211','221132',
'221231','213212','223112','312131','311222','321122','321221','312212','322112','322211',
'212123','212321','232121','111323','131123','131321','112313','132113','132311','211313',
'231113','231311','112133','112331','132131','113123','113321','133121','313121','211331',
'231131','213113','213311','213131','311123','311321','331121','312113','312311','332111',
'314111','221411','431111','111224','111422','121124','121421','141122','141221','112214',
'112412','122114','122411','142112','142211','241211','221114','413111','241112','134111',
'111242','121142','121241','114212','124112','124211','411212','421112','421211','212141',
'214121','412121','111143','111341','131141','114113','114311','411113','411311','113141',
'114131','311141','411131','211412','211214','211232','2331112'
)

# ====================== Recovery-Key + Protector-ID ==========================
function Get-RecoveryInfo {
    param([string]$Mount)
    $result = @()
    try {
        $vol = Get-BitLockerVolume -MountPoint $Mount -ErrorAction Stop
        foreach ($kp in $vol.KeyProtector) {
            if ($kp.KeyProtectorType -eq 'RecoveryPassword' -and $kp.RecoveryPassword) {
                $result += [pscustomobject]@{ Id = $kp.KeyProtectorId; Key = $kp.RecoveryPassword }
            }
        }
        if ($result.Count -gt 0) { return $result }
    } catch { Write-Verbose "Get-BitLockerVolume nicht verfuegbar -> manage-bde." }
    $raw = & manage-bde -protectors -get $Mount 2>$null
    $text = ($raw -join "`n")
    foreach ($m in [regex]::Matches($text, '(\d{6}-){7}\d{6}')) {
        $result += [pscustomobject]@{ Id = '(manage-bde)'; Key = $m.Value }
    }
    return $result
}

# ====================== Code128-Elemente =====================================
function Get-Code128Elements {
    param([string]$Data)
    $numericEven = ($Data -match '^\d+$') -and ($Data.Length % 2 -eq 0)
    if ($numericEven) {
        $start = 105
        $values = for ($i=0; $i -lt $Data.Length; $i+=2) { [int]$Data.Substring($i,2) }
    } else {
        $start = 104
        $values = $Data.ToCharArray() | ForEach-Object { [int][char]$_ - 32 }
    }
    $values = @($values)
    $sum = $start
    for ($i=0; $i -lt $values.Count; $i++) { $sum += $values[$i] * ($i+1) }
    $check = $sum % 103
    $symbols = @($start) + $values + @($check) + @(106)
    $elements = New-Object System.Collections.Generic.List[object]
    foreach ($sym in $symbols) {
        $bar = $true
        foreach ($ch in $script:C128[$sym].ToCharArray()) {
            $elements.Add([pscustomobject]@{ IsBar=$bar; Width=[int]([string]$ch) })
            $bar = -not $bar
        }
    }
    return $elements
}

function Split-IntoBlocks {
    param([string[]]$Groups, [int]$Count)
    $base=[math]::Floor($Groups.Count/$Count); $rem=$Groups.Count%$Count
    $blocks=@(); $idx=0
    for ($b=0; $b -lt $Count; $b++) {
        $take=$base + ($(if ($b -lt $rem){1}else{0}))
        if ($take -le 0) { continue }
        $slice=$Groups[$idx..($idx+$take-1)]
        $payload= if ($IncludeDashes){ $slice -join '-' } else { ($slice -join '') }
        $blocks += [pscustomobject]@{ Payload=$payload; Label=($slice -join '-') }
        $idx += $take
    }
    return $blocks
}

# ====================== QR-Encoder (offline, nur Ziffern) ====================
# Spezialisiert auf 48 Ziffern: QR Version 2 (25x25), EC-Level M, Maske 0.
$script:GFEXP=$null; $script:GFLOG=$null
function Initialize-GF {
    $script:GFEXP=[int[]]::new(512)
    $script:GFLOG=[int[]]::new(256)
    $x=1
    for ($i=0; $i -lt 255; $i++) {
        $script:GFEXP[$i]=$x; $script:GFLOG[$x]=$i
        $x = $x -shl 1
        if ($x -band 0x100) { $x = $x -bxor 0x11D }
    }
    for ($i=255; $i -lt 512; $i++) { $script:GFEXP[$i]=$script:GFEXP[$i-255] }
}
function GMul([int]$a,[int]$b){
    if ($a -eq 0 -or $b -eq 0){ return 0 }
    return $script:GFEXP[($script:GFLOG[$a]+$script:GFLOG[$b])%255]
}
function Get-GenPoly([int]$n){
    $g=@(1)
    for ($i=0; $i -lt $n; $i++){
        $ng=[int[]]::new($g.Count+1)
        for ($j=0; $j -lt $g.Count; $j++){
            $ng[$j]   = $ng[$j]   -bxor $g[$j]
            $ng[$j+1] = $ng[$j+1] -bxor (GMul $g[$j] $script:GFEXP[$i])
        }
        $g=$ng
    }
    return $g
}
function Get-RSEC([int[]]$data,[int]$nec){
    $g=Get-GenPoly $nec
    $res=[int[]]::new($data.Count+$nec)
    for ($i=0;$i -lt $data.Count;$i++){ $res[$i]=$data[$i] }
    for ($i=0;$i -lt $data.Count;$i++){
        $coef=$res[$i]
        if ($coef -ne 0){ for ($j=0;$j -lt $g.Count;$j++){ $res[$i+$j]=$res[$i+$j] -bxor (GMul $g[$j] $coef) } }
    }
    $ec=[int[]]::new($nec)
    for ($i=0;$i -lt $nec;$i++){ $ec[$i]=$res[$data.Count+$i] }
    return $ec
}
function New-QRMatrix48([string]$digits){
    if ($digits.Length -ne 48 -or $digits -notmatch '^\d+$'){ throw "QR-Encoder erwartet exakt 48 Ziffern." }
    $bits=New-Object System.Collections.Generic.List[int]
    # --- Bits zusammensetzen (inline, keine verschachtelten Funktionen) ---
    # Modus 0001 (4 Bit)
    foreach ($p in @(0,0,0,1)){ $bits.Add($p) }
    # Zaehler 48 (10 Bit)
    for ($i=9;$i -ge 0;$i--){ $bits.Add((48 -shr $i) -band 1) }
    # 48 Ziffern -> 16 x 10 Bit
    for ($d=0;$d -lt 48;$d+=3){
        $val=[int]$digits.Substring($d,3)
        for ($i=9;$i -ge 0;$i--){ $bits.Add(($val -shr $i) -band 1) }
    }
    $dataCW=28; $cap=$dataCW*8
    if ($bits.Count+4 -le $cap){ for ($i=0;$i -lt 4;$i++){ $bits.Add(0) } }
    while ($bits.Count % 8 -ne 0){ $bits.Add(0) }
    $codewords=New-Object System.Collections.Generic.List[int]
    for ($i=0;$i -lt $bits.Count;$i+=8){
        $b=0; for($k=0;$k -lt 8;$k++){ $b=($b -shl 1) -bor $bits[$i+$k] }
        $codewords.Add($b)
    }
    $pads=@(0xEC,0x11); $k=0
    while ($codewords.Count -lt $dataCW){ $codewords.Add($pads[$k%2]); $k++ }
    $dataArr=$codewords.ToArray()
    $ec=Get-RSEC $dataArr 16
    $all=New-Object System.Collections.Generic.List[int]
    foreach ($v in $dataArr){ $all.Add([int]$v) }
    foreach ($v in $ec){ $all.Add([int]$v) }

    $size=25
    $m  = [int[,]]::new($size,$size)
    $res= [bool[,]]::new($size,$size)

    # --- Finder-Muster (inline fuer 3 Ecken) ---
    foreach ($fp in @(@(0,0),@(0,($size-7)),@(($size-7),0))){
        $fr=$fp[0]; $fc=$fp[1]
        for ($dr=-1;$dr -le 7;$dr++){
            for ($dc=-1;$dc -le 7;$dc++){
                $rr=$fr+$dr; $cc=$fc+$dc
                if ($rr -ge 0 -and $rr -lt $size -and $cc -ge 0 -and $cc -lt $size){
                    $v=0
                    if ((($dr -eq 0 -or $dr -eq 6) -and $dc -ge 0 -and $dc -le 6) -or (($dc -eq 0 -or $dc -eq 6) -and $dr -ge 0 -and $dr -le 6)){ $v=1 }
                    elseif ($dr -ge 2 -and $dr -le 4 -and $dc -ge 2 -and $dc -le 4){ $v=1 }
                    $m[$rr,$cc]=$v; $res[$rr,$cc]=$true
                }
            }
        }
    }
    # --- Timing-Muster ---
    for ($i=0;$i -lt $size;$i++){
        if ($i % 2 -eq 0){ $tv=1 } else { $tv=0 }
        if (-not $res[6,$i]){ $m[6,$i]=$tv; $res[6,$i]=$true }
        if (-not $res[$i,6]){ $m[$i,6]=$tv; $res[$i,6]=$true }
    }
    # --- Ausrichtungsmuster v2 bei (18,18) ---
    for ($dr=-2;$dr -le 2;$dr++){
        for ($dc=-2;$dc -le 2;$dc++){
            $rr=18+$dr; $cc=18+$dc
            $v=0; if (([math]::Max([math]::Abs($dr),[math]::Abs($dc)) -eq 2) -or ($dr -eq 0 -and $dc -eq 0)){ $v=1 }
            $m[$rr,$cc]=$v; $res[$rr,$cc]=$true
        }
    }
    # --- Dunkelmodul + reservierte Formatbereiche ---
    $m[($size-8),8]=1; $res[($size-8),8]=$true
    for ($i=0;$i -lt 9;$i++){ $res[8,$i]=$true; $res[$i,8]=$true }
    for ($i=0;$i -lt 8;$i++){ $res[8,($size-1-$i)]=$true; $res[($size-1-$i),8]=$true }
    $res[8,8]=$true

    # --- Datenplatzierung (Zickzack) + Maske 0 ---
    $databits=New-Object System.Collections.Generic.List[int]
    foreach ($cw in $all){ for ($i=7;$i -ge 0;$i--){ $databits.Add(($cw -shr $i) -band 1) } }
    $bi=0; $col=$size-1; $up=$true
    while ($col -gt 0){
        if ($col -eq 6){ $col-- }
        if ($up){ $rowList=($size-1)..0 } else { $rowList=0..($size-1) }
        foreach ($r in $rowList){
            foreach ($c in @($col,($col-1))){
                if (-not $res[$r,$c]){
                    if ($bi -lt $databits.Count){ $b=$databits[$bi] } else { $b=0 }
                    $bi++
                    if ((($r+$c)%2) -eq 0){ $b=$b -bxor 1 }
                    $m[$r,$c]=$b
                }
            }
        }
        $up = -not $up; $col-=2
    }
    # --- Formatinfo (Level M, Maske 0) ---
    $fmt="101010000010010"
    $fb=@(); foreach ($ch in $fmt.ToCharArray()){ $fb+=[int]([string]$ch) }
    $coords=@(@(8,0),@(8,1),@(8,2),@(8,3),@(8,4),@(8,5),@(8,7),@(8,8),@(7,8),@(5,8),@(4,8),@(3,8),@(2,8),@(1,8),@(0,8))
    for ($i=0;$i -lt 15;$i++){ $m[$coords[$i][0],$coords[$i][1]]=$fb[$i] }
    for ($i=0;$i -lt 7;$i++){ $m[($size-1-$i),8]=$fb[$i] }
    for ($i=0;$i -lt 8;$i++){ $m[8,($size-8+$i)]=$fb[7+$i] }
    $script:_qrMatrix = $m
}

function Find-IrfanView {
    if ($IrfanViewPath -and (Test-Path $IrfanViewPath)){ return $IrfanViewPath }
    foreach ($c in @(
        "$env:ProgramFiles\IrfanView\i_view64.exe",
        "${env:ProgramFiles(x86)}\IrfanView\i_view64.exe",
        "$env:ProgramFiles\IrfanView\i_view32.exe",
        "${env:ProgramFiles(x86)}\IrfanView\i_view32.exe"
    )){ if ($c -and (Test-Path $c)){ return $c } }
    return $null
}

# ====================== Verifizierbarer QR-PNG-Writer (kein GDI+) ============
# ============================== MAIN =========================================
Add-Type -AssemblyName System.Drawing

$info = Get-RecoveryInfo -Mount $MountPoint
if (-not $info -or $info.Count -eq 0){
    Write-Error "Kein Recovery-Key fuer $MountPoint gefunden. Als Administrator ausfuehren? Laufwerk verschluesselt?"
    return
}
Write-Host "`n=== Gefundene Recovery-Keys ($MountPoint) ===" -ForegroundColor Cyan
foreach ($i in $info){ Write-Host (" ID  {0}`n KEY {1}" -f $i.Id,$i.Key) -ForegroundColor Cyan }
if ($info.Count -gt 1){
    Write-Warning "Mehrere Keys vorhanden! ID oben mit der Key-ID auf dem Wiederherstellungsbildschirm vergleichen. Verwende den ersten."
}
$key=$info[0].Key
$groups=$key.Split('-')
$digitsOnly=($groups -join '')

$blocks=Split-IntoBlocks -Groups $groups -Count $BlockCount
$quiet=12; $blockGap=28; $labelH=22; $titleH=22; $sideMargin=25; $topMargin=20
$titleFont=New-Object System.Drawing.Font('Consolas',11,[System.Drawing.FontStyle]::Bold)
$textFont =New-Object System.Drawing.Font('Consolas',13,[System.Drawing.FontStyle]::Bold)

$rendered=foreach ($blk in $blocks){
    $els=Get-Code128Elements -Data $blk.Payload
    $mods=($els | Measure-Object -Property Width -Sum).Sum + (2*$quiet)
    [pscustomobject]@{ Block=$blk; Elements=$els; WidthPx=$mods*$ModuleWidth }
}
$barContentW=($rendered | Measure-Object -Property WidthPx -Maximum).Maximum

$qrM=$null; $qrPx=0
if (-not $NoQR){
    try {
        Initialize-GF
        $script:_qrMatrix=$null
        New-QRMatrix48 $digitsOnly
        $qrM=$script:_qrMatrix
        $qrBorder=4
        $qrPx=(25+2*$qrBorder)*$QRModulePx
    } catch {
        Write-Warning "QR konnte nicht erzeugt werden:"
        Write-Warning ("  {0}" -f $_.Exception.Message)
        Write-Warning ("  bei: {0}" -f $_.InvocationInfo.PositionMessage)
        $qrM=$null
    }
}

$contentW=[Math]::Max($barContentW,$qrPx)
$canvasW=[int]($contentW+2*$sideMargin)
$barsH=($titleH+$BarcodeHeight+$labelH+$blockGap)*$blocks.Count
$qrSection= if ($qrM){ $titleH+$qrPx+30 } else { 0 }
$canvasH=[int]($topMargin+$barsH+$qrSection)

$bmp=New-Object System.Drawing.Bitmap($canvasW,$canvasH)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::None
$g.Clear([System.Drawing.Color]::White)
$black=[System.Drawing.Brushes]::Black
$y=$topMargin; $n=0
foreach ($r in $rendered){
    $n++
    $g.DrawString("Block $n / $($blocks.Count)  (Code128)",$titleFont,$black,[single]$sideMargin,[single]$y)
    $y+=$titleH
    $startX=[int]($sideMargin+(($contentW-$r.WidthPx)/2)+($quiet*$ModuleWidth))
    $x=$startX
    foreach ($el in $r.Elements){
        $w=$el.Width*$ModuleWidth
        if ($el.IsBar){ $g.FillRectangle($black,$x,$y,$w,$BarcodeHeight) }
        $x+=$w
    }
    $y+=$BarcodeHeight+4
    $g.DrawString($r.Block.Label,$textFont,$black,[single]$sideMargin,[single]$y)
    $y+=($labelH+$blockGap-4)
}
if ($qrM){
    $g.DrawString("QR-Code (ganzer Key)",$titleFont,$black,[single]$sideMargin,[single]$y)
    $y+=$titleH
    $qOriginX=[int]($sideMargin+(($contentW-$qrPx)/2))
    for ($rr=0;$rr -lt 25;$rr++){
        for ($cc=0;$cc -lt 25;$cc++){
            if ($qrM[$rr,$cc] -eq 1){
                $rx=[int]($qOriginX+($cc+$qrBorder)*$QRModulePx)
                $ry=[int]($y+($rr+$qrBorder)*$QRModulePx)
                $g.FillRectangle($black,$rx,$ry,$QRModulePx,$QRModulePx)
            }
        }
    }
}
$g.Dispose()
$bmp.Save($OutputPath,[System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "`nBarcode/QR gespeichert: $OutputPath" -ForegroundColor Green
Write-Host "PRUEFEN: Notepad oeffnen, Codes hineinscannen und mit KEY oben vergleichen!" -ForegroundColor Magenta

$iview=Find-IrfanView
if ($iview){
    $proc=Start-Process -FilePath $iview -ArgumentList "`"$OutputPath`"" -PassThru
    if (-not $KeepFile){
        Write-Host "Schliesse IrfanView -> PNG wird danach geloescht..." -ForegroundColor Yellow
        $proc.WaitForExit()
        Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
        Write-Host "PNG geloescht." -ForegroundColor Green
    }
} else {
    Write-Warning "IrfanView nicht gefunden: $OutputPath manuell oeffnen (oder -IrfanViewPath nutzen)."
}
