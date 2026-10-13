namespace MenuOCR;
internal sealed class ToastForm : Form
{
    private readonly System.Windows.Forms.Timer timer = new();
    private readonly Screen screen;
    private readonly bool interactive;
    protected override bool ShowWithoutActivation => true;
    protected override CreateParams CreateParams { get { var p = base.CreateParams; p.ExStyle |= 0x08000000 | 0x80; return p; } }
    public ToastForm(string title, string detail, bool error, Screen screen, Action? formatted = null, Action? plain = null)
    {
        this.screen = screen;
        AutoScaleMode = AutoScaleMode.Dpi; AutoScaleDimensions = new SizeF(96, 96);
        FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true;
        StartPosition = FormStartPosition.Manual; ClientSize = new Size(400, formatted == null ? 100 : 155);
        BackColor = SystemInformation.HighContrast ? SystemColors.Window : Color.FromArgb(32, 32, 38);
        ForeColor = SystemInformation.HighContrast ? SystemColors.WindowText : Color.White;
        AccessibleName = title + ". " + detail;
        var mark = new Label { Text = error ? "!" : "✓", Font = Theme.Mark, ForeColor = SystemInformation.HighContrast ? ForeColor : error ? Color.FromArgb(255, 190, 85) : Color.FromArgb(90, 225, 170), Location = new Point(18, 20), Size = new Size(44, 55) };
        var heading = new Label { Text = title, Font = Theme.Title, Location = new Point(72, 19), Size = new Size(310, 26) };
        var description = new Label { Text = detail, Font = Theme.Body, Location = new Point(72, 48), Size = new Size(310, 42) };
        Controls.AddRange([mark, heading, description]);
        if (formatted != null && plain != null) {
            var first = Theme.Button("Copy formatted", (_,_) => formatted()); first.Location = new Point(20,100);
            var second = Theme.Button("Copy plain text", (_,_) => plain()); second.Location = new Point(195,100);
            Controls.AddRange([first,second]);
        }
        interactive = formatted != null;
        timer.Interval = 1000; timer.Tick += (_, _) => Close();
    }
    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        var area = screen.WorkingArea;
        Location = new Point(area.Left + (area.Width - Width) / 2, area.Bottom - Height - 24);
        AccessibilityNotifyClients(AccessibleEvents.SystemAlert, -1);
        timer.Start();
    }
    protected override void WndProc(ref Message m) { if (m.Msg == 0x0084 && !interactive) { m.Result = new IntPtr(-1); return; } base.WndProc(ref m); }
    protected override void Dispose(bool disposing) { if (disposing) timer.Dispose(); base.Dispose(disposing); }
}
