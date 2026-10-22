import AppKit
import SwiftUI
import Carbon
import CoreGraphics

final class HotKey {
    var reference: EventHotKeyRef?
    var handler: EventHandlerRef?
    var action: (() -> Void)?
    private static var nextID: UInt32 = 0
    let id: UInt32
    init() {
        Self.nextID += 1; id = Self.nextID
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return noErr }
            let hotkey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
            var received = EventHotKeyID()
            guard let event, GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &received) == noErr, received.id == hotkey.id else { return OSStatus(eventNotHandledErr) }
            hotkey.action?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(key: UInt32, modifiers: UInt32) -> Bool {
        // Register the replacement first so a conflict preserves the existing shortcut.
        var next: EventHotKeyRef?
        let result = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x4F43524D, id: id), GetApplicationEventTarget(), 0, &next)
        guard result == noErr else { return false }
        if let reference { UnregisterEventHotKey(reference) }
        reference = next
        return true
    }
    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}

@main
struct MenuOCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var item: NSStatusItem!
    let hotKey = HotKey()
    let formattedKey = HotKey()
    let plainKey = HotKey()
    var lastResult: OCRResult?
    let feedback = Feedback()
    var captureScreen: NSScreen?
    var status = "Ready — capture a text region"
    var job: Task<Void, Never>?
    var lastImage: Data?
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    var onboardingDefaults = UserDefaults.standard
    var permissionWindow: NSWindow?
    var shortcutKey = UserDefaults.standard.object(forKey: "key") as? UInt32 ?? UInt32(kVK_ANSI_O)
    var shortcutModifiers = UserDefaults.standard.object(forKey: "modifiers") as? UInt32 ?? UInt32(cmdKey | shiftKey)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "MenuOCR")
        hotKey.action = { [weak self] in self?.capture() }
        if !hotKey.register(key: shortcutKey, modifiers: shortcutModifiers) { status = "Shortcut unavailable — change it in Settings" }
        formattedKey.action = { [weak self] in self?.copyFormatted() }
        plainKey.action = { [weak self] in self?.copyPlain() }
        for mode in ["formatted", "plain"] {
            let shortcut = shortcutFor(mode)
            if !keyFor(mode).register(key: shortcut.0, modifiers: shortcut.1) { status = "Copy shortcut unavailable — change it in Settings" }
        }
        refresh()
        if !onboardingDefaults.bool(forKey: "onboardingCompleted") { onboarding() }
        else if !CGPreflightScreenCaptureAccess() {
            status = "Screen Recording needs to be enabled for this build"
            refresh()
        }
    }
    func refresh() {
        item.button?.image = NSImage(systemSymbolName: job == nil ? "text.viewfinder" : "ellipsis.circle", accessibilityDescription: job == nil ? "MenuOCR" : "MenuOCR is working")
        let menu = NSMenu()
        menu.autoenablesItems = false
        let label = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        label.isEnabled = false; menu.addItem(label)
        add(menu, "Capture Text or QR Code", #selector(capture), enabled: job == nil)
        add(menu, "Copy Formatted Text", #selector(copyFormatted), enabled: lastResult != nil && job == nil)
        add(menu, "Copy Plain Text", #selector(copyPlain), enabled: lastResult != nil && job == nil)
        add(menu, "Languages Folder…", #selector(languagesFolder))
        add(menu, "Cancel", #selector(cancel), enabled: job != nil)
        add(menu, "Copy Last Screenshot", #selector(copyImage), enabled: lastImage != nil && job == nil)
        menu.addItem(.separator())
        add(menu, "Show Last Result…", #selector(showLastResult))
        add(menu, "Settings…", #selector(settings))
        add(menu, "Welcome to MenuOCR…", #selector(onboarding))
        add(menu, "Screen Recording Permission…", #selector(permission))
        add(menu, "Quit MenuOCR", #selector(quit))
        item.menu = menu
        item.button?.toolTip = status
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, enabled: Bool = true) {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self; entry.isEnabled = enabled; menu.addItem(entry)
    }
    @objc func capture() {
        guard job == nil else { NSSound.beep(); return }
        feedback.dismiss()
        captureScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        guard CGPreflightScreenCaptureAccess() else {
            status = "Screen Recording permission is needed to capture"
            refresh(); permission(); return
        }
        status = "Select a region; press Escape to cancel"; refresh()
        job = Task.detached { [self] in
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: dir) }
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let file = dir.appendingPathComponent("capture.png")
                // Allow the menu to dismiss before starting the system region picker.
                try await Task.sleep(nanoseconds: 250_000_000)
                _ = try Command.run("/usr/sbin/screencapture", ["-i", "-s", "-x", "-t", "png", file.path], timeout: 180)
                guard FileManager.default.fileExists(atPath: file.path) else { throw CancellationError() }
                let image = try Data(contentsOf: file)
                await MainActor.run { self.lastImage = image }
                let result = try OCR.recognize(file) { message in
                    DispatchQueue.main.async { self.status = message; self.refresh() }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    guard !Task.isCancelled else {
                        self.status = "Cancelled — clipboard unchanged"
                        self.job = nil; self.refresh(); return
                    }
                    self.lastResult = result
                    self.job = nil
                    self.copyResult(formatted: false)

                }
            } catch {
                let message = (error is CancellationError || Task.isCancelled) ? "Cancelled — clipboard unchanged" : error.localizedDescription
                await MainActor.run {
                    self.status = message; self.job = nil; self.refresh()
                    if !(error is CancellationError) && !Task.isCancelled {
                        self.feedback.show(title: "Couldn’t extract text", detail: "Clipboard unchanged. Open MenuOCR → Show Last Result for details.", isError: true, screen: self.captureScreen)
                    }
                }
            }
        }
        refresh()
    }
    func keyFor(_ mode: String) -> HotKey { mode == "formatted" ? formattedKey : mode == "plain" ? plainKey : hotKey }
    func shortcutFor(_ mode: String) -> (UInt32, UInt32) {
        if mode == "capture" { return (shortcutKey, shortcutModifiers) }
        return (UserDefaults.standard.object(forKey: mode + "Key") as? UInt32 ?? UInt32(mode == "formatted" ? kVK_ANSI_C : kVK_ANSI_V), UserDefaults.standard.object(forKey: mode + "Modifiers") as? UInt32 ?? UInt32(cmdKey | controlKey | shiftKey))
    }
    func saveShortcut(_ mode: String, key: UInt32, modifiers: UInt32) -> Bool {
        for other in ["capture", "formatted", "plain"] where other != mode {
            let value = shortcutFor(other)
            if value.0 == key && value.1 == modifiers { return false }
        }
        let old = shortcutFor(mode)
        if old.0 == key && old.1 == modifiers { return true }
        guard keyFor(mode).register(key: key, modifiers: modifiers) else { return false }
        if mode == "capture" {
            shortcutKey = key; shortcutModifiers = modifiers
            UserDefaults.standard.set(key, forKey: "key"); UserDefaults.standard.set(modifiers, forKey: "modifiers")
        } else {
            UserDefaults.standard.set(key, forKey: mode + "Key"); UserDefaults.standard.set(modifiers, forKey: mode + "Modifiers")
        }
        return true
    }
    @objc func copyFormatted() { copyResult(formatted: true) }
    @objc func copyPlain() { copyResult(formatted: false) }
    func copyResult(formatted: Bool) {
        guard job == nil else { NSSound.beep(); return }
        guard let result = lastResult else { feedback.show(title: "Capture text first", detail: "Use your capture shortcut, then choose a copy mode."); return }
        let item = NSPasteboardItem()
        item.setString(result.text, forType: .string)
        if formatted {
            let rich = result.richText
            guard let data = try? rich.data(from: NSRange(location: 0, length: rich.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) else { status = "Couldn’t create formatted text. Clipboard unchanged."; refresh(); return }
            item.setData(data, forType: .rtf)
        }
        NSPasteboard.general.clearContents()
        let copied = NSPasteboard.general.writeObjects([item])
        status = copied ? (result.qrCodeCount > 0 ? "Copied QR content · \(result.qrCodeCount) code(s)" : "Copied \(formatted ? "formatted" : "plain") text · \(result.language)") : "Clipboard copy failed. Try again."
        refresh()
        if copied && (UserDefaults.standard.object(forKey: "showCopyConfirmation") as? Bool ?? true) {
            feedback.show(title: result.qrCodeCount > 0 ? "QR content copied" : "\(formatted ? "Formatted" : "Plain") text copied", detail: "\(result.text.count) characters · Paste with ⌘V", screen: captureScreen, formatted: { [weak self] in self?.copyFormatted() }, plain: { [weak self] in self?.copyPlain() })
        } else if !copied { feedback.show(title: "Couldn’t copy text", detail: status, isError: true) }
    }
    @objc func languagesFolder() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MenuOCR/tessdata")
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); NSWorkspace.shared.open(folder) }
        catch { status = error.localizedDescription; refresh() }
    }
    @objc func cancel() { job?.cancel() }
    @objc func copyImage() {
        guard let lastImage else { return }
        NSPasteboard.general.clearContents()
        let copied = NSPasteboard.general.setData(lastImage, forType: .png)
        status = copied ? "Screenshot copied" : "Couldn’t copy screenshot. Try again."
        refresh()
        if !copied || (UserDefaults.standard.object(forKey: "showCopyConfirmation") as? Bool ?? true) {
            feedback.show(title: copied ? "Screenshot copied" : "Couldn’t copy screenshot", detail: copied ? "Ready to paste with ⌘V" : "Please try again.", isError: !copied)
        }
    }
    @objc func showLastResult() {
        let alert = NSAlert()
        alert.messageText = "MenuOCR Status"
        alert.informativeText = status
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc func permission() {
        if permissionWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 460), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Allow MenuOCR to capture text"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PermissionSetupView(delegate: self).padding(24).frame(width: 440))
            window.center()
            permissionWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        permissionWindow?.makeKeyAndOrderFront(nil)
    }
    func relaunch() {
        guard job == nil else { return }
        hotKey.unregister(); formattedKey.unregister(); plainKey.unregister()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        let app = self
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error {
                    for mode in ["capture", "formatted", "plain"] {
                        let value = app.shortcutFor(mode); _ = app.keyFor(mode).register(key: value.0, modifiers: value.1)
                    }
                    app.feedback.show(title: "Couldn’t relaunch MenuOCR", detail: error.localizedDescription, isError: true)
                } else { NSApp.terminate(nil) }
            }
        }
    }
    @objc func quit() { job?.cancel(); NSApp.terminate(nil) }
    var shortcutDescription: String {
        let keys: [UInt32: String] = [0:"A",11:"B",8:"C",2:"D",14:"E",3:"F",5:"G",4:"H",34:"I",38:"J",40:"K",37:"L",46:"M",45:"N",31:"O",35:"P",12:"Q",15:"R",1:"S",17:"T",32:"U",9:"V",13:"W",7:"X",16:"Y",6:"Z"]
        let parts = [(UInt32(controlKey), "⌃"), (UInt32(optionKey), "⌥"), (UInt32(shiftKey), "⇧"), (UInt32(cmdKey), "⌘")]
        return parts.filter { shortcutModifiers & $0.0 != 0 }.map { $0.1 }.joined(separator: " ") + " " + (keys[shortcutKey] ?? "?")
    }
    @objc func onboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 570), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Welcome to MenuOCR"
            window.delegate = self
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.contentView = NSHostingView(rootView: OnboardingView(delegate: self))
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }
    func finishOnboarding(capture: Bool) {
        onboardingDefaults.set(true, forKey: "onboardingCompleted")
        onboardingWindow?.close()
        settingsWindow?.close()
        permissionWindow?.close()
        NSApp.setActivationPolicy(.accessory)
        if capture { self.capture() }
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === onboardingWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    @objc func settings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "MenuOCR Settings"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: Preferences(delegate: self))
            window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
struct Preferences: View {
    let delegate: AppDelegate
    @State private var key: UInt32
    @State private var command: Bool
    @State private var shift: Bool
    @State private var option: Bool
    @State private var control: Bool
    @State private var message = ""
    @State private var mode = "capture"
    @AppStorage("showCopyConfirmation") private var showCopyConfirmation = true
    let keys: [(String, UInt32)] = [("A", 0), ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3), ("G", 5), ("H", 4), ("I", 34), ("J", 38), ("K", 40), ("L", 37), ("M", 46), ("N", 45), ("O", 31), ("P", 35), ("Q", 12), ("R", 15), ("S", 1), ("T", 17), ("U", 32), ("V", 9), ("W", 13), ("X", 7), ("Y", 16), ("Z", 6)]
    init(delegate: AppDelegate) {
        self.delegate = delegate
        _key = State(initialValue: delegate.shortcutKey)
        let m = delegate.shortcutModifiers
        _command = State(initialValue: m & UInt32(cmdKey) != 0)
        _shift = State(initialValue: m & UInt32(shiftKey) != 0)
        _option = State(initialValue: m & UInt32(optionKey) != 0)
        _control = State(initialValue: m & UInt32(controlKey) != 0)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Global shortcuts").font(.headline)
            Picker("Action", selection: $mode) { Text("Capture text").tag("capture"); Text("Copy formatted result").tag("formatted"); Text("Copy plain result").tag("plain") }
            .onChange(of: mode) { value in
                let saved = delegate.shortcutFor(value); key = saved.0
                command = saved.1 & UInt32(cmdKey) != 0; shift = saved.1 & UInt32(shiftKey) != 0
                option = saved.1 & UInt32(optionKey) != 0; control = saved.1 & UInt32(controlKey) != 0
            }
            HStack {
                Toggle("⌘", isOn: $command).accessibilityLabel("Command"); Toggle("⇧", isOn: $shift).accessibilityLabel("Shift")
                Toggle("⌥", isOn: $option).accessibilityLabel("Option"); Toggle("⌃", isOn: $control).accessibilityLabel("Control")
                Picker("Key", selection: $key) { ForEach(keys, id: \.1) { Text($0.0).tag($0.1) } }.frame(width: 100)
            }
            Button("Save Shortcut") {
                let modifiers = (command ? UInt32(cmdKey) : 0) | (shift ? UInt32(shiftKey) : 0) | (option ? UInt32(optionKey) : 0) | (control ? UInt32(controlKey) : 0)
                guard command || option || control else { message = "Include Command, Option, or Control."; return }
                guard delegate.saveShortcut(mode, key: key, modifiers: modifiers) else { message = "Shortcut unavailable or already used by another action."; return }
                message = "Shortcut saved."; delegate.status = "Ready — shortcut updated"; delegate.refresh()
            }
            Text(message).foregroundStyle(.secondary)
            Divider()
            Toggle("Show confirmation after copying", isOn: $showCopyConfirmation)
            Button("Preview Confirmation") {
                delegate.feedback.show(title: "Text copied to clipboard", detail: "Preview only · Your clipboard is unchanged")
            }
            Text("Confirmations close automatically and keep your current app focused. Errors remain available in Show Last Result.").font(.caption).foregroundStyle(.secondary)
            Text("OCR checks every installed Tesseract model locally. Many models can take several minutes. Cancel from the menu at any time.").font(.caption)
            Text("Default: ⌘⇧O • Escape cancels region selection.").font(.caption)
        }.padding(24).frame(width: 480)
    }
}
