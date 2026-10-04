# Dvojité ⌘V — rychlý výběr z historie

Specifikace funkce, která otevře historii schránky dvojitým stiskem `⌘V`.
Stav: **návrh, zatím neimplementováno.**

## Chování

1. Uživatel stiskne `⌘V` — vloží se aktuální obsah schránky jako obvykle.
2. Pokud do **350 ms** (nastavitelné 250–500 ms) přijde druhý stisk `V` se
   stále drženým nebo znovu stisknutým `⌘`:
   - druhý stisk se **pohltí** (nevloží se podruhé),
   - první vložení se **vrátí** (viz Smazání prvního vložení),
   - u textového kurzoru se **vyroluje panel historie** (viz Animace).
3. Výběrem položky (klik / `↵`) se vloží do původní aplikace, `Esc` panel zavře
   a nic nevkládá (první vložení zůstává vrácené).

`⇧⌘V` zůstává jako samostatná zkratka — otevře panel bez vracení čehokoli.

## Detekce kláves

- `CGEventTap` na `keyDown` (session tap, `.listenOnly` pro první stisk,
  pro druhý stisk vrátit `nil` = pohltit). Carbon `RegisterEventHotKey`
  na samotné `⌘V` nepoužívat — pohltil by každé vložení.
- Vyžaduje oprávnění **Monitorování vstupu** + **Přístupnost**.
  Bez nich funkce tiše vypnutá, `⇧⌘V` funguje dál; v Nastavení stav oprávnění
  a tlačítko „Povolit“.
- Ignorovat syntetické `⌘V` posílané samotným ClipManagerem
  (`PasteService.simulateCmdV`) — označit eventy přes `eventSourceUserData`.
- Auto-repeat (`kCGKeyboardEventAutorepeat`) nepočítat jako druhý stisk.
- Přepínač v Nastavení: „Dvojité ⌘V otevře historii“ (výchozí zapnuto).

## Smazání prvního vložení

- Výchozí: poslat `⌘Z` do frontmost aplikace.
- Fallback pro aplikace, kde `⌘Z` nefunguje spolehlivě (Terminal, iTerm,
  některé webové inputy): pro čistý text poslat `Backspace` × počet znaků
  vloženého textu. Seznam aplikací (bundle ID) s fallbackem v kódu, později
  případně v Nastavení.
- Pro obrázky/soubory jen `⌘Z`.

## Animace — „vymazlená, native-like“

Cíl: ať to působí jako součást macOS (Spotlight, kontextové menu, Stage
Manager), ne jako webová animace. Plynulé 120 Hz na ProMotion displejích.

### Otevření (roll-out)
- **Kotva:** panel vyrůstá z pozice textového kurzoru (caret). Pozice přes
  Accessibility: `kAXSelectedTextRangeAttribute` →
  `kAXBoundsForRangeParameterizedAttribute`. Fallback: pozice myši.
  Když pod kurzorem není místo, panel se otočí a roluje **nahoru**.
- **Pohyb:** spring, ne easing křivka — `.spring(response: 0.38,
  dampingFraction: 0.82)` (odladit na zařízení), jemný překmit max ~2 %.
- **Tvar:** odhalování shora dolů (maska/clip výšky od ~0 na plnou výšku),
  současně `scale` 0.96 → 1.0 s `anchor` u kurzoru a `opacity` 0 → 1
  (opacity rychleji, ~0.12 s).
- **Položky:** stagger — každý řádek nabíhá s posunem ~6 pt a fade, zpoždění
  ~18 ms mezi řádky, jen prvních ~8 viditelných řádků (zbytek bez animace).
- **Materiál a stín:** sklo (`.regularMaterial` / Liquid Glass na macOS 26)
  od začátku, stín se dofadeuje spolu s panelem, žádné probliknutí
  neprůhledného pozadí.
- **Výběr:** první položka je hned zvýrazněná, highlight se přesouvá
  s `matchedGeometryEffect` (klouže, neskáče).

### Zavření
- Rychlejší než otevření: ~0.15 s, zarolování zpět ke kotvě + fade,
  `easeIn`. Po výběru položky panel zmizí dřív, než proběhne vložení.

### Přístupnost a výkon
- Respektovat **Omezit pohyb** (`accessibilityReduceMotion`): jen crossfade
  ~0.15 s, bez škálování a staggeru.
- Okno vytvořené předem a skryté (žádná alokace při otevření), náhledy
  obrázků cachované, aby první snímek animace nebyl trhaný.
- Ladit na reálném Macu — hodnoty výše jsou výchozí bod, ne finál.

## Otevřené otázky
- Má `Esc` vrátit první vložení zpět (redo), nebo ho nechat smazané?
- Délka okna pro dvojklik — 350 ms jako výchozí, ověřit v praxi.
