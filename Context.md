# Gods of Fate — Implementation Context

**Project root:** `C:\Users\wende\Desktop\mein-spiel\mein-spiel\`
**Sync:** Rojo to Roblox Studio (place: "Unbenanntes Erlebnis" / "Gods of Fate")
**Language:** Codebase in EN, in-game DE/EN switchable via Settings (`Locale.setLanguage`)
**Master spec:** `MainPrompt.txt` (do not modify)
**This file:** Always overwrite with up-to-date implementation status so the next session can resume instantly.

---

## How I work in this session
- Rojo syncs all `.luau` files automatically — write to disk, user reloads Studio.
- MCP Roblox Studio is available but expensive in tokens → I avoid `start_stop_play` / heavy screen capture. The user manually launches and tests.
- I only verify by static reads (Glob/Grep/Read) and by compile checks when needed.
- Whenever an asset ID is required (PNG, audio, gamepass), I leave a `rbxassetid://0` or `id = 0` placeholder and instruct the user to upload + paste the ID.

---

## Stage roadmap (per MainPrompt + GDD)

| Stage | Topic                                  | Status     |
|-------|----------------------------------------|------------|
| 1     | Player data persistence + remotes      | DONE       |
| 2     | Economy + PackService + Odds           | DONE       |
| 3     | Inventory + Temple + production tick   | DONE       |
| 4     | Quests + Daily login + Minute reward   | DONE       |
| 5     | Rebirth + Divinity tree                | DONE       |
| 6     | Fusion + server-wide Broadcasts        | DONE       |
| 7     | Gamepasses + Dev Products + Skip Fast  | DONE       |
| 8     | Trading (state machine + hold accept)  | DONE       |
| 9     | Leaderboards + Seasons                 | DONE       |
| 10    | Auctions, Potions, Achievements, Codes | DONE       |
| 11    | Offerings, LuckyHour, Tutorial         | DONE       |
| 12    | Free Roll, Offerings Prod, Pickup FX   | DONE       |
| 13    | Storm, Frenzy, Friends Boost, AFK Cap  | DONE       |
| 14    | Pity+, Referral, Collection Rewards    | DONE       |
| 15    | VIP Area, Referral cap + copy button   | DONE       |
| 16    | AnalyticsService, VIP Bounce fix       | DONE       |
| 17    | Companion "Aion" — orbit, menu, skins  | DONE       |
| 18    | Aura system, Collection Book rewards   | DONE       |
| 19    | Limited Events (3 events + event packs)| DONE       |
| 20    | Eternal Gift, Echo of Faith, Abilities, Quest Reroll | DONE |
| 21    | Temple Upgrades, Tier Progression, Event Gods | DONE |
| 22    | 30-day calendar, Localized god names, Aura display | DONE |
| 23    | Full god roster for all 10 packs (150 gods total)  | DONE |

---

## Stage 7 (DONE) — files changed

1. `src/shared/config/Gamepasses.luau`           NEW — 10 gamepasses + 6 dev products (all robloxId=0 placeholders)
2. `src/server/services/GamepassService.luau`    NEW — MarketplaceService listeners, ownership cache (30 s TTL), ProcessReceipt for DevProducts (idempotent via processedReceipts map), `grantFlag` with per-flag side effects (extraSlots adds 3 slots)
3. `src/server/services/EconomyService.luau`     `getLuckMultiplier(player)` added (used by PackService); x2Gold/Faith/Offerings already wired
4. `src/server/services/PackService.luau`        Uses `EconomyService.getLuckMultiplier`; multiOpen gamepass raises batch cap 10 -> 50
5. `src/server/services/RebirthService.luau`     After reset, restores +3 extraSlots if gamepass owned
6. `src/server/services/PlayerDataService.luau`  RequestProfile snapshot includes `unlocks.gamepasses`
7. `src/server/init.server.luau`                 Loads GamepassService after CommandService
8. `src/shared/remotes/Definitions.luau`         + `PromptGamepass`, `PromptDevProduct`, `OnGamepassUpdate`
9. `src/client/ui/Icons.luau`                    + `gamepasses` slot (placeholder)
10. `src/client/ui/NavBar.luau`                  + Gamepasses tile (slot 11)
11. `src/client/ui/panels/GamepassPanel.luau`    NEW — categorised list (Boosts/Convenience/Utility) + Dev Products
12. `src/client/controllers/UIController.luau`   Wired GamepassPanel, OnGamepassUpdate listener, RollController.setSkipFast on grant + initial snapshot
13. `src/client/controllers/RollController.luau` `setSkipFast(v)` API; when active uses SKIP_STEP_MS=35 and SKIP_HOLD=0.4
14. `src/shared/locale/en.luau` + `de.luau`      Full `nav.gamepasses`, `gamepass.*`, `product.*` keys

---

## Key conventions / decisions

### Server services pattern
- **Server-authoritative**: all economy/inventory/rebirth/quest math is on server. Client never sees DataStore values directly, only patch events.
- **Lazy require**: when service A needs service B but they would circularly depend, use `script.Parent:FindFirstChild("BService")` then `require()` at call time (see PackService -> QuestService / BroadcastService).
- **RateLimit**: every remote endpoint runs through `RateLimit.consume(player, key, max, windowSec)`.

