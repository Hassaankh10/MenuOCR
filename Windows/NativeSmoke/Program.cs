using System.Drawing.Imaging;
using MenuOCR;
using var image = new Bitmap(1300,240);
using (var graphics = Graphics.FromImage(image)) {
 graphics.Clear(Color.White);
 using var font = new Font("Arial",72);
 graphics.DrawString("Hello world 123",font,Brushes.Black,30,50);
}
using var png = new MemoryStream(); image.Save(png,ImageFormat.Png);
var service = new OcrService(args[0]);
var result = service.Recognize(png.ToArray(),CancellationToken.None,Console.WriteLine);
if (result.Language != "eng" || !result.Text.Contains("Hello world 123",StringComparison.OrdinalIgnoreCase)) throw new Exception("OCR smoke test failed: " + result.Text);
Console.WriteLine($"PASS native OCR: {result.Text} ({result.Confidence:F1})");
using var cancellation = new CancellationTokenSource(); cancellation.Cancel();
try { service.Recognize(png.ToArray(), cancellation.Token, _ => {}); throw new Exception("Cancellation ignored."); }
catch (OperationCanceledException) { Console.WriteLine("PASS OCR cancellation"); }

Exception? uiError = null;
var thread = new Thread(() => {
    try {
        var lines = new[] { new MenuOCR.Core.OcrLine("Title",1,0,40), new MenuOCR.Core.OcrLine("Hello {world} \\ café 中文",2,20,20) };
        using var rich = new RichTextBox(); rich.Rtf = MenuOCR.Core.RichText.Rtf(lines, "");
        if (rich.Text.Replace("\r\n","\n").TrimEnd() != MenuOCR.Core.RichText.Plain(lines)) throw new Exception("RTF text differs from plain text.");
        var data = new DataObject(); data.SetData(DataFormats.UnicodeText,rich.Text); data.SetData(DataFormats.Rtf,rich.Rtf);
        Clipboard.SetDataObject(data,true,5,100);
        if (!Clipboard.ContainsText(TextDataFormat.Rtf) || Clipboard.GetText() != rich.Text) throw new Exception("Rich clipboard formats missing.");
        Clipboard.SetText("plain check");
        if (Clipboard.ContainsText(TextDataFormat.Rtf)) throw new Exception("Plain copying retained rich formatting.");
        Console.WriteLine("PASS native RTF round-trip and rich/plain clipboard formats");
        using var first = new HotkeyWindow(); using var second = new HotkeyWindow();
        var one = new MenuOCR.Core.Shortcut("F8", MenuOCR.Core.ShortcutModifiers.Control | MenuOCR.Core.ShortcutModifiers.Alt | MenuOCR.Core.ShortcutModifiers.Shift);
        var two = one with { Key = "F9" };
        if (!first.TryRegister(one) || second.TryRegister(one) || !second.TryRegister(two) || second.TryRegister(one) || !second.TryRegister(two)) throw new Exception("Hotkey collision or rollback failed.");
        first.Unregister();
        if (!second.TryRegister(one)) throw new Exception("Released hotkey could not be reassigned.");
        Console.WriteLine("PASS native global shortcut conflicts, preservation and reassignment");
        using var toast = new ToastForm("Copied", "One second check", false, Screen.PrimaryScreen!, () => {}, () => {});
        using var watchdog = new System.Windows.Forms.Timer { Interval = 2500 };
        watchdog.Tick += (_,_) => toast.Close();
        toast.Shown += (_,_) => toast.BeginInvoke(new Action(() => {
            // Drive the real MouseEnter event which previously stopped dismissal.
            typeof(Control).GetMethod("OnMouseEnter", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!.Invoke(toast.Controls[0], [EventArgs.Empty]);
        }));
        var elapsed = System.Diagnostics.Stopwatch.StartNew(); watchdog.Start(); toast.ShowDialog(); watchdog.Stop();
        if (elapsed.Elapsed.TotalSeconds < .9 || elapsed.Elapsed.TotalSeconds > 1.8) throw new Exception("Confirmation did not dismiss after one second while hovered.");
        Console.WriteLine("PASS one-second confirmation dismissal while hovered");
    } catch (Exception error) { uiError = error; }
});
thread.SetApartmentState(ApartmentState.STA); thread.Start(); thread.Join();
if (uiError != null) throw uiError;
