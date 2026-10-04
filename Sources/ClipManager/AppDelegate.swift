import Cocoa
import SwiftUI
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var clipboardPanel: ClipboardPanel?
    private var settingsWindow: NSWindow?

    let store = ClipboardStore.shared
    let panelModel = PanelModel()
    private let monitor = ClipboardMonitor.shared
    private let hotkeyManager = HotkeyManager.shared

    /// App that was frontmost when the panel opened — focus goes back there on close / paste.
    private var previousApp: NSRunningApplication?

    private var keyMonitor: Any?

    /// Bumped on every open/close so a stale "order out after the close animation" is ignored.
    private var panelGeneration = 0
    private var isPanelOpen = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.shared.load()
        store.load()
        setupMenuBar()
        setupClipboardPanel()
        installKeyMonitor()
        startMonitoring()
        registerHotkey()
        UpdateChecker.checkForUpdates()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        monitor.stop()
        store.save(wait: true)
    }

    func applicationWillResignActive(_ notification: Notification) {
        // User switched to another app themselves — don't pull focus back
        closePanel(restoreFocus: false)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipManager")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Zobrazit historii", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Nastavení…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Ukončit ClipManager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - Panel

    private func setupClipboardPanel() {
        let panelView = ClipboardPanelView()
            .environmentObject(store)
            .environmentObject(panelModel)
        clipboardPanel = ClipboardPanel(contentView: panelView)
    }

    @objc func togglePanel() {
        if isPanelOpen {
            closePanel()
        } else {
            openPanel()
        }
    }

    func openPanel() {
        guard let panel = clipboardPanel else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : frontmost

        // Open on the screen the mouse is on
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let size = ClipboardPanel.windowSize
            let x = frame.midX - size.width / 2
            let y = frame.midY - size.height / 2 + frame.height * 0.1
            panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: false)
        }

        panelGeneration += 1
        isPanelOpen = true

        // Start from the collapsed state without animating, then roll out
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            panelModel.isPresented = false
            panelModel.prepareForOpen()
        }

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async { [self] in
            withAnimation(PanelAnimation.open) {
                panelModel.isPresented = true
            }
            panel.refreshShadow(for: 0.5)
        }
    }

    /// Hides the panel (after a short close animation). With `restoreFocus`, the app that was
    /// frontmost before gets focus back right away.
    func closePanel(restoreFocus: Bool = true) {
        guard isPanelOpen, let panel = clipboardPanel else { return }
        isPanelOpen = false
        panelGeneration += 1
        let generation = panelGeneration

        withAnimation(PanelAnimation.close) {
            panelModel.isPresented = false
        }
        panel.refreshShadow(for: PanelAnimation.closeDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + PanelAnimation.closeDuration) { [weak self] in
            guard self?.panelGeneration == generation else { return } // reopened meanwhile
            panel.orderOut(nil)
        }

        let app = previousApp
        previousApp = nil
        if restoreFocus, let app {
            activate(app)
        }
    }

    // MARK: - Keyboard

    /// All panel keys are handled here by keyCode (layout independent), before SwiftUI sees them.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isPanelOpen, event.window === self.clipboardPanel else { return event }
            return self.handlePanelKey(event) ? nil : event
        }
    }

    /// Returns true when the key was consumed.
    private func handlePanelKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let items = store.displayItems

        switch Int(event.keyCode) {
        case kVK_Escape:
            closePanel()
            return true
        case kVK_UpArrow:
            moveSelection(by: -1, count: items.count)
            return true
        case kVK_DownArrow:
            moveSelection(by: 1, count: items.count)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            pasteSelectedOrMarked(items)
            return true
        case kVK_Delete, kVK_ForwardDelete:
            if let item = items[safe: panelModel.selectedIndex] {
                store.removeItem(item)
                panelModel.marked.removeAll { $0 == item.id }
                panelModel.selectedIndex = min(panelModel.selectedIndex, max(0, items.count - 2))
            }
            return true
        case kVK_Space:
            if let item = items[safe: panelModel.selectedIndex] {
                panelModel.toggleMark(item.id)
            }
            return true
        default:
            break
        }

        // Item keys: plain → paste that item, ⇧ → mark it for multi-paste
        guard flags.isSubset(of: .shift), let index = ItemShortcuts.index(forKeyCode: event.keyCode) else {
            return false
        }
        guard let item = items[safe: index] else {
            NSSound.beep()
            return true
        }
        if flags.contains(.shift) {
            panelModel.toggleMark(item.id)
            panelModel.selectedIndex = index
        } else {
            Log.paste.info("Paste via item key #\(index + 1)")
            pasteItem(item)
        }
        return true
    }

    private func moveSelection(by delta: Int, count: Int) {
        guard count > 0 else { return }
        panelModel.selectedIndex = min(max(panelModel.selectedIndex + delta, 0), count - 1)
    }

    func pasteSelectedOrMarked(_ items: [ClipboardItem]? = nil) {
        let items = items ?? store.displayItems
        if !panelModel.marked.isEmpty {
            let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            pasteItems(panelModel.marked.compactMap { byID[$0] })
        } else if let item = items[safe: panelModel.selectedIndex] {
            pasteItem(item)
        }
    }

    // MARK: - Paste

    func pasteItem(_ item: ClipboardItem) {
        guard PasteService.writeToPasteboard(item) else { return }
        store.moveToTop(item)
        finishPaste()
    }

    /// Pastes several items in the given order. All-text selections are joined into one paste;
    /// mixed selections (images, files…) are pasted one after another.
    func pasteItems(_ items: [ClipboardItem]) {
        guard items.count > 1 else {
            if let item = items.first { pasteItem(item) }
            return
        }
        guard let storageDir = store.storageDirectory else { return }
        Log.paste.info("Multi-paste of \(items.count) items")

        let texts = items.compactMap { $0.plainText(storageDirectory: storageDir) }
        if texts.count == items.count {
            PasteService.writeText(texts.joined(separator: AppSettings.shared.multiPasteSeparator.string))
            finishPaste()
            return
        }

        let target = previousApp
        closePanel(restoreFocus: true)
        guard AppSettings.shared.pasteOnSelect, let target, PasteService.hasAccessibility else {
            // Without auto-paste only one item can sit on the clipboard — take the first one
            PasteService.writeToPasteboard(items[0])
            if AppSettings.shared.pasteOnSelect, target != nil { PasteService.showAccessibilityHint() }
            return
        }
        pasteSequentially(items[...], into: target)
    }

    private func pasteSequentially(_ items: ArraySlice<ClipboardItem>, into target: NSRunningApplication) {
        guard let item = items.first else { return }
        guard PasteService.writeToPasteboard(item) else {
            pasteSequentially(items.dropFirst(), into: target)
            return
        }
        whenFrontmost(target) { [weak self] isFrontmost in
            guard isFrontmost else { return } // user switched away — stop
            PasteService.simulateCmdV()
            // Give the target app time to read the clipboard before it's replaced
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.pasteSequentially(items.dropFirst(), into: target)
            }
        }
    }

    /// Closes the panel and, if enabled, sends ⌘V to the app the user came from.
    private func finishPaste() {
        let target = previousApp
        closePanel(restoreFocus: true)

        guard AppSettings.shared.pasteOnSelect, let target else { return }
        guard PasteService.hasAccessibility else {
            PasteService.showAccessibilityHint()
            return
        }

        whenFrontmost(target) { isFrontmost in
            // Never send ⌘V to some other app than the one the user came from
            if isFrontmost { PasteService.simulateCmdV() }
        }
    }

    /// Waits (up to ~0.5 s) until `app` is frontmost, then gives it a moment to make its window key.
    private func whenFrontmost(_ app: NSRunningApplication, attemptsLeft: Int = 20, then action: @escaping (Bool) -> Void) {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action(true) }
        } else if attemptsLeft == 0 {
            action(false)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
                self?.whenFrontmost(app, attemptsLeft: attemptsLeft - 1, then: action)
            }
        }
    }

    private func activate(_ app: NSRunningApplication) {
        // macOS 14 cooperative activation: hand activation over explicitly, then request it
        NSApp.yieldActivation(to: app)
        _ = app.activate(from: NSRunningApplication.current, options: [])
    }

    // MARK: - Settings

    @objc func openSettings() {
        closePanel(restoreFocus: false)

        if let existing = settingsWindow, existing.isVisible {
            NSApp.activate()
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView().environmentObject(store)
        let hosting = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Nastavení ClipManager"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 460, height: 640))
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Private helpers

    private func startMonitoring() {
        monitor.onNewItem = { [weak self] item in
            DispatchQueue.main.async {
                self?.store.addItem(item)
            }
        }
        monitor.start()
    }

    private func registerHotkey() {
        let settings = AppSettings.shared
        let registered = hotkeyManager.register(
            keyCode: UInt32(settings.hotkeyKeyCode),
            modifiers: UInt32(settings.hotkeyModifiers)
        ) {
            DispatchQueue.main.async {
                (NSApp.delegate as? AppDelegate)?.togglePanel()
            }
        }

        if !registered {
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "Zkratku \(settings.hotkeyDisplayString) nelze použít"
            alert.informativeText = "Nejspíš ji už používá jiná aplikace. Historii otevřeš kliknutím na ikonu ClipManageru v menu baru."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func reregisterHotkey() {
        hotkeyManager.unregister()
        registerHotkey()
    }
}
