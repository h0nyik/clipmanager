import AppKit
import SwiftUI

// MARK: - ClipboardPanel

final class ClipboardPanel: NSWindow {

    /// Size of the visible card.
    static let size = NSSize(width: 420, height: 560)
    /// Transparent margin around the card so the open animation (offset/scale) isn't clipped.
    static let shadowMargin: CGFloat = 36
    static let windowSize = NSSize(width: size.width + 2 * shadowMargin, height: size.height + 2 * shadowMargin)

    init(contentView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level                    = .floating
        backgroundColor          = .clear
        isOpaque                 = false
        hasShadow                = true   // follows the card's alpha; refreshed while it animates
        isMovableByWindowBackground = false
        hidesOnDeactivate        = false  // AppDelegate closes it on deactivate
        collectionBehavior       = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed     = false

        let hosting = NSHostingView(rootView: contentView)
        hosting.sizingOptions = []        // window size is fixed; don't let SwiftUI resize it
        hosting.frame = NSRect(origin: .zero, size: Self.windowSize)
        self.contentView = hosting
    }

    /// The window shadow is computed from the content's alpha, so recompute it on every frame
    /// while the card animates.
    func refreshShadow(for duration: TimeInterval) {
        let end = Date().addingTimeInterval(duration)
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            self?.invalidateShadow()
            if Date() >= end { timer.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
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
