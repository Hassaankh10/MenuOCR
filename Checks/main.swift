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
