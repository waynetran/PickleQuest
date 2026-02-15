# PickleQuest Milestones

## Roadmap

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Foundation + Match Engine | **Complete** |
| 2 | Inventory, Equipment, Store, Leveling | **Complete** |
| 2.5 | SUPR Rating System | **Complete** |
| 2.6 | Match History, Rep, Durability, Energy | **Complete** |
| 3 | Map + Location + NPC World | **Complete** |
| 3.1 | Economy, Rep & Loot UX Fixes | **Complete** |
| 4 | SpriteKit Match Visualization | **Complete** |
| 5 | Doubles, Team Synergy, Tournaments | Planned |
| 6 | Training, Coaching, Energy + Economy | Planned |
| 7 | Persistence, Polish, Multiplayer Prep | Planned |

---

## Milestone 1: Foundation + Match Engine

**Commit**: `1f53499`

### What was built
- **App scaffold**: SwiftUI app with MVVM + Services architecture, XcodeGen project, Swift 6 strict concurrency
- **10-stat system**: power, accuracy, spin, speed, defense, reflexes, positioning, clutch, stamina, consistency (1-99 scale)
- **Match engine** (actor): point-by-point simulation with serve phase (ace check), rally phase (shot-by-shot winner/error/forced error), clutch modifier
- **Fatigue system**: energy drain per rally shot, 3 thresholds (70/50/30%) with escalating stat penalties, stamina reduces drain
- **Momentum system**: consecutive point streaks (+2% to +7%), opponent streaks (-1% to -5%), resets between games
- **StatCalculator**: base stats + equipment bonuses with diminishing returns (linear <60, 0.7x 60-80, 0.4x 80+, hard cap 99)
- **6 starter NPCs**: across beginner/intermediate/advanced/expert tiers with personalities and dialogue
- **Protocol-based services**: PlayerService, MatchService, NPCService with mock implementations
- **Basic UI**: Match tab with NPC picker, match simulation event log, result screen
- **Test suite**: match engine, fatigue, momentum, stat calculator tests

### Files created
- `App/` — PickleQuestApp, AppState, DependencyContainer
- `Models/` — Player, PlayerStats, PlayerProgression, Equipment, EquipmentSlot, EquipmentRarity, EquipmentAbility, MatchConfig, MatchPoint, MatchEvent, MatchResult, NPC, MapItem, Wallet, Consumable, StoreItem, GameConstants
- `Engine/MatchSimulation/` — MatchEngine, StatCalculator, FatigueModel, MomentumTracker, RallySimulator, PointResolver
- `Services/Protocols/` — PlayerService, MatchService, NPCService
- `Services/Mock/` — MockPlayerService, MockMatchService, MockNPCService
- `ViewModels/` — MatchViewModel
- `Views/` — ContentView, MatchHubView, NPCPickerView, MatchSimulationView, MatchResultView, StatBar

---

## Milestone 2: Inventory, Equipment, Store, Leveling

**Commit**: `04c6104`

### What was built
- **Inventory system**: equipment list with filtering by slot, equip/unequip, sell functionality
- **Equipment detail view**: full stat bonuses, condition bar, ability display, rarity badge
- **Store system**: 8 items per rotation, weighted rarity (common 30% → legendary 3%), refresh for 50 coins
- **Loot generation**: procedural names (prefix + base per slot/rarity), rarity-scaled stat bonuses, ability generation for epic+
- **Leveling**: XP curves (base 100, 1.3x growth), 3 stat points per level, manual stat allocation
- **Stat allocation UI**: per-stat +1 buttons with effective stats preview
- **Economy**: starting 500 coins, match win 100 + difficulty bonus, match loss 25

### Files created
- `Engine/LootGeneration/` — LootGenerator, EquipmentNameGenerator
- `Services/Protocols/` — InventoryService, StoreService
- `Services/Mock/` — MockInventoryService, MockStoreService
- `ViewModels/` — InventoryViewModel, StoreViewModel, PlayerProfileViewModel
- `Views/Inventory/` — InventoryView, EquipmentCardView, EquipmentDetailView, EquipmentSlotsView
- `Views/Store/` — StoreView, StoreItemCard
- `Views/Player/` — PlayerProfileView, StatAllocationView
- `Views/Components/` — RarityBadge, LootDropRow, LevelUpBanner

