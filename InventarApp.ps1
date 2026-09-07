# =====================================================
#  Inventarisierung - App
#  Gleiche Erfassungslogik wie Inventarisierung.ps1, mit GUI:
#  dunkles "Deep Space"-Theme, prozedural erzeugter Sternenhimmel
#  mit Nebeln/Planeten, ein Gravitationslinsen-Gitter (Ecke unten
#  links) und ein Pulsar-Indikator (Ecke oben rechts) beim Scannen.
#
#  Echtes Foto statt Sternenhimmel:
#  Lege eine Datei "assets\space-bg.jpg" neben dieses Script -
#  wird automatisch als Hintergrund verwendet, wenn vorhanden.
#  Zwei bestaetigte, gemeinfreie NASA-Quellen zum Herunterladen:
#    https://science.nasa.gov/mission/hubble/multimedia/hubble-images/
#    https://commons.wikimedia.org/wiki/File:Released_to_Public_The_Trifid_Nebula_(NASA)_(411777678).jpg
#
#  CSV-Spalten passen zum Snipe-IT Export.
# =====================================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$Basis     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CsvPfad   = Join-Path $Basis "Inventar.csv"
$FotoPfad  = Join-Path $Basis "assets\space-bg.jpg"
$MerkRaum     = Join-Path $Basis ".letzter_raum"
$MerkStandort = Join-Path $Basis ".letzter_standort"

# Panel-Hersteller interner Notebook-Displays (werden uebersprungen)
$InterneDisplays = @("LGD","AUO","BOE","CMN","SHP","IVO","CSO","SDC","LEN","PNP")

