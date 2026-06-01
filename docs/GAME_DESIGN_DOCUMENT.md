# GODS OF FATE — Game Design Document

> **Arbeitstitel:** **Gods of Fate** (Alternativen: *Pantheon RNG*, *Divine Factory*, *Mythos: Rebirth*)
> **Genre:** RNG-Collector × Factory-Tycoon × Rebirth-Progression
> **Plattform:** Roblox (PC + Mobile + Tablet, ab ~6 J. lesbar)
> **Sprachen:** Code/Asset-Namen Englisch · Spielsprache umschaltbar EN/DE
> **Engine-Stack:** Luau, Rojo-Projekt, ProfileService (Datenpersistenz), Knit/eigene Service-Architektur, RemoteEvents/RemoteFunctions mit serverseitiger Validation.

---

## 0. Pitch (1 Satz)

> *„Ziehe Götter aus immer mächtigeren Packs, baue sie in deinem Tempel zu einer Produktions-Maschine zusammen, fusioniere, rebirthe und werde zur lebenden Legende deines Servers — mit gehypten Pulls, Server-Broadcasts und einer Progression, die nie aufhört.“*

**Hook-Worte fürs Thumbnail:** “SECRET GOD!”, “1 in 10 MILLION”, “RAINBOW PULL!”, “REBIRTH ∞”.

---

## 1. Designziele & Erfolgs-Heuristiken

| Ziel | Messung |
|---|---|
| Sofort verständlich | Neuer Spieler macht ersten Pull < 30 s ohne Tutorial-Text |
| Befriedigende Progression | Erste Rebirth-fähigkeit < 30 min, Loop unendlich skalierbar |
| Viral Clip-tauglich | Mind. 1 „Screen geht aus, Server schreit“-Moment pro Stunde Playtime |
| Retention | D1 ≥ 35 %, D7 ≥ 12 %, Sessions ≥ 18 min |
| Mobile-First UX | Alle Kern-Actions mit Daumen erreichbar, Buttons ≥ 56 dp |
| Fair Monetization | Spielbar ohne Robux bis Pack 7. Robux verkauft Komfort, nicht Power |

---

## 2. Core Loop

```
EARN GOLD → BUY PACK → OPEN PACK → PULL GOD → PLACE IN TEMPLE
   ↑                                                       ↓
   └── REBIRTH ← TEMPLE UPGRADES ← FAITH ← PRODUCTION ─────┘
                       ↓
                   FUSION / TRADING / AUCTION / QUESTS
```

**Minute 0–2:** Spawn → Tutorial-Pull (gratis) → erster Gott auf Slot 1.
**Minute 2–10:** Tempel produziert Gold automatisch → 3–5 weitere Pulls → erstes Pack 2 freigeschaltet.
**Minute 10–30:** Erste Fusion-Möglichkeit, erstes Faith-Upgrade, erste Quest erfüllt.
**Minute 30–60:** Erstes Rebirth, erstes Divinity-Upgrade, Pack 3 unlock.
**Stunde 1+:** Tieferer Loop: Offerings, Auctions, Trading, Season-Ranking, Secret-Jagd.

---

## 3. Currencies & Resource Design

| Währung | Symbol | Quelle | Sink | Soft-Cap |
|---|---|---|---|---|
| **Gold** | 🟡 | Tempel-Produktion, Quests | Packs, Slot-Käufe | Skaliert mit Rebirth |
| **Faith** | ✨ | Götter „beten“ (langsamer Drop pro Tick) | Temple-Upgrades, Production-Multiplier | Per Pack-Tier |
| **Offerings** | 🕯️ | Sehr langsam aus Mythic+ Göttern, Boss-Events | Permanente, *randomisierte* %-Buffs | Selten gehalten |
| **Gems** | 💎 | Quests, Daily/Weekly, Achievements, Robux | Potions, Cosmetics, Re-Roll-Tickets | Free-Earn ≈ 60–120/Tag |
| **Divinity** | 🌟 | Rebirth-Reward | Permanente Upgrades im Divinity-Tree | Unendlich |

