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
| 9     | Leaderboards + Seasons                 | NEXT       |
| 10    | Auctions, Potions, Achievements, Codes | PENDING    |

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

## Stage 9 plan (next)

Leaderboards + Seasons:
1. `src/server/services/LeaderboardService.luau`       NEW — OrderedDataStore writer (gold, rebirths, divinity, rarest, fusionRank, totalProduction)
2. `src/server/services/SeasonService.luau`            NEW — season config, weekly cycle, top-100 reward distribution at season end
3. `src/shared/config/Seasons.luau`                    NEW — season ids, durations, reward tables
4. `src/client/controllers/LeaderboardController.luau` NEW — paginated fetch via remote
5. `src/client/ui/panels/LeaderboardPanel.luau`        NEW — categories tab, top 100 list
6. `src/client/ui/panels/SeasonPanel.luau`             NEW — current season progress + claim
7. Hook PlayerDataService.OnSaved to write leaderboard entries
8. New remotes: `RequestLeaderboard(category, page)`, `ClaimSeasonReward`

## Next session checklist
- [ ] Read this file first.
- [ ] Start Stage 8 Trading — files listed above.
- [ ] Confirm user uploaded any pending Robux gamepass IDs (if testing monetisation).
- [ ] After Stage 8: Stage 9 Leaderboards + Seasons.
