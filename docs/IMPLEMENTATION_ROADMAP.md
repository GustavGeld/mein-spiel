# Implementation Roadmap — Gods of Fate

Konkrete Build-Reihenfolge mit Code-Modulen, Akzeptanzkriterien und Test-Ideen.
Ergänzt das [GDD](./GAME_DESIGN_DOCUMENT.md).

---

## Stage 0 — Foundation (Day 1–3)

| Task | Datei | Akzeptanz |
|---|---|---|
| Rojo-Struktur erweitern | `default.project.json` | Mappings für `Shared.Remotes`, `Shared.Config`, `Shared.Locale` |
| Service-Locator | `shared/utils/ServiceLocator.luau` | Registriert und löst Services nach Name |
| Logger | `shared/utils/Logger.luau` | `Logger.scope("PackService").info(...)` |
| Signal | `shared/utils/Signal.luau` | Eigenes Signal oder GoodSignal-Port |
| Remote-Layer (typed) | `shared/remotes/Net.luau` + `Definitions.luau` | `Net:Function("BuyPack")` returnt RemoteFunction, lazy-create on server |
| Locale-Stub | `shared/locale/en.luau`, `de.luau`, `Locale.luau` | `Locale.t(key, lang)` |

**Test:** Server bootstrap loggt „all services online“ in < 1 s.

---

## Stage 1 — Player Data (Day 4–6)

- `server/data/Profile.luau` (Default-Schema, Version 1).
- `server/services/PlayerDataService.luau` (ProfileService Wrapper, `Profiles[player]`, `OnLoaded`-Signal, `Save`, `Release`).
- Save-Throttle 60 s + BindToClose.
- Replication: `OnEconomyUpdate`, `OnInventoryUpdate`, `OnTempleUpdate` — Patches statt Full-State.

**Test:** Spieler joint → erhält Default-Profil → Rejoin behält Werte.

---

## Stage 2 — Economy + Pack 1 (Day 7–11)

- `shared/config/Rarities.luau` (alle 50 Rarities + Farbe + Display-Name-Keys).
- `shared/config/Packs.luau` (10 Packs + Ascendant + Odds-Tabellen).
- `shared/config/Secrets.luau` (Secret-Pool-Definition).
- `shared/math/Odds.luau` (Roll-Funktion, Pity, Secret-Check).
- `server/services/EconomyService.luau` (`Add`, `Sub`, `Can`, `Transact`).
- `server/services/PackService.luau` (`Buy`, `OpenOne`, `OpenMany`).
- Client `RollController` mit Scroll-Band + Live-Probability.

**Test:** 10 000 Pulls von Pack 1 ergeben Odds-Verteilung im ±0.3 %-Bereich.

---

## Stage 3 — Inventory + Temple (Day 12–16)

- `server/services/InventoryService.luau` (UID-Generator, Filters, Lock-Flag).
- `server/world/PlotService.luau` (Plot-Vergabe pro Spieler, CFrame-Origin).
- `server/services/TempleService.luau` (Placement-Validation, Production-Tick alle 5 s, Faith-Tick).
- Client `TempleController` (Slot-UI, Place-Sheet).
- Production-Formel siehe GDD §3.

**Test:** Gott platziert → Gold steigt sichtbar pro Tick. Entfernen funktioniert. Mehr Slots = mehr Production.

---

## Stage 4 — Quests + Locale (Day 17–20)

- `server/services/QuestService.luau` (Daily-Roll bei Login, Progress-Hooks).
- `shared/config/Quests.luau` (Pool + Targets).
- `client/ui/QuestPanel`.
- `client/controllers/LocaleController.luau` (`SetLanguage`, signal, persistent).
- Settings-UI mit Language-Switcher.

**Test:** Sprache wechseln → alle aktiven UIs rerendern sofort.

---

## Stage 5 — Rebirth + Divinity (Day 21–25)

