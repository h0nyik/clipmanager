import AppKit
import SwiftUI

// MARK: - ClipboardPanel

final class ClipboardPanel: NSWindow {

    static let size = NSSize(width: 420, height: 560)

    init(contentView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level                    = .floating
        backgroundColor          = .clear
        isOpaque                 = false
        hasShadow                = true   // follows the rounded, transparent content
        isMovableByWindowBackground = false
        hidesOnDeactivate        = false  // AppDelegate closes it on deactivate
        collectionBehavior       = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed     = false

        let hosting = NSHostingView(rootView: contentView)
        hosting.sizingOptions = []        // window size is fixed; don't let SwiftUI resize it
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        self.contentView = hosting
    }

    // Escape fallback when the SwiftUI view doesn't have focus
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            (NSApp.delegate as? AppDelegate)?.closePanel()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