**Wichtig:** Gold/Faith/Offerings sind Skalierungs-Achsen. Gems sind die einzige Premium-/Quest-Währung. Divinity ist meta. Nur diese 5 → leicht verständlich.

### Formeln (Default-Balance)

- **Production pro Gott:** `base * rarityMult * fusionMult * (1 + temple.lvl * 0.05) * (1 + divinityProductionPct)`
- **Faith Tick:** Alle 5 s, `sum(gods.faithRate)`.
- **Offerings Tick:** Nur Mythic+, 1 Roll alle 60 s mit `0.5% + 0.1% pro Rarity-Stufe über Mythic`.
- **Pack-Preis:** `basePrice[tier] * 1.18^ownedPackTier` (klassische Roblox-Inflationskurve).
- **Rebirth-Reward:** `floor( (lifetimeGold / threshold)^0.62 )` Divinity. Threshold steigt pro Rebirth × 4.5.

---

## 4. Packs & Rarities

### 4.1 Rarity-Tabelle

10 Packs × 5 Rarities. Schlechteste Rarity ist **mindestens 60× häufiger** als die beste. Globale **Secret Gods** mit ~ 1 in 500 000 bis 1 in 50 000 000, pack-unabhängig.

| Pack | Unlock | Preis (Gold) | Rarities (best→worst sichtbar) |
|---|---|---|---|
| 1 *Mortal Pack* | Start | 100 | Common, Uncommon, Rare, Epic, Unique |
| 2 *Champion Pack* | 50 k Gold | 2.5 k | Elite, Heroic, Rising Star, Legendary, Mythic |
| 3 *Pantheon Pack* | 1 M Gold | 75 k | Immortal, Demi-God, Valkyrie, God, Goddess |
| 4 *Celestial Pack* | 25 M Gold + Rebirth 1 | 1.5 M | Ascended, Ancient, High-Tier, Cosmic, Celestial |
| 5 *Astral Pack* | 1 B Gold + Rebirth 3 | 60 M | Astral, Nebula, Galaxy, Universe, Archon |
| 6 *Temporal Pack* | 50 B + Rebirth 6 | 2.5 B | Chrono, Temporal, Dimensional, Spatial, Divine |
| 7 *Radiant Pack* | 1 T + Rebirth 10 | 100 B | Luminary, Seraphim, Sacred, Exalted, Radiant |
| 8 *Eternal Pack* | 25 T + Rebirth 15 | 4 T | Timeless, Infinite, Boundless, Absolute, Eternal |
| 9 *Abyss Pack* | 500 T + Rebirth 22 | 150 T | Abyssal, Void, Eldritch, Chaos, Primordial |
| 10 *Beyond Pack* | 10 Q + Rebirth 30 | 5 Q | Singularity, Transcendental, Omnipotent, Zenith, Beyond |
| ★ *Ascendant Pack* | **Robux only (1 999 R$)** | — | Eigene 5 Robux-only-Rarities mit garantiertem Pity nach 50 Pulls |

### 4.2 Default-Odds pro Pack (5 sichtbare Rarities)

```
Worst:   58.0%
2nd:     27.0%
3rd:     11.0%
4th:      3.6%
Best:     0.4%   (= 1 in 250)
```

Pack 10 wird auf der besten Rarity auf **1 in 1 500** gestreckt, Secret Gods sitzen *zusätzlich* über jedem Pack:

```
Secret-Pool 1  (Pack 1–3) :  1 in   500 000
Secret-Pool 2  (Pack 4–6) :  1 in 2 500 000
Secret-Pool 3  (Pack 7–10):  1 in 50 000 000   ← Server-Broadcast + Cinematic
```

Beim Rollen: **Wahrscheinlichkeit erscheint live unter dem aktuell durchscrollenden Gott** (z. B. „1 in 50“ → „1 in 500 000“). Spannungsaufbau garantiert.

### 4.3 Pack-UI-Rules

