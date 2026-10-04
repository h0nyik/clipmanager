import Cocoa
import SwiftUI
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var clipboardPanel: ClipboardPanel?
    private var settingsWindow: NSWindow?

    let store = ClipboardStore.shared
    private let panelState = PanelState()
    private let monitor = ClipboardMonitor.shared
    private let hotkeyManager = HotkeyManager.shared

    /// App that was frontmost when the panel opened — focus goes back there on close / paste.
    private var previousApp: NSRunningApplication?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.shared.load()
        store.load()
        setupMenuBar()
        setupClipboardPanel()
        startMonitoring()
        registerHotkey()
        UpdateChecker.checkForUpdates()
    }

    func applicationWillTerminate(_ notification: Notification) {
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
            .environmentObject(panelState)
        clipboardPanel = ClipboardPanel(contentView: panelView)
    }

    @objc func togglePanel() {
        guard let panel = clipboardPanel else { return }
        if panel.isVisible {
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
            let size = ClipboardPanel.size
            let x = frame.midX - size.width / 2
            let y = frame.midY - size.height / 2 + frame.height * 0.1
            panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: false)
        }

        panelState.didOpen()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
    }

    /// Hides the panel. With `restoreFocus`, the app that was frontmost before gets focus back.
    func closePanel(restoreFocus: Bool = true) {
        guard let panel = clipboardPanel, panel.isVisible else { return }
        panel.orderOut(nil)

        let app = previousApp
        previousApp = nil
        if restoreFocus, let app {
            activate(app)
        }
    }

    // MARK: - Paste

    func pasteItem(_ item: ClipboardItem) {
        guard PasteService.writeToPasteboard(item) else { return }
        store.moveToTop(item)

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
        window.setContentSize(NSSize(width: 460, height: 560))
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
