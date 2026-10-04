# ClipManager — plán dalšího vývoje

Stav k 4. 10. 2026. Základ je v1.1.0 (stabilita, soukromí, release pipeline).
Plán je rozdělený do fází: fáze 1 nezávisí na žádném serveru a dělá se hned,
fáze 2 a 3 potřebují rozhodnutí (viz [Otevřené otázky](#otevřené-otázky)).

---

## Fáze 1 — aplikace (bez serveru)

### 1.1 Animace otevření / zavření panelu
Teď se panel objeví naráz. Cíl: nativní pocit (Spotlight, Raycast).
- Otevření: pružina (`spring`, cca 0.32 s), panel se odroluje shora dolů
  (maska výšky), lehké zvětšení 0.96 → 1 a zprůhlednění 0 → 1.
- Položky najíždějí postupně (stagger ~15 ms, jen prvních ~10 viditelných).
- Zavření: rychlé (~0.14 s) zarolování + fade, okno se schová až po animaci.
- Respektuje **Omezit pohyb** (jen krátký crossfade).
- Implementace: `PanelModel.isPresented` řídí SwiftUI animaci; AppDelegate
  okno ukáže hned a schová až po dokončení zavírací animace.

### 1.2 Výběr položky klávesou
Každá z prvních položek dostane klávesu, stisk ji rovnou vloží.
- Pořadí: `1 2 3 4 5 6 7 8 9 0`, pak `Q W E R T Y U I O P`, `A S D F G H J K L`,
  `Z X C V B N M` → **36 položek**.
- Klávesy se mapují podle **fyzické pozice** (keyCode), takže fungují i na české
  klávesnici, kde číselná řada píše `+ěščřžýáíé`. Číselná řada je popsaná
  číslicemi, písmena podle aktuálního rozložení (Z/Y na QWERTZ sedí).
- Odznak s klávesou vlevo u každé položky.
- Klávesnice v panelu se zpracovává na jednom místě (`NSEvent` local monitor
  podle keyCode). Dnes se dělí mezi SwiftUI `onKeyPress` a `keyDown` okna.

### 1.3 Hromadné vložení
- Označení položek: `Mezerník` (aktuální řádek), `⇧` + klávesa položky, `⌘`-klik.
- Označené položky mají pořadové číslo (1, 2, 3…), vloží se **v pořadí
  označení**.
- `↵` s označenými položkami je vloží postupně do původní aplikace
  (zápis do schránky → ⌘V → krátká pauza → další). Funguje i pro obrázky
  a soubory, nejen text.
- Volba v nastavení: oddělovač mezi textovými položkami (nový řádek / nic).

### 1.4 Ikona aplikace
- Moderní ikona ve stylu macOS (squircle, gradient, vrstvené „karty“ schránky).
- Zdroj `Resources/AppIcon.svg` → PNG 1024 px → `AppIcon.icns` (sips + iconutil
  v build skriptu). DMG dostane stejnou ikonu.

### 1.5 Copyright a O aplikaci
- `© 2025–2026 h0nyik · jeKral.cz` v Info.plist, LICENSE, nastavení
  (sekce O aplikaci s odkazem na jeKral.cz) a v README.

### 1.6 Logování
- `os.Logger` (Unified Logging, subsystem `io.clipmanager.app`) místo `print`,
  kategorie `clipboard`, `paste`, `store`, `hotkey`, `update`, `license`.
- Obsah schránky se **nikdy** neloguje (jen typy a velikosti).
- „Exportovat diagnostiku“ v nastavení: posledních 24 h logů do souboru,
  aby šlo poslat hlášení chyby.

---

## Fáze 2 — licence a Free / Pro

### Model
| | Free | Pro |
|---|---|---|
| Položky v historii | např. 10 | neomezeně (limit z nastavení) |
| Mapování kláves | prvních 10 (číselná řada) | všech 36 |
| Hromadné vložení | ✗ | ✓ |
| Připnuté položky | 3 | neomezeně |

(Konkrétní čísla jsou na rozhodnutí.)

### Klient
- `LicenseManager`: stav `free / trial / pro / revoked`, aktivace klíčem,
  uložení do Klíčenky (Keychain), ne do UserDefaults.
- Licence = podepsaný token (Ed25519, veřejný klíč v aplikaci, CryptoKit).
  Ověřuje se offline, takže aplikace funguje i bez internetu.
- Pravidelná online kontrola (při startu + každých 24 h): server potvrdí,
  že licence a **tato instalace** jsou platné. Tolerance offline 14 dní.
- Zrušená licence nebo zablokovaná instalace → přechod na **Free** (historie
  se zkrátí na limit Free, data se nesmažou, oznámení s důvodem). Aplikace se
  nevypíná úplně. Uživatel o data nepřijde a je to právně čistší.
- Možnost „nouzového vypnutí“ konkrétní verze (např. kritická chyba) přes
  pole `minSupportedVersion` v odpovědi serveru → výzva k aktualizaci.

### Server — varianta A: Lemon Squeezy / Paddle (doporučeno na start)
- Platby, DPH (OSS v EU), faktury a **licenční API** v jednom
  (aktivace, validace, počet instancí na klíč, deaktivace instance).
- Žádný vlastní server pro licence. Vypnutí konkrétní instalace = deaktivace
  instance v dashboardu.

### Server — varianta B: vlastní backend
- Např. Supabase (Postgres + Edge Functions) nebo Vercel + DB.
- Endpointy: `POST /v1/activate`, `POST /v1/heartbeat`, `POST /v1/deactivate`,
  admin `POST /v1/admin/instances/{id}/block`.
- Tabulky `licenses`, `installations`, `heartbeats`. Platby by stejně šly přes
  platební bránu (Stripe / Lemon Squeezy) s webhookem.

---

## Fáze 3 — telemetrie a přehled instancí

### Co se posílá
- Anonymní ID instalace (náhodné UUID, ne hardware ID), verze aplikace
  a macOS, architektura, jazyk, tier licence.
- Agregované počty: otevření panelu, vložení (klikem / klávesou / hromadně),
  počet položek v historii, pády.
- **Nikdy obsah schránky**, názvy souborů ani názvy aplikací.
- Země se určí na serveru z IP a IP se neukládá. Tak vznikne mapa aktivních
  instancí po světě.

### Jak
- Události se ukládají lokálně a odesílají dávkově (1× za hodinu, gzip).
  Bez sítě se nic neztratí, fronta má limit.
- Heartbeat (fáze 2) slouží zároveň jako „instance je spuštěná“, takže
  dashboard ukáže aktivní instance za posledních 24 h / 7 dní.
- Dashboard: Supabase / Grafana / jednoduchá stránka nad DB.

### Souhlas (GDPR)
- Telemetrie je **opt-in**: při prvním spuštění dialog „Pomoci zlepšovat
  ClipManager anonymními statistikami?“ a přepínač v nastavení.
- Heartbeat licence (kvůli ověření licence) je nutný pro Pro a bude
  popsaný v zásadách ochrany osobních údajů.
- Potřeba: stránka se zásadami ochrany osobních údajů na jeKral.cz.

---

## Otevřené otázky
1. **Backend licencí:** Lemon Squeezy / Paddle (A), nebo vlastní server (B)?
   Pokud B: Supabase, nebo Vercel?
2. **Limity Free** a cena Pro (jednorázově / předplatné)?
3. **Open source:** repozitář je veřejný pod MIT. Kdokoli může licenční kontrolu
   odstranit a aplikaci si sestavit sám. Možnosti: nechat MIT (Pro jako
   „podpora autora“), změnit licenci budoucích verzí (např. source-available),
   nebo repozitář zneveřejnit. Už vydané verze zůstávají MIT.
4. **Apple Developer ID** (99 USD/rok): pro placenou aplikaci prakticky nutné
   (podpis + notarizace). Bez něj uživatelé vidí varování Gatekeeperu
   a po každé aktualizaci znovu povolují Přístupnost.

---

## Pořadí prací
1. Fáze 1: animace → klávesy → hromadné vložení → ikona → copyright → logování
2. Rozhodnutí k otevřeným otázkám
3. Fáze 2: klient licencí + server
4. Fáze 3: telemetrie + dashboard
