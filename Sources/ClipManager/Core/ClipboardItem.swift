import AppKit
import CryptoKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ClipboardItem

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var timestamp: Date
    var isPinned: Bool

    /// One payload per NSPasteboardItem (e.g. several files copied at once in Finder).
    var payloads: [Payload]

    /// Cached display text for text-like content (already trimmed and length-capped)
    var displayText: String?

    /// Category for icon / color / grouping
    var category: Category

    /// SHA-256 of all types + data, used for de-duplication. nil for items saved by v1.0.
    var contentHash: String?

    // MARK: - Payload

    struct Payload: Codable, Equatable {
        /// Pasteboard types in their original order
        var types: [String]
        /// Inline data for small representations (key: UTI, value: base64)
        var inlineData: [String: String]
        /// Filenames of large representations in the item's data directory (key: UTI, value: filename)
        var fileData: [String: String]
    }

    // MARK: - Category

    enum Category: String, Codable {
        case plainText
        case richText
        case html
        case image
        case fileURL
        case color
        case other

        var icon: String {
            switch self {
            case .plainText:  return "doc.text"
            case .richText:   return "doc.richtext"
            case .html:       return "chevron.left.forwardslash.chevron.right"
            case .image:      return "photo"
            case .fileURL:    return "folder"
            case .color:      return "paintpalette"
            case .other:      return "doc"
            }
        }

        var color: Color {
            switch self {
            case .plainText:  return .blue
            case .richText:   return .indigo
            case .html:       return .orange
            case .image:      return .green
            case .fileURL:    return .yellow
            case .color:      return .pink
            case .other:      return Color(.systemGray)
            }
        }

        /// Fallback title when there is no display text
        var title: String {
            switch self {
            case .plainText, .richText, .html: return "Text"
            case .image:   return "Obrázek"
            case .fileURL: return "Soubor"
            case .color:   return "Barva"
            case .other:   return "Data"
            }
        }
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        isPinned: Bool = false,
        payloads: [Payload],
        displayText: String?,
        category: Category,
        contentHash: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.payloads = payloads
        self.displayText = displayText
        self.category = category
        self.contentHash = contentHash
    }

    // MARK: - Codable (reads the v1.0 single-payload format too)

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, isPinned, payloads, displayText, category, contentHash
        // v1.0
        case pasteboardTypes, inlineData, fileData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        timestamp   = try c.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        isPinned    = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        displayText = try c.decodeIfPresent(String.self, forKey: .displayText)
        category    = (try? c.decode(Category.self, forKey: .category)) ?? .other
        contentHash = try c.decodeIfPresent(String.self, forKey: .contentHash)

        if let payloads = try c.decodeIfPresent([Payload].self, forKey: .payloads) {
            self.payloads = payloads
        } else {
            payloads = [Payload(
                types:      try c.decodeIfPresent([String].self, forKey: .pasteboardTypes) ?? [],
                inlineData: try c.decodeIfPresent([String: String].self, forKey: .inlineData) ?? [:],
                fileData:   try c.decodeIfPresent([String: String].self, forKey: .fileData) ?? [:]
            )]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(isPinned, forKey: .isPinned)
        try c.encode(payloads, forKey: .payloads)
        try c.encodeIfPresent(displayText, forKey: .displayText)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(contentHash, forKey: .contentHash)
    }

    // MARK: - Helpers

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id && lhs.isPinned == rhs.isPinned && lhs.timestamp == rhs.timestamp
    }

    /// Raw data of one representation, from inline storage or from the item's data directory.
    func data(forType type: String, in payload: Payload, storageDirectory: URL) -> Data? {
        if let b64 = payload.inlineData[type] {
            return Data(base64Encoded: b64)
        }
        if let filename = payload.fileData[type] {
            let url = storageDirectory
                .appendingPathComponent(id.uuidString, isDirectory: true)
                .appendingPathComponent(filename)
            return try? Data(contentsOf: url)
        }
        return nil
    }
}

// MARK: - ClipboardItemFactory

enum ClipboardItemFactory {

    /// Representations larger than this are stored as files instead of inline base64 in history.json.
    static let inlineLimit = 32_000

    /// Display text is capped so huge copies don't bloat history.json or slow down list layout.
    static let maxDisplayLength = 2_000

