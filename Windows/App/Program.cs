using System.Threading;
namespace MenuOCR;
internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using var instance = new Mutex(true, "Local\\MenuOCR.Windows", out bool created);
        if (!created) { MessageBox.Show("MenuOCR is already running. Look for its icon in the system tray.", "MenuOCR", MessageBoxButtons.OK, MessageBoxIcon.Information); return; }
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
        SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());
        try { using var app = new TrayApp(); Application.Run(app); }
        catch (Exception error) { MessageBox.Show(error.Message, "MenuOCR couldn’t start", MessageBoxButtons.OK, MessageBoxIcon.Error); }
    }
}
