#!/usr/bin/env python3
"""
QR round-trip verification: runs the PS matrix generation via pwsh,
renders to PNG, and verifies the result matches the original key.

Usage: python3 verify_qr.py [48-digit-key]
Default key: 002130563959533643315590484044259380247291123563
"""
import subprocess, sys, tempfile, os

try:
    from PIL import Image
    from pyzbar.pyzbar import decode
except ImportError:
    print("Install: pip install pillow pyzbar && apt-get install -y libzbar0")
    sys.exit(1)

KEY = sys.argv[1] if len(sys.argv) > 1 else "002130563959533643315590484044259380247291123563"
assert len(KEY) == 48 and KEY.isdigit(), "Key must be exactly 48 digits"

# PowerShell QR matrix generation (exact copy of script logic)
PS_SCRIPT = r"""
$script:GFEXP=[int[]]::new(512);$script:GFLOG=[int[]]::new(256);$x=1
for($i=0;$i -lt 255;$i++){$script:GFEXP[$i]=$x;$script:GFLOG[$x]=$i;$x=$x -shl 1;if($x -band 0x100){$x=$x -bxor 0x11D}}
for($i=255;$i -lt 512;$i++){$script:GFEXP[$i]=$script:GFEXP[$i-255]}
function GMul([int]$a,[int]$b){if($a -eq 0 -or $b -eq 0){return 0};return $script:GFEXP[($script:GFLOG[$a]+$script:GFLOG[$b])%255]}
function Get-GenPoly([int]$n){$g=@(1);for($i=0;$i -lt $n;$i++){$ng=[int[]]::new($g.Count+1);for($j=0;$j -lt $g.Count;$j++){$ng[$j]=$ng[$j] -bxor $g[$j];$ng[$j+1]=$ng[$j+1] -bxor (GMul $g[$j] $script:GFEXP[$i])};$g=$ng};return $g}
function Get-RSEC([int[]]$data,[int]$nec){$g=Get-GenPoly $nec;$res=[int[]]::new($data.Count+$nec);for($i=0;$i -lt $data.Count;$i++){$res[$i]=$data[$i]};for($i=0;$i -lt $data.Count;$i++){$coef=$res[$i];if($coef -ne 0){for($j=0;$j -lt $g.Count;$j++){$res[$i+$j]=$res[$i+$j] -bxor (GMul $g[$j] $coef)}}};$ec=[int[]]::new($nec);for($i=0;$i -lt $nec;$i++){$ec[$i]=$res[$data.Count+$i]};return $ec}
function New-QRMatrix48([string]$digits){
    $bits=New-Object System.Collections.Generic.List[int]
    foreach($p in @(0,0,0,1)){$bits.Add($p)}
    for($i=9;$i -ge 0;$i--){$bits.Add((48 -shr $i) -band 1)}
    for($d=0;$d -lt 48;$d+=3){$val=[int]$digits.Substring($d,3);for($i=9;$i -ge 0;$i--){$bits.Add(($val -shr $i) -band 1)}}
    $dataCW=28;$cap=$dataCW*8
    if($bits.Count+4 -le $cap){for($i=0;$i -lt 4;$i++){$bits.Add(0)}}
    while($bits.Count%8 -ne 0){$bits.Add(0)}
    $cw=New-Object System.Collections.Generic.List[int]
    for($i=0;$i -lt $bits.Count;$i+=8){$b=0;for($k=0;$k -lt 8;$k++){$b=($b -shl 1) -bor $bits[$i+$k]};$cw.Add($b)}
    $pads=@(0xEC,0x11);$k=0
    while($cw.Count -lt $dataCW){$cw.Add($pads[$k%2]);$k++}
    $da=$cw.ToArray();$ec=Get-RSEC $da 16
    $all=New-Object System.Collections.Generic.List[int];foreach($v in $da){$all.Add([int]$v)};foreach($v in $ec){$all.Add([int]$v)}
    $sz=25;$m=[int[,]]::new($sz,$sz);$res=[bool[,]]::new($sz,$sz)
    foreach($fp in @(@(0,0),@(0,($sz-7)),@(($sz-7),0))){$fr=$fp[0];$fc=$fp[1];for($dr=-1;$dr -le 7;$dr++){for($dc=-1;$dc -le 7;$dc++){$rr=$fr+$dr;$cc=$fc+$dc;if($rr -ge 0 -and $rr -lt $sz -and $cc -ge 0 -and $cc -lt $sz){$v=0;if((($dr -eq 0 -or $dr -eq 6) -and $dc -ge 0 -and $dc -le 6) -or (($dc -eq 0 -or $dc -eq 6) -and $dr -ge 0 -and $dr -le 6)){$v=1}elseif($dr -ge 2 -and $dr -le 4 -and $dc -ge 2 -and $dc -le 4){$v=1};$m[$rr,$cc]=$v;$res[$rr,$cc]=$true}}}}
    for($i=0;$i -lt $sz;$i++){if($i%2 -eq 0){$tv=1}else{$tv=0};if(-not $res[6,$i]){$m[6,$i]=$tv;$res[6,$i]=$true};if(-not $res[$i,6]){$m[$i,6]=$tv;$res[$i,6]=$true}}
    for($dr=-2;$dr -le 2;$dr++){for($dc=-2;$dc -le 2;$dc++){$rr=18+$dr;$cc=18+$dc;$v=0;if(([math]::Max([math]::Abs($dr),[math]::Abs($dc)) -eq 2) -or ($dr -eq 0 -and $dc -eq 0)){$v=1};$m[$rr,$cc]=$v;$res[$rr,$cc]=$true}}
    $m[($sz-8),8]=1;$res[($sz-8),8]=$true
    for($i=0;$i -lt 9;$i++){$res[8,$i]=$true;$res[$i,8]=$true}
    for($i=0;$i -lt 8;$i++){$res[8,($sz-1-$i)]=$true;$res[($sz-1-$i),8]=$true}
    $res[8,8]=$true
    $db=New-Object System.Collections.Generic.List[int];foreach($cw2 in $all){for($i=7;$i -ge 0;$i--){$db.Add(($cw2 -shr $i) -band 1)}}
    $bi=0;$col=$sz-1;$up=$true
    while($col -gt 0){if($col -eq 6){$col--};if($up){$rl=($sz-1)..0}else{$rl=0..($sz-1)};foreach($r in $rl){foreach($c in @($col,($col-1))){if(-not $res[$r,$c]){if($bi -lt $db.Count){$b=$db[$bi]}else{$b=0};$bi++;if((($r+$c)%2) -eq 0){$b=$b -bxor 1};$m[$r,$c]=$b}}};$up=-not $up;$col-=2}
    $fmt='101010000010010';$fb=@();foreach($ch in $fmt.ToCharArray()){$fb+=[int]([string]$ch)}
    $coords=@(@(8,0),@(8,1),@(8,2),@(8,3),@(8,4),@(8,5),@(8,7),@(8,8),@(7,8),@(5,8),@(4,8),@(3,8),@(2,8),@(1,8),@(0,8))
    for($i=0;$i -lt 15;$i++){$m[$coords[$i][0],$coords[$i][1]]=$fb[$i]}
    for($i=0;$i -lt 7;$i++){$m[($sz-1-$i),8]=$fb[$i]}
    for($i=0;$i -lt 8;$i++){$m[8,($sz-8+$i)]=$fb[7+$i]}
    return ,$m
}
$mat=New-QRMatrix48 'KEY_PLACEHOLDER'
for($r=0;$r -lt 25;$r++){$row='';for($c=0;$c -lt 25;$c++){$row+=$mat[$r,$c]};Write-Host $row}
""".replace('KEY_PLACEHOLDER', KEY)

