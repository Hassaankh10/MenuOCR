using System.Runtime.InteropServices;
using MenuOCR.Core;

namespace MenuOCR;
internal sealed class HotkeyWindow : Form
{
    private int? registeredId;
    private int nextId = 100;
    private Shortcut? registeredShortcut;
    public event EventHandler? Pressed;
    [DllImport("user32.dll", SetLastError = true)] private static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    public HotkeyWindow() { ShowInTaskbar = false; FormBorderStyle = FormBorderStyle.None; _ = Handle; }
    public bool TryRegister(Shortcut shortcut)
    {
        if (!shortcut.IsValid) return false;
        if (shortcut == registeredShortcut) return true;
        if (!Enum.TryParse<Keys>(shortcut.Key, out var key)) return false;
        int id = nextId++;
        if (!RegisterHotKey(Handle, id, (uint)shortcut.Modifiers | 0x4000u, (uint)key)) return false;
        if (registeredId.HasValue) UnregisterHotKey(Handle, registeredId.Value);
        registeredId = id;
        registeredShortcut = shortcut;
        return true;
    }
    protected override void WndProc(ref Message message)
    {
        if (message.Msg == 0x0312 && message.WParam.ToInt32() == registeredId) Pressed?.Invoke(this, EventArgs.Empty);
        base.WndProc(ref message);
    }
    protected override void Dispose(bool disposing)
    {
        if (registeredId.HasValue && IsHandleCreated) UnregisterHotKey(Handle, registeredId.Value);
        registeredId = null;
        base.Dispose(disposing);
    }
}
