using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using MenuOCR.Core;

namespace MenuOCR;
internal sealed class SelectionOverlay : Form
{
    private readonly Bitmap desktop;
    private readonly Rectangle virtualBounds;
    private Point start;
    private Rectangle selection;
    private bool selecting;
    private string hint = "Drag around the text · Escape to cancel";
    public Bitmap? SelectedImage { get; private set; }
    public Rectangle SelectedScreenRectangle => new(virtualBounds.X + selection.X, virtualBounds.Y + selection.Y, selection.Width, selection.Height);
    public SelectionOverlay(Bitmap desktop, Rectangle virtualBounds)
    {
        this.desktop = desktop; this.virtualBounds = virtualBounds;
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        Bounds = virtualBounds;
        ShowInTaskbar = false; TopMost = true; DoubleBuffered = true; KeyPreview = true; Cursor = Cursors.Cross;
        AccessibleName = "Select text region. Drag to select; press Escape to cancel.";
    }
    protected override void OnDpiChanged(DpiChangedEventArgs e) { e.Cancel = true; base.OnDpiChanged(e); Bounds = virtualBounds; }
    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.DrawImageUnscaled(desktop, 0, 0);
        using var shade = new SolidBrush(Color.FromArgb(135, 0, 0, 0));
        e.Graphics.FillRectangle(shade, ClientRectangle);
        if (selecting && !selection.IsEmpty) {
            var state = e.Graphics.Save(); e.Graphics.SetClip(selection);
            e.Graphics.DrawImageUnscaled(desktop, 0, 0); e.Graphics.Restore(state);
            using var pen = new Pen(Color.White, 2); e.Graphics.DrawRectangle(pen, selection);
        }
        var primary = Screen.PrimaryScreen?.Bounds ?? virtualBounds;
        var hintBounds = new Rectangle(primary.X - virtualBounds.X + 20, primary.Y - virtualBounds.Y + 24, Math.Max(200, primary.Width - 40), 48);
        TextRenderer.DrawText(e.Graphics, hint, Font, hintBounds, Color.White, Color.FromArgb(35, 35, 40), TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
    }
    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        start = e.Location; selecting = true; selection = Rectangle.Empty; Capture = true; Invalidate();
    }
    protected override void OnMouseMove(MouseEventArgs e)
    {
        if (!selecting) return;
        selection = SelectionMath.Normalize(start, e.Location, desktop.Size); Invalidate();
    }
    protected override void OnMouseUp(MouseEventArgs e)
    {
        if (!selecting || e.Button != MouseButtons.Left) return;
        selection = SelectionMath.Normalize(start, e.Location, desktop.Size); Capture = false;
        if (selection.Width < 8 || selection.Height < 8) {
            selecting = false; hint = "Select a larger region · Escape to cancel"; Invalidate(); return;
        }
        SelectedImage = desktop.Clone(selection, PixelFormat.Format32bppArgb);
        DialogResult = DialogResult.OK; Close();
    }
    protected override void OnKeyDown(KeyEventArgs e) { if (e.KeyCode == Keys.Escape) CancelSelection(); base.OnKeyDown(e); }
    public void CancelSelection() { DialogResult = DialogResult.Cancel; Close(); }
}
