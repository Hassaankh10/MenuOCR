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