- Roll-Animation scrollt ~ 12–18 Götter durch, Geschwindigkeit verlangsamt zum Ende.
- Sehr seltene Pulls: Screen dimmt, Vignette, Bass-Drop, Slow-Motion auf letzten 3 Vorschau-Göttern.
- Secret Pulls: **ServerBroadcast** an alle Spieler, Goldener Rahmen, eigener Sound, Kamerazoom auf Tempel.
- Bei 5x / 10x / Max: Optional „Skip / Open Fast“ (Gamepass) → nur Endergebnisse anzeigen.

### 4.4 Pity (kein Best-Pity)

- Pity gilt **nur für 4th-best Rarity** (= „Epic-Pity“-Mechanik). Nach `220 - tier*15` Pulls ohne 4th+ → garantierter 4th-best Roll.
- Best-Rarity und Secrets haben **kein Pity** → Mythos-Wert bleibt erhalten.

---

## 5. Temple / Factory

- 3D-Tempel pro Spieler (Plot/Lobby-System wie *Pet Sim* / *Anime Adventures Lobby*).
- Slots: Start = 3, max via Temple-Upgrade & Divinity = **48**.
- Jeder Slot zeigt:
  - Rarity-Frame (Farbcode)
  - Production/sec (live)
  - Rarity-Wahrscheinlichkeit (so wie im Pack gerollt, z. B. „1 in 500“) **in Rarity-Farbe**
- Götter sind initial R6-/R15-Roblox-Puppen mit Rarity-Aura, Glow & idle Animation. **God-Skins** unlockbar via Quests, Events, Robux-Bundles, Achievements.
- Temple wächst optisch in **Tiers**: Steinhaus → Marmor → Gold → Cosmic → Eternal → Beyond. Jeder Tier ändert Skybox-Tinting & Partikel.
- **Auto-Collect**-Gamepass: Gold/Faith/Offerings fliegen automatisch ins Wallet (sonst 10 m Range).

---

## 6. Fusion System

| Anzahl gleicher Götter | Erfolgschance | Effekt |
|---|---|---|
| 2 | 8 % | +1 Fusion Rank |
| 3 | 22 % | +1 |
| 4 | 55 % | +1 |
| 5 | **100 %** | +1 |

- Verbraucht **alle** eingesetzten Götter. Fehlschlag (< 5) → alle weg.
- Fusion-Rank skaliert **Production × (1 + rank * 0.35)** und ist *getrennt* von Rarity.
- UI: großer Wahrscheinlichkeitsring, „RISK“-Stempel < 100 %, „GUARANTEED“ ab 5.
- VFX: Säule aus Licht, Beam-Merge, FlashShake → cliptauglich.
- **Fusion Rank-Cap:** 25 (Roblox-Limit gegen Number-Inflation).

---

## 7. Rebirth & Divinity

- Verlust beim Rebirth: Gold, Faith, Offerings, Inventory, Temple-Levels, Pack-Unlocks.
- Bleibt erhalten: **Divinity, Divinity-Upgrades, Cosmetics, Collection-Book, Fusion-Rank**, sowie ein **„Eternal Gift“** = 1 zufälliger gezogener Gott pro Rebirth-Decade (10, 20, 30 …). Das ist der „2. Faktor, der nicht zurückgesetzt wird“.
- Rebirth-Bar oben in HUD, leuchtet ab ≥ 1 Divinity.
- **Milestone-Bonus:** Bei Rebirth `2,5,10,25,50,100,250,500,1000,…` → permanentes Temple-Upgrade „Echo of Faith“ (+10 % global production). Limit schiebt sich nach.
- Keine Obergrenze. Skaliert via Soft-Caps: ab Rebirth 1000 wird die Reward-Kurve geglättet (`^0.4` statt `^0.62`).

### Divinity-Tree (permanent)

| Branch | Knoten (Auszug) | Max |
|---|---|---|
| **Fortune** | Luck +1 %/lvl, Better Pity, Secret-Chance +0.005 %/lvl | 100 |
| **Wealth** | Gold +2 %, Auto-Sell-Junk, Offline Gold 1 h | 100 |
| **Devotion** | Faith +2 %, Temple Slots +1/10 lvl, Roll-Speed | 100 |
| **Ascension** | Divinity Gain +1 %, Rebirth Multi-Tap, Production +1 % | 100 |
| **Mythos** | Collection-Book Bonus, Fusion-Risk -2 %/lvl bis -40 % | 50 |

