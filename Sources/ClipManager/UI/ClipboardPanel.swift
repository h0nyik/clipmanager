import AppKit
import SwiftUI

// MARK: - ClipboardPanel

final class ClipboardPanel: NSWindow {

    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level                    = .floating
        backgroundColor          = .clear
        isOpaque                 = false
        hasShadow                = true
        isMovableByWindowBackground = false
        hidesOnDeactivate        = true
        collectionBehavior       = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed     = false

        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = frame
        self.contentView = hosting
    }

    // Forward Escape to the SwiftUI content (belt & suspenders)
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            orderOut(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
