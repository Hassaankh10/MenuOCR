using System.Text;
namespace MenuOCR.Core;
public sealed record OcrLine(string Text, int Paragraph, int Left, int Height);
public static class RichText
{
    public static string Plain(IReadOnlyList<OcrLine> lines) => string.Concat(lines.Select((line, i) => (i == 0 ? "" : line.Paragraph == lines[i-1].Paragraph ? "\n" : "\n\n") + line.Text));
    public static string Escape(string text)
    {
        var result = new StringBuilder();
        foreach (char c in text) {
            if (c is '\\' or '{' or '}') result.Append('\\').Append(c);
            else if (c == '\n') result.Append("\\line ");
            else if (c == '\r') continue;
            else if (c == '\t') result.Append("\\tab ");
            else if (c < 32) continue;
            else if (c > 126) result.Append("\\u").Append((short)c).Append('?');
            else result.Append(c);
        }
        return result.ToString();
    }
    public static string Rtf(IReadOnlyList<OcrLine> lines, string fallback)
    {
        var result = new StringBuilder(@"{\rtf1\ansi\deff0\uc1{\fonttbl{\f0 Segoe UI;}}\f0 ");
        if (lines.Count == 0) return result.Append("\\fs24 ").Append(Escape(fallback)).Append('}').ToString();
        var heights = lines.Select(l => Math.Max(1,l.Height)).Order().ToArray();
        double median = heights[(heights.Length-1)/2]; int margin = lines.Min(l => l.Left);
        for (int i=0; i<lines.Count; i++) {
            var line = lines[i];
            if (i>0) result.Append(line.Paragraph == lines[i-1].Paragraph ? "\\par " : "\\par\\par ");
            int indent = (int)Math.Clamp((line.Left-margin)*240/median,0,3600);
            int size = (int)Math.Clamp(line.Height*24/median,16,56);
            result.Append($"\\pard\\li{indent}\\sa80\\fs{size} ").Append(Escape(line.Text));
        }
        return result.Append('}').ToString();
    }
}
