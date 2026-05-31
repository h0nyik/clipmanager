import Foundation
import Cocoa
import ServiceManagement

// MARK: - AppSettings

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Keys

    private enum Key: String {
        case historyLimit       = "historyLimit"
        case hotkeyKeyCode      = "hotkeyKeyCode"
        case hotkeyModifiers    = "hotkeyModifiers"
        case persistHistory     = "persistHistory"
        case pasteOnSelect      = "pasteOnSelect"
        case launchAtLogin      = "launchAtLogin"
        case checkUpdates       = "checkUpdates"
    }

    // MARK: - Properties

    @Published var historyLimit: Int = 100 {
        didSet { defaults.set(historyLimit, forKey: Key.historyLimit.rawValue) }
    }

    // Carbon: V key = 0x09, Shift+Cmd = (shiftKey | cmdKey) = 512 | 256 = 768
    @Published var hotkeyKeyCode: Int = 0x09 {
        didSet { defaults.set(hotkeyKeyCode, forKey: Key.hotkeyKeyCode.rawValue) }
    }

    @Published var hotkeyModifiers: Int = 768 {
        didSet { defaults.set(hotkeyModifiers, forKey: Key.hotkeyModifiers.rawValue) }
    }

    @Published var persistHistory: Bool = true {
        didSet { defaults.set(persistHistory, forKey: Key.persistHistory.rawValue) }
    }

    @Published var pasteOnSelect: Bool = true {
        didSet { defaults.set(pasteOnSelect, forKey: Key.pasteOnSelect.rawValue) }
    }

    @Published var launchAtLogin: Bool = false {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin.rawValue)
            applyLaunchAtLogin()
        }
    }

    @Published var checkUpdates: Bool = true {
        didSet { defaults.set(checkUpdates, forKey: Key.checkUpdates.rawValue) }
    }

    // MARK: - Load saved values

    func load() {
        defaults.register(defaults: [
            Key.historyLimit.rawValue:    100,
            Key.hotkeyKeyCode.rawValue:   0x09,
            Key.hotkeyModifiers.rawValue: 768,
            Key.persistHistory.rawValue:  true,
            Key.pasteOnSelect.rawValue:   true,
            Key.launchAtLogin.rawValue:   false,
            Key.checkUpdates.rawValue:    true,
        ])

        historyLimit     = defaults.integer(forKey: Key.historyLimit.rawValue)
        hotkeyKeyCode    = defaults.integer(forKey: Key.hotkeyKeyCode.rawValue)
        hotkeyModifiers  = defaults.integer(forKey: Key.hotkeyModifiers.rawValue)
        persistHistory   = defaults.bool(forKey: Key.persistHistory.rawValue)
        pasteOnSelect    = defaults.bool(forKey: Key.pasteOnSelect.rawValue)
        launchAtLogin    = defaults.bool(forKey: Key.launchAtLogin.rawValue)
        checkUpdates     = defaults.bool(forKey: Key.checkUpdates.rawValue)
    }

    // MARK: - Launch at Login (macOS 13+)

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[AppSettings] Launch at login error: \(error)")
        }
    }

    // MARK: - Hotkey display string

    var hotkeyDisplayString: String {
        var parts: [String] = []
        let mods = hotkeyModifiers
        if mods & 256  != 0 { parts.append("⌘") }
        if mods & 512  != 0 { parts.append("⇧") }
        if mods & 2048 != 0 { parts.append("⌥") }
        if mods & 4096 != 0 { parts.append("⌃") }
        parts.append(carbonKeyName(keyCode: hotkeyKeyCode))
        return parts.joined()
    }

    private func carbonKeyName(keyCode: Int) -> String {
        let map: [Int: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x32: "`", 0x31: "Space",
        ]
        return map[keyCode] ?? "?"
    }
}
