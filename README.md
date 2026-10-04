# ClipManager

Jednoduchý, rychlý a nativní správce historie schránky pro macOS.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Funkce

- **Ukládá vše** — text, obrázky, RTF, HTML, soubory (i více najednou), barvy, a jakýkoli jiný typ dat ze schránky
- **Neukládá hesla** — respektuje značky správců hesel (1Password, Bitwarden aj. — `org.nspasteboard.ConcealedType`)
- **Bez duplicit** — opakované zkopírování stejného obsahu jen posune položku nahoru
- **Rychlý přístup** — zobrazí historii stisknutím `⇧⌘V`, s nativní animací
- **Vložení jednou klávesou** — položky mají klávesy `1–0`, `Q–P`, `A–L`, `Z–M` (36 položek), funguje i na české klávesnici
- **Hromadné vložení** — označ víc položek (`␣` / `⇧`+klávesa / `⌘`-klik) a vlož je najednou v pořadí označení
- **Pinned položky** — připni důležité položky, aby se nevymazaly
- **Náhledy obrázků** — miniatury přímo v seznamu
- **Automatické vkládání** — vybráním položky se obsah okamžitě vloží (`⌘V`) do aktivní aplikace
- **Persistence** — historie přežije restart aplikace
- **Nativní design** — odpovídá aktuálním standardům macOS (glass efekty, SF Symbols)
- **Menu bar app** — běží na pozadí, neobtěžuje v docku
- **Universal binary** — funguje na Apple Silicon i Intel Mac

## Instalace

### DMG (doporučeno)

1. Stáhni nejnovější `ClipManager-x.x.x.dmg` z [Releases](https://github.com/h0nyik/clipmanager/releases)
2. Přetáhni `ClipManager.app` do `/Applications`
3. Spusť aplikaci

> **Pozor:** Bez nastavených podpisových secrets (viz níže) je build podepsaný jen ad-hoc a není notarizovaný.
> macOS pak první spuštění zablokuje: Nastavení systému → Soukromí a zabezpečení → **Přesto otevřít**
> (nebo `xattr -dr com.apple.quarantine /Applications/ClipManager.app`).
> Ad-hoc podpis se mění s každým buildem, proto je po aktualizaci potřeba ClipManager v Přístupnosti odebrat a přidat znovu.

### Homebrew (plánováno)

```sh
brew install --cask clipmanager
```

## Sestavení ze zdrojového kódu

**Požadavky:**
- macOS 14.0+
- Xcode 15+ nebo Swift 5.9 toolchain

```sh
git clone https://github.com/h0nyik/clipmanager.git
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
| Vložit položku jednou klávesou | `1`…`0`, `Q`…`P`, `A`…`L`, `Z`…`M` |
| Navigace v seznamu | `↑` / `↓` |
| Vložit vybranou položku | `↵ Enter` / klik |
| Označit pro hromadné vložení | `␣` / `⇧` + klávesa položky / `⌘`-klik |
| Vložit označené (v pořadí označení) | `↵ Enter` |
| Smazat vybranou položku | `⌫` |
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
├── AppDelegate.swift           # App lifecycle, menu bar, panel, vkládání do předchozí aplikace
├── Core/
│   ├── ClipboardItem.swift     # Datový model + factory (čte NSPasteboard)
│   ├── ClipboardMonitor.swift  # Polling NSPasteboard (0.5s interval)
│   ├── ClipboardStore.swift    # Správa dat + persistence (JSON + soubory)
│   ├── HotkeyManager.swift     # Carbon RegisterEventHotKey (bez Accessibility)
│   ├── PasteService.swift      # Zápis na NSPasteboard + simulace ⌘V
│   ├── AppSettings.swift       # UserDefaults-backed nastavení
│   ├── UpdateChecker.swift     # GitHub Releases API kontrola
│   ├── ItemShortcuts.swift     # Mapování položek na klávesy (podle keyCode)
│   └── Log.swift               # Unified Logging + export diagnostiky
└── UI/
    ├── ClipboardPanel.swift    # NSWindow subclass (floating, glass)
    ├── PanelModel.swift        # Stav panelu: animace, výběr, označené položky
    ├── ClipboardPanelView.swift # Hlavní SwiftUI view
    ├── ClipboardItemView.swift # Řádek položky (text / obrázek / soubor)
    └── SettingsView.swift      # Nastavení
```

## CI/CD

- **Apple Silicon** — GitHub Actions (`macos-15`, M-series runner) → universal binary
- **Intel Mac** — self-hosted runner s labelom `intel-mac`
- **Release** — tag `v*.*.*` spustí build → podpis → DMG → (notarizace) → GitHub Release.
  Tag s pomlčkou (`v1.2.0-beta.1`) vytvoří pre-release, který kontrola aktualizací ignoruje.
- **Každý build** (push / PR) nahraje DMG jako artifact — ke stažení v záložce Actions

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

## Ikona

Zdroj je `Assets/AppIcon.svg`. PNG se vyrenderuje přes `node Scripts/render-icon.mjs` (Playwright),
`.icns` vyrobí `Scripts/build-app.sh` při sestavení.

## Licence

MIT — viz [LICENSE](LICENSE). © 2025–2026 h0nyik · [jeKral.cz](https://jekral.cz)