---

## 8. Trading & Auction

### 8.1 Trading
- Trading-Button öffnet Lobby-Liste (alle Spieler im Server).
- Klick auf Spieler → „Send Trade Request“. Empfänger kann in Settings Trade-Invites global aus-/anschalten.
- Trade-UI: zwei Seiten, Drag-from-Inventory, Live-Mirror.
- **Confirm-Hold:** beide müssen den „Accept“-Button **5 Sekunden gleichzeitig halten**. Bewegung/Bruch → Reset.
- Server validiert beide Inventories *nach* Hold, *vor* Commit. Atomic swap via ProfileService transaction.
- Anti-Scam: Items zeigen Rarity, Fusion-Rank, Production. Letzte 2 s zeigen „FINAL PREVIEW“ groß.

### 8.2 Auction House
- Lobby-Gebäude „Auction Hall“.
- Spieler listet Gott mit Mindestpreis (Gold) + Buyout (optional).
- Laufzeit 30 min / 2 h / 12 h. Max 5 aktive Listings.
- 5 % Gold-Tax (Sink gegen Inflation).
- Sniping-Schutz: Bid in letzten 60 s → +60 s Verlängerung.
- Globale Filter: Rarity, Pack, Fusion-Rank, Preis.

---

## 9. Quests, Dailies, Minute-Rewards

| System | Cadence | Rewards |
|---|---|---|
| **Minute Reward** | alle 60 s online | Gold-Schub, 1× pro 10 min: kleines Gem-Trickle |
| **Daily Quests** | 3 pro Tag, reroll 1×/Tag | Gems, Potion, gelegentlich Pack |
| **Weekly Quests** | 7 pro Woche | Pack 3+, Gems-Pool, Divinity-Boost-Potion |
| **Daily Login** | 30-Tage-Kalender | D7 = Auto-Roll-Trial 1 h, D14 = Pack 4 Token, D30 = Mythic-Gott |
| **Lucky Daily Roll** | 1×/Tag gratis aus Pack 1 | Pity-frei, kann Secret droppen |
| **Achievements** | Permanent | Cosmetics, Title, Divinity |

Quest-Beispiele:
- „Pull 25 Rare or better“
- „Place 5 different Gods in Temple“
- „Earn 1 M Faith“
- „Win 1 Auction“
- „Fuse 3 times“

---

## 10. Leaderboards & Seasons

Server- & globale Leaderboards (OrderedDataStore + MemoryStore-Cache, hourly snapshot):
- Gold (lifetime)
- Divinity
- Rebirths
- Rarest God Pulled (Rarity-Index)
- Highest Fusion Rank
- Total Production / sec

### Season-Struktur
- **Dauer:** 6 Wochen.
- **Soft-Reset:** Saison-Ranking startet leer; Inventories bleiben.
- **Top 100 Belohnungen** (Beispiel Pyramide):
  - Top 1: exklusiver Seasonal God + Crown-Cosmetic + 1 Robux-Gamepass Coupon
  - Top 2–3: Seasonal God + Aura
  - Top 4–10: Seasonal God
  - Top 11–25: 5× Pack 7
  - Top 26–50: 3× Pack 6
  - Top 51–100: 1× Pack 6 + Gems
- Unter 100: nichts, aber sichtbarer Progress-Bar mit „2.4k bis Top 100“ Anzeige für Motivation.

---

## 11. Monetarisierung

### Gamepasses (Komfort, kein Power-Spike)
| Gamepass | Robux (Empfehlung) |
|---|---|
| Auto Roll Permanent | 999 |
| Open Fast / Skip Animation | 499 |
| 2× Gold | 599 |
| 2× Faith | 599 |
| 2× Offerings | 1 299 |
| 2× Luck | 1 499 |
| +6 Temple Slots | 799 |
| Auto Collect | 399 |
| VIP Area (Lounge + Gem-Trickle) | 799 |
| Multi-Open ×25 / ×50 | 699 / 1 299 |
| Trade Highlight (Auction Boost) | 299 |

