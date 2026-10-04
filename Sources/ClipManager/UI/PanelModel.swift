import Foundation

// MARK: - PanelModel
// Shared state of the history panel. The window is reused between openings, so everything that
// must start fresh (selection, marks, scroll, animation) is reset in `prepareForOpen()`.

final class PanelModel: ObservableObject {

    /// Drives the open / close animation.
    @Published var isPresented = false

    /// Highlighted row (index into `ClipboardStore.displayItems`).
    @Published var selectedIndex = 0

    /// Items marked for multi-paste, in the order they were marked.
    @Published var marked: [UUID] = []

    /// Labels for the per-item shortcut keys, refreshed on every open (keyboard layout can change).
    @Published private(set) var shortcutLabels: [String] = ItemShortcuts.labels()

    /// Changes on every open — the view scrolls back to the top when it does.
    @Published private(set) var openID = UUID()

    func prepareForOpen() {
        selectedIndex = 0
        marked = []
        shortcutLabels = ItemShortcuts.labels()
        openID = UUID()
    }

    func toggleMark(_ id: UUID) {
        if let idx = marked.firstIndex(of: id) {
            marked.remove(at: idx)
        } else {
            marked.append(id)
        }
    }

    /// 1-based position in the multi-paste order, or nil when not marked.
    func markNumber(of id: UUID) -> Int? {
        marked.firstIndex(of: id).map { $0 + 1 }
    }
}