### Post-milestone patches
- `c3c216e` Fix inventory/profile/store not refreshing on tab switch
- `bc6f89d` Fix empty data on first tab visit due to .task/.onAppear race
- `4e654d5` Add bugs-to-remember doc
- `e17a368` Add Close button to equipment detail sheet
- `c51773e` Add All button and filter chip to inventory slot filter
- `4224cac` Rename filter chip from slot name to 'Show All'

---

## Milestone 2.5: SUPR Rating System

**Commit**: `cf4d768`, `cca7150`

### What was built
- **SUPR rating algorithm**: margin-of-victory Elo — expected score (Elo formula scaled for DUPR 2.0-8.0), actual score via tanh curve of point margin
- **Key insight**: close loss to stronger opponent can gain rating — incentivizes competitive play
- **Reliability system**: 40% depth (matches/30) + 30% breadth (opponents/15) + 30% recency (days since last match)
- **K-factor tiers**: 64 (new, reliability <0.3) → 32 (developing) → 16 (established, reliability >0.7)
- **Auto-unrate**: matches with rating gap > 1.0 automatically unrated to prevent manipulation
- **Rated/unrated toggle**: on NPC picker, with auto-unrate warning
- **UI surfaces**: SUPR score + monthly delta on Profile, opponent SUPR on NPC picker, SUPR change badge on match results, Performance tab with W-L record

### Files created
- `Engine/Rating/` — DUPRCalculator
- `Models/Player/` — DUPRProfile
- `docs/supr-algorithm.md`
- `PickleQuestTests/Engine/` — DUPRCalculatorTests, DUPRProfileTests

---

## Milestone 2.6: Match History, Rep, Durability, Energy

**Commits**: `2ec7162`, `3b87020`, `009b88d`

### What was built
- **Match history**: persisted to player array, displayed in Performance tab (opponent, score, SUPR/rep changes, broken equipment)
- **Reputation system**: +10 base win / -10 base loss, SUPR gap scaling, 8 titles (Disgrace → Court Celebrity), NPC sell price multiplier
- **Equipment durability**: shoes/paddles wear 8% per loss + SUPR gap bonus, break at 0% and auto-unequip
- **Persistent energy**: 100% max, 50% floor, -10% on loss + SUPR gap bonus, +1%/minute real-time recovery
- **Equipment sets**: 5 sets (Court King, Speed Demon, Iron Wall, Mind Games, Endurance Pro) with tiered cumulative bonuses for rare+ items
- **Flavor text**: procedural humor descriptions by slot, dominant stat, and rarity
- **Starter equipment**: new players auto-equip paddle, shoes, shirt
- **Paddle gate**: must have paddle equipped to start match
- **SUPR display fix**: unrated matches show potential rating change (e.g. "(+0.15)") in gray

### Files created/modified
- `Engine/Rating/` — RepCalculator
- `Models/Player/` — RepProfile, MatchHistoryEntry
- `Models/Equipment/` — EquipmentSet
- `Views/Performance/` — PerformanceView
- `Views/Components/` — MatchHistoryRow

---

## Milestone 3: Map + Location + NPC World

**Commits**: `68325c0` (dev mode), `e8178ae` (map + courts + NPCs)

