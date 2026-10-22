import Foundation
import AppKit

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let tsv = "header\n5\t1\t1\t1\t1\t1\t0\t0\t1\t1\t90\tHello\n5\t1\t1\t1\t2\t1\t0\t0\t1\t1\t70\tworld\nmalformed"
let parsed = OCRResult.parse(tsv, language: "eng")
check(parsed.text == "Hello\nworld", "Line reconstruction")
check(parsed.confidence == 80, "Weighted confidence")
check(OCRResult.parse("header", language: "eng").text.isEmpty, "Empty result")
for (command, args, timeout) in [("/usr/bin/false", [String](), 5.0), ("/bin/sleep", ["5"], 0.1)] {
    do { _ = try Command.run(command, args, timeout: timeout); fatalError("Expected failure") } catch { }
}
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1000, pixelsHigh: 180, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1000, height: 180).fill()
("Hello world 123" as NSString).draw(at: NSPoint(x: 30, y: 65), withAttributes: [.font: NSFont.systemFont(ofSize: 60), .foregroundColor: NSColor.black])
NSGraphicsContext.restoreGraphicsState()
let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
defer { try? FileManager.default.removeItem(at: file) }
try bitmap.representation(using: .png, properties: [:])!.write(to: file)
let result = try OCR.recognize(file) { print($0) }
check(result.text.contains("Hello world 123"), "Real OCR result: \(result.text)")
print("PASS: TSV parsing, confidence, empty result, command failure, timeout, and real OCR/model selection (\(result.language)).")

let structured = OCRResult(layout: [OCRLine(text: "Title", paragraph: "1", left: 0, height: 40), OCRLine(text: "Hello {world} café 中文", paragraph: "2", left: 20, height: 20)], text: "Title\n\nHello {world} café 中文", confidence: 90, language: "eng")
let rich = structured.richText
check(rich.string == structured.text, "Rich and plain content differ")
let rtf = try rich.data(from: NSRange(location: 0, length: rich.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
let decoded = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
check(decoded.string == structured.text, "Unicode RTF round-trip")
check((rich.attribute(.paragraphStyle, at: rich.length-1, effectiveRange: nil) as! NSParagraphStyle).headIndent > 0, "Indentation missing")
if CommandLine.arguments.count == 3 {
    let output = try Command.run(CommandLine.arguments[1], [file.path, "stdout", "--tessdata-dir", CommandLine.arguments[2], "-l", "eng", "tsv"])
    check(OCRResult.parse(output, language: "eng").text.contains("Hello world 123"), "Bundled OCR failed")
    print("PASS: bundled engine recognition with explicit bundled data")
}
print("PASS: rich/plain text equivalence, Unicode RTF round-trip and indentation")

let fixtureDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Tests/Fixtures")
for (name, expected, count) in [("qr-url", "https://example.com/menuocr?x=1&y=2", 1), ("qr-unicode", "MenuOCR café 中文", 1), ("qr-rotated", "https://example.com/rotated", 1), ("qr-multiple", "https://example.com/first\nhttps://example.com/second", 2), ("qr-duplicate", "https://example.com/first", 1)] {
    let result = try OCR.recognize(fixtureDirectory.appendingPathComponent(name + ".png")) { _ in }
    check(result.text == expected && result.qrCodeCount == count, "QR fixture \(name): \(result.text)")
}
let blankQR = try QRDetection.recognize(fixtureDirectory.appendingPathComponent("qr-blank.png"))
check(blankQR == nil, "Blank image must not produce QR data")
print("PASS: QR URLs, Unicode, rotation, multiple codes, deduplication and no-code fallback")
