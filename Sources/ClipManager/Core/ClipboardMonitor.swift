import AppKit
import Combine

final class ClipboardMonitor {

    static let shared = ClipboardMonitor()

    var onNewItem: ((ClipboardItem) -> Void)?

    /// Set to true before writing to NSPasteboard programmatically to skip the next change.
    var ignoringNextChange = false

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    private init() {}

    // MARK: - Control

    func start() {
        guard timer == nil else { return }
        // Use a RunLoop timer so it fires even during scroll events
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    private func checkForChanges() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if ignoringNextChange {
            ignoringNextChange = false
            return
        }

        guard let storageDir = ClipboardStore.shared.storageDirectory else { return }
        guard let item = ClipboardItemFactory.fromCurrentPasteboard(storageDirectory: storageDir) else { return }

        onNewItem?(item)
    }
}
