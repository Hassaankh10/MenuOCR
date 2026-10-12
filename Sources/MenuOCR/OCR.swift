import Foundation

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

struct OCRResult {
    let text: String
    let confidence: Double
    let language: String
    static func parse(_ tsv: String, language: String) -> OCRResult {
        var lines: [String] = [], words: [String] = [], previous = ""
        var total = 0.0, weight = 0.0
        for row in tsv.split(separator: "\n").dropFirst() {
            let fields = row.split(separator: "\t", maxSplits: 11, omittingEmptySubsequences: false)
            guard fields.count == 12, fields[0] == "5", let confidence = Double(fields[10]), confidence >= 0 else { continue }
            let word = String(fields[11]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }
            let key = fields[1...4].joined(separator: ":")
            if key != previous && !words.isEmpty { lines.append(words.joined(separator: " ")); words = [] }
            previous = key
            words.append(word)
            let length = Double(word.count)
            total += confidence * length; weight += length
        }
        if !words.isEmpty { lines.append(words.joined(separator: " ")) }
        return OCRResult(text: lines.joined(separator: "\n"), confidence: weight > 0 ? total / weight : 0, language: language)
    }
}

struct OCR {
    static var executable: String? {
        ["/opt/homebrew/bin/tesseract", "/usr/local/bin/tesseract"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static func recognize(_ image: URL, progress: @escaping (String) -> Void) throws -> OCRResult {
        guard let executable else { throw AppError(message: "Tesseract is missing. Install it with: brew install tesseract tesseract-lang") }
        let listing = try Command.run(executable, ["--list-langs"])
        let languages = listing.split(separator: "\n").map(String.init).filter {
            !$0.hasPrefix("List of") && $0 != "osd" && !$0.isEmpty
        }.sorted()
        guard !languages.isEmpty else { throw AppError(message: "No language models installed. Run brew install tesseract-lang.") }
        var best: OCRResult?, failures: [String] = []
        for (index, language) in languages.enumerated() {
            try Task<Never, Never>.checkCancellation()
            progress("Checking \(language) (\(index + 1)/\(languages.count))…")
            do {
                let tsv = try Command.run(executable, [image.path, "stdout", "-l", language, "--psm", "3", "tsv"])
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