### What was built
- **Map tab**: replaced static Match tab with MapKit-powered map centered on player GPS
- **10 courts**: generated procedurally around player location at 200m-2.5km offsets, from beginner (Sunrise Rec Center) to master (Legends Court)
- **POI-based court placement**: MKLocalSearch finds real parks, recreation centers, and pickleball courts; CLGeocoder validates random fallback locations (no water, bridges, highways)
- **17 NPCs**: expanded from 6 to 17 across all 5 difficulty tiers with unique personalities and dialogue
- **Court discovery**: undiscovered courts show as "?" markers, walk within 200m to reveal, dev mode reveals all
- **Court detail sheet**: court info, difficulty badges, NPC list with SUPR scores and Challenge buttons, rated/unrated toggle
- **LocationManager**: `@MainActor` CLLocationManager wrapper with delegate pattern
- **Developer mode**: wrench icon in Profile toolbar opens sheet to override stats (sliders 1-99), SUPR rating, reputation, level, coins, energy, and GPS location; snapshot/reset to true values
- **Dev mode D-pad**: arrow buttons on map for ~50m walking simulation in N/S/E/W directions
- **Sticky mode**: toggle in D-pad center — when enabled, panning the map moves the player location to the camera center
- **Bottom status bar**: discovery progress (4/10 courts), SUPR score, energy, paddle warning
- **Match flow integration**: tap court → detail sheet → Challenge NPC → existing simulation → results → back to map

### New files
- `Models/World/Court.swift` — Court model (GPS, difficulty tiers, MapItem conformance)
- `Services/Protocols/CourtService.swift` — Court generation + NPC assignment protocol
- `Services/Mock/MockCourtService.swift` — POI-based court generation with safety validation, NPC distribution
- `Services/LocationManager.swift` — CLLocationManager with delegate callbacks
- `ViewModels/MapViewModel.swift` — Location, courts, selection, discovery, dev movement + sticky mode
- `Views/Map/MapContentView.swift` — MapKit with annotations, D-pad overlay, sticky mode, bottom bar
- `Views/Map/CourtAnnotationView.swift` — Colored difficulty markers
- `Views/Map/CourtDetailSheet.swift` — Court info + NPC challenge cards
- `Views/Player/DevModeView.swift` — Stat/rating/location override panel
- `Extensions/CLLocationCoordinate2D+Sendable.swift` — Sendable + Equatable conformance

### Modified files
- NPC.swift (Comparable), Player.swift (discoveredCourtIDs), MockNPCService (17 NPCs), DependencyContainer (CourtService, LocationManager), AppState (dev mode, location override), ContentView (tab rename), MatchHubView (map as idle state), project.yml (location permission)

### Post-milestone patches
- Smart court placement: MKLocalSearch POI queries + CLGeocoder safety validation
- Dev mode movement: D-pad (N/S/E/W ~50m steps) + sticky mode (pan to move player)

---

## Milestone 3.1: Economy, Rep & Loot UX Fixes

### What was built
- **No coins on loss**: `matchLossBaseReward` set to 0; coins are win-only (wager system planned for future milestone)
- **Rep formula overhaul**: new SUPR-gap-based formula replacing flat gain/loss
  - Upset win (beating stronger): big rep gain (+10 base + gap * 15)
  - Expected win (beating weaker): diminished gain (min +3)
  - Loss to much stronger (gap >= 0.5): small respect gain (+1 to +3)
  - Loss to slightly stronger or equal: 0 change
  - Loss to weaker: rep penalty (-5 base - gap * 10, capped at -30)
- **Loot equip/discard on results screen**: each loot item has Equip and Keep buttons; unhandled items trigger a discard confirmation dialog on Continue
- **Selective loot processing**: only kept/equipped items are added to inventory; equipped items auto-equip in their slot
- **Wager/hustler design doc**: documented planned wager and hustler NPC systems in game-design.md

### Files modified
- `GameConstants.swift` — coins + rep constants
- `RepCalculator.swift` — new formula, removed unused difficulty param
- `MockMatchService.swift` — updated rep call site
- `MatchViewModel.swift` — loot decisions state, updated rep call
- `LootDropRow.swift` — equip/keep buttons
- `MatchResultView.swift` — loot interaction, discard confirmation, hide 0 coins
- `MatchHubView.swift` — selective loot processing + equip
- `docs/game-design.md` — updated economy, rep, loot, added wager/hustler section

---

## Milestone 4: SpriteKit Match Visualization