### Developer Products
- Gem-Bundles 80 / 400 / 1 000 / 2 500 / 7 000
- Gold-Boost 1 h / 24 h
- Pack-Bundles („Starter Pantheon Bundle“)
- Potion-Bundles
- Rebirth-Skip-Tokens (nur sehr früh, < Rebirth 5, gegen Frust)

### Robux-Only Pack
- Das **Ascendant Pack** ist *das* einzige Robux-Pack. Eigene 5 Rarities, garantierter Pity nach 50 Pulls. **Wichtig:** Die Götter darin sind cosmetisch stärker, nicht balance-brechend.

### Anti-P2W-Regeln
- Kein Robux-Cap auf Best-Rarities (nur Pity).
- Trading & Auction *nur* mit Gold (kein Robux-Marketplace) → kein RMT-Vektor.
- Leaderboard misst nicht Robux-Output (Gold-spent verbotener Metric).

---

## 12. Server-Events, Hype & Viralität

- **Secret Server Broadcast:** Vollbild-Banner, Sound, „PlayerName pulled XYZ!“ → 10 s, Klick öffnet ihren Tempel.
- **Lucky Hour** (alle 4 h für 15 min): globaler +25 % Luck, sichtbarer Timer.
- **Storm Event:** zufällig 1×/2 h, Server-Rain aus Goldmünzen die Spieler einsammeln.
- **Pack Frenzy:** Pack kostet 50 % für 10 min.
- **Seasonal Events:** Halloween, X-Mas, Lunar New Year → Limited Gods.
- **Friends Boost:** +5 % Production pro Freund online, max +25 %.
- **Gift System:** Premium-Spieler senden 1 Gratis-Gem-Päckchen/Tag an einen Freund.
- **Referral Codes:** Beide Spieler bekommen Pack 2 + 50 Gems.
- **Collection Book / Dex:** zeigt alle Götter (auch ungerollte als Silhouette). Volle Reihe = Aura-Cosmetic.

---

## 13. UI / UX

### Globale Bottom-Nav (mobile-first, Daumen-Zone)
```
[ Shop | Inventory | Temple | Fusion | Quests | More ▾ ]
                                              └─ Trading, Auctions, Leaderboards, Settings, Codes, Collection
```

### Frames
1. **Shop**: vertikale Liste der 10 Packs + Ascendant. Karten zeigen Cover-Art, Top-Rarity-Preview, Buy 1 / 5 / 10 / Max.
2. **Inventory**: Grid 4×∞ mobile / 6×∞ desktop. Filter: Pack, Rarity, Fusion-Rank, Sort. Long-press = mass-select.
3. **Roll Screen**: Center-Stage, scroll-band horizontal, rarity-Wahrscheinlichkeit live darunter in Rarity-Farbe + Glow. „Skip“-Button (Gamepass), „Continue“ nach Reveal.
4. **Temple**: 3D-Plot, Slot-Hover zeigt Production. Side-Sheet „Place God“, „Upgrade Slot“, „Remove“.
5. **Fusion Stand**: 5 leere Sockel, drop-zone. Rechts Wahrscheinlichkeitsring + Fusion-Rank-Anzeige. „FUSE!“ Button mit Hold-Confirm.
6. **Rebirth Screen**: lila Gradient, „You will lose: …“, „You will gain: X Divinity“, Confirm hold 2 s.
7. **Quests**: Tabs Daily / Weekly / Achievements. Progress-Bars, Claim-Buttons.
8. **Settings**: Audio, VFX-Quality (Low/High für Mobile-FPS), Trade Invites On/Off, Language EN/DE, Reduced Motion (Accessibility).
9. **Trading**: Player-Liste, Trade-Window, Hold-Bar visualisiert.
10. **Auctions**: Liste mit Filter, „My Listings“ Tab, Bid-Modal.
11. **Leaderboards**: Tabs für 6 Kategorien, eigene Position pinned.
12. **Season Rewards**: Pyramide-View, eigener Rank gross.
13. **Potions**: aktive Buffs als HUD-Icons + Timer.
14. **Language Switcher**: Globe-Icon in Settings, Live-Reload via Locale-Service.

