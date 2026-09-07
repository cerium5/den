# =====================================================
#  Inventarisierung - App
#  Gleiche Logik wie Inventarisierung.ps1, nur mit GUI:
#  dunkles Theme, Matrix-Regen im Hintergrund, Radar-
#  und Sonar-Ping-Animation beim Scannen.
#  CSV-Spalten passen zum Snipe-IT Export.
# =====================================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$Basis   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CsvPfad = Join-Path $Basis "Inventar.csv"
$MerkRaum     = Join-Path $Basis ".letzter_raum"
$MerkStandort = Join-Path $Basis ".letzter_standort"

# Panel-Hersteller interner Notebook-Displays (werden uebersprungen)
$InterneDisplays = @("LGD","AUO","BOE","CMN","SHP","IVO","CSO","SDC","LEN","PNP")

# =====================================================
#  Oberflaeche (XAML)
# =====================================================
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Inventarisierung" Width="1040" Height="720"
        WindowStartupLocation="CenterScreen" Background="#0A0E0A"
        FontFamily="Consolas">
  <Grid>
    <Canvas x:Name="MatrixCanvas" Background="Black" ClipToBounds="True"/>

    <Border Background="#DD000000" CornerRadius="10" Margin="18" BorderBrush="#3CFF7A" BorderThickness="1">
      <Grid Margin="18">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Titel + Radar -->
        <DockPanel Grid.Row="0" Margin="0,0,0,14">
          <Canvas x:Name="RadarCanvas" Width="34" Height="34" DockPanel.Dock="Right">
            <Ellipse Width="34" Height="34" Stroke="#3CFF7A" StrokeThickness="1"/>
            <Ellipse Width="18" Height="18" Canvas.Left="8" Canvas.Top="8" Stroke="#1F6B3A" StrokeThickness="1"/>
            <Line x:Name="RadarLine" X1="17" Y1="17" X2="17" Y2="1" Stroke="#3CFF7A" StrokeThickness="1.5"
                  RenderTransformOrigin="0.5,0.5">
              <Line.RenderTransform>
                <RotateTransform x:Name="RadarRotate" Angle="0"/>
              </Line.RenderTransform>
            </Line>
          </Canvas>
          <TextBlock Text="INVENTARISIERUNG" Foreground="#3CFF7A" FontSize="22" FontWeight="Bold"/>
        </DockPanel>

        <!-- Raum / Standort / Modus -->
        <WrapPanel Grid.Row="1" Margin="0,0,0,12">
          <StackPanel Margin="0,0,20,0" Width="220">
            <TextBlock Text="Raum" Foreground="#3CFF7A" FontSize="11"/>
            <TextBox x:Name="TxtRaum" Background="#111511" Foreground="White" BorderBrush="#2A3A2A" Padding="4"/>
          </StackPanel>
          <StackPanel Margin="0,0,20,0" Width="260">
            <TextBlock Text="Standort" Foreground="#3CFF7A" FontSize="11"/>
            <TextBox x:Name="TxtStandort" Background="#111511" Foreground="White" BorderBrush="#2A3A2A" Padding="4"/>
          </StackPanel>
        </WrapPanel>

        <!-- Aktionen -->
        <WrapPanel Grid.Row="2" Margin="0,0,0,12">
          <Button x:Name="BtnScanPc" Content="PC / Notebook scannen" Padding="10,6" Margin="0,0,8,8"
                  Background="#123018" Foreground="#3CFF7A" BorderBrush="#3CFF7A"/>
          <Button x:Name="BtnScanMonitor" Content="Monitore scannen" Padding="10,6" Margin="0,0,8,8"
                  Background="#123018" Foreground="#3CFF7A" BorderBrush="#3CFF7A"/>
          <Button x:Name="BtnManuell" Content="Zeile manuell hinzufuegen" Padding="10,6" Margin="0,0,8,8"
                  Background="#1A1A1A" Foreground="#CCCCCC" BorderBrush="#444444"/>
          <Button x:Name="BtnLoeschen" Content="Ausgewaehlte Zeile loeschen" Padding="10,6" Margin="0,0,8,8"
                  Background="#1A1A1A" Foreground="#CCCCCC" BorderBrush="#444444"/>
        </WrapPanel>

        <!-- Tabelle -->
        <Grid Grid.Row="3">
          <DataGrid x:Name="Grid1" AutoGenerateColumns="False" CanUserAddRows="False"
                    CanUserDeleteRows="True" HeadersVisibility="Column" GridLinesVisibility="Horizontal"
                    Background="#0D110D" Foreground="White" RowBackground="#0D110D"
                    AlternatingRowBackground="#12160F" BorderBrush="#2A3A2A" BorderThickness="1">
            <DataGrid.Columns>
              <DataGridTextColumn Header="Kategorie"    Binding="{Binding Kategorie}"    Width="100"/>
              <DataGridTextColumn Header="Asset Tag"    Binding="{Binding AssetTag}"     Width="120"/>
              <DataGridTextColumn Header="Seriennummer" Binding="{Binding Seriennummer}" Width="150"/>
              <DataGridTextColumn Header="Modell"       Binding="{Binding Modell}"       Width="160"/>
              <DataGridTextColumn Header="Hersteller"   Binding="{Binding Hersteller}"   Width="110"/>
              <DataGridTextColumn Header="Notiz"        Binding="{Binding Notiz}"        Width="*"/>
            </DataGrid.Columns>
          </DataGrid>

          <!-- Sonar-Ping beim Scannen -->
          <Ellipse x:Name="PingKreis" Width="60" Height="60" Stroke="#3CFF7A" StrokeThickness="2"
                   Opacity="0" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,10,10,0"
                   RenderTransformOrigin="0.5,0.5" IsHitTestVisible="False">
            <Ellipse.RenderTransform>
              <ScaleTransform x:Name="PingScale" ScaleX="0.2" ScaleY="0.2"/>
            </Ellipse.RenderTransform>
          </Ellipse>
        </Grid>

        <!-- Status + Speichern -->
        <DockPanel Grid.Row="4" Margin="0,12,0,0">
          <Button x:Name="BtnSpeichern" Content="In CSV speichern" DockPanel.Dock="Right" Padding="14,7"
                  Background="#3CFF7A" Foreground="Black" FontWeight="Bold" BorderThickness="0"/>
          <TextBlock x:Name="TxtStatus" Foreground="#8FE0A8" VerticalAlignment="Center" Text="Bereit."/>
        </DockPanel>

      </Grid>
    </Border>
  </Grid>
