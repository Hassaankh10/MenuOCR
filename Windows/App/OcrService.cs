using MenuOCR.Core;
using Tesseract;

namespace MenuOCR;
public sealed class OcrService(params string[] dataDirectories)
{
    public IReadOnlyList<(string Language, string Directory)> Models()
    {
        var models = new Dictionary<string, string>(StringComparer.Ordinal);
        // Later folders override bundled models, so user-installed data can be updated independently.
        foreach (var directory in dataDirectories) {
            if (!Directory.Exists(directory)) continue;
            foreach (var file in Directory.EnumerateFiles(directory, "*.traineddata")) {
                var name = Path.GetFileNameWithoutExtension(file);
                if (name == "osd" || !System.Text.RegularExpressions.Regex.IsMatch(name, "^[A-Za-z0-9_]+$")) continue;
                models[name] = directory;
            }
        }
        return models.OrderBy(x => x.Key, StringComparer.Ordinal).Select(x => (x.Key, x.Value)).ToArray();
    }
    public OcrResult Recognize(byte[] png, CancellationToken cancellation, Action<string> progress)
    {
        var models = Models();
        if (models.Count == 0) throw new InvalidOperationException("No OCR languages found. Reinstall MenuOCR or add .traineddata files to the languages folder.");
        var results = new List<OcrResult>();
        var failures = new List<string>();
        using var image = Pix.LoadFromMemory(png);
        for (int i = 0; i < models.Count; i++) {
            cancellation.ThrowIfCancellationRequested();
            var (language, directory) = models[i];
            progress($"Checking {language} ({i + 1}/{models.Count})…");
            try {
                using var engine = new TesseractEngine(directory, language, EngineMode.LstmOnly);
                using var page = engine.Process(image, PageSegMode.Auto);
                var text = page.GetText().Trim();
                var lines = new List<OcrLine>();
                int paragraph = 0;
                using (var lineIterator = page.GetIterator()) {
                    lineIterator.Begin();
                    do {
                        if (lineIterator.IsAtBeginningOf(PageIteratorLevel.Para)) paragraph++;
                        var line = lineIterator.GetText(PageIteratorLevel.TextLine)?.Trim();
                        if (!string.IsNullOrEmpty(line) && lineIterator.TryGetBoundingBox(PageIteratorLevel.TextLine, out var box))
                            lines.Add(new(line, paragraph, box.X1, box.Height));
                    } while (lineIterator.Next(PageIteratorLevel.TextLine));
                }
                if (lines.Count > 0) text = RichText.Plain(lines);
                var words = new List<(string, float)>();
                using var iterator = page.GetIterator();
                iterator.Begin();
                do {
                    var word = iterator.GetText(PageIteratorLevel.Word);
                    if (word != null) words.Add((word, iterator.GetConfidence(PageIteratorLevel.Word)));
                } while (iterator.Next(PageIteratorLevel.Word));
                results.Add(new OcrResult(text, language, OcrRanking.Score(words)) { Lines = lines });
            } catch (Exception error) when (error is not OperationCanceledException) {
                failures.Add($"{language}: {error.GetBaseException().Message}");
            }
            cancellation.ThrowIfCancellationRequested();
        }
        if (failures.Count > 0)
            throw new InvalidOperationException("Could not compare all installed languages. Repair or remove broken models. If native libraries cannot load, install Microsoft Visual C++ 2015–2022 Redistributable (x64).\n\n" + string.Join("\n", failures).Substring(0, Math.Min(1000, string.Join("\n", failures).Length)));
        return OcrRanking.Best(results) ?? throw new InvalidOperationException("No text found. Select a larger, clear, upright region.");
    }
}