# Run PS to get matrix
result = subprocess.run(['pwsh', '-NonInteractive', '-Command', PS_SCRIPT],
                        capture_output=True, text=True, timeout=30)
lines = [ln.strip() for ln in result.stdout.strip().split('\n')
         if len(ln.strip()) == 25 and all(c in '01' for c in ln.strip())]

if len(lines) != 25:
    print(f"ERROR: PS output malformed ({len(lines)} rows)")
    print(result.stderr[:500])
    sys.exit(1)

matrix = [[int(c) for c in row] for row in lines]

# Render PNG
scale, border = 12, 4
size = 25
full = size + 2*border
img = Image.new("1", (full*scale, full*scale), 1)
px = img.load()
for r in range(size):
    for c in range(size):
        if matrix[r][c] == 1:
            for y in range((r+border)*scale, (r+border+1)*scale):
                for x in range((c+border)*scale, (c+border+1)*scale):
                    px[x, y] = 0

tmp = tempfile.mktemp(suffix='.png')
img.save(tmp)

# Decode
out = decode(Image.open(tmp))
os.unlink(tmp)

if out and out[0].data.decode() == KEY:
    print(f"PASS  Round-trip OK: {KEY}")
    sys.exit(0)
else:
    decoded = out[0].data.decode() if out else "(nothing)"
    print(f"FAIL  Expected: {KEY}")
    print(f"      Got:      {decoded}")
    sys.exit(1)