# =====================================================
#  Oberflaeche (XAML) - dunkles Weltraum-Theme
# =====================================================
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Inventarisierung" Width="1080" Height="740"
        WindowStartupLocation="CenterScreen" Background="#05070D"
        FontFamily="Segoe UI">

  <Window.Resources>
    <Style x:Key="AppButton" TargetType="Button">
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="Background" Value="#11213A"/>
      <Setter Property="Foreground" Value="#CFE8FF"/>
      <Setter Property="BorderBrush" Value="#3FD3FF"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="4,0"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="AppButtonPrimary" TargetType="Button" BasedOn="{StaticResource AppButton}">
      <Setter Property="Background" Value="#FFC168"/>
      <Setter Property="Foreground" Value="#20160A"/>
      <Setter Property="BorderBrush" Value="#FFC168"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style x:Key="AppTextBox" TargetType="TextBox">
      <Setter Property="Background" Value="#0C1424"/>
      <Setter Property="Foreground" Value="#EAF2FF"/>
      <Setter Property="BorderBrush" Value="#274064"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="6,5"/>
      <Setter Property="CaretBrush" Value="#3FD3FF"/>
    </Style>
  </Window.Resources>

  <Grid>
    <!-- Hintergrund: Farbverlauf + prozeduraler Sternenhimmel/Nebel -->
    <Canvas x:Name="SpaceCanvas" ClipToBounds="True">
      <Canvas.Background>
        <LinearGradientBrush StartPoint="0.2,0" EndPoint="0.8,1">
          <GradientStop Color="#0A1030" Offset="0"/>
          <GradientStop Color="#05070D" Offset="0.55"/>
          <GradientStop Color="#020204" Offset="1"/>
        </LinearGradientBrush>
      </Canvas.Background>
    </Canvas>

    <!-- Optionales echtes Foto (assets\space-bg.jpg), sonst bleibt es leer -->
    <Image x:Name="FotoBild" Stretch="UniformToFill" Opacity="0.5" Visibility="Collapsed"/>

    <!-- Inhalts-Panel -->
    <Border Background="#DE070B16" CornerRadius="12" Margin="20" BorderBrush="#2E4E78" BorderThickness="1">
      <Border.Effect>
        <DropShadowEffect Color="#3FD3FF" Opacity="0.18" BlurRadius="40" ShadowDepth="0"/>
      </Border.Effect>
      <Grid Margin="22">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Titel + Pulsar-Indikator -->
        <DockPanel Grid.Row="0" Margin="0,0,0,16">
          <Canvas x:Name="PulsarCanvas" Width="30" Height="30" DockPanel.Dock="Right" VerticalAlignment="Top">
            <Ellipse Width="30" Height="30" Stroke="#274064" StrokeThickness="1"/>
            <Ellipse x:Name="PulsarKern" Width="7" Height="7" Canvas.Left="11.5" Canvas.Top="11.5" Fill="#FFFFFF">
              <Ellipse.Effect>
                <DropShadowEffect Color="#8FD9FF" Opacity="0.9" BlurRadius="14" ShadowDepth="0"/>
              </Ellipse.Effect>
            </Ellipse>
            <Line x:Name="PulsarStrahl" X1="15" Y1="15" X2="15" Y2="0" Stroke="#8FD9FF" StrokeThickness="1.4"
                  Opacity="0.85" RenderTransformOrigin="0.5,0.5">
              <Line.RenderTransform>
                <RotateTransform x:Name="PulsarRotate" Angle="0"/>
              </Line.RenderTransform>
            </Line>
          </Canvas>
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="INVENTARISIERUNG" Foreground="#F3F8FF" FontSize="23" FontWeight="Bold"/>
            <TextBlock Text="Feld-Erfassung · Snipe-IT Export" Foreground="#7C93B8" FontSize="12" Margin="1,2,0,0"/>
          </StackPanel>
        </DockPanel>

        <!-- Raum / Standort -->
        <WrapPanel Grid.Row="1" Margin="0,0,0,14">
          <StackPanel Margin="0,0,20,0" Width="220">
            <TextBlock Text="RAUM" Foreground="#5B84B8" FontSize="10.5" FontWeight="Bold" Margin="0,0,0,4"/>
            <TextBox x:Name="TxtRaum" Style="{StaticResource AppTextBox}"/>
          </StackPanel>
          <StackPanel Margin="0,0,20,0" Width="280">
            <TextBlock Text="STANDORT" Foreground="#5B84B8" FontSize="10.5" FontWeight="Bold" Margin="0,0,0,4"/>
            <TextBox x:Name="TxtStandort" Style="{StaticResource AppTextBox}"/>
          </StackPanel>
        </WrapPanel>

        <!-- Aktionen -->
        <WrapPanel Grid.Row="2" Margin="0,0,0,14">
          <Button x:Name="BtnScanPc" Content="PC / Notebook scannen" Style="{StaticResource AppButton}"/>
          <Button x:Name="BtnScanMonitor" Content="Monitore scannen" Style="{StaticResource AppButton}"/>
          <Button x:Name="BtnManuell" Content="Zeile manuell hinzufuegen" Style="{StaticResource AppButton}"/>
          <Button x:Name="BtnLoeschen" Content="Ausgewaehlte Zeile loeschen" Style="{StaticResource AppButton}"/>
        </WrapPanel>

        <!-- Tabelle -->
        <Grid Grid.Row="3">
          <DataGrid x:Name="Grid1" AutoGenerateColumns="False" CanUserAddRows="False"
                    CanUserDeleteRows="True" HeadersVisibility="Column" GridLinesVisibility="Horizontal"
                    Background="#0A0F1C" RowBackground="#0A0F1C" AlternatingRowBackground="#0E1526"
                    HorizontalGridLinesBrush="#1C2C46" BorderBrush="#274064" BorderThickness="1"
                    RowHeaderWidth="0" FontSize="13">
            <DataGrid.Resources>
              <Style TargetType="DataGridColumnHeader">
                <Setter Property="Background" Value="#0B1424"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
                <Setter Property="FontWeight" Value="Bold"/>
                <Setter Property="FontSize" Value="12.5"/>
                <Setter Property="Padding" Value="10,9"/>
                <Setter Property="BorderBrush" Value="#3FD3FF"/>
                <Setter Property="BorderThickness" Value="0,0,1,2"/>
                <Setter Property="HorizontalContentAlignment" Value="Left"/>
              </Style>
              <Style TargetType="DataGridCell">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="#EAF2FF"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="8,6"/>
                <Style.Triggers>
                  <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#1B3A5C"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                  </Trigger>
                </Style.Triggers>
              </Style>
            </DataGrid.Resources>
            <DataGrid.Columns>
              <DataGridTextColumn Header="Kategorie"    Binding="{Binding Kategorie}"    Width="100"/>
              <DataGridTextColumn Header="Asset Tag"    Binding="{Binding AssetTag}"     Width="120"/>
              <DataGridTextColumn Header="Seriennummer" Binding="{Binding Seriennummer}" Width="150"/>
              <DataGridTextColumn Header="Modell"       Binding="{Binding Modell}"       Width="160"/>
              <DataGridTextColumn Header="Hersteller"   Binding="{Binding Hersteller}"   Width="110"/>
              <DataGridTextColumn Header="Notiz"        Binding="{Binding Notiz}"        Width="*"/>
            </DataGrid.Columns>
          </DataGrid>

          <!-- Gravitationswellen-Ping beim Scannen -->
          <Ellipse x:Name="PingKreis" Width="70" Height="70" Stroke="#8FD9FF" StrokeThickness="2"
                   Opacity="0" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,10,10,0"
                   RenderTransformOrigin="0.5,0.5" IsHitTestVisible="False">
            <Ellipse.RenderTransform>
              <ScaleTransform x:Name="PingScale" ScaleX="0.2" ScaleY="0.2"/>
            </Ellipse.RenderTransform>
          </Ellipse>
        </Grid>

        <!-- Status + Speichern -->
        <DockPanel Grid.Row="4" Margin="0,14,0,0">
          <Button x:Name="BtnSpeichern" Content="In CSV speichern" DockPanel.Dock="Right"
                  Style="{StaticResource AppButtonPrimary}"/>
          <TextBlock x:Name="TxtStatus" Foreground="#8FA9CC" VerticalAlignment="Center" Text="Bereit."/>
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
$SpaceCanvas    = $Window.FindName("SpaceCanvas")
$FotoBild       = $Window.FindName("FotoBild")
$PulsarRotate   = $Window.FindName("PulsarRotate")
$PingKreis      = $Window.FindName("PingKreis")
$PingScale      = $Window.FindName("PingScale")