</Window>
"@

$Reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($Reader)

$TxtRaum        = $Window.FindName("TxtRaum")
$TxtStandort    = $Window.FindName("TxtStandort")
$BtnScanPc      = $Window.FindName("BtnScanPc")
$BtnScanMonitor = $Window.FindName("BtnScanMonitor")
$BtnManuell     = $Window.FindName("BtnManuell")
$BtnLoeschen    = $Window.FindName("BtnLoeschen")
$BtnSpeichern   = $Window.FindName("BtnSpeichern")
$Grid1          = $Window.FindName("Grid1")
$TxtStatus      = $Window.FindName("TxtStatus")
$MatrixCanvas   = $Window.FindName("MatrixCanvas")
$RadarRotate    = $Window.FindName("RadarRotate")
$PingKreis      = $Window.FindName("PingKreis")
$PingScale      = $Window.FindName("PingScale")

if (Test-Path $MerkRaum)     { $TxtRaum.Text     = (Get-Content $MerkRaum -Raw).Trim() }
if (Test-Path $MerkStandort) { $TxtStandort.Text = (Get-Content $MerkStandort -Raw).Trim() }

# =====================================================
#  Datentabelle (Grundlage fuer die Grid-Anzeige + CSV)
# =====================================================
$Tabelle = New-Object System.Data.DataTable
foreach ($Spalte in @("AssetTag","AssetName","Seriennummer","Modell","Kategorie","Standort","Raum",
                      "Hostname","Hersteller","Benutzer","OS","RamGB","Mac","Ip","Notiz","Erfasst")) {
    [void]$Tabelle.Columns.Add($Spalte, [string])
}
$Grid1.ItemsSource = $Tabelle.DefaultView

function Zeile-Hinzufuegen {
    param([hashtable]$Felder)
    $Zeile = $Tabelle.NewRow()
    foreach ($Spalte in $Tabelle.Columns.ColumnName) {
        $Zeile[$Spalte] = if ($Felder.ContainsKey($Spalte)) { [string]$Felder[$Spalte] } else { "" }
    }
    $Zeile["Erfasst"] = Get-Date -Format "yyyy-MM-dd HH:mm"
    $Tabelle.Rows.Add($Zeile)
}

# =====================================================
#  Sonar-Ping (physikalisch: sich ausbreitende Welle)
# =====================================================
function Zeige-Ping {
    $Dauer = [TimeSpan]::FromSeconds(0.6)
    $ScaleAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.2, 3.5, $Dauer)
    $OpacityAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.9, 0.0, $Dauer)
    $PingScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $ScaleAnim)
    $PingScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $ScaleAnim)
    $PingKreis.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $OpacityAnim)
}

