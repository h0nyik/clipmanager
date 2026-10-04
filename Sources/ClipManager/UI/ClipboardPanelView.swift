import SwiftUI

// MARK: - PanelAnimation

enum PanelAnimation {
    static let open = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let closeDuration: TimeInterval = 0.14
    static let close = Animation.easeIn(duration: closeDuration)

    /// Rows slide in one after another; only the first ~10 are staggered.
    static func row(index: Int) -> Animation {
        .spring(response: 0.36, dampingFraction: 0.82).delay(Double(min(index, 10)) * 0.018)
    }
}

// MARK: - ClipboardPanelView
// Keyboard input is handled by AppDelegate (keyCode based, see ItemShortcuts); this view only renders
// PanelModel and handles mouse interaction.

struct ClipboardPanelView: View {

    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var model: PanelModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size = ClipboardPanel.size
    private let cornerRadius: CGFloat = 18

    private var delegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    private var shown: Bool { model.isPresented }

    var body: some View {
        card
            // Roll-out: the card is revealed top-down while it scales and fades in
            .mask(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .frame(height: shown || reduceMotion ? size.height : size.height * 0.18)
            }
            .scaleEffect(shown || reduceMotion ? 1 : 0.97, anchor: .top)
            .offset(y: shown || reduceMotion ? 0 : -6)
            .opacity(shown ? 1 : 0)
            .frame(width: ClipboardPanel.windowSize.width, height: ClipboardPanel.windowSize.height)
    }

    // MARK: - Card

    private var card: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.4)
                itemList
                Divider().opacity(0.4)
                footer
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "clipboard")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Historie schránky")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if model.marked.isEmpty {
                Text("\(store.items.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            } else {
                Button {
                    delegate?.pasteSelectedOrMarked()
                } label: {
                    Label("Vložit \(model.marked.count)", systemImage: "square.stack.3d.down.forward")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Vložit označené položky v pořadí označení (↵)")
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                if ClipboardStore.confirmClearHistory() {
                    store.clearAll(keepPinned: true)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Vymazat historii (zachovat připnuté)")

            Button {
                delegate?.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Nastavení")
        }
        .animation(.spring(duration: 0.25), value: model.marked.isEmpty)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var itemList: some View {
        let items = store.displayItems

        return Group {
            if items.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemView(
                                    item: item,
                                    isSelected: model.selectedIndex == index,
                                    shortcut: model.shortcutLabels[safe: index],
                                    markNumber: model.markNumber(of: item.id)
                                )
                                .id(item.id)
                                .opacity(shown ? 1 : 0)
                                .offset(y: shown || reduceMotion ? 0 : 8)
                                .animation(
                                    shown && !reduceMotion ? PanelAnimation.row(index: index) : PanelAnimation.close,
                                    value: shown
                                )
                                .onTapGesture { handleTap(item, index: index) }
                                .contextMenu { itemContextMenu(item: item) }

                                if index < items.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 12)
                                        .opacity(0.3)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: model.selectedIndex) { _, idx in
                        if let item = store.displayItems[safe: idx] {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: model.openID) { _, _ in
                        if let first = store.displayItems.first {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("Schránka je prázdná")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            hint("1–M", "Vložit")
            hint("␣", "Označit")
            hint("↵", model.marked.isEmpty ? "Vložit" : "Vložit vše")
            hint("⌫", "Smazat")
            hint("esc", "Zavřít")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func hint(_ key: String, _ title: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(title)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func itemContextMenu(item: ClipboardItem) -> some View {
        Button("Vložit") {
            delegate?.pasteItem(item)
        }
        Button(model.markNumber(of: item.id) == nil ? "Označit pro hromadné vložení" : "Zrušit označení") {
            model.toggleMark(item.id)
        }
        Button(item.isPinned ? "Odepnout" : "Připnout") {
            store.togglePin(item)
        }
        Divider()
        Button("Smazat", role: .destructive) {
            model.marked.removeAll { $0 == item.id }
            store.removeItem(item)
        }
    }

    // MARK: - Actions

    private func handleTap(_ item: ClipboardItem, index: Int) {
        model.selectedIndex = index
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) {
            model.toggleMark(item.id)
        } else {
            delegate?.pasteItem(item)
        }
    }
}

// MARK: - GlassBackground

struct GlassBackground: View {
    var body: some View {
        ZStack {
            if #available(macOS 26, *) {
                Color.clear
                    .background(.regularMaterial)
            } else {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            }
        }
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material      = material
        v.blendingMode  = blendingMode
        v.state         = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material     = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Array safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