if (Test-Path $MerkRaum)     { $TxtRaum.Text     = (Get-Content $MerkRaum -Raw).Trim() }
if (Test-Path $MerkStandort) { $TxtStandort.Text = (Get-Content $MerkStandort -Raw).Trim() }

# Echtes Foto verwenden, wenn vorhanden - sonst bleibt der prozedurale
# Sternenhimmel (weiter unten) der Hintergrund.
if (Test-Path $FotoPfad) {
    try {
        $Bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $Bmp.BeginInit()
        $Bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $Bmp.UriSource = New-Object System.Uri((Resolve-Path $FotoPfad).Path, [System.UriKind]::Absolute)
        $Bmp.EndInit()
        $FotoBild.Source = $Bmp
        $FotoBild.Visibility = "Visible"
    } catch { }
}

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
#  Gravitationswellen-Ping (physikalisch: sich ausbreitende Welle,
#  wie bei einer LIGO-Detektion) - laeuft beim Scannen an
# =====================================================
function Zeige-Ping {
    $Dauer = [TimeSpan]::FromSeconds(0.7)
    $ScaleAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.2, 3.2, $Dauer)
    $OpacityAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.85, 0.0, $Dauer)
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
#  Prozeduraler Sternenhimmel: Sterne, Nebel, Planeten,
#  Gravitationslinsen-Gitter. Laeuft immer als Basis -
#  ein echtes Foto (assets\space-bg.jpg) liegt optional
#  halbtransparent darueber.
# =====================================================
$Zufall = New-Object System.Random