### Farb-Codes Rarities (Auswahl)
- Common ⚪ #B8B8B8 · Uncommon 🟢 #2DD36F · Rare 🔵 #2D87E0 · Epic 🟣 #A23DE0 · Unique 🟠 #FFAA00
- Mythic 🔴 #E0353D · Goddess 💖 #FF66CC · Celestial 💛 Gradient Gold-White
- Beyond/Singularity: animierter Rainbow-Shift mit Schwarz-Outline
- Secret: animierte Holo-Iridescence + Partikel

---

## 14. Lokalisation

- Singleton-Service `LocalizationService` (Client) lädt Tabellen aus `ReplicatedStorage.Shared.Locale.en` / `.de`.
- Keys statt Hardstrings: `T("shop.buyButton")`.
- UI-Komponenten subscriben auf Locale-Changed-Event und re-rendern.
- Settings-Switch schreibt `playerData.settings.language` → DataStore.
- Roblox `LocalizationService` Integration vorbereitet (zukünftig Auto-Translate).
- Default = `en`. DE als komplett gepflegte zweite Sprache.

---

## 15. Technische Architektur

### Ordnerstruktur (Rojo)
```
src/
├─ client/
│   ├─ controllers/      (UI-Controllers, Input, VFX)
│   ├─ ui/               (Roact-/Fusion-Komponenten oder klassische UI-Manager)
│   ├─ effects/          (Roll-Animation, Camera-Shakes, Broadcasts)
│   └─ init.client.luau  (Bootstrap)
├─ server/
│   ├─ services/         (PackService, EconomyService, RebirthService, …)
│   ├─ data/             (ProfileService Schemas, Migrations)
│   ├─ security/         (Validation, AntiExploit, RateLimits)
│   ├─ world/            (Plot Allocation, Temple Spawning)
│   └─ init.server.luau
└─ shared/
    ├─ config/           (Packs, Rarities, Prices, DivinityTree, …)
    ├─ remotes/          (Remote-Definitions, typed)
    ├─ locale/           (en.luau, de.luau)
    ├─ math/             (BigNumber, ProductionFormulas)
    ├─ types/            (Type definitions)
    └─ utils/            (Logger, Signal, Net)
```

### Services (Server)
- `PlayerDataService` (ProfileService Wrapper, save/load, migrations)
- `EconomyService` (Gold/Faith/Offerings/Gems, transactions)
- `PackService` (Odds, Rolling, Pity, Secret-Check)
- `InventoryService` (gods, filters, locks for trade)
- `TempleService` (slot placement, production tick)
- `FusionService`
- `RebirthService` + `DivinityService`
- `QuestService` (daily/weekly/minute/login)
- `TradeService` (request flow, hold-confirm, atomic swap)
- `AuctionService` (listings, bids, time extension)
- `LeaderboardService` (OrderedDataStore + cache)
- `SeasonService` (timeline, reward distribution job)
- `BroadcastService` (server + cross-server via MessagingService)
- `RateLimitService`
- `AnalyticsService` (Roblox PlayerEvents + custom)

### Controllers (Client)
- `UIController`, `RollController`, `TempleCameraController`, `InputController`, `LocaleController`, `NotificationController`, `BroadcastController`, `TradeUIController`.

### Remote-Definitions (typed, Whitelist-only)
```
Remotes/
├─ Functions/  BuyPack, OpenPack, PlaceGod, RemoveGod, Fuse, RebirthConfirm,
│              ClaimQuest, BuyUpgrade, ListAuction, BidAuction, CancelListing,
│              SendTradeRequest, RespondTrade, OfferItem, RemoveOffer,
│              HoldAccept, ChangeSetting, SwitchLanguage
└─ Events/     OnPullResult, OnInventoryUpdate, OnEconomyUpdate, OnBroadcast,
               OnTempleUpdate, OnQuestUpdate, OnLeaderboardUpdate, OnLocaleUpdate
```

