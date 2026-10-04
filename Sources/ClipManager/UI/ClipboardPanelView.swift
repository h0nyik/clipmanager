import SwiftUI

// MARK: - ClipboardPanelView

struct ClipboardPanelView: View {

    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var panelState: PanelState

    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    private var displayItems: [ClipboardItem] {
        // Pinned items always at top, then rest sorted by timestamp desc
        let pinned   = store.items.filter { $0.isPinned }
        let unpinned = store.items.filter { !$0.isPinned }
        return pinned + unpinned
    }

    private var delegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    var body: some View {
        ZStack {
            // Background: glass material
            GlassBackground()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.4)
                itemList
                Divider().opacity(0.4)
                footer
            }
        }
        .frame(width: ClipboardPanel.size.width, height: ClipboardPanel.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.escape)     { closePanel(); return .handled }
        .onKeyPress(.upArrow)    { moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow)  { moveSelection(by: 1); return .handled }
        .onKeyPress(.return)     { pasteSelected(); return .handled }
        .onKeyPress(.delete)     { deleteSelected(); return .handled }
        .onAppear { resetForOpen() }
        .onChange(of: panelState.openID) { _, _ in resetForOpen() }
        .onChange(of: store.items.count) { _, _ in clampSelection() }
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

            Text("\(store.items.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .monospacedDigit()

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
                (NSApp.delegate as? AppDelegate)?.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Nastavení")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var itemList: some View {
        Group {
            if displayItems.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemView(
                                    item: item,
                                    isSelected: selectedIndex == index
                                )
                                .id(item.id)
                                .onTapGesture {
                                    selectedIndex = index
                                    pasteItem(item)
                                }
                                .contextMenu {
                                    itemContextMenu(item: item)
                                }

                                if index < displayItems.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 12)
                                        .opacity(0.3)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, idx in
                        if let item = displayItems[safe: idx] {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: panelState.openID) { _, _ in
                        if let first = displayItems.first {
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
        HStack(spacing: 16) {
            Label("Vybrat", systemImage: "return")
            Label("Navigovat", systemImage: "arrow.up.arrow.down")
            Label("Smazat", systemImage: "delete.left")
            Label("Zavřít", systemImage: "escape")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.quaternary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Context menu

    @ViewBuilder
    private func itemContextMenu(item: ClipboardItem) -> some View {
        Button(item.isPinned ? "Odepnout" : "Připnout") {
            store.togglePin(item)
        }
        Divider()
        Button("Smazat", role: .destructive) {
            store.removeItem(item)
        }
    }

    // MARK: - Actions

    private func pasteItem(_ item: ClipboardItem) {
        // AppDelegate handles both modes (auto-paste on / copy only)
        delegate?.pasteItem(item)
    }

    private func pasteSelected() {
        guard let item = displayItems[safe: selectedIndex] else { return }
        pasteItem(item)
    }

    private func closePanel() {
        delegate?.closePanel()
    }

    private func deleteSelected() {
        guard let item = displayItems[safe: selectedIndex] else { return }
        store.removeItem(item)
    }

    private func resetForOpen() {
        selectedIndex = 0
        // Focus after the window became key, otherwise arrow keys may not reach the view
        DispatchQueue.main.async { isFocused = true }
    }

    private func clampSelection() {
        selectedIndex = min(selectedIndex, max(0, displayItems.count - 1))
    }

    private func moveSelection(by delta: Int) {
        guard !displayItems.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), displayItems.count - 1)
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
