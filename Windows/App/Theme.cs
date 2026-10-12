using System.Drawing.Drawing2D;
namespace MenuOCR;
internal static class Theme
{
    public static readonly Color Ink = Color.FromArgb(38, 31, 62);
    public static readonly Color Purple = Color.FromArgb(87, 61, 178);
    public static readonly Font Body = new("Segoe UI", 10);
    public static readonly Font Small = new("Segoe UI", 9);
    public static readonly Font Title = new("Segoe UI", 14, FontStyle.Bold);
    public static readonly Font Heading = new("Segoe UI", 30, FontStyle.Bold);
    public static readonly Font Keycaps = new("Segoe UI", 22, FontStyle.Bold);
    public static readonly Font Mark = new("Segoe UI", 27, FontStyle.Bold);
    public static Button Button(string text, EventHandler action, bool primary = false)
    {
        var button = new Button { Text = text, AutoSize = true, Padding = new Padding(12, 7, 12, 7), Font = Body,
            FlatStyle = FlatStyle.Flat, BackColor = primary ? Purple : Color.White,
            ForeColor = primary ? Color.White : Ink, Cursor = Cursors.Hand };
        button.FlatAppearance.BorderColor = primary ? Purple : Color.FromArgb(210, 205, 225);
        button.Click += action;
        return button;
    }
    public static Label Label(string text, int width, Font? font = null) => new() {
        Text = text, Font = font ?? Body, ForeColor = Ink, BackColor = Color.Transparent,
        AutoSize = false, Width = width, Height = 65, Padding = new Padding(0, 8, 0, 0) };
    public static Icon Icon()
    {
        using var stream = typeof(Theme).Assembly.GetManifestResourceStream("MenuOCR.Icon")!;
        using var icon = new Icon(stream);
        return (Icon)icon.Clone();
    }
}
internal sealed class GradientPanel : Panel
{
    public GradientPanel() { DoubleBuffered = true; }
    protected override void OnPaintBackground(PaintEventArgs e)
    {
        if (ClientSize.Width == 0 || ClientSize.Height == 0) return;
        using var brush = new LinearGradientBrush(ClientRectangle, Color.FromArgb(238, 230, 255), Color.FromArgb(255, 239, 225), 35f);
        e.Graphics.FillRectangle(brush, ClientRectangle);
    }
}
