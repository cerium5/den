using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

class Launcher
{
    [STAThread]
    static void Main()
    {
        string ordner = Path.GetDirectoryName(Application.ExecutablePath);
        string skript = Path.Combine(ordner, "InventarApp.ps1");

        if (!File.Exists(skript))
        {
            MessageBox.Show("InventarApp.ps1 wurde nicht gefunden:\n" + skript, "Inventarisierung",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + skript + "\"",
            WorkingDirectory = ordner,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        try
        {
            using (var p = Process.Start(psi)) { p.WaitForExit(); }
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.ToString(), "Fehler beim Starten", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
