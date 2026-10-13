import AppKit
import Carbon

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let suite = "MenuOCR.StartupCheck.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    @MainActor func makeDelegate() -> AppDelegate {
        let delegate = AppDelegate()
        delegate.onboardingDefaults = defaults
        delegate.shortcutKey = UInt32(kVK_F20)
        delegate.shortcutModifiers = UInt32(controlKey | cmdKey | shiftKey)
        return delegate
    }
    let first = makeDelegate()
    first.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    assert(first.onboardingWindow?.isVisible == true, "First launch must show onboarding")
    assert(app.activationPolicy() == .regular, "Onboarding should have normal window activation")
    first.onboardingWindow?.close()
    assert(!defaults.bool(forKey: "onboardingCompleted"), "Closing unfinished setup must not mark it complete")
    assert(app.activationPolicy() == .accessory, "Closing setup must remove the Dock presence")
    first.onboarding()
    first.settings()
    first.permission()
    first.finishOnboarding(capture: false)
    assert(defaults.bool(forKey: "onboardingCompleted"), "Completion must persist")
    assert(first.onboardingWindow?.isVisible == false)
    assert(first.settingsWindow?.isVisible == false)
    assert(first.permissionWindow?.isVisible == false)
    assert(app.activationPolicy() == .accessory, "Completed onboarding must leave a menu-bar app")
    let clipboard = NSPasteboard.general
    let saved = clipboard.pasteboardItems?.map { item -> NSPasteboardItem in
        let copy = NSPasteboardItem()
        for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
        return copy
    } ?? []
    defer { clipboard.clearContents(); if !saved.isEmpty { clipboard.writeObjects(saved) } }
    first.lastResult = OCRResult(text: "Hello café 中文", confidence: 90, language: "eng")
    func send(_ key: HotKey) {
        var event: EventRef?
        assert(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, EventAttributes(0), &event) == noErr)
        defer { ReleaseEvent(event) }
        var id = EventHotKeyID(signature: 0x4F43524D, id: key.id)
        assert(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &id) == noErr)
        assert(SendEventToEventTarget(event, GetApplicationEventTarget()) == noErr)
    }
    send(first.formattedKey)
    assert(clipboard.string(forType: .string) == "Hello café 中文" && clipboard.data(forType: .rtf) != nil, "Formatted shortcut routing or clipboard formats failed")
    send(first.plainKey)
    assert(clipboard.string(forType: .string) == "Hello café 中文" && clipboard.data(forType: .rtf) == nil, "Plain shortcut routing or format removal failed")
    let used = first.shortcutFor("formatted")
    assert(!first.saveShortcut("capture", key: used.0, modifiers: used.1), "Duplicate shortcuts should be rejected")
    first.feedback.dismiss()
    first.formattedKey.unregister(); first.plainKey.unregister()
    first.hotKey.unregister()
    NSStatusBar.system.removeStatusItem(first.item)
    let next = makeDelegate()
    next.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    assert(next.onboardingWindow == nil, "Later launches must not repeat onboarding")
    assert(next.permissionWindow == nil, "Later launches must stay quiet even without Screen Recording")
    assert(app.activationPolicy() == .accessory)
    assert(next.item != nil, "Menu bar item must remain")
    next.formattedKey.unregister(); next.plainKey.unregister()
    next.hotKey.unregister()
    NSStatusBar.system.removeStatusItem(next.item)
    print("PASS: first launch, unfinished setup, completion persistence, window closure, no Dock after completion, quiet later launches, distinct copy shortcut routing, rich/plain clipboard formats, duplicate rejection")
}
