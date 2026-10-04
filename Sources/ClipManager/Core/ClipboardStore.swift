import AppKit
import Combine

// MARK: - ClipboardStore

final class ClipboardStore: ObservableObject {

    static let shared = ClipboardStore()

    @Published var items: [ClipboardItem] = []

    // nonisolated — safe to call from any thread (FileManager.default is thread-safe)
    var storageDirectory: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("io.clipmanager.app", isDirectory: true)
    }

    private var metadataURL: URL? {
        storageDirectory?.appendingPathComponent("history.json")
    }

    /// JSON encoding + writing happens here, off the main thread.
    private let saveQueue = DispatchQueue(label: "io.clipmanager.store.save", qos: .utility)
    private var pendingSave: DispatchWorkItem?

    private init() {}

    /// Order shown in the panel: pinned items first, then the rest newest first.
    var displayItems: [ClipboardItem] {
        items.filter(\.isPinned) + items.filter { !$0.isPinned }
    }

    // MARK: - Mutations

    func addItem(_ item: ClipboardItem) {
        // Same content copied again → bump the existing entry instead of storing a duplicate
        if let hash = item.contentHash, let idx = items.firstIndex(where: { $0.contentHash == hash }) {
            deleteItemFiles(item)
            var existing = items.remove(at: idx)
            existing.timestamp = Date()
            items.insert(existing, at: 0)
            scheduleSave()
            return
        }

        items.insert(item, at: 0)
        trimToLimit()
        scheduleSave()
    }

    /// Moves an item to the top of the history (after it was pasted from the panel).
    func moveToTop(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        var moved = items.remove(at: idx)
        moved.timestamp = Date()
        items.insert(moved, at: 0)
        scheduleSave()
    }

    func removeItem(_ item: ClipboardItem) {
        deleteItemFiles(item)
        items.removeAll { $0.id == item.id }
        scheduleSave()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        scheduleSave()
    }

    func clearAll(keepPinned: Bool = true) {
        let toRemove = keepPinned ? items.filter { !$0.isPinned } : items
        toRemove.forEach { deleteItemFiles($0) }
        if keepPinned {
            items.removeAll { !$0.isPinned }
        } else {
            items.removeAll()
        }
        scheduleSave()
    }

    /// Asks before wiping the history (one stray click on the trash icon used to delete everything).
    static func confirmClearHistory() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Vymazat historii schránky?"
        alert.informativeText = "Připnuté položky zůstanou zachované."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Vymazat")
        alert.addButton(withTitle: "Zrušit")
        alert.buttons.first?.hasDestructiveAction = true
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Drops the oldest unpinned items over the configured limit.
    func trimToLimit() {
        let limit = max(1, AppSettings.shared.historyLimit)
        var unpinnedCount = items.filter { !$0.isPinned }.count
        var trimmed = false
        while unpinnedCount > limit, let idx = items.lastIndex(where: { !$0.isPinned }) {
            deleteItemFiles(items[idx])
            items.remove(at: idx)
            unpinnedCount -= 1
            trimmed = true
        }
        if trimmed { scheduleSave() }
    }

    // MARK: - Persistence

    /// Coalesces bursts of changes into one write.
    func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Writes the current history (or removes it when persistence is off). Call on the main thread.
    func save(wait: Bool = false) {
        pendingSave?.cancel()
        pendingSave = nil
        guard let dir = storageDirectory, let metaURL = metadataURL else { return }

        let persist = AppSettings.shared.persistHistory
        let snapshot = items
        saveQueue.async {
            guard persist else {
                try? FileManager.default.removeItem(at: metaURL)
                return
            }
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: metaURL, options: .atomic)
            } catch {
                Log.store.error("Save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if wait { saveQueue.sync {} }
    }

    func load() {
        defer { pruneOrphanedFiles() }

        guard let metaURL = metadataURL,
              FileManager.default.fileExists(atPath: metaURL.path) else { return }

        guard AppSettings.shared.persistHistory else {
            try? FileManager.default.removeItem(at: metaURL)
            return
        }

        do {
            let data = try Data(contentsOf: metaURL)
            // One undecodable entry shouldn't wipe the whole history
            items = try JSONDecoder().decode([LossyItem].self, from: data).compactMap(\.value)
        } catch {
            Log.store.error("Load failed, history moved to history.corrupt.json: \(error.localizedDescription, privacy: .public)")
            // Keep the unreadable file for inspection instead of overwriting it on the next save
            let backup = metaURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: metaURL, to: backup)
            items = []
        }
    }

    // MARK: - File cleanup

    private func deleteItemFiles(_ item: ClipboardItem) {
        guard let dir = storageDirectory else { return }
        let itemDir = dir.appendingPathComponent(item.id.uuidString)
        try? FileManager.default.removeItem(at: itemDir)
    }

    /// Removes data directories no history entry points to (crash leftovers, history not persisted).
    private func pruneOrphanedFiles() {
        guard let dir = storageDirectory,
              let contents = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: [.isDirectoryKey]
              ) else { return }

        let referenced = Set(items.map { $0.id.uuidString })
        for url in contents {
            let name = url.lastPathComponent
            guard UUID(uuidString: name) != nil, !referenced.contains(name),
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - LossyItem

private struct LossyItem: Decodable {
    let value: ClipboardItem?

    init(from decoder: Decoder) throws {
        value = try? ClipboardItem(from: decoder)
    }
}
