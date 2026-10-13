import AppKit
import SwiftUI
import Combine
import CoreGraphics

@MainActor
struct PermissionSetupView: View {
    let delegate: AppDelegate
    @State private var allowed = CGPreflightScreenCaptureAccess()
    @State private var requested = false
    @State private var settingsError = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: allowed ? "checkmark.circle.fill" : "rectangle.dashed.badge.record")
                    .font(.title2).foregroundStyle(allowed ? Color.green : Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Screen Recording").font(.headline)
                    Text(allowed ? "Enabled · You're ready to capture" : requested ? "Waiting for permission" : "One permission. Your choice.").font(.subheadline)
                }
            }
            Text("MenuOCR needs access to the pixels in the region you select. OCR runs locally, and temporary screenshots are deleted after processing.").font(.caption).fixedSize(horizontal: false, vertical: true)
            Text("Accessibility permission is not needed.").font(.caption).foregroundStyle(.secondary)
            if !allowed {
                Button {
                    if !requested {
                        requested = true
                        _ = CGRequestScreenCaptureAccess()
                        refresh()
                        if !allowed { openSettings() }
                    } else { openSettings() }
                } label: {
                    Text(requested ? "Open System Settings" : "Allow Screen Recording…")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color(red: 0.34, green: 0.24, blue: 0.70), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Open Privacy & Security → Screen Recording.")
                    Text("2. Enable MenuOCR. If it isn't listed, use + to select the installed app.")
                    Text("3. Return here. We'll check automatically.")
                }.font(.caption).fixedSize(horizontal: false, vertical: true)
                if requested {
                    Text("Enabled it already? macOS may need MenuOCR to reopen before the change takes effect.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Relaunch MenuOCR") { delegate.relaunch() }.disabled(delegate.job != nil)
                }
                Button("Show MenuOCR in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            } else {
                Text("Press \(delegate.shortcutDescription) to capture, then ⌘V to paste.").font(.caption)
            }
            if settingsError {
                Text("Couldn't open settings. Open System Settings → Privacy & Security → Screen Recording manually.").font(.caption).foregroundStyle(.red)
            }
        }
        .onReceive(timer) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .onChange(of: allowed) { granted in
            if granted {
                delegate.status = "Screen Recording enabled — ready to capture"
                if delegate.item != nil { delegate.refresh() }
            }
        }
    }
    private func refresh() { allowed = CGPreflightScreenCaptureAccess() }
    private func openSettings() {
        settingsError = !NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}