Alle Remotes:
- Rate-limited (Token-Bucket pro Player + pro Remote).
- Server-side validation (Args type-check, ownership check, currency check).
- Logging bei Anomalien.

### Datenmodell (ProfileService Profile)

```luau
PlayerProfile = {
  version = 4,
  currencies = { gold = 0, faith = 0, offerings = 0, gems = 0, divinity = 0 },
  lifetime  = { gold = 0, pulls = 0, rebirths = 0, rarestRarity = 0 },
  inventory = {
    gods = {                       -- array of god instances
      { uid="…", id="Zeus", rarity=14, fusionRank=2, packTier=3, secret=false, locked=false }
    },
    potions = { … },
    cosmetics = { … },
  },
  unlocks = {
    packs = { [1]=true, [2]=true, [3]=false, ... },
    gamepasses = { autoRoll=false, openFast=false, … },
  },
  temple = {
    tier = 1,
    slots = { { godUid=… }, { godUid=… }, … },     -- size = currentSlotCount
    upgrades = { production=0, slots=0, faith=0 },
  },
  divinity = {
    spent = 0,
    tree = { fortune={luck=0,pity=0,secret=0}, wealth=…, devotion=…, ascension=…, mythos=… },
  },
  quests = {
    daily   = { … },
    weekly  = { … },
    minute  = { lastClaim=0 },
    login   = { streak=0, lastDay=0 },
  },
  settings = { language="en", tradeInvites=true, vfxQuality="high", reducedMotion=false, music=true, sfx=true },
  social   = { friendsBoost=true, referrer=nil, codesRedeemed={…} },
  season   = { id="S1", score=0, claimed=false },
  collection = { discovered={ Zeus=true, … } },
  flags    = { tutorialDone=false, firstSecret=false },
  meta     = { createdAt=…, lastLogin=…, playtime=0 },
}
```

### Persistenz
- Profile auto-save alle 60 s + bei BindToClose.
- Migrations bei Version-Bump (jeweils `migrations/v3_to_v4.luau`).
- Trading nutzt **Reserved Lock**: beide Profile werden während Confirm-Hold locked, Items in `inventory.locked=true` markiert, atomic swap, dann unlock.
- Leaderboards via OrderedDataStore (1 Key pro Kategorie/Saison), Cache durch MemoryStore.

### Anti-Exploit
- Client schickt **nie** Werte, immer Intents (`BuyPack(packId, count)` statt `BuyPack(packId, count, price)`).
- Server berechnet Preise.
- Pulls werden vollständig server-seitig per `Random.new()` mit kryptographisch sicherem Seed pro Player gewürfelt; Client bekommt nur das Endergebnis + animationsfähige Vorschau-Liste (auch server-generiert).
- Trade-Hold serverseitig getimed mit Heartbeats.
- DataStore-Writes nur über Service-Layer, nirgendwo direkt.

---

## 16. Balance-Vorgaben (Startwerte, tuneable)

| Param | Wert |
|---|---|
| Start-Gold | 100 |
| Pack 1 Preis | 100 Gold |
| Pack 1 Best Odds | 1 in 250 (0.4 %) |
| Erstes Rebirth-Threshold | 5 M lifetime Gold |
| Divinity bei Rebirth 1 | 8 |
| Slot-Start | 3 (max via Upgrade + Divinity = 48) |
| Roll-Animation | 3.5 s normal, 6.5 s rare, 12 s secret-cinematic |
| Auto-Roll-Speed | 2 s pro Pack |
| Open Fast | 0.4 s pro Pack |
| Multi-Open Max | 50 |
| Fusion 100 % Cap | 5 Götter |
| Auction Tax | 5 % |
| Lucky Hour | alle 4 h, 15 min, +25 % Luck |
| Pity 4th-best | 220 Pulls (Pack-Tier-abhängig) |

---

## 17. Roadmap & Priorisierung

