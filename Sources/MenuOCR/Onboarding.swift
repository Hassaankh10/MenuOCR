import SwiftUI
import AppKit
import CoreGraphics

@MainActor
struct OnboardingView: View {
    let delegate: AppDelegate
    @State private var step = 0
    @State private var screenAllowed = CGPreflightScreenCaptureAccess()
    @State private var engineInstalled = OCR.executable != nil
    @State private var shortcut = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink = Color(red: 0.15, green: 0.12, blue: 0.25)
    private let purple = Color(red: 0.34, green: 0.24, blue: 0.70)
    private let headings = ["Any text.\nYours to keep.", "A little setup.\nAll on your Mac.", "Meet your new\nmuscle memory.", "A little shortcut.\nA lot less typing."]
    private let subtitles = ["From a screenshot to your clipboard.\nCapture the words. Keep your flow.", "Two quick checks before your first capture.\nYour screenshots never leave this Mac for OCR.", "Press your shortcut, draw a box, and paste.\nMenuOCR takes care of the rest.", "You'll find us in your menu bar.\nReady whenever the right words aren't selectable."]

    init(delegate: AppDelegate, initialStep: Int = 0) {
        self.delegate = delegate
        _step = State(initialValue: min(3, max(0, initialStep)))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.93, green: 0.90, blue: 1), Color(red: 1, green: 0.94, blue: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 0) {
                HStack {
                    Label("MenuOCR", systemImage: "text.viewfinder").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("MADE FOR YOUR FLOW").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2)
                }.padding(.bottom, 22)
                HStack(alignment: .center, spacing: 36) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(String(format: "%02d / 04", step + 1)).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(purple)
                        Text(headings[step]).font(.system(size: 43, weight: .semibold, design: .serif)).tracking(-1.5).fixedSize(horizontal: false, vertical: true)
                        Text(subtitles[step]).font(.system(size: 15)).lineSpacing(5).foregroundStyle(ink.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
                        if step == 0 {
                            Label("No account. No cloud OCR.", systemImage: "lock.shield").font(.system(size: 12, weight: .medium)).padding(.top, 10)
                        }
                    }.frame(width: 345, alignment: .leading)
                    illustration.frame(maxWidth: .infinity)
                }.frame(maxHeight: .infinity)
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Capsule().fill(index == step ? purple : ink.opacity(0.15)).frame(width: index == step ? 26 : 7, height: 7)
                    }
                    Spacer()
                    Text("\(step + 1) of 4").font(.caption).foregroundStyle(ink.opacity(0.65))
                }.accessibilityElement(children: .ignore).accessibilityLabel("Setup step \(step + 1) of 4").padding(.vertical, 20)
                HStack(spacing: 16) {
                    if step > 0 { Button("Back") { advance(-1) }.buttonStyle(.plain) }
                    Button("Set up later") { delegate.onboardingWindow?.close() }.buttonStyle(.plain).foregroundStyle(ink.opacity(0.7))
                    Spacer()
                    Button(action: next) {
                        HStack(spacing: 16) { Text(step == 0 ? "Let's begin" : step == 3 ? "Take my first capture" : "Continue"); Image(systemName: "arrow.right") }
                            .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 22).padding(.vertical, 15)
                            .background(purple, in: Capsule()).foregroundStyle(.white)
                    }.buttonStyle(.plain).keyboardShortcut(.defaultAction)
                    .disabled(step == 3 && (!screenAllowed || !engineInstalled))
                    .opacity(step == 3 && (!screenAllowed || !engineInstalled) ? 0.45 : 1)
                }
            }.padding(36)
        }
        .foregroundStyle(ink)
        .frame(width: 820, height: 570)
        .preferredColorScheme(.light)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in shortcut = delegate.shortcutDescription }
    }

    @ViewBuilder private var illustration: some View {
        if step == 0 {
            VStack(spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 142, height: 142).shadow(color: purple.opacity(0.18), radius: 20, y: 12).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("The best ideas are\nworth keeping.").font(.system(size: 23, weight: .medium, design: .serif)).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(purple.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    Label("Capture → Copy → Paste", systemImage: "sparkles").font(.system(size: 12, weight: .semibold)).foregroundStyle(purple)
                }.padding(22).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24)).rotationEffect(.degrees(-3))
            }
        } else if step == 1 {
            VStack(alignment: .leading, spacing: 18) {
                setupRow("Local OCR engine", detail: engineInstalled ? "Tesseract is installed." : "Install once with Homebrew.", ready: engineInstalled)
                if !engineInstalled {
                    Text("brew install tesseract").font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    Button("Copy install command") {
                        NSPasteboard.general.clearContents()
                        let copied = NSPasteboard.general.setString("brew install tesseract", forType: .string)
                        delegate.feedback.show(title: copied ? "Install command copied" : "Couldn’t copy command", detail: copied ? "Paste into Terminal to install Tesseract." : "Select the command above and copy it manually.", isError: !copied)
                    }
                    Link("Homebrew installation guide ↗", destination: URL(string: "https://brew.sh")!)
                }
                Divider()
                setupRow("Screen Recording", detail: screenAllowed ? "Permission is enabled." : "Allows you to capture the region you select. No continuous recording.", ready: screenAllowed)
                if !screenAllowed {
                    Button("Enable Screen Recording") { _ = CGRequestScreenCaptureAccess(); delegate.permission() }
                    Text("After enabling access, macOS may require you to quit and reopen MenuOCR.").font(.caption).foregroundStyle(ink.opacity(0.7))
                }
                Button("Check again") { refresh() }
            }.font(.system(size: 12)).padding(24).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
        } else if step == 2 {
            VStack(spacing: 24) {
                Image(systemName: "command").font(.system(size: 42, weight: .light)).foregroundStyle(purple).accessibilityHidden(true)
                Text(shortcut).font(.system(size: 30, weight: .medium, design: .rounded)).padding(22).frame(maxWidth: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16)).shadow(color: ink.opacity(0.1), radius: 0, y: 5)
                VStack(spacing: 10) {
                    Label("Draw around the text", systemImage: "crop")
                    Label("Paste anywhere with ⌘V", systemImage: "doc.on.clipboard")
                }.font(.system(size: 14))
                Button("Make the shortcut yours…") { delegate.settings() }
                Button("Preview the copy confirmation") { delegate.feedback.show(title: "Text copied to clipboard", detail: "Preview only · Your clipboard is unchanged") }
                    .font(.caption)
            }.padding(24).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 24))
        } else {
            VStack(spacing: 24) {
                Image(systemName: engineInstalled && screenAllowed ? "checkmark.seal.fill" : "circle.dashed").font(.system(size: 72)).foregroundStyle(purple).accessibilityHidden(true)
                Text(engineInstalled && screenAllowed ? "Your words await." : "Almost there.").font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(engineInstalled && screenAllowed ? "Start with a few lines of clear text.\nWe'll let you know when it's copied." : "Finish the setup checks before capturing.\nYou can come back at any time.")
                    .font(.system(size: 14)).multilineTextAlignment(.center).lineSpacing(4)
                if !engineInstalled || !screenAllowed { Button("Return to setup") { step = 1; refresh() } }
                Button("Finish without capturing") { finish(capture: false) }.font(.caption)
            }.padding(24).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private func setupRow(_ title: String, detail: String, ready: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle.dashed").font(.system(size: 22)).foregroundStyle(ready ? Color(red: 0.1, green: 0.45, blue: 0.3) : purple)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 14, weight: .semibold)); Text(detail).fixedSize(horizontal: false, vertical: true) }
        }
    }
    private func refresh() { screenAllowed = CGPreflightScreenCaptureAccess(); engineInstalled = OCR.executable != nil; shortcut = delegate.shortcutDescription }
    private func advance(_ delta: Int) { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step = min(3, max(0, step + delta)) }; refresh() }
    private func next() { if step == 3 { finish(capture: true) } else { advance(1) } }
    private func finish(capture: Bool) {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        delegate.onboardingWindow?.close()
        if capture { delegate.capture() }
    }
}
