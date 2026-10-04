import SwiftUI
import AppKit

// MARK: - ClipboardItemView

struct ClipboardItemView: View {

    let item: ClipboardItem
    let isSelected: Bool
    /// Key that pastes this item (nil past the 36th item)
    var shortcut: String? = nil
    /// Position in the multi-paste order, nil when not marked
    var markNumber: Int? = nil

    @State private var isHovered   = false
    @State private var thumbnail: NSImage? = nil
    @EnvironmentObject var store: ClipboardStore

    private var showHighlight: Bool { isSelected || isHovered }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            shortcutKey
            categoryBadge
            contentPreview
            Spacer(minLength: 0)
            trailingActions
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(highlightBackground)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onAppear { loadThumbnail() }
    }

    // MARK: - Shortcut key

    private var shortcutKey: some View {
        Text(shortcut ?? "")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(width: 20, height: 20)
            .background {
                if shortcut != nil {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(isSelected ? 0.14 : 0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                }
            }
            .help(shortcut.map { "Stiskni \($0) pro vložení, ⇧\($0) pro označení" } ?? "")
    }

    // MARK: - Category badge

    private var categoryBadge: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(item.category.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(item.category.color)
            }

            if let markNumber {
                Text("\(markNumber)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .padding(.horizontal, markNumber > 9 ? 2 : 0)
                    .background(Capsule().fill(Color.accentColor))
                    .offset(x: 5, y: -5)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25, bounce: 0.4), value: markNumber)
    }

    // MARK: - Content preview

    @ViewBuilder
    private var contentPreview: some View {
        if item.category == .image, let img = thumbnail {
            imagePreview(img)
        } else {
            textPreview
        }
    }

    private func imagePreview(_ image: NSImage) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Obrázek")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(item.timestamp.relativeFormatted)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Only two lines are shown; never hand SwiftUI a huge string to lay out (v1.0 stored full text)
            Text(String((item.displayText ?? item.category.title).prefix(300)))
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.timestamp.relativeFormatted)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Trailing

    @ViewBuilder
    private var trailingActions: some View {
        if isHovered || item.isPinned {
            HStack(spacing: 4) {
                pinButton
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    private var pinButton: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                store.togglePin(item)
            }
        } label: {
            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 13))
                .foregroundStyle(item.isPinned ? Color.yellow : Color.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(item.isPinned ? "Odepnout" : "Připnout")
    }

    // MARK: - Highlight

    @ViewBuilder
    private var highlightBackground: some View {
        if markNumber != nil {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(isSelected ? 0.24 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal, 4)
        } else if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
                .padding(.horizontal, 4)
        } else if isHovered {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .padding(.horizontal, 4)
        } else {
            Color.clear
        }
    }

    // MARK: - Thumbnail loading

    private func loadThumbnail() {
        guard item.category == .image, thumbnail == nil else { return }
        if let cached = ThumbnailCache.shared.object(forKey: item.id as NSUUID) {
            thumbnail = cached
            return
        }
        // storageDirectory is a nonisolated computed property — safe to read off-actor
        guard let dir = ClipboardStore.shared.storageDirectory else { return }
        let capturedItem = item
        Task.detached(priority: .userInitiated) {
            guard let img = capturedItem.thumbnailImage(storageDirectory: dir) else { return }
            ThumbnailCache.shared.setObject(img, forKey: capturedItem.id as NSUUID)
            await MainActor.run { thumbnail = img }
        }
    }
}

// MARK: - ThumbnailCache

/// Rows are recreated while scrolling / reopening the panel; keep decoded thumbnails around.
enum ThumbnailCache {
    static let shared: NSCache<NSUUID, NSImage> = {
        let cache = NSCache<NSUUID, NSImage>()
        cache.countLimit = 200
        return cache
    }()
}

// MARK: - Date formatting

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.locale = Locale(identifier: "cs_CZ")
    return formatter
}()

extension Date {
    var relativeFormatted: String {
        relativeDateFormatter.localizedString(for: self, relativeTo: Date())
    }
}
