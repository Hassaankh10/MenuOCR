using MenuOCR.Core;
namespace MenuOCR;
internal sealed class SettingsForm : Form
{
    public SettingsForm(AppSettings settings, Func<AppSettings, string?> save)
    {
        Text = "MenuOCR Settings"; Icon = Theme.Icon(); Font = Theme.Body;
        AutoScaleMode = AutoScaleMode.Dpi; AutoScaleDimensions = new SizeF(96,96);
        ClientSize = new Size(500,460); FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false; StartPosition = FormStartPosition.CenterScreen;
        var panel = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(24), AutoScroll = true };
        var readers = new List<Func<Shortcut>>();
        foreach (var (name, shortcut) in new[] { ("Capture text", settings.Shortcut), ("Copy formatted result", settings.FormattedShortcut), ("Copy plain result", settings.PlainShortcut) }) {
            panel.Controls.Add(new Label { Text = name, AutoSize = true, Font = Theme.Title });
            var row = new FlowLayoutPanel { Width = 440, Height = 40, WrapContents = false };
            var flags = new[] { ShortcutModifiers.Control, ShortcutModifiers.Alt, ShortcutModifiers.Shift, ShortcutModifiers.Windows };
            var checks = flags.Select(f => new CheckBox { Text = f == ShortcutModifiers.Control ? "Ctrl" : f == ShortcutModifiers.Windows ? "Win" : f.ToString(), Width = 70, Checked = shortcut.Modifiers.HasFlag(f) }).ToArray();
            var key = new ComboBox { Width = 85, DropDownStyle = ComboBoxStyle.DropDownList, AccessibleName = name + " key" };
            key.Items.AddRange(Enumerable.Range('A',26).Select(c => ((char)c).ToString()).Concat(Enumerable.Range(1,12).Select(i => "F"+i)).ToArray()); key.SelectedItem = shortcut.Key;
            row.Controls.AddRange(checks); row.Controls.Add(key); panel.Controls.Add(row);
            readers.Add(() => new Shortcut(key.SelectedItem as string ?? "", flags.Where((f,i) => checks[i].Checked).Aggregate((ShortcutModifiers)0,(a,b) => a|b)));
        }
        var confirmation = new CheckBox { Text = "Show confirmation after copying", AutoSize = true, Checked = settings.ShowCopyConfirmation }; panel.Controls.Add(confirmation);
        var message = new Label { Width = 440, Height = 55, ForeColor = Color.DarkRed }; panel.Controls.Add(message);
        var button = Theme.Button("Save", (_,_) => {
            var updated = new AppSettings { OnboardingCompleted = settings.OnboardingCompleted, ShowCopyConfirmation = confirmation.Checked, Shortcut = readers[0](), FormattedShortcut = readers[1](), PlainShortcut = readers[2]() };
            if (!updated.ShortcutsValid) { message.Text = "Use distinct shortcuts including Ctrl, Alt, or Win."; return; }
            var error = save(updated); if (error != null) { message.Text = error; return; }
            DialogResult = DialogResult.OK; Close();
        },true); panel.Controls.Add(button); Controls.Add(panel); AcceptButton = button;
    }
}
