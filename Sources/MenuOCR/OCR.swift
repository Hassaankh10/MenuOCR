import Foundation
import AppKit

struct AppError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Command {
    // File-backed output avoids pipe deadlocks on large OCR results.
    static func run(_ executable: String, _ args: [String], timeout: TimeInterval = 45) throws -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("stdout"), err = dir.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: out.path, contents: nil)
        FileManager.default.createFile(atPath: err.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: out), stderr = try FileHandle(forWritingTo: err)
        defer { try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.standardOutput = stdout
        process.standardError = stderr
        var environment = ProcessInfo.processInfo.environment
        environment["OMP_THREAD_LIMIT"] = "2"
        process.environment = environment
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Task<Never, Never>.isCancelled || Date() > deadline {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.1)
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
                throw AppError(message: Task<Never, Never>.isCancelled ? "Cancelled." : "Operation timed out.")
            }
            Thread.sleep(forTimeInterval: 0.04)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = (try? String(contentsOf: err, encoding: .utf8)) ?? ""
            throw AppError(message: "\(URL(fileURLWithPath: executable).lastPathComponent) failed: \(detail.prefix(600))")
        }
        return try String(contentsOf: out, encoding: .utf8)
    }
}

struct OCRLine {
    let text: String
    let paragraph: String
    let left: Double
    let height: Double
}

struct OCRResult {
    var layout: [OCRLine] = []
    var richText: NSAttributedString {
        let output = NSMutableAttributedString(string: "")
        let heights = layout.map { max(1, $0.height) }.sorted()
        let median = heights.isEmpty ? 1 : heights[(heights.count - 1) / 2]
        let margin = layout.map(\.left).min() ?? 0
        for (index, line) in layout.enumerated() {
            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = min(180, max(0, line.left - margin) * 12 / median)
            style.headIndent = style.firstLineHeadIndent
            style.paragraphSpacing = 4
            let prefix = index == 0 ? "" : line.paragraph == layout[index - 1].paragraph ? "\n" : "\n\n"
            output.append(NSAttributedString(string: prefix + line.text, attributes: [.font: NSFont.systemFont(ofSize: min(28, max(8, line.height * 12 / median))), .paragraphStyle: style]))
        }
        return layout.isEmpty ? NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12)]) : output
    }
    let text: String
    let confidence: Double
    let language: String
    static func parse(_ tsv: String, language: String) -> OCRResult {
        var lines: [String] = [], words: [String] = [], previous = ""
        var total = 0.0, weight = 0.0
        var layout: [OCRLine] = [], paragraph = "", left = Double.greatestFiniteMagnitude, height = 0.0
        func finishLine() {
            guard !words.isEmpty else { return }
            let text = words.joined(separator: " ")
            lines.append(text); layout.append(OCRLine(text: text, paragraph: paragraph, left: left.isFinite ? left : 0, height: height))
            words = []; left = Double.greatestFiniteMagnitude; height = 0
        }
        for row in tsv.split(separator: "\n").dropFirst() {
            let fields = row.split(separator: "\t", maxSplits: 11, omittingEmptySubsequences: false)
            guard fields.count == 12, fields[0] == "5", let confidence = Double(fields[10]), confidence >= 0 else { continue }
            let word = String(fields[11]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }
            let key = fields[1...4].joined(separator: ":")
            if key != previous { finishLine() }
            paragraph = fields[1...3].joined(separator: ":")
            left = min(left, Double(fields[6]) ?? 0); height = max(height, Double(fields[9]) ?? 0)
            previous = key
            words.append(word)
            let length = Double(word.count)
            total += confidence * length; weight += length
        }
        finishLine()
        let text = layout.enumerated().map { index, line in
            (index == 0 ? "" : line.paragraph == layout[index - 1].paragraph ? "\n" : "\n\n") + line.text
        }.joined()
        return OCRResult(layout: layout, text: text, confidence: weight > 0 ? total / weight : 0, language: language)
    }
}

struct OCR {
    static var executable: String? {
        [Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/OCR/bin/tesseract").path, "/opt/homebrew/bin/tesseract", "/usr/local/bin/tesseract"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static func recognize(_ image: URL, progress: @escaping (String) -> Void) throws -> OCRResult {
        guard let executable else { throw AppError(message: "Tesseract is missing. Install it with: brew install tesseract tesseract-lang") }
        let user = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MenuOCR/tessdata").path
        let directories = [Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/OCR/share/tessdata").path, "/opt/homebrew/share/tessdata", "/usr/local/share/tessdata", user]
        var models: [String: String] = [:]
        for directory in directories {
            for file in (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? [] where file.hasSuffix(".traineddata") {
                let name = String(file.dropLast(12))
                if name != "osd" && name.range(of: "^[A-Za-z0-9_]+$", options: .regularExpression) != nil { models[name] = directory }
            }
        }
        let languages = models.keys.sorted()
        guard !languages.isEmpty else { throw AppError(message: "No OCR language data found. Reinstall MenuOCR or add models to its languages folder.") }
        var best: OCRResult?, failures: [String] = []
        for (index, language) in languages.enumerated() {
            try Task<Never, Never>.checkCancellation()
            progress("Checking \(language) (\(index + 1)/\(languages.count))…")
            do {
                let tsv = try Command.run(executable, [image.path, "stdout", "-l", language, "--tessdata-dir", models[language]!, "--psm", "3", "tsv"])
                let result = OCRResult.parse(tsv, language: language)
                if !result.text.isEmpty && (best == nil || result.confidence > best!.confidence) { best = result }
            } catch {
                if Task<Never, Never>.isCancelled { throw CancellationError() }
                failures.append(language)
            }
        }
        guard let best else { throw AppError(message: "No text recognized. Select a larger, upright text region. Failed models: \(failures.joined(separator: ", "))") }
        guard failures.isEmpty else { throw AppError(message: "Could not compare all installed models (\(failures.joined(separator: ", "))). Clipboard unchanged; repair/remove those models and retry.") }
        return best
    }
}
