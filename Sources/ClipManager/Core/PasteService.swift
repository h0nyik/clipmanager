import AppKit
import CoreGraphics

// MARK: - PasteService

enum PasteService {

    // MARK: - Write to pasteboard

    /// Writes all stored data from a ClipboardItem back onto NSPasteboard.general.
    static func writeToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard let storageDir = ClipboardStore.shared.storageDirectory else { return }

        let pbItem = NSPasteboardItem()

        for typeString in item.pasteboardTypes {
            let pbType = NSPasteboard.PasteboardType(rawValue: typeString)

            var data: Data?

            if let b64 = item.inlineData[typeString] {
                data = Data(base64Encoded: b64)
            } else if let filename = item.fileData[typeString] {
                let fileURL = storageDir
                    .appendingPathComponent(item.id.uuidString)
                    .appendingPathComponent(filename)
                data = try? Data(contentsOf: fileURL)
            }

            if let data {
                pbItem.setData(data, forType: pbType)
            }
        }

        pasteboard.writeObjects([pbItem])
    }

    // MARK: - Simulate Cmd+V

    /// Simulates ⌘V keystroke using CGEventPost.
    /// Requires Accessibility permission; if not granted, does nothing (user can press Cmd+V manually).
    static func simulateCmdV() {
        guard AXIsProcessTrusted() else {
            // Show a subtle toast or notification to inform the user
            showAccessibilityHint()
            return
        }

        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)   // V
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Accessibility check

    static func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private static func showAccessibilityHint() {
        let alert = NSAlert()
        alert.messageText = "ClipManager — chybí oprávnění"
        alert.informativeText = "Přidej ClipManager do Accessibility v Nastavení systému → Soukromí & Zabezpečení → Přístupnost, aby fungovalo automatické vkládání."
        alert.addButton(withTitle: "Otevřít nastavení")
        alert.addButton(withTitle: "Zrušit")
        if alert.runModal() == .alertFirstButtonReturn {
            requestAccessibilityIfNeeded()
        }
    }
}
