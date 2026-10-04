import AppKit

final class ClipboardMonitor {

    static let shared = ClipboardMonitor()

    var onNewItem: ((ClipboardItem) -> Void)?

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    private init() {}

    // MARK: - Control

    func start() {
        guard timer == nil else { return }
        // Use a RunLoop timer so it fires even during scroll events
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call right after ClipManager itself writes to the pasteboard, so that write isn't recorded as a new copy.
    func syncChangeCount() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Polling

    private func checkForChanges() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let storageDir = ClipboardStore.shared.storageDirectory else { return }
        guard let item = ClipboardItemFactory.fromCurrentPasteboard(storageDirectory: storageDir) else { return }

        onNewItem?(item)
    }
}
