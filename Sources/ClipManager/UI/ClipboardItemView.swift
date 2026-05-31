import SwiftUI
import AppKit

// MARK: - ClipboardItemView

struct ClipboardItemView: View {

    let item: ClipboardItem
    let isSelected: Bool

    @State private var isHovered   = false
    @State private var thumbnail: NSImage? = nil
    @EnvironmentObject var store: ClipboardStore

    private var showHighlight: Bool { isSelected || isHovered }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
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

    // MARK: - Category badge

    private var categoryBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(item.category.color.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: item.category.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(item.category.color)
        }
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
            Text(item.displayText ?? item.category.rawValue)
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
        if isSelected {
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
        // storageDirectory is a nonisolated computed property — safe to read off-actor
        guard let dir = ClipboardStore.shared.storageDirectory else { return }
        let capturedItem = item
        Task.detached(priority: .userInitiated) {
            let img = capturedItem.thumbnailImage(storageDirectory: dir)
            await MainActor.run { thumbnail = img }
        }
    }
}

// MARK: - Date formatting

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "cs_CZ")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