# =====================================================
#  PC / Notebook scannen
# =====================================================
$BtnScanPc.Add_Click({
    Zeige-Ping
    try {
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

        $RamGb  = [math]::Round($sys.TotalPhysicalMemory / 1GB, 0)
        $Serial = $bios.SerialNumber

        Zeile-Hinzufuegen @{
            AssetTag = $Serial; AssetName = $env:COMPUTERNAME; Seriennummer = $Serial
            Modell = $sys.Model; Kategorie = $Kategorie; Standort = $TxtStandort.Text; Raum = $TxtRaum.Text
            Hostname = $env:COMPUTERNAME; Hersteller = $sys.Manufacturer; Benutzer = $env:USERNAME
            OS = $os.Caption; RamGB = $RamGb; Mac = $Macs; Ip = $Ip; Notiz = ""
        }
        $TxtStatus.Text = "PC erkannt: $($sys.Manufacturer) $($sys.Model)  SN $Serial"
    } catch {
        $TxtStatus.Text = "Geraetedaten konnten nicht gelesen werden."
    }
})

# =====================================================
#  Monitore scannen
#  EDID-Seriennummer wird nur als Vorschlag eingetragen -
#  bei manchen Herstellern (z.B. Dell) steht dort der
#  Service Tag statt der laengeren Seriennummer vom
#  Aufkleber. Direkt in der Tabelle korrigierbar.
# =====================================================
$BtnScanMonitor.Add_Click({
    Zeige-Ping
    try {
        $Monitore = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop
        $Gefunden = 0
        foreach ($m in $Monitore) {
            $mHersteller = -join ($m.ManufacturerName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_})
            $mModell     = -join ($m.UserFriendlyName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_})
            $mEdidSerial = -join ($m.SerialNumberID   | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_})

            if ($InterneDisplays -contains $mHersteller) { continue }
            $Gefunden++

            $Hinweis = if ($mEdidSerial) {
                "EDID-Vorschlag - mit Aufkleber vergleichen (kann Service Tag statt Seriennummer sein)"
            } else {
                "Kein EDID-Wert - Seriennummer vom Aufkleber eintragen"
            }

            Zeile-Hinzufuegen @{
                AssetTag = $mEdidSerial; AssetName = $mModell; Seriennummer = $mEdidSerial
                Modell = $mModell; Kategorie = "Monitor"; Standort = $TxtStandort.Text; Raum = $TxtRaum.Text
                Hersteller = $mHersteller; Benutzer = $env:USERNAME; Notiz = $Hinweis
            }
        }
        $TxtStatus.Text = if ($Gefunden -gt 0) { "$Gefunden Monitor(e) erkannt - Seriennummern in der Tabelle pruefen." }
                          else { "Kein externer Monitor gefunden." }
    } catch {
        $TxtStatus.Text = "Monitore konnten nicht ausgelesen werden."
    }
})

# =====================================================
#  Manuell / Loeschen
# =====================================================
$BtnManuell.Add_Click({
    Zeile-Hinzufuegen @{
        Kategorie = "Sonstiges"; Standort = $TxtStandort.Text; Raum = $TxtRaum.Text; Benutzer = $env:USERNAME
    }
    $TxtStatus.Text = "Leere Zeile hinzugefuegt - bitte Felder ausfuellen."
})

$BtnLoeschen.Add_Click({
    $Ausgewaehlt = $Grid1.SelectedItem
    if ($Ausgewaehlt) {
        $Ausgewaehlt.Row.Delete()
        $Tabelle.AcceptChanges()
        $TxtStatus.Text = "Zeile geloescht."
    }
})

