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
    first.hotKey.unregister()
    NSStatusBar.system.removeStatusItem(first.item)
    let next = makeDelegate()
    next.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    assert(next.onboardingWindow == nil, "Later launches must not repeat onboarding")
    assert(next.permissionWindow == nil, "Later launches must stay quiet even without Screen Recording")
    assert(app.activationPolicy() == .accessory)
    assert(next.item != nil, "Menu bar item must remain")
    next.hotKey.unregister()
    NSStatusBar.system.removeStatusItem(next.item)
    print("PASS: first launch, unfinished setup, completion persistence, window closure, no Dock after completion, quiet later launches")
}
