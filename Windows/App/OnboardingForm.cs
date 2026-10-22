namespace MenuOCR;
internal sealed class OnboardingForm : Form
{
    private readonly TrayApp app;
    private readonly Label heading = Theme.Label("", 685, Theme.Heading);
    private readonly Label subtitle = Theme.Label("", 685);
    private readonly FlowLayoutPanel content = new() { Width = 685, Height = 230, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, BackColor = Color.Transparent };
    private readonly Label progress = Theme.Label("", 220, Theme.Small);
    private readonly Button next;
    private readonly Button back;
    private int step;
    public OnboardingForm(TrayApp app)
    {
        this.app = app;
        Text = "Welcome to MenuOCR"; Icon = Theme.Icon(); Font = Theme.Body;
        AutoScaleMode = AutoScaleMode.Dpi; AutoScaleDimensions = new SizeF(96, 96);
        ClientSize = new Size(760, 555); FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false; StartPosition = FormStartPosition.CenterScreen;
        var canvas = new GradientPanel { Dock = DockStyle.Fill };
        var stack = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(32, 24, 32, 20), FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = Color.Transparent };
        stack.Controls.Add(new Label { Text = "MenuOCR   /   MADE FOR YOUR FLOW", Font = Theme.Small, ForeColor = Theme.Purple, Width = 685, Height = 30, BackColor = Color.Transparent });
        heading.Height = 68; subtitle.Height = 64;
        stack.Controls.Add(heading); stack.Controls.Add(subtitle); stack.Controls.Add(content);
        progress.Height = 30; stack.Controls.Add(progress);
        var footer = new FlowLayoutPanel { Width = 685, Height = 65, WrapContents = false, BackColor = Color.Transparent };
        back = Theme.Button("Back", (_, _) => { step--; RenderStep(); });
        next = Theme.Button("Let's begin", (_, _) => { if (step < 3) { step++; RenderStep(); } else app.FinishOnboarding(false); }, true);
        footer.Controls.Add(back); footer.Controls.Add(Theme.Button("Set up later", (_, _) => Close())); footer.Controls.Add(next);
        stack.Controls.Add(footer); canvas.Controls.Add(stack); Controls.Add(canvas); AcceptButton = next;
        RenderStep();
    }
    private void RenderStep()
    {
        foreach (Control control in content.Controls.Cast<Control>().ToArray()) {
            if (control is PictureBox picture) picture.Image?.Dispose();
            control.Dispose();
        }
        content.Controls.Clear(); back.Visible = step > 0;
        progress.Text = $"STEP {step + 1} OF 4";
        next.Text = step == 0 ? "Let's begin" : step == 3 ? "Finish setup" : "Continue";
        if (step == 0) {
            heading.Text = "Any text. Yours to keep.";
            subtitle.Text = "From a screenshot to your clipboard. Capture words or QR codes. Keep your flow.";
            content.Controls.Add(new PictureBox { Image = Icon!.ToBitmap(), Size = new Size(94, 94), SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.Transparent });
            content.Controls.Add(Theme.Label("No account. No cloud OCR.\nMenuOCR lives in your system tray after setup.", 650));
        } else if (step == 1) {
            heading.Text = "A little setup. All on your PC.";
            subtitle.Text = "Tesseract and English data come with the app. Additional languages are yours to add.";
            var count = app.LanguageCount;
            content.Controls.Add(Theme.Label(count == 0 ? "No OCR models found. Reinstall the app or add a language model." : $"✓ {count} OCR language model{(count == 1 ? "" : "s")} found.", 650));
            content.Controls.Add(Theme.Label("Windows doesn't need a Screen Recording or Accessibility switch for this capture method. Protected video and secure desktops may appear blank.", 650));
            content.Controls.Add(Theme.Button("Open languages folder", (_, _) => app.OpenLanguages()));
            content.Controls.Add(Theme.Button("OCR setup help", (_, _) => app.OpenHelp()));
        } else if (step == 2) {
            heading.Text = "Meet your new muscle memory.";
            subtitle.Text = "Press your shortcut, draw a box, and paste. Escape cancels selection.";
            content.Controls.Add(Theme.Label(app.Settings.Shortcut.ToString(), 650, Theme.Keycaps));
            content.Controls.Add(Theme.Button("Make the shortcut yours…", (_, _) => { app.ShowSettings(this); RenderStep(); }));
            content.Controls.Add(Theme.Button("Preview copy confirmation", (_, _) => app.PreviewConfirmation()));
        } else {
            heading.Text = "A little shortcut. A lot less typing.";
            subtitle.Text = "Find MenuOCR in your system tray. Windows may put it behind the hidden-icons arrow.";
            content.Controls.Add(Theme.Label("Select a few clear, upright lines. We'll let you know when the text is copied. Paste into your current app with Ctrl + V.", 650));
            var capture = Theme.Button("Finish and take my first capture", (_, _) => app.FinishOnboarding(true), true);
            capture.Enabled = app.LanguageCount > 0; content.Controls.Add(capture);
        }
    }
}
