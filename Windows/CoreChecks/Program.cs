using System.Drawing;
using MenuOCR.Core;
void Check(bool condition, string name) { if (!condition) throw new Exception(name); Console.WriteLine("PASS " + name); }
Check(Shortcut.Default.IsValid, "default global shortcut");
Check(!new Shortcut("O", ShortcutModifiers.Shift).IsValid, "reject plain typing shortcuts");
Check(!new Shortcut("F13", ShortcutModifiers.Control).IsValid, "reject unsupported keys");
Check(!new Shortcut("A", (ShortcutModifiers)17).IsValid, "reject unknown modifiers");
Check(SelectionMath.Normalize(new(90,80), new(-10,20), new(100,100)) == new Rectangle(0,20,90,60), "backward selection clamps to screen");
Check(Math.Abs(OcrRanking.Score(new[] { ("abcd", 80f), ("a", 20f), ("",100f), ("noise",float.NaN) }) - 68) < .001, "confidence weighted by valid text length");
Check(OcrRanking.Best(new[] { new OcrResult("", "eng", 99), new OcrResult("hello", "fra", 50), new OcrResult("hello", "eng", 80) })?.Language == "eng", "empty recognition cannot win");
var dir = Path.Combine(Path.GetTempPath(), "MenuOCR-check-" + Guid.NewGuid());
try {
 var path = Path.Combine(dir, "settings.json");
 Check(!AppSettings.Load(path).OnboardingCompleted, "first launch requires onboarding");
 new AppSettings { OnboardingCompleted = true, Shortcut = new("F8", ShortcutModifiers.Alt) }.Save(path);
 var loaded = AppSettings.Load(path);
 Check(loaded.OnboardingCompleted && loaded.Shortcut.Key == "F8", "completed onboarding and shortcut persist");
 File.WriteAllText(path, "{\"Shortcut\":null}");
 bool rejected=false; try { AppSettings.Load(path); } catch (InvalidDataException) { rejected=true; }
 Check(rejected, "reject corrupt saved shortcut");
} finally { if (Directory.Exists(dir)) Directory.Delete(dir,true); }

var lines = new[] { new OcrLine("Title",1,0,40), new OcrLine("Hello {world} \\ café 中文",2,20,20) };
Check(RichText.Plain(lines).StartsWith("Title\n\nHello"), "paragraph separation");
var rtf = RichText.Rtf(lines, "");
Check(rtf.Contains("\\fs48") && rtf.Contains("\\li240"), "relative sizes and indentation");
Check(rtf.Contains("\\{world\\}") && rtf.Contains("\\u233?"), "RTF escapes literal braces and Unicode");
Check(!new AppSettings { FormattedShortcut = Shortcut.Default }.ShortcutsValid, "reject duplicate action shortcuts");
