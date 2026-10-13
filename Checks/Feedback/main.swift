import AppKit
import SwiftUI

@MainActor
func verify() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
    let clipboard = NSPasteboard.general.changeCount
    let feedback = Feedback()
    feedback.show(title: "Text copied to clipboard", detail: "128 characters · Ready to paste with ⌘V")
    guard let panel = app.windows.first(where: { $0 is NSPanel && $0.isVisible }) else { fatalError("No visible feedback panel") }
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
        assert(abs(panel.frame.midX - screen.visibleFrame.midX) < 1, "Popup must be centered horizontally")
        assert(abs(panel.frame.minY - screen.visibleFrame.minY - 28) < 1, "Popup must be above the Dock")
    }
    assert(!panel.isKeyWindow)
    assert(panel.ignoresMouseEvents)
    assert(panel.styleMask.contains(.nonactivatingPanel))
    assert(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmost)
    assert(NSPasteboard.general.changeCount == clipboard)
    if let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
    RunLoop.main.run(until: Date().addingTimeInterval(4.5))
    assert(!panel.isVisible, "Success should automatically dismiss")
    feedback.show(title: "First", detail: "Old message")
    feedback.show(title: "Second", detail: "New message")
    assert(app.windows.filter { $0 is NSPanel && $0.isVisible }.count == 1)
    feedback.dismiss()
    assert(app.windows.filter { $0 is NSPanel && $0.isVisible }.isEmpty)
    feedback.show(title: "Plain text copied", detail: "128 characters · Paste with ⌘V", formatted: {}, plain: {})
    let interactive = app.windows.first { $0 is NSPanel && $0.isVisible }!
    assert(!interactive.ignoresMouseEvents && !interactive.isKeyWindow)
    assert(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmost)
    if let view = interactive.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
    feedback.dismiss()
    let icon = NSImage(contentsOfFile: CommandLine.arguments[2])
    assert(icon != nil && icon!.isValid, "ICNS must decode")
    print("PASS: popup visibility, nonactivation, focus preserved, clipboard unchanged, auto-dismiss, replacement, explicit dismissal, ICNS decode")
}
MainActor.assumeIsolated { verify() }