### Replication
- All snapshot events live on `Net:Event("OnXxxUpdate")`.
- Currently active: `OnEconomyUpdate`, `OnInventoryUpdate`, `OnTempleUpdate`, `OnRebirthUpdate`, `OnQuestUpdate`, `OnBroadcast`, `OnLocaleUpdate`, `OnPullResult`.
- To be added in Stage 7: `OnGamepassUpdate` (fires with `{ [passId:string]: boolean }`).

### Economy multipliers
`EconomyService.getMultiplier(player, currency)` already merges:
- Divinity tree branch level (per currency) * 0.02
- `unlocks.gamepasses.x2Gold/x2Faith/x2Offerings` -> x2

To extend in Stage 7: add `x2Luck` (for Odds), `autoCollect`, `multiOpenRoll`.

### Profile shape (Profile schema v1)
See `src/server/data/DefaultProfile.luau`. Key fields:
- `currencies: { gold, faith, offerings, gems, divinity }`
- `lifetime: { gold, pulls, rebirths, rarestRarity }`
- `inventory.gods: { uid, id, rarityId, packTier, fusionRank, secret, locked }`
- `unlocks: { packs, gamepasses }` — string keys, boolean values
- `temple: { tier, slots, upgrades }`
- `divinity: { spent, tree: { fortune, wealth, devotion, ascension, mythos } }`
- `quests: { daily, weekly, dayStamp, minute, login }`

### NavBar slots (10 currently)
shop, inventory, index, quests, daily, rewards, trade, fusion, rebirth, settings.
Stage 7 will append `gamepasses` (slot 11).

### Locale
- `Locale.t(key)` lookup with EN fallback.
- `Locale.LanguageChanged` Signal fires when player switches.
- UIController calls `rebuildIfPanelOpen()` on language change.

---

## Stage status detail

### Stage 1-3 — economy / packs / temple
Stable. Pack cinematic via `RollController`, multi-roll grid reveal, AutoRoll per-pack toggle.

### Stage 4 — quests
- Daily quests pool: pulls_5, pulls_25, rarity_rare, rarity_epic, gold_spent_5k, place_3, secret_1 (see `Quests.luau`).
- `QuestService.ensureDailies(player)` uses UTC `dayStamp` + RNG seeded by `userId+day` so the same dailies appear all day.
- Login streak: 7-cell calendar, `ClaimLogin` remote, day rollover at UTC midnight.
- Minute reward: `ClaimMinute`, 60 s cooldown, hands out gems (per `Quests.minuteReward`).
- Hooks: `onPull`, `onGoldSpent`, `onGodPlaced` (called via lazy require from PackService/TempleService).

### Stage 5 — rebirth + divinity
- Threshold: `1_000_000 * (1 + n*0.5)^2`.
- Divinity reward: `1 + rebirths + clamp(overshoot * 4, 0, 4)`.
- `RebirthService.RebirthConfirm` resets economy/inventory/temple, keeps divinity + collection + cosmetics + lifetime stats (rebirths++).
- `DivinityTree`: 5 branches x 1 node each (fortune.luck, wealth.gold, devotion.faith, ascension.production, mythos.secret), `DivinityService.BuyUpgrade` validates divinity balance + increments level.

### Stage 6 — fusion + broadcasts
- `Fusion.successChance(count)`: 2->0.10, 3->0.35, 4->0.65, >=5->1.0.
- On success: survivor god `fusionRank += 1`, others removed; failure removes ALL inputs.
- Broadcasts: `BroadcastService.fire(payload)` -> `OnBroadcast` event to all players; client `BroadcastController` shows 5 s coloured banner top-center.
- Triggered for: secret pulls, best-rarity pack pull, fusion success at rank >= 3.

---

