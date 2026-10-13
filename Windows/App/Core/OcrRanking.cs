namespace MenuOCR.Core;
public sealed record OcrResult(string Text, string Language, double Confidence)
{
    public IReadOnlyList<OcrLine> Lines { get; init; } = [];
    public string Rtf => RichText.Rtf(Lines, Text);
}
public static class OcrRanking
{
    public static double Score(IEnumerable<(string Text, float Confidence)> words)
    {
        double sum = 0, length = 0;
        foreach (var word in words) {
            if (string.IsNullOrWhiteSpace(word.Text) || !float.IsFinite(word.Confidence) || word.Confidence < 0) continue;
            var count = word.Text.Trim().Length;
            sum += Math.Clamp(word.Confidence, 0, 100) * count;
            length += count;
        }
        return length == 0 ? 0 : sum / length;
    }
    public static OcrResult? Best(IEnumerable<OcrResult> results) => results
        .Where(r => !string.IsNullOrWhiteSpace(r.Text))
        .OrderByDescending(r => r.Confidence).ThenBy(r => r.Language, StringComparer.Ordinal).FirstOrDefault();
}
