using MenuOCR.Core;
namespace MenuOCR;
internal sealed class SettingsForm : Form
{
    public SettingsForm(AppSettings settings, Func<Shortcut, bool, string?> save)
    {
        Text = "MenuOCR Settings"; Icon = Theme.Icon(); Font = Theme.Body;
        AutoScaleMode = AutoScaleMode.Dpi; AutoScaleDimensions = new SizeF(96, 96);
        ClientSize = new Size(470, 290); FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false; StartPosition = FormStartPosition.CenterScreen;
        var panel = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(24) };
        panel.Controls.Add(new Label { Text = "Global capture shortcut", Font = Theme.Title, AutoSize = true, Margin = new Padding(0, 0, 0, 15) });
        var modifiers = new FlowLayoutPanel { Width = 420, Height = 40, WrapContents = false };
        var ctrl = new CheckBox { Text = "Ctrl", Width = 65, Checked = settings.Shortcut.Modifiers.HasFlag(ShortcutModifiers.Control) };
        var alt = new CheckBox { Text = "Alt", Width = 60, Checked = settings.Shortcut.Modifiers.HasFlag(ShortcutModifiers.Alt) };
        var shift = new CheckBox { Text = "Shift", Width = 70, Checked = settings.Shortcut.Modifiers.HasFlag(ShortcutModifiers.Shift) };
        var win = new CheckBox { Text = "Win", Width = 65, Checked = settings.Shortcut.Modifiers.HasFlag(ShortcutModifiers.Windows) };
        var key = new ComboBox { Width = 85, DropDownStyle = ComboBoxStyle.DropDownList, AccessibleName = "Shortcut key" };
        key.Items.AddRange(Enumerable.Range('A', 26).Select(c => ((char)c).ToString()).Concat(Enumerable.Range(1, 12).Select(i => "F" + i)).ToArray());
        key.SelectedItem = settings.Shortcut.Key;
        modifiers.Controls.AddRange([ctrl, alt, shift, win, key]); panel.Controls.Add(modifiers);
        var confirmation = new CheckBox { Text = "Show confirmation after copying", Checked = settings.ShowCopyConfirmation, AutoSize = true, Margin = new Padding(0, 8, 0, 8) };
        panel.Controls.Add(confirmation);
        var message = new Label { Width = 415, Height = 54, ForeColor = Color.DarkRed };
        var button = Theme.Button("Save", (_, _) => {
            var flags = (ctrl.Checked ? ShortcutModifiers.Control : 0) | (alt.Checked ? ShortcutModifiers.Alt : 0) | (shift.Checked ? ShortcutModifiers.Shift : 0) | (win.Checked ? ShortcutModifiers.Windows : 0);
            var shortcut = new Shortcut(key.SelectedItem as string ?? "", flags);
            if (!shortcut.IsValid) { message.Text = "Include Ctrl, Alt, or Win with the key."; return; }
            var error = save(shortcut, confirmation.Checked);
            if (error != null) { message.Text = error; return; }
            DialogResult = DialogResult.OK; Close();
        }, primary: true);
        panel.Controls.Add(message); panel.Controls.Add(button); Controls.Add(panel); AcceptButton = button;
    }
}