- `server/services/RebirthService.luau` (Threshold-Check, Reward, Reset selektiver Felder).
- `server/services/DivinityService.luau` (Tree-Validation, Buy-Upgrade).
- `shared/config/DivinityTree.luau` (Branches, Knoten, Kosten).
- `client/ui/RebirthScreen`, `client/ui/DivinityTreeUI`.

**Test:** Rebirth → Profile-Diff zeigt nur erwartete Felder zurückgesetzt; Divinity + Cosmetics + Collection-Book bleiben.

---

## Stage 6 — Fusion + Broadcasts (Day 26–29)

- `server/services/FusionService.luau` (Same-God-Check, RNG, Verlust-Logic).
- `shared/math/Fusion.luau` (Wahrscheinlichkeits-Tabelle).
- `client/effects/FusionVFX.luau`.
- `server/services/BroadcastService.luau` (server + cross-server via MessagingService).
- Trigger: Pull eines „best Rarity“ oder Secret → Broadcast.

**Test:** Secret-Pull triggert sichtbaren Server-Broadcast bei allen Spielern innerhalb 1 s.

---

## Stage 7 — Gamepasses (Day 30–32)

- `server/services/GamepassService.luau` (MarketplaceService-Listener, Cache).
- Apply-Hooks: `EconomyService.GetMultiplier(player, "gold")` etc.
- Auto-Roll-Trigger (Server-Loop wenn Gamepass UND Spieler im Roll-Screen).
- Open-Fast = Skip-Flag im RollService.

**Test:** Gamepass kaufen → sofort aktiv ohne Rejoin.

---

## Stage 8 — Trading (Day 33–38)

- `server/services/TradeService.luau` (State-Machine: Invite → Negotiate → HoldConfirm → Commit).
- Hold-Confirm: beide Spieler senden `HoldHeartbeat`, Server prüft, dass beide 5 s konstant gesendet haben. Bei Abbruch reset.
- Atomic Swap: beide Profile lockt (mit Timeout), Items wandern UID-stabil, dann unlock.
- Anti-Scam: 1.5 s nach jeder Inventar-Änderung resettet der Accept-Timer beider Seiten.

**Test:** 100 simulierte Trades hintereinander, kein Duplications-Bug. Disconnect mitten im Trade → Items bleiben beim Original-Besitzer.

---

## Stage 9 — Leaderboards + Soft Launch (Day 39–42)

- `server/services/LeaderboardService.luau` (OrderedDataStore + MemoryStore-Cache, hourly snapshot).
- `client/ui/LeaderboardUI`.
- Soft-Launch in Roblox VIP/Closed-Test, dann offiziell.

---

## Stage 10 — Post-Launch Sprint (Update 1)

- Auctions
- Seasons + Top-100 Reward-Job
- Weekly Quests
- Potions + Buff-Engine
- Ascendant Pack
- Server Events (Lucky Hour, Storm)
- Friends Boost + Referral Codes
- Achievements

---

## Querschnittsthemen

- **Telemetrie:** `AnalyticsService` loggt Pull-Verteilung, Currency-Sinks, Quest-Completion, Trade-Volume, Rebirth-Tempo. Wöchentlicher Balance-Review.
- **A/B-Hooks:** Feature-Flags via `Shared.Config.Flags.luau` für graduelle Roll-Outs.
- **Performance-Budget:** Mobile Low-End 30 FPS @ 6 Gods auf Plot, 60 FPS auf Mid. VFX-Quality-Toggle senkt Partikel um 70 %.
- **Accessibility:** Reduced-Motion (Roll-Animation kürzer), Color-Blind-Modus für Rarity-Farben (Symbole zusätzlich).

---

## Definition of Done pro Stage

- [ ] Server-Service mit Validation, Logging, Rate-Limit.
- [ ] Client-UI mit Locale-Keys (kein Hardstring).
- [ ] Mindestens 1 Edge-Case-Test (insbesondere Trading/Fusion).
- [ ] Analytics-Event vorhanden.
- [ ] Funktioniert in Roblox Studio Play-Solo + zwei-Client-Server.
- [ ] Profile-Migration falls Schema-Change.
