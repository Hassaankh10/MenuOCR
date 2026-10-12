using System.Text.Json;

namespace MenuOCR.Core;

[Flags]
public enum ShortcutModifiers : uint { Alt = 1, Control = 2, Shift = 4, Windows = 8 }
public sealed record Shortcut(string Key, ShortcutModifiers Modifiers)
{
    public static Shortcut Default => new("O", ShortcutModifiers.Control | ShortcutModifiers.Shift);
    public bool IsValid => System.Text.RegularExpressions.Regex.IsMatch(Key ?? "", "^([A-Z]|F([1-9]|1[0-2]))$")
        && (Modifiers & (ShortcutModifiers.Control | ShortcutModifiers.Alt | ShortcutModifiers.Windows)) != 0
        && ((uint)Modifiers & ~15u) == 0;
    public override string ToString() => string.Join(" + ", new[] {
        Modifiers.HasFlag(ShortcutModifiers.Control) ? "Ctrl" : null,
        Modifiers.HasFlag(ShortcutModifiers.Alt) ? "Alt" : null,
        Modifiers.HasFlag(ShortcutModifiers.Shift) ? "Shift" : null,
        Modifiers.HasFlag(ShortcutModifiers.Windows) ? "Win" : null, Key }.Where(x => x != null));
}
public sealed class AppSettings
{
    public bool OnboardingCompleted { get; set; }
    public bool ShowCopyConfirmation { get; set; } = true;
    public Shortcut Shortcut { get; set; } = Shortcut.Default;
    public static AppSettings Load(string path)
    {
        if (!File.Exists(path)) return new();
        var settings = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(path))
            ?? throw new InvalidDataException("Settings are empty.");
        if (settings.Shortcut == null || !settings.Shortcut.IsValid)
            throw new InvalidDataException("The saved shortcut is invalid.");
        return settings;
    }
    public void Save(string path)
    {
        if (!Shortcut.IsValid) throw new InvalidDataException("Include Ctrl, Alt, or Win and a valid key.");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try {
            File.WriteAllText(temporary, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
            File.Move(temporary, path, overwrite: true);
        } finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
