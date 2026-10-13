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
    func testRichTextStructureAndRoundTrip() throws {
        let result = OCRResult(layout: [OCRLine(text: "Title", paragraph: "1", left: 0, height: 40), OCRLine(text: "Hello {world} café 中文", paragraph: "2", left: 20, height: 20)], text: "Title\n\nHello {world} café 中文", confidence: 90, language: "eng")
        let rich = result.richText
        XCTAssertEqual(rich.string, result.text)
        let data = try rich.data(from: NSRange(location: 0, length: rich.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let decoded = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(decoded.string, result.text)
        XCTAssertGreaterThan((rich.attribute(.paragraphStyle, at: rich.length - 1, effectiveRange: nil) as! NSParagraphStyle).headIndent, 0)
    }
    @MainActor func testClipboardModes() throws {
        let clipboard = NSPasteboard.general
        let old = clipboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        } ?? []
        defer { clipboard.clearContents(); if !old.isEmpty { clipboard.writeObjects(old) } }
        let app = AppDelegate()
        app.lastResult = OCRResult(text: "Hello café 中文", confidence: 90, language: "eng")
        // Avoid UI side effects while checking the same clipboard writer used by the app.
        let flag = UserDefaults.standard.object(forKey: "showCopyConfirmation")
        UserDefaults.standard.set(false, forKey: "showCopyConfirmation")
        defer { if let flag { UserDefaults.standard.set(flag, forKey: "showCopyConfirmation") } else { UserDefaults.standard.removeObject(forKey: "showCopyConfirmation") } }
        app.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(app.item) }
        app.copyResult(formatted: true)
        XCTAssertEqual(clipboard.string(forType: .string), "Hello café 中文")
        XCTAssertNotNil(clipboard.data(forType: .rtf))
        app.copyResult(formatted: false)
        XCTAssertEqual(clipboard.string(forType: .string), "Hello café 中文")
        XCTAssertNil(clipboard.data(forType: .rtf))
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