### What was built
- **SpriteKit court scene**: behind-the-baseline broadcast camera perspective with trapezoid court, kitchen zones, net, and court lines
- **Pixel art sprites**: programmatically generated via UIGraphicsImageRenderer — 16x24 back-view player (4x scale), 12x18 front-view opponent (3x scale), 6x6 wiffle ball, all with `.nearest` filtering for crisp pixel art
- **Perspective system**: `CourtRenderer.courtPoint(nx:ny:)` maps normalized court coords to screen points with depth-based width interpolation; `perspectiveScale(ny:)` shrinks far objects
- **Full animation system**: `MatchAnimator` maps every `MatchEvent` to SKAction sequences
  - **Match start**: players slide in from off-screen, "VS" text flash
  - **Point played**: serve swing → ball arc (parabolic `sin(π*t)` trajectory) → rally bounces (up to 5) → outcome animation
  - **Outcome types**: ace (ball whizzes past + flinch), winner (ground hit + pump + dust), unforced error (net/out callout), forced error (ball wide), rally (final shot + rally length callout)
  - **Streak**: orange glow ring expansion on streaking player
  - **Fatigue**: player dim + sweat drop particle
  - **Ability**: purple flash ring + ability name callout
  - **Game end**: winner celebration jump
  - **Match end**: bigger jump + scale pulse, "VICTORY!"/"DEFEAT" overlay
- **Async bridge**: `SKNode.runAsync(_:)` using `withCheckedContinuation` for clean async/await integration with SKAction completion handlers
- **SwiftUI integration**: `MatchSpriteView` wraps `SpriteView` + `ScoreHeaderView` in ZStack overlay
- **Fallback**: `useSpriteVisualization` flag on ViewModel preserves text-based `MatchSimulationView` as fallback
- **No engine changes**: all existing tests pass (80/80)

### Architecture
```
MatchEngine (actor) → AsyncStream<MatchEvent> → MatchViewModel (@MainActor)
                                                       ↓
                                              courtScene.animate(event:) async
                                                       ↓
                                              MatchCourtScene (SKScene, @MainActor)
                                                       ↓
                                              MatchAnimator runs SKAction sequences
                                                       ↓
                                              returns when animation completes
```

### New files
- `Views/Match/SpriteKit/MatchAnimationConstants.swift` — all timing, sizing, color, z-position constants
- `Views/Match/SpriteKit/SpriteFactory.swift` — programmatic pixel art texture generation
- `Views/Match/SpriteKit/CourtRenderer.swift` — perspective court drawing with trapezoid projection
- `Views/Match/SpriteKit/MatchCourtScene.swift` — SKScene subclass, node setup, announcement helpers
- `Views/Match/SpriteKit/MatchAnimator.swift` — event-to-animation sequencer with all event types
- `Views/Match/MatchSpriteView.swift` — SwiftUI wrapper (SpriteView + score overlay)
- `Extensions/SKNode+Async.swift` — async/await bridge for SKActions

### Modified files
- `ViewModels/MatchViewModel.swift` — `courtScene` property, `useSpriteVisualization` flag, async animation in event loop
- `Views/Match/MatchHubView.swift` — routes to `MatchSpriteView` when sprite visualization enabled

---

## Milestone 5: Doubles, Team Synergy, Tournaments (Planned)

### Goals
- 2v2 doubles matches with partner NPC
- Team synergy bonuses between compatible personalities
- Tournament brackets (single elimination, round robin)
- Tournament-exclusive rewards and loot
- Leaderboard tracking

---

## Milestone 6: Training, Coaching, Energy + Economy (Planned)

### Goals
- Training mini-games at courts (serve practice, rally drills)
- NPC coaches with stat-specific training bonuses
- Expanded energy system (consumables to restore energy)
- Economy balancing (coin sinks, premium items)
- Daily challenges and quests

---

## Milestone 7: Persistence, Polish, Multiplayer Prep (Planned)

### Goals
- Local persistence (SwiftData or UserDefaults)
- Cloud save preparation (protocol-based storage layer)
- UI polish pass (animations, haptics, sound effects)
- Onboarding flow for new players
- Multiplayer architecture prep (real-time match protocol)