# =====================================================
#  Speichern
# =====================================================
$BtnSpeichern.Add_Click({
    $TxtRaum.Text.Trim()     | Out-File $MerkRaum -Encoding UTF8 -Force
    $TxtStandort.Text.Trim() | Out-File $MerkStandort -Encoding UTF8 -Force

    if ($Tabelle.Rows.Count -eq 0) {
        $TxtStatus.Text = "Nichts erfasst."
        return
    }

    $Alle = foreach ($Row in $Tabelle.Rows) {
        [PSCustomObject]@{
            "Asset Tag"        = $Row.AssetTag
            "Asset Name"       = $Row.AssetName
            "Seriennummer"     = $Row.Seriennummer
            "Modell"           = $Row.Modell
            "Kategorie"        = $Row.Kategorie
            "Status"           = "Einsetzbar"
            "Herausgegeben an" = ""
            "Standort"         = $Row.Standort
            "Einkaufspreis"    = ""
            "Aktueller Wert"   = ""
            "Raum"             = $Row.Raum
            "Hostname"         = $Row.Hostname
            "Hersteller"       = $Row.Hersteller
            "Benutzer"         = $Row.Benutzer
            "Betriebssystem"   = $Row.OS
            "RAM_GB"           = $Row.RamGB
            "MAC"              = $Row.Mac
            "IP"               = $Row.Ip
            "Notiz"            = $Row.Notiz
            "Erfasst"          = $Row.Erfasst
        }
    }

    $Vorhanden = @()
    if (Test-Path $CsvPfad) {
        $Vorhanden = @(Import-Csv $CsvPfad -Delimiter ";").Seriennummer
    }

    $Neu     = $Alle | Where-Object { $Vorhanden -notcontains $_.Seriennummer }
    $Doppelt = $Alle.Count - $Neu.Count

    if ($Neu.Count -gt 0) {
        if (Test-Path $CsvPfad) {
            $Neu | Export-Csv $CsvPfad -Delimiter ";" -NoTypeInformation -Encoding UTF8 -Append
        } else {
            $Neu | Export-Csv $CsvPfad -Delimiter ";" -NoTypeInformation -Encoding UTF8
        }
    }

    $Gesamt = @(Import-Csv $CsvPfad -Delimiter ";").Count
    $TxtStatus.Text = "$($Neu.Count) neu gespeichert, $Doppelt schon vorhanden. Gesamt: $Gesamt Geraete."

    if ($Neu.Count -gt 0) { $Tabelle.Clear() }
})

# =====================================================
#  Matrix-Regen (Hintergrundanimation)
# =====================================================
$MatrixZeichen = "アイウエオカキクケコサシスセソ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
$Zufall  = New-Object System.Random
$Streams = New-Object System.Collections.ArrayList

function Neuer-Stream {
    param([double]$X, [double]$StartY)
    $Text = New-Object System.Windows.Controls.TextBlock
    $Text.Text = [string]$MatrixZeichen[$Zufall.Next(0, $MatrixZeichen.Length)]
    $Text.FontFamily = "Consolas"
    $Text.FontSize = 15
    $Text.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(60,255,122))
    $Text.Opacity = [double]($Zufall.Next(35, 90)) / 100
    [System.Windows.Controls.Canvas]::SetLeft($Text, $X)
    [System.Windows.Controls.Canvas]::SetTop($Text, $StartY)
    [void]$MatrixCanvas.Children.Add($Text)
    return [PSCustomObject]@{ Element = $Text; X = $X; Y = $StartY; Speed = ($Zufall.Next(3, 9)) }
}

$Window.Add_Loaded({
    $Breite = $Window.ActualWidth
    $Hoehe  = $Window.ActualHeight
    $SpaltenBreite = 16
    $AnzahlSpalten = [math]::Max(1, [int]($Breite / $SpaltenBreite))
    for ($i = 0; $i -lt $AnzahlSpalten; $i++) {
        $x = $i * $SpaltenBreite
        $y = $Zufall.Next(-600, 0)
        [void]$Streams.Add((Neuer-Stream -X $x -StartY $y))
    }

    $MatrixTimer = New-Object System.Windows.Threading.DispatcherTimer
    $MatrixTimer.Interval = [TimeSpan]::FromMilliseconds(45)
    $MatrixTimer.Add_Tick({
        foreach ($s in $Streams) {
            $s.Y += $s.Speed
            if ($s.Y -gt $Hoehe) {
                $s.Y = $Zufall.Next(-300, 0)
                $s.Element.Opacity = [double]($Zufall.Next(35, 90)) / 100
            }
            if ($Zufall.Next(0, 6) -eq 0) {
                $s.Element.Text = [string]$MatrixZeichen[$Zufall.Next(0, $MatrixZeichen.Length)]
            }
            [System.Windows.Controls.Canvas]::SetTop($s.Element, $s.Y)
        }
    })
    $MatrixTimer.Start()

    $RadarTimer = New-Object System.Windows.Threading.DispatcherTimer
    $RadarTimer.Interval = [TimeSpan]::FromMilliseconds(30)
    $RadarTimer.Add_Tick({ $RadarRotate.Angle = ($RadarRotate.Angle + 4) % 360 })
    $RadarTimer.Start()

    $Window.Add_Closed({ $MatrixTimer.Stop(); $RadarTimer.Stop() }.GetNewClosure())
})

[void]$Window.ShowDialog()
