import SwiftUI
import UniformTypeIdentifiers

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject var store: ClipboardStore
    @ObservedObject private var settings = AppSettings.shared

    @State private var historyLimitStr: String = ""
    @State private var hasAccessibility = PasteService.hasAccessibility

    var body: some View {
        Form {
            generalSection
            hotkeySection
            storageSection
            updateSection
            dangerSection
            aboutSection
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
        .onAppear {
            historyLimitStr = "\(settings.historyLimit)"
            hasAccessibility = PasteService.hasAccessibility
        }
        // Permission is granted in System Settings — refresh when the user comes back
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = PasteService.hasAccessibility
        }
        .onChange(of: settings.persistHistory) { _, _ in
            store.save()
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
                    .onSubmit(applyHistoryLimit)
                    .onDisappear(perform: applyHistoryLimit)
                Text("položek")
                    .foregroundStyle(.secondary)
            }

            Picker("Oddělovač při hromadném vložení textu", selection: $settings.multiPasteSeparator) {
                ForEach(AppSettings.MultiPasteSeparator.allCases) { separator in
                    Text(separator.title).tag(separator)
                }
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
                if ClipboardStore.confirmClearHistory() {
                    store.clearAll(keepPinned: true)
                }
            }
            .foregroundStyle(.red)
        }
    }

    private var updateSection: some View {
        Section("Aktualizace") {
            Toggle("Kontrolovat aktualizace automaticky", isOn: $settings.checkUpdates)

            HStack {
                Text("Verze \(UpdateChecker.currentVersion) (\(UpdateChecker.currentBuild))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Zkontrolovat nyní") {
                    UpdateChecker.checkForUpdates(force: true)
                }
            }
        }
    }

    private var dangerSection: some View {
        Section("Přístupnost") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label(
                        hasAccessibility ? "Automatické vkládání povoleno" : "Automatické vkládání nemá oprávnění",
                        systemImage: hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(hasAccessibility ? Color.green : Color.orange)
                    Text("Nastavení systému → Soukromí a zabezpečení → Přístupnost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !hasAccessibility {
                    Button("Povolit…") {
                        PasteService.requestAccessibility()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("O aplikaci") {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClipManager \(UpdateChecker.currentVersion)")
                        .font(.headline)
                    Text(Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© h0nyik · jeKral.cz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Link("jeKral.cz", destination: URL(string: "https://jekral.cz")!)
            }

            Button("Exportovat diagnostiku…", action: exportDiagnostics)
                .help("Uloží záznamy aplikace (bez obsahu schránky) pro nahlášení chyby")
        }
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ClipManager-diagnostika.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Log.exportDiagnostics().write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            Log.app.error("Diagnostics export failed: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    private func applyHistoryLimit() {
        if let val = Int(historyLimitStr), val > 0, val <= 10_000 {
            settings.historyLimit = val
            store.trimToLimit()
        } else {
            historyLimitStr = "\(settings.historyLimit)"
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
