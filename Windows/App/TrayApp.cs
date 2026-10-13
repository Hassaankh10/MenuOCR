using System.Diagnostics;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using MenuOCR.Core;

namespace MenuOCR;
internal sealed class TrayApp : ApplicationContext
{
    private readonly HotkeyWindow hotkey = new();
    private readonly HotkeyWindow formattedKey = new();
    private readonly HotkeyWindow plainKey = new();
    private OcrResult? lastResult;
    private readonly ToolStripMenuItem formattedItem = new("Copy Formatted Text");
    private readonly ToolStripMenuItem plainItem = new("Copy Plain Text");
    private readonly NotifyIcon tray;
    private readonly ContextMenuStrip menu = new();
    private readonly ToolStripMenuItem statusItem = new("Ready — capture a text region") { Enabled = false };
    private readonly ToolStripMenuItem captureItem = new("Capture Text");
    private readonly ToolStripMenuItem cancelItem = new("Cancel");
    private readonly ToolStripMenuItem imageItem = new("Copy Last Screenshot");
    private readonly ToolStripMenuItem settingsItem = new("Settings…");
    private readonly Icon appIcon = Theme.Icon();
    private readonly string userDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MenuOCR");
    private readonly string settingsPath;
    private readonly OcrService ocr;
    private CancellationTokenSource? cancellation;
    private SelectionOverlay? overlay;
    private OnboardingForm? onboarding;
    private ToastForm? toast;
    private Bitmap? lastImage;
    private bool busy, exiting;
    private string status = "Ready — capture a text region";
    public AppSettings Settings { get; private set; }
    public int LanguageCount { get { try { return ocr.Models().Count; } catch { return 0; } } }
    public TrayApp()
    {
        Directory.CreateDirectory(userDirectory);
        settingsPath = Path.Combine(userDirectory, "settings.json");
        string? settingsWarning = null;
        try { Settings = AppSettings.Load(settingsPath); }
        catch (Exception error) when (error is IOException or System.Text.Json.JsonException or UnauthorizedAccessException) {
            Settings = new(); settingsWarning = "Couldn’t read settings; using defaults. " + error.Message;
        }
        var userModels = Path.Combine(userDirectory, "tessdata"); Directory.CreateDirectory(userModels);
        ocr = new OcrService(Path.Combine(AppContext.BaseDirectory, "tessdata"), userModels);
        captureItem.Click += async (_, _) => await CaptureAsync();
        cancelItem.Click += (_, _) => Cancel();
        imageItem.Click += (_, _) => CopyImage();
        settingsItem.Click += (_, _) => ShowSettings();
        menu.Items.AddRange([statusItem, captureItem, cancelItem, imageItem, new ToolStripSeparator(), settingsItem]);
        formattedItem.Click += async (_,_) => await CopyResultAsync(true);
        plainItem.Click += async (_,_) => await CopyResultAsync(false);
        menu.Items.Insert(2,formattedItem); menu.Items.Insert(3,plainItem);
        menu.Items.Add("Welcome to MenuOCR…", null, (_, _) => ShowOnboarding());
        menu.Items.Add("Languages folder…", null, (_, _) => OpenLanguages());
        menu.Items.Add("OCR setup help…", null, (_, _) => OpenHelp());
        menu.Items.Add("Show Last Result…", null, (_, _) => MessageBox.Show(status, "MenuOCR", MessageBoxButtons.OK, MessageBoxIcon.Information));
        menu.Items.Add(new ToolStripSeparator()); menu.Items.Add("Quit MenuOCR", null, (_, _) => ExitThread());
        tray = new NotifyIcon { Icon = appIcon, Text = "MenuOCR", ContextMenuStrip = menu, Visible = true };
        tray.DoubleClick += async (_, _) => { if (!Settings.OnboardingCompleted) ShowOnboarding(); else await CaptureAsync(); };
        hotkey.Pressed += async (_, _) => await CaptureAsync();
        formattedKey.Pressed += async (_,_) => await CopyResultAsync(true);
        plainKey.Pressed += async (_,_) => await CopyResultAsync(false);
        if (!(formattedKey.TryRegister(Settings.FormattedShortcut) & plainKey.TryRegister(Settings.PlainShortcut))) status = "Copy shortcut unavailable. Open Settings.";
        if (!hotkey.TryRegister(Settings.Shortcut)) SetStatus("Shortcut unavailable. Choose another in Settings.");
        else Refresh();
        if (settingsWarning != null) { SetStatus(settingsWarning); ShowToast("Settings need attention", "Open MenuOCR → Show Last Result for details.", true); }
        if (!Settings.OnboardingCompleted) ShowOnboarding();
    }
    private void SetStatus(string text) { status = text; Refresh(); }
    private void Refresh()
    {
        statusItem.Text = status.Length > 160 ? status[..160] + "…" : status;
        tray.Text = ("MenuOCR: " + status).Replace('\n', ' ').Replace('\r', ' ')[..Math.Min(63, ("MenuOCR: " + status).Length)];
        formattedItem.Enabled = plainItem.Enabled = lastResult != null && !busy;
        captureItem.Enabled = !busy; cancelItem.Enabled = busy; settingsItem.Enabled = !busy; imageItem.Enabled = lastImage != null && !busy;
    }
    private void OnUi(Action action)
    {
        if (exiting || hotkey.IsDisposed) return;
        try { hotkey.BeginInvoke(new Action(() => { if (!exiting) action(); })); } catch (InvalidOperationException) { }
    }
    public async Task CaptureAsync()
    {
        if (busy || exiting) return;
        busy = true; cancellation = new(); var token = cancellation.Token;
        toast?.Close(); SetStatus("Select a region. Escape cancels.");
        var screen = Screen.FromPoint(Cursor.Position);
        try {
            // Dismiss tray menus or onboarding before taking the frozen desktop image.
            await Task.Delay(180, token);
            var bounds = SystemInformation.VirtualScreen;
            using var frozen = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
            using (var graphics = Graphics.FromImage(frozen)) graphics.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size, CopyPixelOperation.SourceCopy);
            using (var picker = new SelectionOverlay(frozen, bounds)) {
                overlay = picker;
                if (picker.ShowDialog() != DialogResult.OK || picker.SelectedImage == null) { SetStatus("Cancelled — clipboard unchanged"); return; }
                if (token.IsCancellationRequested) { picker.SelectedImage.Dispose(); token.ThrowIfCancellationRequested(); }
                lastImage?.Dispose(); lastImage = picker.SelectedImage;
                var region = picker.SelectedScreenRectangle;
                screen = Screen.FromPoint(new Point(region.Left + region.Width / 2, region.Top + region.Height / 2));
            }
            overlay = null;
            using var png = new MemoryStream(); lastImage.Save(png, ImageFormat.Png);
            var bytes = png.ToArray();
            var result = await Task.Run(() => ocr.Recognize(bytes, token, message => OnUi(() => { if (busy && !token.IsCancellationRequested) SetStatus(message); })), token);
            token.ThrowIfCancellationRequested();
            lastResult = result;
            await CopyResultAsync(false, token, screen, allowBusy: true);

        } catch (OperationCanceledException) { SetStatus("Cancelled — clipboard unchanged"); }
        catch (Exception error) { SetStatus(error.Message); ShowToast("Couldn’t copy text", "Open MenuOCR → Show Last Result for details.", true, screen); }
        finally { overlay = null; busy = false; cancellation?.Dispose(); cancellation = null; Refresh(); }
    }
    private async Task CopyResultAsync(bool formatted, CancellationToken token = default, Screen? screen = null, bool allowBusy = false)
    {
        if (busy && !allowBusy) return;
        if (lastResult == null) { ShowToast("Capture text first", "Press your capture shortcut, then choose a copy mode."); return; }
        var result = lastResult;
        try {
            var data = new DataObject(); data.SetData(DataFormats.UnicodeText, result.Text);
            if (formatted) data.SetData(DataFormats.Rtf, result.Rtf);
            bool copied = false;
            for (int attempt = 0; attempt < 5; attempt++) {
                token.ThrowIfCancellationRequested();
                try { Clipboard.SetDataObject(data,true); copied = true; break; }
                catch (ExternalException) { await Task.Delay(100,token); }
            }
            if (!copied) throw new InvalidOperationException("Clipboard is busy. Use a copy action to retry.");
            SetStatus($"Copied {(formatted ? "formatted" : "plain")} text · {result.Language}");
            if (Settings.ShowCopyConfirmation) {
                toast?.Close(); toast = new ToastForm($"{(formatted ? "Formatted" : "Plain")} text copied", $"{result.Text.Length} characters · Paste with Ctrl + V", false, screen ?? Screen.FromPoint(Cursor.Position), async () => await CopyResultAsync(true), async () => await CopyResultAsync(false)); toast.Show();
            }
        } catch (OperationCanceledException) { throw; }
        catch (Exception error) { SetStatus(error.Message); ShowToast("Couldn’t copy text", "Use the tray menu to retry.",true,screen); }
    }
    private void Cancel()
    {
        cancellation?.Cancel();
        if (overlay != null) overlay.CancelSelection();
        else if (busy) SetStatus("Cancelling after the current OCR model finishes…");
    }
    private void CopyImage()
    {
        if (lastImage == null) return;
        try { Clipboard.SetDataObject(new DataObject(DataFormats.Bitmap, lastImage), true, 5, 100); SetStatus("Screenshot copied"); if (Settings.ShowCopyConfirmation) ShowToast("Screenshot copied", "Ready to paste with Ctrl + V"); }
        catch (ExternalException) { SetStatus("Couldn’t copy screenshot. The clipboard is busy."); ShowToast("Couldn’t copy screenshot", "Try again in a moment.", true); }
    }
    private void ShowToast(string title, string detail, bool error = false, Screen? screen = null)
    {
        toast?.Close(); toast = new ToastForm(title, detail, error, screen ?? Screen.FromPoint(Cursor.Position)); toast.Show();
    }
    public void PreviewConfirmation() => ShowToast("Text copied to clipboard", "Preview only · Your clipboard is unchanged");
    public void ShowSettings(Form? owner = null)
    {
        if (busy) return;
        using var form = new SettingsForm(Settings, SaveSettings); form.ShowDialog(owner);
    }
    private string? SaveSettings(AppSettings replacement)
    {
        var old = Settings;
        // Release all three before registration so users can swap their assignments.
        void Clear() { hotkey.Unregister(); formattedKey.Unregister(); plainKey.Unregister(); }
        bool Register(AppSettings value) => hotkey.TryRegister(value.Shortcut) & formattedKey.TryRegister(value.FormattedShortcut) & plainKey.TryRegister(value.PlainShortcut);
        Clear();
        if (!Register(replacement)) { Clear(); if (!Register(old)) SetStatus("Couldn’t restore shortcuts. Open Settings."); return "Shortcut unavailable. Choose another combination."; }
        try { replacement.Save(settingsPath); Settings = replacement; SetStatus("Ready — shortcuts saved"); return null; }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException) { Clear(); if (!Register(old)) SetStatus("Couldn’t restore shortcuts. Open Settings."); return "Couldn’t save settings: " + error.Message; }
    }
    private void ShowOnboarding()
    {
        if (busy) return;
        if (onboarding is { IsDisposed: false }) { onboarding.Activate(); return; }
        onboarding = new OnboardingForm(this); onboarding.FormClosed += (_, _) => onboarding = null; onboarding.Show();
    }
    public void FinishOnboarding(bool capture)
    {
        Settings.OnboardingCompleted = true;
        try { Settings.Save(settingsPath); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException) {
            Settings.OnboardingCompleted = false; MessageBox.Show("Couldn’t save setup: " + error.Message, "MenuOCR"); return;
        }
        onboarding?.Close();
        if (capture) OnUi(async () => await CaptureAsync());
    }
    public void OpenLanguages() => OpenLink(Path.Combine(userDirectory, "tessdata"));
    public void OpenHelp() => OpenLink("https://github.com/Hassaankh10/MenuOCR/blob/main/Windows/README.md");
    private void OpenLink(string target)
    {
        try { Process.Start(new ProcessStartInfo(target) { UseShellExecute = true }); }
        catch (Exception error) { SetStatus(error.Message); ShowToast("Couldn’t open that", "Open MenuOCR → Show Last Result for details.", true); }
    }
    protected override void ExitThreadCore()
    {
        exiting = true; cancellation?.Cancel(); overlay?.CancelSelection();
        toast?.Close(); onboarding?.Close(); tray.Visible = false;
        base.ExitThreadCore();
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) { exiting = true; cancellation?.Cancel(); hotkey.Dispose(); formattedKey.Dispose(); plainKey.Dispose(); tray.Dispose(); menu.Dispose(); toast?.Dispose(); onboarding?.Dispose(); lastImage?.Dispose(); appIcon.Dispose(); }
        base.Dispose(disposing);
    }
}
