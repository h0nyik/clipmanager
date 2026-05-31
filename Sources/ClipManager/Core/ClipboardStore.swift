import Foundation
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

    private init() {}

    // MARK: - Mutations

    func addItem(_ item: ClipboardItem) {
        let settings = AppSettings.shared

        // Deduplicate: skip if the topmost non-pinned item has identical display text and category
        if let topItem = items.first(where: { !$0.isPinned }),
           topItem.category == item.category,
           topItem.displayText == item.displayText,
           item.category != .image {
            return
        }

        // Identical images check via first inline data value
        if item.category == .image,
           let firstNew = item.inlineData.values.first,
           let topImage = items.first(where: { !$0.isPinned && $0.category == .image }),
           topImage.inlineData.values.first == firstNew {
            return
        }

        items.insert(item, at: 0)

        // Trim oldest unpinned items over the limit
        let limit = settings.historyLimit
        var unpinnedCount = items.filter { !$0.isPinned }.count
        while unpinnedCount > limit {
            if let idx = items.lastIndex(where: { !$0.isPinned }) {
                deleteItemFiles(items[idx])
                items.remove(at: idx)
                unpinnedCount -= 1
            } else {
                break
            }
        }

        if settings.persistHistory {
            save()
        }
    }

    func removeItem(_ item: ClipboardItem) {
        deleteItemFiles(item)
        items.removeAll { $0.id == item.id }
        save()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        save()
    }

    func clearAll(keepPinned: Bool = true) {
        let toRemove = keepPinned ? items.filter { !$0.isPinned } : items
        toRemove.forEach { deleteItemFiles($0) }
        if keepPinned {
            items.removeAll { !$0.isPinned }
        } else {
            items.removeAll()
        }
        save()
    }

    // MARK: - Persistence

    func save() {
        guard let dir = storageDirectory, let metaURL = metadataURL else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: metaURL, options: .atomic)
        } catch {
            print("[ClipboardStore] Save error: \(error)")
        }
    }

    func load() {
        guard AppSettings.shared.persistHistory,
              let metaURL = metadataURL,
              FileManager.default.fileExists(atPath: metaURL.path) else { return }
        do {
            let data = try Data(contentsOf: metaURL)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            print("[ClipboardStore] Load error: \(error)")
            items = []
        }
    }

    // MARK: - File cleanup

    private func deleteItemFiles(_ item: ClipboardItem) {
        guard let dir = storageDirectory else { return }
        let itemDir = dir.appendingPathComponent(item.id.uuidString)
        try? FileManager.default.removeItem(at: itemDir)
    }
}