    /// Marker types apps put on the pasteboard to say "don't record this" (nspasteboard.org) —
    /// password managers, generated/transient content, etc.
    private static let ignoredMarkerTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword",
        "de.petermaurer.TransientPasteboardType",
        "com.typeit4me.clipping",
        "Pasteboard generator type",
    ]

    /// Reads all data from the current NSPasteboard and creates a ClipboardItem.
    /// Returns nil if the pasteboard is empty or marked as concealed/transient.
    static func fromCurrentPasteboard(storageDirectory: URL) -> ClipboardItem? {
        let pasteboard = NSPasteboard.general
        guard let pasteboardItems = pasteboard.pasteboardItems, !pasteboardItems.isEmpty else {
            return nil
        }

        let allTypes = Set(pasteboardItems.flatMap { $0.types.map(\.rawValue) })
        guard allTypes.isDisjoint(with: ignoredMarkerTypes) else { return nil }

        let itemID = UUID()
        let itemDir = storageDirectory.appendingPathComponent(itemID.uuidString, isDirectory: true)

        var payloads: [ClipboardItem.Payload] = []
        var hasher = SHA256()
        var firstData: [NSPasteboard.PasteboardType: Data] = [:]
        var fileURLs: [URL] = []

        for (index, pbItem) in pasteboardItems.enumerated() {
            var payload = ClipboardItem.Payload(types: [], inlineData: [:], fileData: [:])

            for type in pbItem.types {
                guard let data = pbItem.data(forType: type) else { continue }
                let typeString = type.rawValue

                if data.count > inlineLimit {
                    let filename = "\(index)_" + typeString
                        .replacingOccurrences(of: "/", with: "_")
                        .replacingOccurrences(of: ".", with: "_")
                    do {
                        try FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)
                        try data.write(to: itemDir.appendingPathComponent(filename))
                    } catch {
                        print("[ClipboardItemFactory] Failed to store \(typeString): \(error)")
                        continue
                    }
                    payload.fileData[typeString] = filename
                } else {
                    payload.inlineData[typeString] = data.base64EncodedString()
                }

                payload.types.append(typeString)
                hasher.update(data: Data(typeString.utf8))
                hasher.update(data: data)

                if firstData[type] == nil { firstData[type] = data }
                if type == .fileURL,
                   let string = String(data: data, encoding: .utf8),
                   let url = URL(string: string) {
                    fileURLs.append(url)
                }
            }

            if !payload.types.isEmpty { payloads.append(payload) }
        }

        guard !payloads.isEmpty else { return nil }

        let (category, displayText) = describe(
            plainText: pasteboard.string(forType: .string),
            firstData: firstData,
            fileURLs: fileURLs
        )

        return ClipboardItem(
            id: itemID,
            payloads: payloads,
            displayText: displayText,
            category: category,
            contentHash: hasher.finalize().map { String(format: "%02x", $0) }.joined()
        )
    }

    // MARK: - Categorization

    /// Picks category + preview text. Priority: files > text > image > rich text without plain text > color.
    /// (Finder puts an icon TIFF next to file URLs and Office puts a picture next to text,
    /// so "contains an image" alone doesn't mean the user copied an image.)
    private static func describe(
        plainText: String?,
        firstData: [NSPasteboard.PasteboardType: Data],
        fileURLs: [URL]
    ) -> (ClipboardItem.Category, String?) {
        let types = Array(firstData.keys)
        func conforming(_ uti: UTType) -> Data? {
            types.first { UTType($0.rawValue)?.conforms(to: uti) == true }.flatMap { firstData[$0] }
        }

        if !fileURLs.isEmpty {
            let names = fileURLs.map { $0.lastPathComponent }
            let text = names.count == 1 ? names[0] : "\(names[0]) + \(names.count - 1) další"
            return (.fileURL, text)
        }

        let rtf  = firstData[.rtf] ?? conforming(.rtf)
        let html = firstData[.html] ?? conforming(.html)

        if let plainText, let text = clip(plainText) {
            if rtf != nil { return (.richText, text) }
            if html != nil { return (.html, text) }
            return (.plainText, text)
        }

        let hasImage = types.contains { $0 == .tiff || $0 == .png || UTType($0.rawValue)?.conforms(to: .image) == true }
        if hasImage { return (.image, nil) }

        if let rtf, let text = plainTextFromRTF(rtf) { return (.richText, clip(text)) }
        if let html, let string = String(data: html, encoding: .utf8) { return (.html, clip(plainTextFromHTML(string))) }

        if types.contains(where: { $0 == .color || $0.rawValue.contains("NSColor") }) {
            return (.color, nil)
        }
        return (.other, nil)
    }

    private static func clip(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxDisplayLength))
    }

    private static func plainTextFromRTF(_ data: Data) -> String? {
        try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ).string
    }

    /// Cheap tag stripping for previews — NSAttributedString's HTML importer spins up WebKit
    /// on the main thread, which is far too slow to run on every copy.
    private static func plainTextFromHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

// MARK: - Thumbnails

extension ClipboardItem {

    /// Downsampled thumbnail if this item contains image data (never decodes the full-size image).
    func thumbnailImage(storageDirectory: URL, maxPixelSize: Int = 160) -> NSImage? {
        guard category == .image, let payload = payloads.first else { return nil }

        let preferred = [
            NSPasteboard.PasteboardType.png.rawValue,
            NSPasteboard.PasteboardType.tiff.rawValue,
            UTType.jpeg.identifier,
        ]
        let candidates = preferred.filter { payload.types.contains($0) }
            + payload.types.filter { !preferred.contains($0) && UTType($0)?.conforms(to: .image) == true }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        for type in candidates {
            guard let data = data(forType: type, in: payload, storageDirectory: storageDirectory),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else { continue }
            return NSImage(cgImage: cgImage, size: .zero)
        }
        return nil
    }
}