function Neuer-Nebel {
    param([double]$X, [double]$Y, [double]$Radius, [byte]$R, [byte]$G, [byte]$B)
    $Brush = New-Object System.Windows.Media.RadialGradientBrush
    $Brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop(
        [System.Windows.Media.Color]::FromArgb(70, $R, $G, $B), 0)))
    $Brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop(
        [System.Windows.Media.Color]::FromArgb(0, $R, $G, $B), 1)))
    $Blob = New-Object System.Windows.Shapes.Ellipse
    $Blob.Width = $Radius; $Blob.Height = $Radius
    $Blob.Fill = $Brush
    $Blob.Effect = New-Object System.Windows.Media.Effects.BlurEffect
    $Blob.Effect.Radius = 55
    [System.Windows.Controls.Canvas]::SetLeft($Blob, $X)
    [System.Windows.Controls.Canvas]::SetTop($Blob, $Y)
    [void]$SpaceCanvas.Children.Add($Blob)
}

function Neuer-Planet {
    param([double]$X, [double]$Y, [double]$Groesse, [string]$HellHex, [string]$DunkelHex, [bool]$MitRing)
    if ($MitRing) {
        $Ring = New-Object System.Windows.Shapes.Ellipse
        $Ring.Width = $Groesse * 2.2; $Ring.Height = $Groesse * 0.7
        $Ring.Stroke = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(120,220,200,160))
        $Ring.StrokeThickness = 3
        $Ring.Opacity = 0.55
        [System.Windows.Controls.Canvas]::SetLeft($Ring, $X - ($Groesse * 0.6))
        [System.Windows.Controls.Canvas]::SetTop($Ring, $Y + ($Groesse * 0.4))
        [void]$SpaceCanvas.Children.Add($Ring)
    }
    $Brush = New-Object System.Windows.Media.RadialGradientBrush
    $Brush.GradientOrigin = New-Object System.Windows.Point(0.32, 0.3)
    $Brush.Center = New-Object System.Windows.Point(0.32, 0.3)
    $Brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop(
        [System.Windows.Media.ColorConverter]::ConvertFromString($HellHex), 0)))
    $Brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop(
        [System.Windows.Media.ColorConverter]::ConvertFromString($DunkelHex), 1)))
    $Kugel = New-Object System.Windows.Shapes.Ellipse
    $Kugel.Width = $Groesse; $Kugel.Height = $Groesse
    $Kugel.Fill = $Brush
    $Kugel.Opacity = 0.7
    [System.Windows.Controls.Canvas]::SetLeft($Kugel, $X)
    [System.Windows.Controls.Canvas]::SetTop($Kugel, $Y)
    [void]$SpaceCanvas.Children.Add($Kugel)
}

function Zeichne-GravitationsGitter {
    param([double]$X, [double]$Y, [double]$Breite, [double]$Hoehe)
    $MassX  = $Breite / 2
    $Sigma  = $Breite / 4.2
    $Tiefe  = $Hoehe * 0.65
    $Farbe  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(130,110,180,255))

    $GitterCanvas = New-Object System.Windows.Controls.Canvas
    $GitterCanvas.Width = $Breite
    $GitterCanvas.Height = $Hoehe + $Tiefe
    [System.Windows.Controls.Canvas]::SetLeft($GitterCanvas, $X)
    [System.Windows.Controls.Canvas]::SetTop($GitterCanvas, $Y)
    [void]$SpaceCanvas.Children.Add($GitterCanvas)

    for ($row = 0; $row -le 6; $row++) {
        $BaseY = $row * ($Hoehe / 6)
        $Punkte = New-Object System.Windows.Media.PointCollection
        for ($px = 0; $px -le $Breite; $px += ($Breite/20)) {
            $d = $px - $MassX
            $Dip = $Tiefe * [math]::Exp(-($d*$d)/(2*$Sigma*$Sigma))
            [void]$Punkte.Add((New-Object System.Windows.Point($px, $BaseY + $Dip)))
        }
        $Linie = New-Object System.Windows.Shapes.Polyline
        $Linie.Points = $Punkte
        $Linie.Stroke = $Farbe
        $Linie.StrokeThickness = 1
        [void]$GitterCanvas.Children.Add($Linie)
    }
    for ($col = 0; $col -le 8; $col++) {
        $BaseX = $col * ($Breite / 8)
        $Punkte = New-Object System.Windows.Media.PointCollection
        for ($py = 0; $py -le $Hoehe; $py += ($Hoehe/16)) {
            $d = $BaseX - $MassX
            $Dip = $Tiefe * [math]::Exp(-($d*$d)/(2*$Sigma*$Sigma))
            [void]$Punkte.Add((New-Object System.Windows.Point($BaseX, $py + $Dip)))
        }
        $Linie = New-Object System.Windows.Shapes.Polyline
        $Linie.Points = $Punkte
        $Linie.Stroke = $Farbe
        $Linie.StrokeThickness = 1
        [void]$GitterCanvas.Children.Add($Linie)
    }

    $MassePunkt = New-Object System.Windows.Shapes.Ellipse
    $MassePunkt.Width = 6; $MassePunkt.Height = 6
    $MassePunkt.Fill = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(255,193,104))
    $MassePunkt.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $MassePunkt.Effect.Color = [System.Windows.Media.Color]::FromRgb(255,193,104)
    $MassePunkt.Effect.BlurRadius = 16
    $MassePunkt.Effect.ShadowDepth = 0
    [System.Windows.Controls.Canvas]::SetLeft($MassePunkt, $MassX - 3)
    [System.Windows.Controls.Canvas]::SetTop($MassePunkt, $Hoehe + $Tiefe - 3)
    [void]$GitterCanvas.Children.Add($MassePunkt)
}

