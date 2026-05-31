# ClipManager

Jednoduchý, rychlý a nativní správce historie schránky pro macOS.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Funkce

- **Ukládá vše** — text, obrázky, RTF, HTML, soubory, barvy, a jakýkoli jiný typ dat ze schránky
- **Rychlý přístup** — zobrazí historii stisknutím `⇧⌘V` (nastavitelné)
- **Pinned položky** — připni důležité položky, aby se nevymazaly
- **Náhledy obrázků** — miniatury přímo v seznamu
- **Automatické vkládání** — vybráním položky se obsah okamžitě vloží (`⌘V`) do aktivní aplikace
- **Persistence** — historie přežije restart aplikace
- **Nativní design** — odpovídá aktuálním standardům macOS (glass efekty, SF Symbols)
- **Menu bar app** — běží na pozadí, neobtěžuje v docku
- **Universal binary** — funguje na Apple Silicon i Intel Mac

## Instalace

### DMG (doporučeno)

1. Stáhni nejnovější `ClipManager-x.x.x.dmg` z [Releases](https://github.com/roztisk/clipmanager/releases)
2. Přetáhni `ClipManager.app` do `/Applications`
3. Spusť aplikaci

> **Pozor:** Aplikace není notarizována App Store, ale je podepisována Developer ID certifikátem.  
> Pokud macOS zablokuje spuštění: Systémová nastavení → Soukromí & Zabezpečení → Otevřít přesto

### Homebrew (plánováno)

```sh
brew install --cask clipmanager
```

## Sestavení ze zdrojového kódu

**Požadavky:**
- macOS 14.0+
- Xcode 15+ nebo Swift 5.9 toolchain

```sh
git clone https://github.com/roztisk/clipmanager.git
cd clipmanager

# Sestavení .app bundle (universal binary)
make app

# Nebo debug build pro vývoj
swift build -c debug --arch arm64
```

Sestavenou aplikaci najdeš v `build/ClipManager.app`.

## Použití

| Akce | Zkratka |
|------|---------|
| Zobrazit historii | `⇧⌘V` |
| Navigace v seznamu | `↑` / `↓` |
| Vložit vybranou položku | `↵ Enter` |
| Zavřít panel | `Esc` |
| Připnout / odepnout | hover → klik na 📌 |
| Nastavení | Pravý klik na ikonu v menu baru |

## Oprávnění

- **Přístupnost** — vyžadováno pro automatické vkládání (`⌘V`). Aplikace si sama požádá o povolení.
- **Síť** — pouze pro kontrolu aktualizací (GitHub API). Žádná data schránky se neodesílají.

## Architektura

```
Sources/ClipManager/
├── main.swift                  # Entry point
├── AppDelegate.swift           # App lifecycle, menu bar, panel management
├── Core/
│   ├── ClipboardItem.swift     # Datový model + factory (čte NSPasteboard)
│   ├── ClipboardMonitor.swift  # Polling NSPasteboard (0.5s interval)
│   ├── ClipboardStore.swift    # Správa dat + persistence (JSON + soubory)
│   ├── HotkeyManager.swift     # Carbon RegisterEventHotKey (bez Accessibility)
│   ├── PasteService.swift      # Zápis na NSPasteboard + simulace ⌘V
│   ├── AppSettings.swift       # UserDefaults-backed nastavení
│   └── UpdateChecker.swift     # GitHub Releases API kontrola
└── UI/
    ├── ClipboardPanel.swift    # NSWindow subclass (floating, glass)
    ├── ClipboardPanelView.swift # Hlavní SwiftUI view
    ├── ClipboardItemView.swift # Řádek položky (text / obrázek / soubor)
    └── SettingsView.swift      # Nastavení
```

## CI/CD

- **Apple Silicon** — GitHub Actions (`macos-15`, M-series runner) → universal binary
- **Intel Mac** — self-hosted runner s labelom `intel-mac`
- **Release** — tag `v*.*.*` spustí build → podpis → DMG → GitHub Release

### Self-hosted Intel runner

```sh
# Na Intel Macu:
# 1. GitHub → Settings → Actions → Runners → New self-hosted runner
# 2. Vyber macOS, label: intel-mac
# 3. Následuj instrukce z GitHubu
```

### GitHub Secrets (pro release builds)

| Secret | Popis |
|--------|-------|
| `CODESIGN_IDENTITY` | Developer ID Application: ... |
| `CODESIGN_CERT_P12_B64` | Base64 .p12 certifikát |
| `CODESIGN_CERT_PASSPHRASE` | Heslo k .p12 |
| `NOTARIZE_APPLE_ID` | Apple ID pro notarizaci |
| `NOTARIZE_TEAM_ID` | Team ID (Apple Developer) |
| `NOTARIZE_PASSWORD` | App-specific password |

## Roadmap

- [ ] Vyhledávání v historii
- [ ] Blacklist aplikací (nemonitorovat hesla z 1Password apod.)
- [ ] Sparkle auto-update (místo GitHub API)
- [ ] Homebrew Cask
- [ ] Nastavitelná klávesová zkratka přes UI

## Licence

MIT — viz [LICENSE](LICENSE)
