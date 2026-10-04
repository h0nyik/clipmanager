import Carbon.HIToolbox
import Foundation

// MARK: - ItemShortcuts
// Keys that pick a history item directly: number row, then the three letter rows → 36 items.
// Matched by physical key (keyCode), so they work on any layout — e.g. on the Czech keyboard the
// number row types "+ěščřžýáíé" without Shift, yet the keys still map to items 1–10.

enum ItemShortcuts {

    static let keyCodes: [UInt16] = [
        // 1 2 3 4 5 6 7 8 9 0
        0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19, 0x1D,
        // Q W E R T Y U I O P
        0x0C, 0x0D, 0x0E, 0x0F, 0x11, 0x10, 0x20, 0x22, 0x1F, 0x23,
        // A S D F G H J K L
        0x00, 0x01, 0x02, 0x03, 0x05, 0x04, 0x26, 0x28, 0x25,
        // Z X C V B N M
        0x06, 0x07, 0x08, 0x09, 0x0B, 0x2D, 0x2E,
    ]

    private static let numberRowLabels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private static let qwertyLabels = Array("QWERTYUIOPASDFGHJKLZXCVBNM").map(String.init)

    static var count: Int { keyCodes.count }

    /// Item index for a pressed key, or nil if the key isn't one of the item keys.
    static func index(forKeyCode keyCode: UInt16) -> Int? {
        keyCodes.firstIndex(of: keyCode)
    }

    /// Labels in item order. Number row is always shown as digits; letters follow the current layout
    /// (so QWERTZ shows Z where the key really is).
    static func labels() -> [String] {
        let letterCodes = keyCodes.dropFirst(numberRowLabels.count)
        let letters = zip(letterCodes, qwertyLabels).map { code, fallback in
            layoutCharacter(for: code).flatMap { $0.count == 1 ? $0 : nil } ?? fallback
        }
        return numberRowLabels + letters
    }

    /// Character the key produces in the current keyboard layout (uppercased), via UCKeyTranslate.
    private static func layoutCharacter(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawLayout = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = Unmanaged<CFData>.fromOpaque(rawLayout).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}
