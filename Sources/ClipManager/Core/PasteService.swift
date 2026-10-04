import AppKit
import CoreGraphics

// MARK: - PasteService

enum PasteService {

    // MARK: - Write to pasteboard

    /// Writes all stored representations of a ClipboardItem back onto NSPasteboard.general.
    /// Returns false (and leaves the pasteboard untouched) if nothing could be restored.
    @discardableResult
    static func writeToPasteboard(_ item: ClipboardItem) -> Bool {
        guard let storageDir = ClipboardStore.shared.storageDirectory else { return false }

        let pbItems: [NSPasteboardItem] = item.payloads.compactMap { payload in
            let pbItem = NSPasteboardItem()
            for type in payload.types {
                if let data = item.data(forType: type, in: payload, storageDirectory: storageDir) {
                    pbItem.setData(data, forType: NSPasteboard.PasteboardType(rawValue: type))
                }
            }
            return pbItem.types.isEmpty ? nil : pbItem
        }

        guard !pbItems.isEmpty else {
            NSSound.beep()
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(pbItems)
        ClipboardMonitor.shared.syncChangeCount()
        return true
    }

    /// Puts plain text on the pasteboard (used for multi-paste of text items).
    static func writeText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ClipboardMonitor.shared.syncChangeCount()
    }

    // MARK: - Simulate Cmd+V

    /// Simulates a ⌘V keystroke. Requires Accessibility permission (check `hasAccessibility` first).
    static func simulateCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }

    // MARK: - Accessibility

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt and opens the Accessibility pane in System Settings.
    static func requestAccessibility() {
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        guard !AXIsProcessTrustedWithOptions(options as CFDictionary) else { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func showAccessibilityHint() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "ClipManager — chybí oprávnění"
        alert.informativeText = """
            Obsah je zkopírovaný ve schránce — vlož ho ručně pomocí ⌘V.

            Pro automatické vkládání přidej ClipManager v Nastavení systému → Soukromí a zabezpečení → Přístupnost. \
            Po aktualizaci aplikace může být potřeba ClipManager ze seznamu odebrat a přidat znovu.
            """
        alert.addButton(withTitle: "Otevřít nastavení")
        alert.addButton(withTitle: "Nevkládat automaticky")
        alert.addButton(withTitle: "Zrušit")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            requestAccessibility()
        case .alertSecondButtonReturn:
            AppSettings.shared.pasteOnSelect = false
        default:
            break
        }
    }
}