function Baue-Sternenhimmel {
    $Breite = $Window.ActualWidth
    $Hoehe  = $Window.ActualHeight

    # Nebel-Schwaden (dezent, in den Ecken - nicht ueber dem Inhaltsbereich)
    Neuer-Nebel -X (-80)              -Y (-60)              -Radius 480 -R 90  -G 70  -B 160
    Neuer-Nebel -X ($Breite - 380)    -Y ($Hoehe - 420)      -Radius 520 -R 40  -G 110 -B 150

    # Sterne mit leichtem Funkeln
    for ($i = 0; $i -lt 140; $i++) {
        $Groesse = 1 + $Zufall.NextDouble() * 2
        $Stern = New-Object System.Windows.Shapes.Ellipse
        $Stern.Width = $Groesse; $Stern.Height = $Groesse
        $Stern.Fill = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(235,242,255))
        $Stern.Opacity = 0.25 + $Zufall.NextDouble() * 0.6
        [System.Windows.Controls.Canvas]::SetLeft($Stern, $Zufall.NextDouble() * $Breite)
        [System.Windows.Controls.Canvas]::SetTop($Stern, $Zufall.NextDouble() * $Hoehe)
        [void]$SpaceCanvas.Children.Add($Stern)

        if ($i % 5 -eq 0) {
            $Dauer = [TimeSpan]::FromSeconds(1.5 + $Zufall.NextDouble() * 2.5)
            $Funkel = New-Object System.Windows.Media.Animation.DoubleAnimation($Stern.Opacity, 0.1, $Dauer)
            $Funkel.AutoReverse = $true
            $Funkel.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $Stern.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $Funkel)
        }
    }

    # Planeten weit in den Ecken, hinter dem Panel
    Neuer-Planet -X ($Breite - 150) -Y 40 -Groesse 60 -HellHex "#8FD9FF" -DunkelHex "#1A3A5C" -MitRing $false
    Neuer-Planet -X 40 -Y ($Hoehe - 170) -Groesse 90 -HellHex "#FFD9A0" -DunkelHex "#7A4A20" -MitRing $true

    # Gravitationslinsen-Gitter, unten links
    Zeichne-GravitationsGitter -X 30 -Y ($Hoehe - 210) -Breite 230 -Hoehe 90
}

$Window.Add_Loaded({
    Baue-Sternenhimmel

    $PulsarTimer = New-Object System.Windows.Threading.DispatcherTimer
    $PulsarTimer.Interval = [TimeSpan]::FromMilliseconds(30)
    $PulsarTimer.Add_Tick({ $PulsarRotate.Angle = ($PulsarRotate.Angle + 3) % 360 })
    $PulsarTimer.Start()

    $Window.Add_Closed({ $PulsarTimer.Stop() }.GetNewClosure())
})

[void]$Window.ShowDialog()