### MUST-HAVE (MVP / Soft-Launch)
1. ProfileService + PlayerDataService
2. EconomyService (Gold, Faith, Gems – Offerings später)
3. PackService + 3 Packs spielbar
4. Roll-Screen mit Wahrscheinlichkeits-Anzeige + Basic-Animation
5. Inventory + Temple mit 3 Slots, Production-Tick
6. Daily Quest (1 Quest reicht für Launch)
7. Locale-Framework EN/DE
8. Settings + Language Switch
9. Robux Auto-Roll + Open Fast Gamepass
10. Basic Broadcasts (für seltene Pulls)
11. Anti-Exploit Basis + Rate Limits

### SHOULD-HAVE (Launch Window)
- Rebirth + Divinity (2 Branches: Fortune, Wealth)
- Fusion-System
- Packs 4–6
- Trading mit Hold-Confirm
- Leaderboard (Gold, Divinity, Rarest)
- Daily Login
- Auto-Collect Gamepass
- Collection Book
- Lucky Daily Roll

### NICE-TO-HAVE (Update 1, Woche 2–6)
- Auction House
- Packs 7–8
- Seasons + Top-100 Rewards
- Weekly Quests
- Potions & Buff-System
- Ascendant Pack (Robux Pack)
- Server Events (Lucky Hour, Storm)
- Friends Boost, Referral Codes
- Achievement System

### LONG-TERM (Updates 2+)
- Packs 9–10
- Cross-Server Megabroadcasts (MessagingService)
- Mythos-Branch im Divinity-Tree
- Cosmetic God-Skins als eigene Pipeline
- Seasonal Limited Gods (Halloween, X-Mas …)
- Mobile-only Side-Events
- Clan/Guild-System
- Daily Tournaments
- In-Game Cosmetic-Editor (Aura-Mix)

---

## 18. Empfehlung: Build-Reihenfolge (konkret)

1. **Woche 1:** Core-Framework — Rojo, Service-Locator, ProfileService-Wrapper, Remote-Layer, Locale-Stub.
2. **Woche 2:** Economy + Pack 1 + Roll-UI mit Odds-Anzeige.
3. **Woche 3:** Inventory + Temple-Slots + Production-Loop.
4. **Woche 4:** Pack 2/3, Quest- und Login-System, Settings + Sprache.
5. **Woche 5:** Rebirth + Divinity-Tree (Fortune & Wealth).
6. **Woche 6:** Fusion + Broadcasts + Gamepasses (Auto-Roll, Open Fast).
7. **Woche 7:** Trading + Hold-Confirm + Anti-Exploit-Pass.
8. **Woche 8:** Leaderboard + Soft-Launch.
9. **Woche 9+:** Auction, Seasons, Events, Cosmetic-Pipeline.

---

## 19. Klare „NICHTs“ (No-Gos)

- Kein Best-Rarity-Pity.
- Kein Robux-Auction-Markt.
- Kein chaotisches Multi-Currency-System (max 5).
- Kein „leaderboard-pay-to-win“.
- Kein blockierendes Tutorial (Skip jederzeit möglich, Tooltips contextual).
- Keine erzwungenen Ads / Group-Pflicht *ohne* sinnvolle Belohnung (Auto-Roll-Group-Unlock ist okay, weil zusätzlich, nicht blockierend).
- Keine Sound-Loops, die nervtötend werden — Roll-Sounds rotieren in 6 Varianten.

---

## 20. Name-Vorschläge

| Slot | Vorschläge |
|---|---|
| Spielname | **Gods of Fate** · *Pantheon RNG* · *Divine Factory* · *Mythos: Rebirth* |
| Premium Pack | *Ascendant Pack* · *Throne Pack* |
| Premium-Währung | *Gems* (klassisch) · *Aether Shards* (thematisch) |
| Permanente Meta-Währung | *Divinity* · *Halo Sparks* |
| Spieler-Titel | Mortal → Acolyte → Priest → Oracle → Demi-God → Pantheon → Ascendant → Transcendent → Beyond |

---

## 21. Erfolg = Disziplin

Vor jedem neuen Feature die Frage:
> *„Macht das den Pull-Moment besser, die Progression klarer oder den Clip viraler?“*
Falls nicht → später.