## Known issues / quirks
- **DataStore in Studio**: wrapped in pcall; falls back to in-memory store. Crash from API access denied is suppressed.
- **`start_stop_play` MCP**: occasionally hangs in Studio. Avoid; ask user to test manually.
- **Strict-mode UI types**: don't attach custom fields to Frame/TextLabel instances (`row._refresh = ...` errors). Store refresh callbacks in a separate `{...}` table.
- **Asset IDs**: God PNGs uploaded for first 5 (Hermes_Apprentice, Vesta_Spark, Pan_Whistler, Hermes_Messenger, Vesta_Flame). NavBar icons uploaded for all except `fusion` (still placeholder).
- **Gamepass IDs**: ALL 10 gamepasses + 6 dev products have real IDs (see `Gamepasses.luau`).
- **Place-creator owns own gamepasses**: When testing as the place creator, Roblox auto-grants all gamepasses. PromptGamepass now pre-checks `UserOwnsGamePassAsync` and silently grants instead of showing the "already owned" dialog.
- **NavBar layout**: 2 rows x 6 columns grid bottom-left (11 of 12 cells used, one trailing empty). Hover uses color tween only — UIGridLayout overrides individual size tweens.
- **Fixed DailyPanel:212 spam**: the stale `conn:Disconnect()` upvalue race in `makeMinute` is removed. The task.spawn refresh loop alone handles the cooldown UI.
- **AutoRoll gating**: `AutoRollController.setEnabled(bool)` is mirrored from `gamepasses.autoRoll`. ShopPanel autoBtn shows 🔒 until pass owned. Clicking when locked triggers `PromptGamepass("autoRoll")`.
- **DEV toggles**: Studio-only `DebugTogglePass` remote + UI button per pass. Also `/pass <flag>` chat command for quick on/off. `/inv clear`, `/inv delete <rarity>`, `/inv count` for inventory testing.
- **NavBar columns**: 2 columns × 6 rows (was 6 × 2). Item order remains the same (`Layout.SortOrder = LayoutOrder`).
- **Close button**: Panel.luau uses `rbxassetid://84399223297180` via ImageButton; falls back to text "✕" if asset is `0`.
- **Inventory equipped row**: Top horizontal scroller shows one card per temple slot (with $/s preview, slot # badge); click to unequip. **Equipped gods are no longer duplicated in the main grid** — they live only in the equipped row.
- **Panel sizes**: `Panel.create` accepts an optional sizeOverride. UIController gives Inventory 1100×700, Fusion/Gamepass 960×640, others default 820×560. UISizeConstraint clamps to screen.
- **GodCard scaling**: `cardSize: Vector2?` field — proportional layout. PNG well grows with card. Default still 160×220 for backwards compat (RollController grid uses default size).
- **NavBar**: now vertically centered (`AnchorPoint = (0, 0.5)`, `Position = (0, 18, 0.5, 0)`), 2 columns × 6 rows on the left edge.
- **GamepassPanel cards**: 120 px tall, clean right-column with `UIListLayout` stacking Price → Buy → DEV button (or Owned ✓ → DEV: Disable). No overlap.
- **extraSlots revoke**: when DEV-toggled off (or `/pass extraSlots` flips off), `revokeFlagSideEffect` trims temple.slots back to 3. Gods that were equipped in 4-6 implicitly drop back to inventory (their UIDs persist).
- **Scroll memory**: `rebuildIfPanelOpen` snapshots/restores ScrollingFrame `CanvasPosition` by tree-order index, so OnGamepassUpdate / OnQuestUpdate no longer scrolls panels back to top.
- **x50 batch**: ShopPanel adds a x50 button when `multiOpen` pass is owned; otherwise a x50 🔒 lock button that triggers PromptGamepass("multiOpen").
- **Stage 8 Trading**: `TradeService` with state machine (open → holding both → completed/cancelled). Hold-watcher coroutine polls `os.clock()` every 0.1 s; both sides must hold ≥5 s simultaneously. Atomic swap removes from owner A, adds to B (single PlayerDataService.update tx). Cancellation/leave releases all locks.
- **Trade UI**: `TradePanel` either shows a player-lobby list or an active session (two columns + hold bar). Invite popup top-center. Toast for end/decline events. When a session starts, the Trade tab is auto-opened; when it ends, panel rebuilds back to lobby.

---

## Testing recipe (give user copy-paste for each stage)
1. Reload Rojo in Studio (top-right Rojo plugin -> Disconnect -> Connect).
2. Press Play.
3. Open chat:
   - `/money set 5000000` -> bankrolls testing.
   - `/money add -1000` -> quick negatives test.
4. NavBar buttons should show panel toggle behaviour.
5. Buy 10x any pack -> ONE cinematic, then grid reveal with OK.
6. Place 3 gods in temple -> idle -> gold ticks up.
7. Fusion: get 2+ same gods -> open Fusion -> fuse with 5 for guaranteed rank-up.
8. Rebirth at 1 M gold -> confirm hold-button (3 s).

---

## Stage 7 — what the user has to do manually
1. Create Gamepasses on the place via Creator Dashboard. Paste the IDs into
   `src/shared/config/Gamepasses.luau` next to each `gp(...)` call as `robloxId`.
2. Create Dev Products (Game -> Monetization -> Developer Products). Paste IDs into
   the corresponding `dp(...)` rows in the same file.
3. Until IDs are filled, the Buy buttons show "Coming Soon" (`gamepass.unavailable`)
   and PromptGamepass returns `{ ok=false, reason="not_configured" }`.
4. The skipFast gamepass also needs no further code — buying it auto-mirrors to
   `RollController.setSkipFast(true)` via OnGamepassUpdate.

## Stage 9 (DONE) — Leaderboards + Seasons

1. `src/shared/config/Seasons.luau`                    NEW — Saison-ID (wochenbasiert), Score-Formel (pulls + rebirths×500), Reward-Tiers, formatTime
2. `src/server/services/LeaderboardService.luau`       NEW — OrderedDataStore pro Kategorie (pulls/rebirths/gold/rarity/season); schreibt bei OnSaved/OnLoaded; RequestLeaderboard(cat,page) remote (20/Seite, max 100); Studio-Mock
3. `src/server/services/SeasonService.luau`            NEW — Setzt season.id/claimed bei Saison-Reset; aktualisiert season.score bei jedem Save; ClaimSeasonReward prüft ODS-Rang, vergibt Gems; feuert OnSeasonUpdate
4. `src/client/controllers/LeaderboardController.luau` NEW — fetchPage(cat,page), claimSeasonReward(), setzt seasonData, leitet OnSeasonUpdate weiter
5. `src/client/ui/panels/LeaderboardPanel.luau`        NEW — 5 Kategorie-Tabs, paginierte Rangliste (20/Seite), lokaler Spieler goldfarbig hervorgehoben
6. `src/client/ui/panels/SeasonPanel.luau`             NEW — Header (ID + Zeit), eigener Rang (async), Reward-Tier-Tabelle, Claim-Button
7. Definitions.luau: + RequestLeaderboard, ClaimSeasonReward (Functions); + OnSeasonUpdate (Event)
8. init.server.luau: + LeaderboardService, SeasonService nach TradeService
9. UIController: + LeaderboardPanel/SeasonPanel require + wiring; + LeaderboardController.start(); Season-Snapshot nach RequestProfile
10. NavBar: + leaderboard + season Tiles (13 Items, 7 Reihen)
11. Icons: + leaderboard 🏆, season 🌀
12. en.luau + de.luau: nav.leaderboard/season + alle leaderboard.*/season.* Keys
13. PlayerDataService: RequestProfile lifetime-Snapshot um .pulls erweitert

## World interaction & temple display (2026-06-03)

- `src/client/controllers/WorldInteractionController.luau` NEW — binds every
  `ProximityPrompt` in Workspace to the matching panel. Mapping: `fusionaltar` →
  `fusion`, `rebirthportal` → `rebirth`. Uses `UIController.openPanel(id)`.
- `src/client/controllers/UIController.luau` exposes `openPanel(id)` + `snapshot`
  for external controllers.
- `src/client/controllers/TempleDisplayController.luau` NEW — paints the locally
  equipped god of slots 1-3 onto the three `Workspace.Modelle.Tempel.Rahmen`
  models. Slot order is decided by ascending `Z` of the Rahmen pivot. Instead of
  putting SurfaceGuis on the mesh `Bildflache` directly (which renders unreliably
  on custom meshes), the controller spawns its OWN flat canvas Parts welded to
  the bildflache: 2 picture-canvases (front + back, rotate with the frame) and
  2 stats-canvases below the frame (anchored, Heartbeat-driven sine float).
  Picture background = rarity colour with radial glow; stats below show name +
  rarity + Gold/s · Faith/s with a glowing `UIStroke` tinted by rarity. Image
  from `Gods.byId[id].iconAssetId`. Listens to `OnTempleUpdate`,
  `OnInventoryUpdate`, `Locale.LanguageChanged` and pulls `RequestProfile` once
  on start. Rebuild is idempotent via `__TempleDisplayBuilt` attribute.
- `init.client.luau` starts both new controllers.

Slots 4-6 are intentionally left unhandled until the Tempel model gets three
additional Rahmen.

## Stage 10 (DONE) — Auctions, Potions, Achievements, Codes, Weekly Quests

1. DefaultProfile: + `achievements.claimed`, + `quests.weekStamp`
2. `src/shared/config/Potions.luau` — 6 Tränke (luck/gold/faith/prod/offerings/autoRoll), Gems-Kosten, 10 min
3. `src/shared/config/Achievements.luau` — 17 Meilensteine (pulls/rebirths/gold/collection/fusion/secrets)
4. `src/server/data/Codes.luau` — 6 Einlösecodes (server-only)
5. `src/server/services/PotionService.luau` — BuyPotion, in-memory Timer, getMultiplier, 30s Heartbeat
6. `src/server/services/AchievementService.luau` — ClaimAchievement, Progress live aus Profil, OnAchievementUpdate
7. `src/server/services/CodeService.luau` — RedeemCode (case-insensitive, idempotent via codesRedeemed)
8. `src/server/services/AuctionService.luau` — ListAuction/BidAuction(Direktkauf)/CancelListing, 5% Steuer, 24h, GlobalDataStore
9. QuestService: ensureWeeklies, bumpProgress für daily+weekly, onRebirth hook, ClaimQuest für beide Tabellen
10. Quests.luau: weeklyPool (6 Quests), utcWeek(), pickWeeklies()
11. RebirthService: onRebirth quest hook via lazy require
12. EconomyService: getMultiplier nutzt jetzt PotionService (lazy require)
13. Definitions.luau: + 7 neue Functions + 3 neue Events
14. init.server.luau: + 4 neue Services, + 3 neue Remote-Stubs
15. `src/client/ui/panels/RewardsPanel.luau` — 3 Tabs: Codes | Potions (Timer-UI) | Achievements (Progress+Claim)
16. `src/client/ui/panels/AuctionPanel.luau` — Browse/MyListings Tabs, Kaufen+Stornieren, OnAuctionUpdate live
17. QuestsPanel: Daily|Weekly Tab-Switcher (buildQuestList helper)
18. UIController: + RewardsPanel/AuctionPanel require+wiring, StubPanel für rewards entfernt
19. NavBar: + auctions Tile (15 Items, 8 Reihen)
20. Icons: + auctions 🔨
21. en.luau + de.luau: alle rewards.*/potion.*/ach.*/auction.*/quest.weekly* Keys

## Stage 11 (DONE) — Polish: Offerings, LuckyHour, Tutorial, Prod-Potion

1. `src/server/services/OfferingService.luau` NEW — SpendOfferings remote (3 Tiers: 25/50/100 Offerings), zufälliger Buff (luck/gold/faith/prod, 30 min), getBonus() API, in-memory
2. `src/server/services/LuckyHourService.luau` NEW — zufälliger Lucky Hour Event (30–90 min Intervall, 15 min Dauer, +25% Luck), Broadcast + OnLuckyHour Event
3. `src/client/controllers/TutorialController.luau` NEW — 3-Schritt-Overlay für neue Spieler (flags.tutorialDone == false): Shop → Inventory → Temple; CompleteTutorial remote; Skip-Button
4. TempleService: Prod-Potion + Offering prod-Buff in tick()-Formel integriert
5. EconomyService.getLuckMultiplier: + Potion + Offering + LuckyHour (alle lazy require)
6. EconomyService.getMultiplier: + Offering Buff für gold/faith/offerings
7. RewardsPanel: 4. Tab "Shrine" (Offerings-Spending UI) hinzugefügt; Tab-Buttons AutomaticSize
8. UIController: Lucky Hour Banner (grüner Frame oben, 15 min auto-destroy), TutorialController.start nach RequestProfile
9. Definitions.luau: + SpendOfferings, CompleteTutorial (Functions); + OnOfferingUpdate, OnLuckyHour (Events)
10. init.server.luau: + 2 neue Remote-Stubs + Services; PlayerDataService: + CompleteTutorial Handler
11. en.luau + de.luau: offering.* + tutorial.* Keys

## Stage 12 (DONE) — Daily Free Roll, Offerings Production, Pickup FX, Streak Luck

1. **Daily Free Roll** — `ClaimFreeRoll` Remote in QuestService; Pack 1 kostenlos täglich; DailyPanel grüne Karte mit Roll-Button; snapshot.quests.freeRoll.lastDay persistiert
2. **Offerings passiv produziert** — TempleService tick addiert 2% des Gold-Wertes als Offerings in `pending.offerings`; wird mit Orbs eingesammelt + floating "🕯 +X" Text
3. **Floating Pickup-Zahlen** — TempleOrbsController spawnt BillboardGui über Character beim Einsammeln: "+1.5k 🪙" grün, "+50 ✨" orange, "+3 🕯" violett, float-up + fade-out 1.6s
4. **Lila Offerings-Orbs** — Dritter Orb-Typ (OFFERING_COLOR = 180,120,255) um Rahmen
5. **Login-Streak Luck Bonus** — EconomyService.getLuckMultiplier: +2% Luck pro Streak-Tag (max +20% bei Streak ≥10)
6. **DefaultProfile** — + `quests.freeRoll = { lastDay = 0 }`, pending-Typ um `offerings: number` erweitert
7. **PackService** — `openPacks` als public exportiert für QuestService
8. **en.luau + de.luau** — daily.freeRoll* Keys

## Stage 13 (DONE) — Storm Event, Pack Frenzy, Friends Boost, AFK Cap

1. `src/server/services/StormService.luau` NEW — Gold Storm Event alle 1–2h, 3 min Dauer, schenkt allen Online-Spielern Bonus-Gold pro 5s Tick (skaliert mit Rebirths). Broadcast + OnStormEvent.
2. `src/server/services/FrenzyService.luau` NEW — Pack Frenzy Event alle 2–4h, 10 min Dauer, 50% Rabatt auf alle Packs. Server wendet Discount in PackService.priceFor() an. Broadcast + OnFrenzyEvent.
3. `src/server/services/FriendsBoostService.luau` NEW — +5% Produktion pro Freund im Server (max +25%). Scannt alle 30s IsFriendsWith. EconomyService.getMultiplier() nutzt FriendsBoost (lazy require).
4. **Offline-Produktion (AFK Cap)** — TempleService.grantOfflineProduction: beim Login berechnet offline-verstrichene Zeit (max 8h), multipliziert mit Pro-Tick-Produktion aller platzierten Götter, addiert Gold+Faith direkt. Listener auf PlayerDataService.OnLoaded.
5. PackService: `priceFor()` wendet FrenzyService.getPriceMultiplier() an (lazy require).
6. EconomyService.getMultiplier: + FriendsBoostService.getBoost (lazy require).
7. UIController: + Storm Banner (blau, Y=58) + Frenzy Banner (orange, Y=108); Frenzy setzt ShopPanel.frenzyDiscount + rebuildIfPanelOpen für Live-Preisupdate.
8. ShopPanel: frenzyDiscount-aware Preisanzeige (🔥 + Prozent).
9. Definitions.luau: + OnStormEvent, OnFrenzyEvent Events.
10. init.server.luau: + StormService, FrenzyService, FriendsBoostService.
11. en.luau + de.luau: event.storm/frenzy/friendsBoost Keys.

## Stage 14 (DONE) — Improved Pity, Referral Codes, Collection Book Rewards

1. **Rare Pity** — `Odds.luau`: neuer "Rare Pity" Counter (`pity["rare_"..packId]`). Nach 50 Pulls ohne Slot 3+ (3rd-best Rarity) → garantierter Slot 3+. Parallel zum bestehenden Epic Pity.
2. `src/server/services/ReferralService.luau` NEW — Referral-Code = "REF-<UserId>". GetReferralCode + RedeemReferral Remotes. 50 Gems für beide Spieler. Offline-Referrer bekommt Pending Reward via DataStore "GodsOfFate_ReferralRewards" beim nächsten Login.
3. `src/server/services/CollectionRewardService.luau` NEW — Gem-Belohnung für komplette Rarity-Reihen im Collection Book. Rewards skalieren nach Pack-Tier (10×Tier Gems). ClaimCollectionReward + GetCollectionStatus Remotes. Claimed in `profile.collection.claimedRows`.
4. DefaultProfile: + `collection.claimedRows: { [string]: boolean }`
5. RewardsPanel: 5. Tab "Referral" — zeigt eigenen Code + Eingabefeld für Freundes-Code
6. Definitions.luau: + GetReferralCode, RedeemReferral, ClaimCollectionReward, GetCollectionStatus (Functions)
7. init.server.luau: + ReferralService, CollectionRewardService
8. en.luau + de.luau: referral.* + collection.* Keys + rewards.tab.referral

---

## Next session checklist
- [ ] Read this file first.
- [ ] Verbleibende manuelle Aufgaben:
  - Mehr Götter-Assets (God PNGs) hochladen → IDs in Gods.luau eintragen
  - NavBar-Icons für neue Tabs (auctions, leaderboard, season) hochladen → Icons.luau
  - Add 3 more Rahmen to Tempel model → `TempleDisplayController.MAX_SLOTS = 6`
  - Robux Gamepass IDs bestätigen (Gamepasses.luau)
## Stage 15 (DONE) — Referral Fix + Copy Button + VIP Area

1. **Referral cap** — Code kann maximal 3× eingelöst werden (pro Referrer). Counter in DataStore "GodsOfFate_ReferralCounts". Atomisches UpdateAsync verhindert Race Condition. `GetReferralCode` gibt jetzt auch `usesLeft` zurück.
2. **Copy-Button** — Referral-Tab hat jetzt "Copy Code"-Button; ruft `setclipboard()` auf und zeigt "Kopiert! ✓" für 2s.
3. `src/server/services/VIPService.luau` NEW — VIP-Pass-Perks:
   - **Gem Trickle**: +5 Gems alle 10 Minuten für alle Online-VIP-Spieler
   - **Barrier Guard**: `Workspace.VIPArea.VIPBarrier` Part — Non-VIP-Spieler werden zurück zum Spawn teleportiert + `OnVIPEject` Event gefeuert
4. UIController: `OnVIPEject` → roter Toast unten
5. Definitions.luau: + `CheckVIPStatus` (Function), + `OnVIPEject` (Event)
6. init.server.luau: + `OnVIPEject` Stub + VIPService
7. en.luau + de.luau: `vip.*` Keys

**Manual setup required:** In Roblox Studio, create a folder/model "VIPArea" in Workspace with a Part named "VIPBarrier" covering the entrance of the VIP zone. The part blocks non-VIP players automatically.

## Stage 16 (DONE) — VIP Bounce fix + AnalyticsService

1. **VIP Bounce** — Kein Spawn-Teleport mehr. Spieler wird in der Richtung weg vom Barrier zurückgedrückt (12 Studs, horizontaler Vektor barrier→player). 1,5s Cooldown pro Spieler gegen Touched-Spam.
2. `src/server/services/AnalyticsService.luau` NEW — Anonymes Telemetrie-System:
   - Events: pack_opened, rarity_rolled, secret_pulled, rebirth, fusion_attempted/success, potion_bought, code_redeemed, referral_used, vip_eject, session_start/end
   - In-Memory Aggregation (bucketed counts), Flush alle 5 min in DataStore "GodsOfFate_Analytics_v1" (Key: "daily_YYYY-MM-DD")
   - PackService: lazy-requires Analytics, trackt pack_opened + rarity_rolled + secret_pulled
   - RebirthService: trackt rebirth mit Rebirth-Count
   - FusionService: trackt fusion_attempted + fusion_success mit Rang
   - game:BindToClose für finalen Flush

## Stage 17 (DONE) — Companion "Aion"

1. `src/shared/config/CompanionSkins.luau` NEW — 8 Skins (default/ember/shadow/crystal/aurum/verdant/void/divine). Jeder Skin hat color, glowColor, material, gemCost.
2. `src/server/services/CompanionService.luau` NEW — GetCompanionData, SetCompanionSkin (mit Gem-Kauf für bezahlte Skins + ownedSkins Map), SetCompanionAbility.
3. `src/client/controllers/CompanionController.luau` NEW:
   - Klont `ReplicatedStorage.AionTemplate` oder baut Fallback-Orb (Neon-Kugel + Ring + Nametag)
   - Heartbeat-Loop: Orbit (2.8 Studs Radius, 0.32 rad/s) + Bob-Animation (±0.22 Studs, 1.7 Hz) + LERP-Smoothing
   - ProximityPrompt (E) öffnet CompanionPanel
   - `setSkin(id)` wechselt Farbe/Material aller BaseParts
   - Respawn-sicher: CharacterAdded/Removing Hooks
4. `src/client/ui/panels/CompanionPanel.luau` NEW — 460×340 Floating Panel mit Slide-In:
   - **Skins-Tab**: UIGridLayout 110×110 Karten, Farbkreis + Name + Preis, Auswahl kauft/wechselt sofort (optimistic + server-verify)
   - **Help-Tab**: Scrollbare Karten für 8 Spielsysteme (Packs, Temple, Fusion, Rebirth, Divinity, Events, Referral, Collection)
   - **Abilities-Tab**: Platzhalter "Coming soon"
5. DefaultProfile: + `companion: { skin, ability, ownedSkins }`
6. Definitions: + GetCompanionData, SetCompanionSkin, SetCompanionAbility
7. init.server + init.client: + CompanionService/Controller
8. en.luau + de.luau: companion.* + help.* Keys

**Manual setup:** Put a Model named `AionTemplate` into ReplicatedStorage. If absent, a glowing orb is used. Name the model `Aion` in Studio for proper display.

## Stage 18 (DONE) — Collection Rewards UI + Aura System + Limited Events

### Aion / UI fixes
- ProximityPrompt removed from CompanionController (E-interact gone; only blue side button opens Aion menu)
- Hide UI: now only hides NavBar + CurrencyBar; Aion side button and 3D companion remain visible
- Hide UI toggle state persisted in `snapshot.guiHidden`; SettingsPanel reads that for correct initial state

### Collection Rewards UI (IndexPanel)
- IndexPanel now has two tabs: "📖 Book" (existing grid) + "🏆 Rewards"
- Rewards tab: loads `GetCollectionStatus` async, renders rarity rows grouped by pack tier
- Each row: color stripe, name, progress bar (filled/total), gem reward amount, Claim button
- Claim button enabled only when row is complete; shows "✓ Claimed" after successful claim

### Aura System
1. `src/shared/config/Auras.luau` NEW — 10 aura tiers (SelectionBox color, PointLight brightness/range)
2. `src/client/controllers/AuraController.luau` NEW — SelectionBox outline + pulsing PointLight on character. `setTier(n)` API. Starts in init.client.luau.
3. CollectionRewardService: on claim, updates `profile.collection.bestAuraTier`, fires `OnAuraUpdate` to client
4. init.server: connects `PlayerDataService.OnLoaded` → fires `OnAuraUpdate` with current tier on join
5. DefaultProfile: `collection.bestAuraTier = 0` added
6. Definitions: `OnAuraUpdate` Event added

### Limited-Time Events
1. `src/shared/config/LimitedEvents.luau` NEW — 3 event definitions (summer_festival, winter_solstice, divine_eclipse)
2. `src/server/services/LimitedEventService.luau` NEW — admin-controlled events (startEvent/stopEvent). Persists in DataStore. Fires `OnEventUpdate` to all clients. `BuyEventPack` remote: checks gold, deducts, opens packs from event tier.
3. UIController: listens to `OnEventUpdate`, shows event banner (slot 3, above frenzy), fetches `GetActiveEvent` on start. Stores `snapshot.activeEvent`.
4. ShopPanel: shows event pack card at top when `snapshot.activeEvent` is set (countdown timer, discounted price, buy button).
5. CommandService: `/event start <id> <minutes>` and `/event stop` and `/event list` admin commands
6. Definitions: `GetActiveEvent`, `BuyEventPack` Functions; `OnEventUpdate` Event added
7. en.luau + de.luau: `aura.*`, `event.*`, `collection.tabBook/tabRewards/locked` keys added

**Admin commands:** `/event start summer_festival 60` (starts Summer Festival for 60 minutes), `/event stop`

## Stage 20 (DONE) — Eternal Gift + Echo of Faith + Aion Abilities + Quest Reroll

1. **Eternal Gift** — Every 10th rebirth saves 1 random non-placed god. Restored to `inventory.gods` after reset. Also logged in `inventory.eternalGods` as history. `RebirthConfirm` response includes `eternalGodId`.
2. **Echo of Faith** — At rebirth counts 2, 5, 10, 25, 50, 100, 250, 500, 1000 → `divinity.echoStacks += 1`. Each stack = +10% production in `TempleService.tick` + offline production.
3. **Aion Abilities** (3 purchasable with gems):
   - **Seeker** (25 💎): +5% luck in `EconomyService.getLuckMultiplier`
   - **Guardian** (50 💎): fusion failures don't consume gods (`FusionService` Guardian check)
   - **Archivist** (75 💎): offline cap 8h → 12h in `TempleService.grantOfflineProduction`
   - `CompanionAbilities.luau` config + `buildAbilitiesTab` replaced with real shop UI
   - `BuyAbility` remote + handler in `init.server.luau`
   - `companion.abilities: { [string]: boolean }` added to DefaultProfile
4. **Quest Reroll** — 1×/day: `RerollQuest` remote in QuestService. QuestsPanel daily tab shows "Reroll Quest" button (greyed-out after use). `quests.rerollDay` in profile.
5. **DefaultProfile** updates: `inventory.eternalGods`, `divinity.echoStacks`, `companion.abilities`, `quests.rerollDay`
6. **Definitions**: `BuyAbility`, `RerollQuest` added
7. **Locale**: `ability.*`, `rebirth.eternalGift/echoUnlocked`, `quest.reroll/rerollUsed`

## Stage 21 (DONE) — Temple Upgrade System + Temple Tier Progression + Event-Exclusive Gods

1. **Temple Tier Progression** — After each rebirth, `temple.tier = min(10, 1 + floor(rebirths/3))`. Tier persists across the new rebirth cycle (set after `applyReset`). Each tier = +5% production.
2. **Temple Upgrades** (faith-funded, reset on rebirth):
   - `production` (max 20 levels, +2% Gold/s & Faith/s each, costs 500×1.5^lvl faith)
   - `faith` (max 20 levels, +2% Faith/s each, costs 300×1.5^lvl faith)
   - `slots` (max 3 levels, adds 1 god slot each, costs 2000×3^lvl faith)
   - `BuyTempleUpgrade` remote in `TempleService`
   - `faithUpgradeMul(profile)` applied to faith production in tick + offline
3. **TemplePanel.luau** NEW — faith upgrade shop: header (tier, faith balance, stat summary), 3 upgrade cards (stripe, icon, level, description, Buy button). Async profile load on open.
4. **NavBar**: "temple" tile added (position 3, between Inventory and Collection)
5. **EventGods.luau** NEW — event-exclusive gods for 3 events (6 gods total). Registered into `Gods.byId` at load (never in `Gods.byRarity`). Required from `init.server.luau` + `init.client.luau`.
6. **LimitedEventService**: `BuyEventPack` has 35% chance to grant 1 event-exclusive god as bonus, added to inventory + pull results.
7. **Definitions**: `BuyTempleUpgrade` added
8. **Locale**: `nav.temple`, `temple.tier/faithBalance/upgrade.*`, `eventgod.*` keys

---

## Stage 22 (DONE) — 30-Day Login Calendar + Localized God Names + Collection Aura Display

1. **30-Day Login Calendar** (`Quests.luau` + `DailyPanel.luau`):
   - `Quests.loginRewards` expanded from 7 → 30 entries (gold/gems/faith, escalating to 1M gold / 250 gems on day 30)
   - Calendar grid layout: 5 columns × 6 rows (`UIGridLayout CellSize = UDim2.new(1/5, -5, 0, 56)`)
   - Box height: 200 → 500px, grid height: 108 → 362px
   - Cell label fonts reduced to 10/13pt to fit 56px-tall cells
   - Streak logic unchanged — uses `((streak-1) % #loginRewards) + 1` so 30-day loop works automatically

2. **Localized God Display Names** (`GodCard.luau` + locale files):
   - `GodCard.displayName` now calls `Locale.has("god." .. id)` first, falls back to `gsub(id, "_", " ")`
   - Added `god.*` locale keys for all 15 base gods, 3 secret gods, 6 event gods in `en.luau` and `de.luau`
   - Examples: Hermes_Apprentice → "Hermes, the Apprentice" / "Hermes, der Lehrling"

3. **Collection Book Aura Display** (`IndexPanel.luau`):
   - Rewards tab row height: 52 → 66px
   - Added `Auras` import
   - Each rarity row shows `✨ <AuraName>` (colored with aura color) below the rarity name
   - Aura tier = pack tier (1–10), matches `Auras[tier]`
   - Progress label repositioned to `fromOffset(12, 42)` to avoid overlap with aura label

---

## Stage 23 (DONE) — Full God Roster for All 10 Packs

1. **Gods.luau** — expanded from 15 gods (Pack 1 only) to 150 gods (15 per pack × 10 packs):
   - Pack 2 (Elite→Mythic): Greek Olympians — Zeus, Ares, Hera, Poseidon, Artemis, Demeter, Apollo, Athena, Hermes, Kronos, Gaia, Prometheus
   - Pack 3 (Immortal→Goddess): Egyptian Pantheon — Ra, Osiris, Isis, Anubis, Thoth, Bastet, Horus, Seth, Sobek, Sekhmet, Hathor, Nut
   - Pack 4 (Ascended→Celestial): Hindu Pantheon — Brahma, Vishnu, Shiva, Indra, Surya, Agni, Durga, Kali, Saraswati, Mahavishnu, Mahashiva, Parashakti
   - Pack 5 (Astral→Archon): East Asian Pantheon — Amaterasu, Susanoo, Tsukuyomi, Izanagi, Izanami, Fujin, Raijin, Benzaiten, Bishamonten, Jade Emperor, Nüwa, Erlang Shen
   - Pack 6 (Chrono→Divine): Mesopotamian Pantheon — Marduk, Ishtar, Enlil, Anu, Nanna, Utu, Enki, Ninhursag, Inanna, Tiamat, Kingu
   - Pack 7 (Luminary→Radiant): Celtic & Slavic — Lugh, Dagda, Morrigan, Cernunnos, Brigid, Danu, Perun, Veles, Rod, Svarog, Mokosh, Khors
   - Pack 8 (Timeless→Eternal): Aztec Pantheon — Huitzilopochtli, Quetzalcoatl, Tlaloc, Xipe Totec, Coatlicue, Xochiquetzal, Tezcatlipoca, Mixcoatl, Chalchiuhtlicue, Ometeotl, Tonatiuh, Tlaltecuhtli
   - Pack 9 (Abyssal→Primordial): Norse End-Times — Surtur, Níðhöggr, Jörmungandr, Fenrir, Hel, Loki, Ymir, Auðhumla, Odin, Thor, Freya, Norns, Yggdrasil, Ragnarök, Asgard
   - Pack 10 (Singularity→Beyond): Abstract cosmic entities — Axiom, Cipher, Nexus, Luminos, Aether, Prism, Excelsia, Omniveil, Allseer, Zenith, Summit, Apex, Terminus, Origin, The Absolute One

2. **Production scaling** (Gold/s per rarity tier):
   - Pack 1: 1→110 | Pack 2: 300→13000 | Pack 3: 40k→1.7M | Pack 4: 5M→200M
   - Pack 5: 600M→24B | Pack 6: 72B→2.8T | Pack 7: 8.4T→330T
   - Pack 8: 1Q→39Q | Pack 9: 120Q→4.7Qi | Pack 10: 14Qi→550Qi
   - (Each pack ≈30× stronger than previous; within-pack 5 rarities scale ~2.5× each)
   - Faith ≈ 1% of Gold for all gods

3. **Locale (en.luau + de.luau)** — full `god.*` keys for all 150 gods + 3 secrets + 6 event gods (total ~159 god name entries per language)

4. **Zero changes needed** to PackService (uses `Gods.byRarity` map, built from `Gods.list` automatically) or CollectionRewardService (uses `Gods.list` for totals)

- [ ] Optional nächste Runde:
  - Temple visual tier progression (TempleDisplayController tier-based mesh swaps)
  - Season leaderboard for new metrics (echo stacks, event gods collected)
  - More packs in the Shop (PackService unlock checks currently cap at Pack 10)
