using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using MenuOCR.Core;
using ZXing;
using ZXing.Common;
namespace MenuOCR;
internal static class QrDetection
{
    public static OcrResult? Recognize(byte[] png, CancellationToken cancellation)
    {
        cancellation.ThrowIfCancellationRequested();
        using var stream = new MemoryStream(png);
        using var source = Image.FromStream(stream);
        using var bitmap = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(bitmap)) { graphics.Clear(Color.White); graphics.DrawImageUnscaled(source, 0, 0); }
        var pixels = new byte[checked(bitmap.Width * bitmap.Height * 4)];
        var data = bitmap.LockBits(new Rectangle(0,0,bitmap.Width,bitmap.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            for (int row=0; row<bitmap.Height; row++) Marshal.Copy(IntPtr.Add(data.Scan0,row*data.Stride),pixels,row*bitmap.Width*4,bitmap.Width*4);
        } finally { bitmap.UnlockBits(data); }
        var reader = new BarcodeReaderGeneric {
            AutoRotate = true,
            Options = new DecodingOptions { TryHarder = true, TryInverted = true, PossibleFormats = [BarcodeFormat.QR_CODE] }
        };
        var codes = reader.DecodeMultiple(pixels,bitmap.Width,bitmap.Height,RGBLuminanceSource.BitmapFormat.BGRA32);
        cancellation.ThrowIfCancellationRequested();
        if (codes == null) return null;
        var values = codes.Where(c => !string.IsNullOrEmpty(c.Text))
            .OrderBy(c => Math.Round((c.ResultPoints?.Average(p => p.Y) ?? 0) / bitmap.Height * 50)).ThenBy(c => c.ResultPoints?.Min(p => p.X) ?? 0)
            .Select(c => c.Text).Distinct(StringComparer.Ordinal).ToArray();
        return values.Length == 0 ? null : new OcrResult(string.Join("\n",values),"",100) { QrCodeCount = values.Length };
    }
}
