import XCTest
import AppKit
@testable import MenuOCR

final class OCRTests: XCTestCase {
    func testTSVLinesAndWeightedConfidence() {
        let tsv = "header\n5\t1\t1\t1\t1\t1\t0\t0\t1\t1\t90\tHello\n5\t1\t1\t1\t1\t2\t0\t0\t1\t1\t80\tworld\n5\t1\t1\t1\t2\t1\t0\t0\t1\t1\t100\tAgain\nmalformed"
        let result = OCRResult.parse(tsv, language: "eng")
        XCTAssertEqual(result.text, "Hello world\nAgain")
        XCTAssertEqual(result.confidence, 90)
        XCTAssertEqual(OCRResult.parse("header", language: "eng").text, "")
    }
    func testFailureAndTimeout() {
        XCTAssertThrowsError(try Command.run("/usr/bin/false", []))
        XCTAssertThrowsError(try Command.run("/bin/sleep", ["5"], timeout: 0.1))
        XCTAssertEqual(try Command.run("/usr/bin/printf", ["hello"]), "hello")
    }
    func testRealEnglishOCR() throws {
        guard let executable = OCR.executable else { throw XCTSkip("Tesseract not installed") }
        let image = NSImage(size: NSSize(width: 1000, height: 180))
        image.lockFocus()
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1000, height: 180).fill()
        ("Hello world 123" as NSString).draw(at: NSPoint(x: 30, y: 65), withAttributes: [.font: NSFont.systemFont(ofSize: 60), .foregroundColor: NSColor.black])
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: file) }
        try bitmap.representation(using: .png, properties: [:])!.write(to: file)
        let text = try Command.run(executable, [file.path, "stdout", "-l", "eng", "tsv"])
        XCTAssertTrue(OCRResult.parse(text, language: "eng").text.contains("Hello world 123"))
        let detected = try OCR.recognize(file) { _ in }
        XCTAssertTrue(detected.text.contains("Hello world 123"))
        XCTAssertEqual(detected.language, "eng")
    }
}
