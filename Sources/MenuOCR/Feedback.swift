import AppKit
import SwiftUI

/// A transient result, shown without activating the app or covering the selected text.
@MainActor
final class Feedback {
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func dismiss() {
        dismissal?.cancel()
        dismissal = nil
        panel?.orderOut(nil)
        panel = nil
    }

    func show(title: String, detail: String, isError: Bool = false, screen: NSScreen? = nil, formatted: (() -> Void)? = nil, plain: (() -> Void)? = nil) {
        dismiss()
        let content = FeedbackView(title: title, detail: detail, isError: isError, formatted: formatted, plain: plain)
        let view = NSHostingView(rootView: content)
        let size = view.fittingSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = view
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = formatted == nil && plain == nil
        panel.animationBehavior = .none
        let target = screen ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = target?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 28))
        }
        self.panel = panel
        // No activation or key-window change: the user's next Cmd-V goes to their current app.
        panel.orderFrontRegardless()
        NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [
            .announcement: "\(title). \(detail)",
            .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
        scheduleDismissal()
    }
    private func scheduleDismissal() {
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
            self?.dismiss()
        }
    }
}

struct FeedbackView: View {
    let title: String
    let detail: String
    let isError: Bool
    var formatted: (() -> Void)? = nil
    var plain: (() -> Void)? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(isError ? Color.orange : Color.green)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let formatted, let plain {
                    HStack { Button("Copy formatted", action: formatted); Button("Copy plain text", action: plain) }.buttonStyle(.bordered)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 360, alignment: .leading)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .windowBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12)))
        .accessibilityElement(children: formatted == nil ? .combine : .contain)
    }
}
