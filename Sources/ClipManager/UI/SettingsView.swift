import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject var store: ClipboardStore
    @ObservedObject private var settings = AppSettings.shared

    @State private var isRecordingHotkey = false
    @State private var historyLimitStr: String = ""

    var body: some View {
        Form {
            generalSection
            hotkeySection
            storageSection
            updateSection
            dangerSection
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
        .onAppear {
            historyLimitStr = "\(settings.historyLimit)"
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section("Obecné") {
            Toggle("Spustit při přihlášení", isOn: $settings.launchAtLogin)

            Toggle("Automaticky vložit (Cmd+V) po výběru", isOn: $settings.pasteOnSelect)

            HStack {
                Text("Limit historie")
                Spacer()
                TextField("100", text: $historyLimitStr)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .onSubmit {
                        if let val = Int(historyLimitStr), val > 0, val <= 10_000 {
                            settings.historyLimit = val
                        } else {
                            historyLimitStr = "\(settings.historyLimit)"
                        }
                    }
                Text("položek")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hotkeySection: some View {
        Section("Klávesová zkratka") {
            HStack {
                Text("Zobrazit historii")
                Spacer()
                HotkeyBadge(displayString: settings.hotkeyDisplayString)
                Button("Změnit…") {
                    // TODO: Present hotkey recorder sheet
                    // For now, show a placeholder
                    showHotkeyPickerAlert()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }

    private var storageSection: some View {
        Section("Ukládání") {
            Toggle("Zachovat historii přes restart", isOn: $settings.persistHistory)

            HStack {
                Text("Uloženo položek")
                Spacer()
                Text("\(store.items.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button("Vymazat historii (zachovat připnuté)") {
                store.clearAll(keepPinned: true)
            }
            .foregroundStyle(.red)
        }
    }

    private var updateSection: some View {
        Section("Aktualizace") {
            Toggle("Kontrolovat aktualizace automaticky", isOn: $settings.checkUpdates)

            Button("Zkontrolovat nyní") {
                UpdateChecker.checkForUpdates(force: true)
            }
        }
    }

    private var dangerSection: some View {
        Section("Přístupnost") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatické vkládání")
                        .font(.body)
                    Text("Vyžaduje povolení v Nastavení systému → Soukromí → Přístupnost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Otevřít nastavení") {
                    PasteService.requestAccessibilityIfNeeded()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Hotkey picker (simplified alert for now)

    private func showHotkeyPickerAlert() {
        let alert = NSAlert()
        alert.messageText = "Klávesová zkratka"
        alert.informativeText = "Úprava klávesové zkratky bude dostupná v další verzi.\n\nAktuální zkratka: \(settings.hotkeyDisplayString)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - HotkeyBadge

struct HotkeyBadge: View {
    let displayString: String

    var body: some View {
        Text(displayString)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
