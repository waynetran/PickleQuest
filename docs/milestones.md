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
| 4.1 | Sprite Sheet + Character Customization | **Complete** |
| 4.2 | Court Realism + Player Positioning | **Complete** |
| 4.3 | Match Actions, Consumables, Character2 | **Complete** |
| 4.4 | Court Ladder Progression System | **Complete** |
| 4.5 | Fog of War Map Exploration | **Complete** |
| 5 | Doubles, Team Synergy, Tournaments | **Complete** |
| 6 | Training, Coaching, Daily Challenges & Economy Rebalance | **Complete** |
| 7a | Onboarding, Player Management & Basic Persistence | **Complete** |
| 7b | Wager System + Hustler NPCs | **Complete** |
| 8 | Match Simulation Realism + Focus Stat | **Complete** |
| 9 | Gear Drop System (Loot on the Map) | **Complete** |
| 9.1 | Drill System Redesign + UI Polish | **Complete** |
| 10 | Interactive Match Mode | **Complete** |
| 10c | Equipment Power Budget & Trait System | **Complete** |
| 10d | Headless Interactive Match Simulator | **Complete** |
| 7c | Persistence Polish, Cloud Prep, Multiplayer Prep | Planned |

---

## Milestone 1: Foundation + Match Engine

**Commit**: `1f53499`

### What was built
- **App scaffold**: SwiftUI app with MVVM + Services architecture, XcodeGen project, Swift 6 strict concurrency
- **11-stat system**: power, accuracy, spin, speed, defense, reflexes, positioning, clutch, focus, stamina, consistency (1-99 scale)
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

## Milestone 4.1: Sprite Sheet + Character Customization

### What was built
- **Sprite sheet integration**: replaced programmatic pixel art (UIGraphicsImageRenderer) with real sprite sheets from "Aces in Pixel" asset pack (character1-Sheet.png 640x832, ball.png 32x16)
- **13 animation states**: idleBack, idleFront, walkToward, walkAway, walkLeft, walkRight, ready, servePrep, serveSwing, forehand, backhand, runDive, celebrate — sliced from 10x13 grid of 64x64px cells
- **Color replacement pipeline**: luminance-preserving pixel-level color swap — maps source palette (11 body-part colors) to target appearance, preserving artist's shading via `blendChannel(original/sourceBase * target)`
- **CharacterAppearance model**: 7-field struct (hair, skin, shirt, shorts, headband, shoes, paddle) with hex color strings, Codable/Hashable/Sendable
- **Deterministic NPC appearances**: `AppearanceGenerator` hashes NPC UUID to stable color indices — personality drives shirt palette (aggressive=reds, defensive=blues, etc.), difficulty boosts saturation
- **Equipment visual influence**: `Equipment.visualColor` optional field — equipped items override corresponding appearance slot colors (paddle→paddleColor, shirt→shirtColor, etc.)
- **SpriteSheetAnimator**: manages frame cycling on SKSpriteNode — fire-and-forget `play()` for loops, async `playAsync()` for one-shots that return on completion, static frame display for frozen poses
- **Animation integration in MatchAnimator**: walkAway/walkToward during match start slide-in, ready stance between points, servePrep→serveSwing sequence, walkLeft/walkRight during lateral movement, forehand/backhand on hits, runDive for flinches, celebrate for point/game/match wins
- **Preloaded texture cache**: color replacement runs once per appearance (~530K pixels), cached by CharacterAppearance hash — subsequent matches reuse cached textures
- **Ball sprite**: sliced from ball.png (2 frames at 16x16)
- **Fallback system**: if sprite sheet fails to load, falls back to programmatic pixel art

### Architecture
```
CharacterAppearance → ColorReplacer.buildMappings() → ColorReplacer.replaceColors()
                                                              ↓
SpriteSheetLoader.loadSheet() → recolored CGImage → sliceFrames() per row
                                                              ↓
SpriteFactory.loadTextures() → [CharacterAnimationState: [SKTexture]] (cached)
                                                              ↓
SpriteSheetAnimator(node, textures) → play(state) / playAsync(state)
```

### New files
- `Models/Player/CharacterAppearance.swift` — appearance data model
- `Models/Player/AppearanceGenerator.swift` — deterministic NPC appearance generation
- `Views/Match/SpriteKit/SpriteSheetLoader.swift` — PNG loading, frame slicing, frame count detection
- `Views/Match/SpriteKit/ColorReplacer.swift` — pixel-level color replacement with luminance preservation
- `Views/Match/SpriteKit/CharacterAnimationState.swift` — animation state enum (row, frame count, loop, timing)
- `Views/Match/SpriteKit/SpriteSheetAnimator.swift` — frame animation controller for SKSpriteNode
- `Extensions/UIColor+Hex.swift` — extracted hex init + hexString property
- `Resources/SpriteSheets/character1-Sheet.png` — base character template (640x832)
- `Resources/SpriteSheets/ball.png` — ball sprite (32x16, 2 frames)

### Modified files
- `Models/Player/Player.swift` — added `appearance: CharacterAppearance` field
- `Models/Equipment/Equipment.swift` — added `visualColor: String?` field
- `Views/Match/SpriteKit/SpriteFactory.swift` — sprite sheet pipeline (makeCharacterNode, makeBallTextures, loadTextures with cache); old programmatic methods kept as private fallbacks
- `Views/Match/SpriteKit/MatchAnimationConstants.swift` — updated Sprites section for 64x64 frames (frameSize, nearPlayerScale 1.5, farPlayerScale 1.4, ballScale 1.0)
- `Views/Match/SpriteKit/MatchCourtScene.swift` — accepts player/opponent appearances, creates SpriteSheetAnimators, exposes nearAnimator/farAnimator
- `Views/Match/SpriteKit/MatchAnimator.swift` — frame animation triggers alongside position animations for all match events
- `ViewModels/MatchViewModel.swift` — playerAppearance/opponentAppearance properties, appearance resolution in startMatch()
- `Views/Match/MatchSpriteView.swift` — passes appearances to MatchCourtScene init

---

## Milestone 4.2: Court Realism + Player Positioning

### What was built
- **Perspective foreshortening**: non-linear Y mapping (`pow(ny, 0.75)`) — far court appears compressed, near court takes ~60% of visual height, matching real behind-baseline camera angle
- **Correct court proportions**: kitchen depth ratio 7/22 (0.318) per official pickleball dimensions, centerlines only in service areas (not through kitchen)
- **Blue court with green apron**: court surface changed from green to blue with slightly darker blue kitchen zones, green grass surround, matching standard pickleball court aesthetics
- **Server behind baseline**: servers now position at ny=-0.03 (near) / ny=1.03 (far) — behind the baseline as required by rules, instead of inside the court at ny=0.08/0.92
- **Progressive kitchen approach**: during rally, players advance toward kitchen line over bounces; returner reaches kitchen by bounce 3 (faster), server by bounce 6 (slower per two-bounce rule)
- **Perspective-correct scaling**: players scale based on court depth position; inverse perspective mapping (`logicalNY`) ensures ball size scales correctly through non-linear depth
- **Scale reset**: player scales properly reset between points and between games after rally movements
- **Paddle fill fix**: post-processing fills checkerboard string pattern in racquet head with solid paddle color
- **Ball visibility**: ball scale 1.0→2.5 (40pt) for clear visibility during play
- **Pickleball rules documentation**: comprehensive rules reference covering singles/doubles scoring, two-bounce rule, kitchen rules, serve rules, positioning by phase, and strategy

### Files modified
- `MatchAnimationConstants.swift` — perspective exponent, blue/green colors, apron, server positions, kitchen approach positions, ball scale, nearPlayerScale
- `CourtRenderer.swift` — perspective Y mapping in courtPoint(), logicalNY() inverse, green apron trapezoid
- `MatchAnimator.swift` — server behind baseline, rally kitchen approach with Y movement + scale updates, ball arc inverse perspective
- `MatchCourtScene.swift` — perspective-based near player scale, resetPlayerPositions with scale reset
- `ColorReplacer.swift` — fillPaddleArea() post-processing, parseHex made internal
- `SpriteFactory.swift` — fillPaddleArea() call after color replacement

### New files
- `docs/pickleball-rules-reference.md` — comprehensive pickleball rules, scoring, positioning, and strategy reference

---

## Milestone 4.3: Match Actions, Consumables, Character2

### What was built
- **Match action buttons**: interactive overlay on right side of match screen with Timeout, Item, Hook Call, and Resign buttons; Skip button at bottom
- **Skip/Fast-forward**: sets `skipRequested` flag on engine — engine continues simulation but filters non-critical events (pointPlayed, streakAlert, fatigueWarning), ViewModel skips animations
- **Resign**: confirmation dialog, engine stops early via `resignRequested` flag, result has `wasResigned = true`, no DUPR change, frequent resign (3+ in last 10 matches) penalizes reputation
- **Timeout**: available when opponent has 2+ point streak, 1 per game; restores 15% energy via `FatigueModel.restore()`, resets opponent streak via `MomentumTracker.resetOpponentStreak()`; clock emoji + "TIMEOUT!" callout animation
- **Consumables**: `Consumable` model integrated into match flow — energy drinks, protein bars, focus gummies as starter items; max 3 per match; consumable picker sheet in UI; green sparkle animation
- **Hook a Line Call**: gamble mechanic — 30% base + 0.1%/rep chance of success (capped 80%); success = free point −5 rep, failure = opponent gets point −20 rep; 1 per game; yellow/red flash animation
- **Bidirectional engine communication**: MatchViewModel stores engine ref, calls actor methods directly (`await engine.requestSkip()` etc.); engine processes actions between points via pending event queue
- **Character2 sprite integration**: `character2-Sheet.png` copied from asset pack, `spriteSheet` field added to `CharacterAppearance`, `SpriteFactory.loadTextures()` uses dynamic sheet name, `AppearanceGenerator` randomly assigns sheets (~50/50) based on NPC UUID hash
- **Consumable inventory**: `consumables: [Consumable]` on Player model, `getConsumables/addConsumable/removeConsumable` on InventoryService, MockInventoryService seeds 3 starter consumables
- **MatchResult.wasResigned**: new field propagated through MatchHistoryEntry, MatchHubView processResult (skips durability wear on resign), MatchViewModel computeRewardsPreview
- **GameConstants.MatchActions**: all tuning constants (timeout energy, hook call chances, resign thresholds, max consumables)
- **Test suite**: 9 new tests covering skip, resign, timeout, consumable usage/limits, hook call availability/scaling, wasResigned flag, MomentumTracker.resetOpponentStreak

### Architecture
```
MatchViewModel (@MainActor) → await engine.requestSkip() / .requestResign() / .requestTimeout() / etc.
                                          ↓
MatchEngine (actor) — sets flags, processes actions, queues MatchEvents
                                          ↓
AsyncStream<MatchEvent> → MatchViewModel → courtScene.animate() → MatchAnimator
                                                                          ↓
                                                   timeout/consumable/hookCall animations
```

### New files
- `Models/Match/MatchAction.swift` — MatchAction enum + MatchActionResult
- `Views/Match/MatchActionButtons.swift` — SwiftUI overlay (ActionButton, ConsumablePickerSheet)
- `Resources/character2-Sheet.png` — second character sprite sheet
- `PickleQuestTests/Engine/MatchActionTests.swift` — 9 tests

### Modified files
- `MatchEngine.swift` — action flags, state tracking, init params, action methods (requestSkip/Resign/Timeout, useConsumable, requestHookCall), skip filtering, resign check, pending event queue
- `MomentumTracker.swift` — resetOpponentStreak()
- `MatchEvent.swift` — 4 new cases (timeoutCalled, consumableUsed, hookCallAttempt, resigned)
- `GameConstants.swift` — MatchActions section
- `MatchResult.swift` — wasResigned field
- `MatchHistoryEntry.swift` — wasResigned field + explicit init with default
- `MatchViewModel.swift` — engine ref, action state, action methods, skip/resign handling, refreshActionState
- `MatchSpriteView.swift` — MatchActionButtons overlay
- `MatchAnimator.swift` — timeout/consumable/hookCall/resigned animations
- `MatchSimulationView.swift` — new event cases in switch
- `MatchHubView.swift` — wasResigned in processResult, skip durability on resign, consumable removal
- `CharacterAppearance.swift` — spriteSheet field, defaultOpponent uses character2-Sheet
- `SpriteFactory.swift` — dynamic sheet name from appearance.spriteSheet
- `AppearanceGenerator.swift` — random spriteSheet assignment
- `Player.swift` — consumables array
- `InventoryService.swift` — consumable methods
- `MockInventoryService.swift` — consumable storage + starter items
- `MatchService.swift` — createMatch params (consumables, reputation)
- `MockMatchService.swift` — passes consumables/reputation to engine

---

## Milestone 4.4: Court Ladder Progression System

**Commit**: `2862519`

### What was built
- **Court ladder system**: each court now has a structured ladder of 2-4 NPCs sorted weakest to strongest by DUPR rating
- **Sequential progression**: players must beat NPCs in order — lowest first, then unlock the next challenger up the ladder
- **Defeated NPC tracking**: beaten NPCs show as "Gone home" with green checkmark; locked NPCs display lock icon and "Beat [name] first"
- **Alpha boss encounters**: after clearing all regulars at a court, an alpha boss spawns with 1.3x scaled stats (capped at 75 per stat), one difficulty tier above the court's strongest NPC
- **Boss loot drops**: beating an alpha guarantees 1 legendary + 2 epic equipment drops (all with abilities)
- **King of the Court**: beating the alpha awards a crown badge and "King of the Court" title on the court header
- **Farmable alphas**: alpha bosses remain available after being beaten — re-challengeable for additional loot drops
- **Court perks**: track per-court domination status (tournament invite, 20% store discount, coaching — stored as data for future feature wiring)
- **Deterministic alpha IDs**: alpha NPCs use UUID derived from court ID, so the same alpha regenerates consistently
- **Ladder UI overhaul**: CourtDetailSheet replaced flat NPC list with full ladder view — strongest at top, alpha card at very top with dramatic red styling, perk badges section

### Architecture
```
CourtProgressionService (protocol)
    ↓
MockCourtProgressionService (actor) — stores ladders + perks + alpha NPCs
    ↓
MapViewModel — loads ladder on court select, validates challenges, records defeats
    ↓
CourtDetailSheet — renders ladder rungs, alpha card, perk badges
    ↓
MatchHubView processResult — calls mapVM.recordMatchResult on win, handles alpha loot
```

### New files
- `Models/World/CourtLadder.swift` — CourtLadder struct (progression state per court/game type), GameType enum (singles/doubles), CourtPerk struct
- `Engine/LootGeneration/AlphaNPCGenerator.swift` — generates alpha boss NPC with 1.3x stat scaling, difficulty bump, deterministic UUID, alpha dialogue
- `Engine/LootGeneration/AlphaLootGenerator.swift` — generates 1 legendary + 2 epic drops for alpha defeats
- `Services/Protocols/CourtProgressionService.swift` — protocol + LadderAdvanceResult enum (nextUnlocked, alphaUnlocked, alphaDefeated, alreadyDefeated)
- `Services/Mock/MockCourtProgressionService.swift` — in-memory actor implementation

### Modified files
- `GameConstants.swift` — CourtProgression section (singlesNPCRange 2...4, alphaStatScale 1.3, alphaStatCap 75, alphaRewardMultiplier 5.0, alphaLootCount 3, storeDiscountPercent 0.20)
- `Player.swift` — courtLadders and courtPerks arrays
- `CourtService.swift` — getLadderNPCs method
- `MockCourtService.swift` — 2-4 NPCs per court sorted by DUPR, getLadderNPCs
- `DependencyContainer.swift` — courtProgressionService dependency
- `MapViewModel.swift` — ladder state (currentLadder, alphaNPC, courtPerk, ladderAdvanceResult), selectCourt initializes ladder, canChallengeNPC validation, recordMatchResult
- `CourtDetailSheet.swift` — full ladder UI overhaul (ladder rungs, alpha card, perk badges, King of Court crown)
- `MapContentView.swift` — passes ladder/perk/alpha to CourtDetailSheet
- `MatchHubView.swift` — post-match ladder advancement, alpha loot handling

---

## Milestone 4.5: Fog of War Map Exploration

**Commit**: `c4b9770`

### What was built
- **Grid-based fog of war**: map covered in semi-transparent dark overlay that hides unexplored areas; walking reveals ~20m radius around the player
- **FogCell grid system**: map divided into 20m x 20m cells; cells tracked as `Set<FogCell>` on AppState with fast coordinate-to-cell conversion using approximate meter-to-degree math
- **Canvas overlay rendering**: `FogOfWarOverlay` uses SwiftUI Canvas with even-odd fill path — draws full-screen fog rectangle, then punches ellipse holes for each revealed cell; `MapReader`/`MapProxy` handles coordinate-to-screen conversion
- **Reveal triggers**: fog reveals on all player movement — real GPS updates, dev mode D-pad, and sticky mode panning all call `revealFog(around:)` through the existing discovery check flow
- **Performance optimizations**: only visible cells rendered (filtered by current map region bounds), sub-pixel cells skipped at extreme zoom-out, circle radius slightly inflated (1.15x) to overlap adjacent cells for smooth edges
- **Dev mode defaults to on**: `isDevMode` now starts `true` with snapshot saved in init
- **Fog of war toggle**: new "Fog of War" section in DevModeView with on/off toggle (default on), revealed cell count display, and "Clear Fog" quick-disable button

### New files
- `Models/FogOfWar.swift` — `FogCell` struct (Hashable, Codable, Sendable) + `FogOfWar` utility enum (cell conversion, reveal radius calculation, fast approximate distance)
- `Views/Map/FogOfWarOverlay.swift` — Canvas-based fog renderer with MapProxy coordinate conversion and even-odd fill

### Modified files
- `AppState.swift` — `fogOfWarEnabled`, `revealedFogCells`, `revealFog(around:)`, `isDevMode` default changed to `true`
- `MapContentView.swift` — `MapReader` wrapper, `visibleRegion` tracking via `.onMapCameraChange(.continuous)`, `FogOfWarOverlay` in ZStack, `revealFog()` call in discovery check
- `DevModeView.swift` — fog of war section with toggle, cell count, clear button

---

## Milestone 5: Doubles, Team Synergy, Tournaments

### What was built
- **2v2 doubles matches**: full doubles mode with partner NPC selection from court roster, 4-player composite stats feeding into existing rally/point engine
- **Team synergy system**: 5×5 personality matrix (0.90–1.10 multiplier) — aggressive+defensive is best pairing (1.08), same-personality overlaps penalized; synergy badge shown on partner picker and result screen
- **TeamStatCompositor**: averages both partners' effective stats (after equipment bonuses), applies synergy multiplier — existing `PointResolver` → `RallySimulator` pipeline unchanged
- **Authentic doubles scoring**: side-out scoring (only serving team scores), three-number format "4-2-1" (serving score, receiving score, server number), both servers serve before side-out, "0-0-2" start
- **DoublesScoreTracker**: manages server rotation, side-out logic, both-serve-before-switch rule, win-by-2 at 11 points
- **4-player SpriteKit rendering**: near/far partner sprites at doublesLeft (0.35) and doublesRight (0.65) positions, perspective-correct scaling, all 4 players animate with sprite sheet animations
- **Doubles animations**: 4-player slide-in at match start, active hitter alternation within each team during rallies, teammate advance toward kitchen alongside active player, team celebrations on match end
- **Singles/doubles toggle**: segmented picker on CourtDetailSheet, doubles shows NPC pairs with synergy info and "Challenge Pair" buttons
- **Partner picker**: dedicated PartnerPickerView sorted by synergy with player (best first), opponent pair info at top, synergy badge per candidate
- **Tournament system**: single-elimination 4-player/team brackets, seeded by DUPR, NPC-vs-NPC auto-simulated, player matches with full SpriteKit
- **TournamentEngine**: actor orchestrating bracket flow via AsyncStream, uses CheckedContinuation for player match handoff
- **TournamentGenerator**: seeds bracket by DUPR, pairs NPC doubles teams by synergy
- **TournamentBracketView**: visual bracket with round progression, match cards, current match highlighting, all tournament states
- **Tournament rewards**: 1.5x XP, 2x coins for tournament matches; winner gets 1 legendary + 2 epic drops
- **MatchType unification**: replaced duplicate `GameType` enum with `MatchType` across all code (CourtLadder, MatchConfig, MatchHistoryEntry)
- **Broadcast overlay**: doubles-aware score overlay showing "DOUBLES" label and three-number score display
- **Doubles result screen**: partner name, opponent team, synergy badge with colored percentage

### Architecture
```
CourtDetailSheet (singles/doubles toggle)
    ↓ doubles challenge
MapContentView → MatchHubView → PartnerPickerView
    ↓ partner selected
MatchViewModel.startDoublesMatch()
    ↓
MockMatchService.createDoublesMatch() → TeamStatCompositor (composite stats) → MatchEngine (with doubles params)
    ↓
MatchEngine uses DoublesScoreTracker for side-out scoring
    ↓
AsyncStream<MatchEvent> → MatchViewModel → MatchCourtScene (4 sprites) → MatchAnimator (4-player animations)

TournamentGenerator.generate() → Tournament bracket
    ↓
TournamentEngine.simulate() → AsyncStream<TournamentEvent>
    ↓
TournamentViewModel (state machine) → TournamentBracketView
    ↓ player match
MatchViewModel (reused for player's tournament matches)
```

### New files
- `Models/Match/TeamSynergy.swift` — 5×5 personality synergy matrix with multiplier and description
- `Models/Match/DoublesScoreTracker.swift` — side-out scoring, server rotation, three-number format
- `Models/Match/Tournament.swift` — Tournament, TournamentBracket, TournamentMatch, TournamentSeed, TournamentStatus, TournamentRewards
- `Engine/MatchSimulation/TeamStatCompositor.swift` — composite team stats from 2 players + synergy
- `Engine/Tournament/TournamentEngine.swift` — actor orchestrating bracket via AsyncStream + CheckedContinuation
- `Engine/Tournament/TournamentGenerator.swift` — bracket seeding by DUPR, NPC pair generation
- `Services/Protocols/TournamentService.swift` — tournament CRUD protocol
- `Services/Mock/MockTournamentService.swift` — in-memory actor implementation
- `ViewModels/TournamentViewModel.swift` — tournament state machine (idle → bracketPreview → roundInProgress → playerMatch → roundResults → finished)
- `Views/Tournament/TournamentBracketView.swift` — visual bracket UI with all tournament states
- `Views/Match/PartnerPickerView.swift` — partner selection with synergy sorting

### Modified files
- `GameConstants.swift` — Doubles section (compositeStatWeight, startServerNumber) + Tournament section (bracketSize, xp/coin multipliers, loot counts)
- `MatchConfig.swift` — `defaultDoubles` config, `isSideOutScoring` computed property
- `MatchEvent.swift` — doubles-aware matchStart (partnerName, opponent2Name), sideOut event, tournament events, updated narration
- `MatchPoint.swift` — optional serverNumber, isSideOut; doublesScoreDisplay on MatchScore
- `MatchResult.swift` — partnerName, opponent2Name, teamSynergy, isDoubles fields
- `MatchHistoryEntry.swift` — matchType, partnerName, opponent2Name
- `Player.swift` — personality field (defaults to .allRounder)
- `CourtLadder.swift` — unified GameType → MatchType
- `MatchEngine.swift` — optional partner fields for all 4 participants, doublesScoreTracker, team synergy, composite stats per point, 4-player fatigue tracking, side-out scoring branch
- `MatchService.swift` — createDoublesMatch protocol method
- `MockMatchService.swift` — createDoublesMatch implementation with synergy + composite stats
- `MatchViewModel.swift` — doubles state (selectedPartner, opponentPartner, teamSynergy, doublesScoreDisplay, isDoublesMode), selectingPartner state, startDoublesMatch, partner/opponent2 appearances
- `CourtDetailSheet.swift` — singles/doubles toggle, doubles NPC pair cards with synergy, tournament button
- `MapContentView.swift` — doubles state, doubles challenge flow through CourtDetailSheet
- `MatchHubView.swift` — partner picker integration, doubles match creation, doubles match history
- `MatchResultView.swift` — doubles info display (partner, opponent team, synergy badge)
- `MatchSimulationView.swift` — doubles-aware broadcast overlay
- `MatchSpriteView.swift` — passes 4 appearances, doubles score display
- `MatchAnimationConstants.swift` — doublesLeftNX/doublesRightNX positions
- `MatchCourtScene.swift` — nearPartner/farPartner nodes and animators, 4-appearance init, setupDoublesPartners, doubles resetPlayerPositions
- `MatchAnimator.swift` — 4-player match start/rally/match end animations, fireAction helper for Swift 6 sendability
- `DependencyContainer.swift` — tournamentService dependency

---

## Milestone 6: Training, Coaching, Daily Challenges & Economy Rebalance

### What was built
- **Training drill system**: 4 drill types (serve, rally, defense, footwork) each targeting 2-3 stats, 3 difficulty levels, grade system (S/A/B/C/D) based on effective stats + variance, SpriteKit drill scene with court visualization and per-drill animations
- **Coach NPCs**: 80% of coach courts use the alpha NPC as coach (derived from top 2 stats), 20% use one of 6 predefined coaches; tier-based fees (200-2000 coins) with exponential diminishing returns (fee doubles per existing boost); beating the alpha unlocks 50% discount on coaching sessions
- **Daily challenges**: 3 random challenges per day (7 types: win matches, complete drills, visit courts, beat stronger, win without consumables, play doubles, earn drill grade), per-challenge coin+XP rewards, 500-coin completion bonus for all 3, floating map banner with expand/collapse
- **Economy rebalance**: equipment now degrades 3% on wins (8% on loss), broken equipment stays in inventory (repairable for ~30% of rarity base price), store expanded with 2 consumable slots (Stamina Shake, Lucky Charm + existing consumables), coach fees as major coin sink
- **Coach discount system**: alpha-as-coach courts resolve the alpha NPC into a Coach with specialty stats derived from the NPC's top 2 stats; defeating the alpha applies a 50% fee discount, with unique dialogue for defeated vs undefeated alphas

### Architecture
```
Training Flow:
CourtDetailSheet → "Train Here" drill buttons → TrainingDrillView (picker/scene/results)
    ↓
TrainingViewModel.startDrill() → TrainingDrillSimulator → TrainingResult (grade + XP)
    ↓
TrainingDrillScene (SpriteKit) → CourtRenderer + SpriteFactory reuse → drill animation

Coach Flow:
MapViewModel.selectCourt() → isAlphaCoachCourt? → Coach.fromAlphaNPC() or getCoachAtCourt()
    ↓
CourtDetailSheet → CoachView (fee display + discount badge) → onCoachSession callback
    ↓
Player: -fee coins, +1 stat, record session, +50 XP

Daily Challenges:
MapContentView .task → loadDailyChallenges() → DailyChallengeBanner overlay
    ↓
Progress tracked: match wins, drill completions, court visits, grades
    ↓
All-3 bonus: +500 coins (claimed from banner)
```

### New files
- `Models/Training/TrainingDrill.swift` — DrillType, DrillDifficulty, DrillGrade, TrainingDrill
- `Models/Training/TrainingResult.swift` — drill result with grade and stat scores
- `Models/Training/Coach.swift` — Coach (with alpha-coach support + discount), CoachDialogue, CoachingRecord
- `Models/Training/DailyChallenge.swift` — ChallengeType, DailyChallenge, DailyChallengeState
- `Engine/Training/TrainingDrillSimulator.swift` — stat-based grade calculation
- `Services/Protocols/TrainingService.swift` + `Services/Mock/MockTrainingService.swift`
- `Services/Protocols/CoachService.swift` + `Services/Mock/MockCoachService.swift` — 6 predefined coaches, alpha-coach court tracking
- `Services/Protocols/DailyChallengeService.swift` + `Services/Mock/MockDailyChallengeService.swift`
- `ViewModels/TrainingViewModel.swift` — drill execution + coach session logic
- `Views/Training/TrainingDrillScene.swift` — SpriteKit drill visualization
- `Views/Training/TrainingDrillView.swift` — drill picker, difficulty, SpriteKit scene, results overlay
- `Views/Training/CoachView.swift` — coach info, specialty stat buttons, discount badge
- `Views/Map/DailyChallengeBanner.swift` — floating compact/expanded challenge tracker

### Modified files
- `GameConstants.swift` — Training, Coaching (alphaCoachChance, alphaDefeatedDiscount), DailyChallenge sections; baseWinWear; consumableSlots
- `Player.swift` — coachingRecord, dailyChallengeState fields
- `Equipment.swift` — isBroken, repairCost computed properties
- `StoreItem.swift` — StoreConsumableItem struct
- `InventoryService.swift` + `MockInventoryService.swift` — repairEquipment method
- `StoreService.swift` + `MockStoreService.swift` — consumable methods + 5-item pool
- `DependencyContainer.swift` — 3 new service dependencies
- `MapViewModel.swift` — coach/daily challenge loading, alpha-coach resolution in selectCourt
- `CourtDetailSheet.swift` — training section + coach section
- `MapContentView.swift` — daily banner, training sheet, daily challenge progress on court visit
- `MatchHubView.swift` — win durability wear, broken equipment stays, daily challenge progress
- `EquipmentDetailView.swift` — repair button for broken equipment
- `InventoryView.swift` + `InventoryViewModel.swift` — repair flow
- `StoreView.swift` + `StoreViewModel.swift` — consumable section
- `DevModeView.swift` — coaching record + daily challenge overrides

### Post-milestone: Training System Redesign

**Commit**: `8d35388`

Replaced the drill grade system (S/A/B/C/D) with energy-based stat gains that always improve the player:
- **Removed**: DrillGrade, DrillDifficulty enums, manual drill type picker
- **Coach levels 1-5**: replaced tiers (1-4), with level-based fee table [200, 500, 1000, 2000, 3000]
- **Daily specialty**: deterministic `hash(coachID + date) % 10` → one StatType per coach per day, coach determines drill type
- **Stat gain formula**: `max(1, Int((energyPercent / 100.0) * Double(coachLevel)))` — always improves, scales with energy and coach level
- **White coach sprite**: all-white `CharacterAppearance` on far side of drill scene feeding balls (forehand/backhand cycles)
- **Fixed result timing**: overlay waits for 4s SpriteKit animation to complete via `onComplete` callback + `animationComplete` flag
- **Unified training flow**: no separate drill picker — coach section in CourtDetailSheet shows daily specialty, fee, expected gain, single "Train" button
- **Files changed**: 16 (6 model, 2 engine/service, 1 ViewModel, 4 views, 2 service implementations, 1 service protocol)

---

## Milestone 7a: Onboarding, Player Management & Basic Persistence

### What was built
- **SwiftData persistence**: `SavedPlayer` @Model stores full player data as JSON blob with indexed summary fields; `SwiftDataPersistenceService` actor creates isolated `ModelContext` per operation
- **Save/load bundle**: `SavedPlayerBundle` round-trips Player + inventory + consumables + fog cells + tutorial status; saves on background, after match, and on player switch
- **Character creation flow**: 3-step paged onboarding — name entry (1-20 chars), appearance preset picker (8 color themes with animated sprite previews), personality selection (5 playstyles with stat biases)
- **AnimatedSpriteView**: reusable sprite animation component extracted from MapPlayerAnnotation; uses TimelineView for animation and Task.detached for off-main-thread color replacement
- **Player chooser**: grid of saved player cards with animated sprite previews, "New Character" card, delete via context menu, loads full bundle and restores services
- **Tutorial match**: guided intro with 3 tip cards, auto-starts unrated match against Coach Pickles (very weak stats ~5, DUPR 2.0, 2x reward multiplier), simplified result processing (XP/coins/loot only)
- **Tutorial post-match**: 3 explainer cards (loot, exploration, progression) before entering the main game
- **App routing**: `AppPhase` enum (loading → playerChooser → characterCreation → tutorialMatch → tutorialPostMatch → playing), `RootView` router
- **Player switching**: "Switch Player" toolbar button on Profile saves current state then opens chooser as full-screen cover
- **Auto-save**: saves on scene phase → background, after every match result

### State flow
```
Launch → [.loading] → check saved players
  ├─ none → [.characterCreation] → name/appearance/personality → save → [.tutorialMatch]
  └─ exists → [.playerChooser] → pick player → load
                ├─ tutorial done → [.playing]
                └─ tutorial pending → [.tutorialMatch]

[.tutorialMatch] → guided match vs Coach Pickles → [.tutorialPostMatch] → explainers → [.playing]

Profile → "Switch Player" → save current → [.playerChooser]
```

### New files (17)
- `Models/Persistence/SavedPlayer.swift` — @Model SwiftData entity
- `Models/Persistence/SavedPlayerSummary.swift` — lightweight chooser display struct
- `Models/Persistence/SavedPlayerBundle.swift` — full save/load bundle
- `Models/Player/CharacterPreset.swift` — 8 appearance presets
- `Models/Onboarding/TutorialTip.swift` — tutorial tip model
- `Models/World/TutorialNPC.swift` — weak tutorial opponent (Coach Pickles)
- `Services/Protocols/PersistenceService.swift` — save/load protocol
- `Services/SwiftData/SwiftDataPersistenceService.swift` — SwiftData actor implementation
- `Views/RootView.swift` — top-level phase router
- `Views/Components/AnimatedSpriteView.swift` — reusable sprite animation
- `Views/Onboarding/CharacterCreationView.swift` — 3-step creation flow
- `Views/Onboarding/PlayerChooserView.swift` — multi-slot player picker
- `Views/Onboarding/PlayerSlotCard.swift` — player card in chooser
- `Views/Onboarding/TutorialMatchView.swift` — tutorial match + tips
- `Views/Onboarding/TutorialPostMatchView.swift` — post-tutorial explainers
- `ViewModels/CharacterCreationViewModel.swift` — creation state
- `ViewModels/TutorialViewModel.swift` — tutorial phases + tips
- `Extensions/NPCPersonality+Display.swift` — personality display metadata

### Modified files (7)
- `App/PickleQuestApp.swift` — ModelContainer, RootView, scenePhase auto-save
- `App/AppState.swift` — AppPhase, optional player init, save method, loadFromBundle
- `App/DependencyContainer.swift` — persistenceService dependency, ModelContainer in init
- `Views/Map/MapPlayerAnnotation.swift` — delegates to AnimatedSpriteView
- `Views/Player/PlayerProfileView.swift` — Switch Player toolbar button + fullScreenCover
- `Views/Match/MatchHubView.swift` — auto-save after match result
- `Services/Mock/MockInventoryService.swift` — reset(inventory:consumables:), static starter helpers

---

## Milestone 7b: Wager System + Hustler NPCs

### What was built
- **Wager system**: players can bet coins on matches against NPCs with tier options [Free, 50, 100, 250, 500]; win doubles the wager, loss deducts it
- **NPC wager decisions**: regular NPCs accept wagers if their SUPR ≥ player - 0.5 and consecutive losses < 3; free matches always accepted; NPCs refuse wagers after losing 3 in a row
- **Hustler NPC archetype**: 3 pre-defined hustler NPCs (Slick Rick, Diamond Dee, The Shark) with hidden stats ("???"), forced wager amounts (300/500/800), and sore-loser mechanic (leave court after defeat)
- **Hustler loot**: defeating a hustler generates premium drops (1 epic + 1 rare + 1 bonus roll 50/50 epic/rare) via `HustlerLootGenerator`
- **Hustler rep bonus**: +25 reputation for beating a hustler (via `GameConstants.Wager.hustlerBeatRepBonus`)
- **WagerSelectionSheet**: intermediate sheet between NPC challenge and match start — tier picker for regular NPCs, forced wager display for hustlers, coin balance check, NPC rejection messages
- **Court hustler distribution**: 3 hustlers distributed across mid-to-high difficulty courts (indices 4-8)
- **Match result wager display**: green "+X (Wager Won!)" on victory, red "-X (Wager Lost)" on defeat, purple hustler defeat callout with bonus rep
- **NPC loss record tracking**: `Player.npcLossRecord` tracks consecutive player wins per NPC for wager refusal mechanic
- **Match history**: wager amounts recorded in `MatchHistoryEntry`

### Architecture
```
CourtDetailSheet (hustler section with "???" stats + wager badges)
    ↓ challenge tap
MapContentView → sets pendingWagerNPC → shows WagerSelectionSheet
    ↓
WagerDecision.evaluate(npc, wagerAmount, playerSUPR, consecutiveWins)
    ├─ .accepted(amount) → matchVM.startMatch(..., wagerAmount:)
    └─ .rejected(reason) → shows rejection message
    ↓
MatchEngine (config.wagerAmount) → calculateCoins returns wagerAmount on win
    ↓
MockMatchService.processMatchResult → wallet.add/spend(wager), hustler rep bonus
    ↓
MatchHubView.processResult → npcLossRecord tracking, hustler loot generation
```

### New files (6)
- `Engine/LootGeneration/HustlerNPCGenerator.swift` — 3 pre-defined hustler NPCs with deterministic UUIDs
- `Engine/LootGeneration/HustlerLootGenerator.swift` — premium loot drops for hustler defeats
- `Models/Match/WagerDecision.swift` — NPC accept/reject logic for wagers
- `Views/Map/WagerSelectionSheet.swift` — wager UI with tier picker / forced hustler wager
- `PickleQuestTests/Engine/WagerDecisionTests.swift` — 7 tests for wager decision logic
- `PickleQuestTests/Engine/HustlerNPCGeneratorTests.swift` — 8 tests for hustler generation

### Modified files (17)
- `NPC.swift` — isHustler, hiddenStats, baseWagerAmount fields
- `MatchConfig.swift` — wagerAmount field
- `Player.swift` — npcLossRecord with Codable migration
- `MatchHistoryEntry.swift` — wagerAmount with Codable migration
- `GameConstants.swift` — Wager section (tiers, thresholds, hustler constants)
- `NPCService.swift` — getHustlerNPCs() protocol method
- `MockNPCService.swift` — hustler generation + getNPC checks hustlers
- `CourtService.swift` — getHustlersAtCourt() protocol method
- `MockCourtService.swift` — hustler distribution across courts
- `MatchEngine.swift` — calculateCoins returns wagerAmount on win
- `MockMatchService.swift` — wager economy + hustler rep bonus
- `MatchViewModel.swift` — wager state, pendingWagerNPC, showWagerSheet
- `MapViewModel.swift` — hustlersAtSelectedCourt loading
- `CourtDetailSheet.swift` — hustler section with mysterious styling
- `MapContentView.swift` — wager sheet flow integration
- `MatchResultView.swift` — wager win/loss badges, hustler defeat callout
- `MatchHubView.swift` — npcLossRecord tracking, hustler loot, wager in history

### NPC Coin Purse System (added post-7b)

**Commit**: `9fbf1b8`

- **NPC purses**: Regular NPCs carry 0-200 coins, hustlers carry 1000-3000. Wager amounts capped at what the NPC has.
- **Hustler restocking**: Hustlers regenerate purse every hour (`hustlerResetInterval: 3600s`). Session-only state — resets on app restart.
- **WagerDecision purse checks**: Regular NPCs reject wagers exceeding their purse ("I don't have that much on me"). Hustlers auto-cap effective wager to min(baseWager, purse). Zero-purse hustlers reject ("I'm tapped out").
- **MapViewModel purse loading**: `npcPursesAtSelectedCourt` populated on court selection, cleared on dismiss, refreshed after match transactions.
- **Post-match purse transactions**: Player win deducts from NPC purse; player loss adds to NPC purse. Purses refresh after each match.
- **UI display**: Purse amounts shown on ladder rung cards (next challenger) and hustler cards. WagerSelectionSheet filters tiers to NPC purse. Hustler sheet shows effective wager when purse < base.
- **Tests**: 4 new WagerDecision tests (purse rejection, within-purse acceptance, hustler purse cap, hustler empty purse).

### Equipment Brand, Level & Base/Bonus Stat System

**Commit**: `83ef0bb`

- **14 equipment brands**: 6 multi-slot (CourtKraft, SwiftSole, EnduroWear, ProSpin, EliteEdge, AllCourt) + 8 single-slot specialists (Dinkmaster, SpinWizard, ThunderSmash, ZenPaddle, RushFoot, IronSole, ClutchGear, FlexForm), ~60 models total
- **Slot-relevant base stats**: each model specializes in one stat relevant to its slot (paddle: power/accuracy/spin/consistency; shoes: speed/positioning/reflexes/defense; etc.)
- **Rarity-driven stat split**: base stat value scales by rarity (common=3, legendary=16); bonus stat count scales (common=0, legendary=4) with separate budget distribution
- **Equipment levels 1-25**: level cap per rarity (common=5, legendary=25), +5% stat scaling per level, exponential upgrade costs with rarity multiplier
- **Player-level gating**: equipment with level > player level contributes 0 stats (prevents twinking)
- **Brand identity**: equipment named "Brand Model" (e.g., "Dinkmaster Vortex"), brand shown on inventory cards and store items
- **Upgrade system**: coin-based upgrades via inventory detail view, cost = `25 * pow(targetLevel, 1.4) * rarityMultiplier`
- **Backward compatible**: all new fields use `decodeIfPresent` with defaults in custom Codable init
- **Updated views**: level badges on cards, base vs bonus stat sections in detail view, upgrade button, level gate warnings
- **Tests**: 6 new loot generator tests (brand assignment, stat budget, base/bonus split), 3 new stat calculator tests (level multiplier, level gate, default level)

---

## Milestone 8: Match Simulation Realism + Focus Stat

### What was built
- **Focus stat**: 11th stat added to mental category (clutch, focus, stamina, consistency); backward-compatible Codable with `decodeIfPresent` defaulting to 15; added to all 38 NPCs, 3 hustlers, tutorial NPC, alpha generator, equipment brands, momentum tracking, and stat calculator
- **Singles side-out scoring**: server wins rally → scores; server loses rally → side-out (serve switches, no score); matches official pickleball rules where only the serving side can score
- **Doubles dink phase**: after serve in doubles, 3-15 shot dink approach phase at the kitchen line before regular rally begins; dink outcomes use soft-game stats (accuracy, spin, focus, consistency, positioning) instead of power; if unresolved, flows into regular rally phase
- **Enhanced timeout animation**: 5-phase walk-off/walk-on sequence (players walk off court → "TIMEOUT" announcement → "Streak Broken!" callout → players walk back → floating energy indicators); timeout now restores energy for ALL participants (both sides)
- **Doubles visual bounces**: raised from 5 to 8 max visual bounces during rally animation to reflect longer doubles rallies
- **Focus-based equipment**: Dinkmaster Focus Cap changed baseStat to `.focus`; added FocusBand Focus headwear model

### Files modified (16)
- `PlayerStats.swift` — focus field, StatType.focus, custom Codable, average divisor 10→11
- `GameConstants.swift` — dink phase constants, removed serveSwitchInterval, startingStatTotal 165/11
- `RallySimulator.swift` — isDoubles param, dink approach phase with 3 new helper methods
- `MatchEngine.swift` — singles side-out scoring, timeout restores all participants, isDoubles threading
- `PointResolver.swift` — isDoubles param threaded to rally simulator
- `MatchEvent.swift` — timeout event energy fields
- `MatchAnimator.swift` — 5-phase timeout animation, doubles bounce cap 8
- `MatchAnimationConstants.swift` — timeout timing, doublesMaxVisualBounces
- `StatCalculator.swift` — focus in momentum-affected stats
- `EquipmentBrand.swift` — focus-based headwear models
- `MockNPCService.swift` — focus values for all 38 NPCs
- `HustlerNPCGenerator.swift` — focus for 3 hustlers
- `TutorialNPC.swift` — focus: 3
- `AlphaNPCGenerator.swift` — focus in stat scaling
- `TeamStatCompositor.swift` — focus in composite stats
- `TrainingDrill.swift` — focus case in forStat switch
- `EquipmentNameGenerator.swift` — focus flavor text

---

## Milestone 9: Gear Drop System (Loot on the Map)

**Commit**: `8b006fe`

### What was built
- **5 drop types** with GPS-anchored backpack pins on the map:
  - **Field Drops**: passive walking spawns every 15-20min, despawn after 30min, max 3 active, spawn within 300m of player
  - **Court Caches**: anchored to discovered courts, locked until winning a match at that court, 4hr cooldown per court, rarity boosted by court difficulty
  - **Trail Drops**: daily themed walking route with 5-8 waypoints ~200m apart, 2hr timer, escalating rarity (final waypoint = epic/legendary), brand-themed loot
  - **Contested Drops**: rare beacons at 500-2000m from player with NPC guardian, 2/day max, guaranteed rare+ loot (3 items)
  - **Fog Stashes**: 2% chance per newly revealed fog cell, remoteness bonus (isolated cells → better rarity)
- **Map integration**: backpack annotations with rarity-colored glow, pulsing animation when in 50m pickup range, type-specific icons (lock for court caches, flame for contested, numbered badges for trails)
- **Loot reveal sheet**: rarity-colored header, coin reward display, equipment list with equip/keep decisions, sticky dismiss button
- **Trail banner**: horizontal progress bar overlay on map showing trail name, waypoint progress, countdown timer
- **Contested drop sheet**: guardian difficulty display, challenge button, risk/reward info
- **Daily reset**: contested and field drop counters reset each calendar day, expired trails auto-clear
- **Fog stash detection**: captures fog cells before/after reveal, spawns stashes in newly revealed cells with "Hidden stash found!" toast
- **Court cache flow**: after winning a match at a court, pending court cache auto-unlocks for collection
- **Persistence**: `GearDropState` on Player model (collectedDropIDs, courtCacheCooldowns, activeTrail, contestedDropsClaimed, fieldDropsCollectedToday, lastDailyReset, lastFieldSpawnTime) — all with backward-compatible Codable

### Architecture
```
GearDropService (protocol)
    ↓
MockGearDropService (actor) — holds activeDrops in memory, uses LootGenerator for collection
    ↓
GearDropSpawnEngine (struct) — coordinate generation, rarity rolling, trail waypoint layout, remoteness calculation
    ↓
MapViewModel — refreshGearDrops() called on location change, collectGearDrop() shows reveal sheet
    ↓
MapContentView — ForEach annotations, reveal sheet, contested sheet, trail banner, fog stash hook in runDiscoveryCheck()
```

### New files (10)
- `Models/GearDrop/GearDrop.swift` — GearDrop model + GearDropType enum (field, courtCache, trail, contested, fogStash)
- `Models/GearDrop/GearDropState.swift` — Persisted player state + TrailRoute with backward-compatible Codable
- `Models/Common/LootDecision.swift` — Shared `LootDecision` enum extracted from MatchViewModel
- `Services/Protocols/GearDropService.swift` — Service protocol (spawn, collect, expire, check)
- `Services/Mock/MockGearDropService.swift` — Actor implementation with all 5 drop type logic
- `Engine/GearDrop/GearDropSpawnEngine.swift` — Coordinate gen, rarity rolling, trail waypoints, remoteness
- `Views/Map/GearDropAnnotationView.swift` — Backpack pin with rarity glow + pulse animation
- `Views/Map/GearDropRevealSheet.swift` — Loot reveal modal with equip/keep decisions
- `Views/Map/TrailBannerView.swift` — Trail progress overlay with live countdown timer
- `Views/Map/ContestedDropSheet.swift` — NPC guardian challenge confirmation

### Modified files (7)
- `GameConstants.swift` — GearDrop section (30 constants: spawn intervals, radii, cooldowns, rarity boosts, trail params, contested limits, fog stash chance)
- `Player.swift` — `gearDropState: GearDropState?` with `decodeIfPresent` backward compat
- `DependencyContainer.swift` — `gearDropService: GearDropService` property + init wiring
- `MapViewModel.swift` — gear drop state vars, refreshGearDrops(), collectGearDrop(), isDropInRange(), checkFogStashes(), unlockCourtCacheIfNeeded(), startTrailRoute()
- `MapContentView.swift` — gear drop annotations in mapLayer, reveal/contested sheets, trail banner, fog stash hook in runDiscoveryCheck(), toast system, processGearDropLoot(), daily reset
- `MatchViewModel.swift` — removed nested `LootDecision` enum (now shared)
- `LootDropRow.swift` — updated binding type from `MatchViewModel.LootDecision?` to `LootDecision?`
- `MatchHubView.swift` — passes `gearDropService` to MapViewModel init

---

## Milestone 9.1: Drill System Redesign + UI Polish

**Commit**: `a251676`

### What was built
- **New drill types**: Replaced defenseDrill/footworkTraining with dinkingDrill/returnOfServe, renamed rallyDrill→baselineRally, redesigned servePractice with swipe input
- **Rally scoring system**: 5-shot rally streaks (10 rounds) for baseline/dinking drills — 5 consecutive returns = 1 rally completed, miss resets counter
- **Swipe-to-serve input**: Serve practice uses upward swipe gesture — angle controls aim direction, distance controls power, player stats reduce scatter
- **Serve side switching**: 5 serves from right side, then animated switch to left side for 5 more
- **Return of serve drill**: Coach serves alternating sides, player returns with joystick, 3 cone targets on coach's court for bonus scoring
- **Cone target rendering**: Triangle SKShapeNodes at target positions, flash green on hit with "Cone Hit!" indicator
- **Per-drill HUD**: Rally mode shows "Rally X/10" + "Returns: X/5", serve mode shows "Serve X/10" + side indicator, return mode shows "Return X/10" + "Cone Hits: X"
- **ScoringMode enum**: rallyStreak (baseline/dink), serveAccuracy (serve), returnTarget (return of serve) — each with distinct grade calculation
- **Pre-match instruction overlay**: MatchSpriteView now shows opponent name, match type, and explains all 5 actions (Timeout, Item, Hook, Resign, Skip) before match starts
- **"Let's Play Pickleball!" button**: Replaces "Let's Go!" on drill instruction overlay, also used on match start overlay
- **Consistent dev launcher**: All drill type buttons use `.frame(maxWidth: .infinity)` for uniform width
- **DrillCoachAI updates**: Kitchen-zone clamping for dinking, `serveToPlayer()` method for return of serve, no-return mode for serve practice

### Modified files (12)
- `TrainingDrill.swift` — 4 new DrillType cases with updated properties and forStat() mapping
- `DrillConfig.swift` — DrillInputMode enum, new config fields (inputMode, rallyShotsRequired, totalRounds, showConeTargets)
- `GameConstants.swift` — Serve swipe constants (minDistance, maxPower, angleRange) + cone target positions/radius
- `InteractiveDrillResult.swift` — Added ralliesCompleted and coneHits fields
- `DrillScorekeeper.swift` — Rewritten with ScoringMode, rally/cone tracking, mode-specific success rates
- `DrillCoachAI.swift` — Dinking behavior, serveToPlayer(), serve practice catch-only mode
- `DrillShotCalculator.swift` — Updated all switch statements for new drill types
- `InteractiveDrillScene.swift` — Swipe input, cone targets, rally counting, serve side management, new phases
- `InteractiveDrillView.swift` — Per-drill instructions, button text, rally/cone result display
- `TrainingDrillScene.swift` — Updated animation switch cases
- `DevTrainingLauncher.swift` — Consistent button sizing, default to baselineRally
- `MatchSpriteView.swift` — Pre-match instruction overlay with action explanations

---

## Milestone 10: Interactive Match Mode

### What was built
- **Real-time match gameplay**: play full pickleball matches using drill-scene controls (joystick, 6 shot mode buttons, stamina system) against NPC opponents instead of watching simulated matches
- **MatchAI**: strategic NPC opponent that uses `calculatePlayerShot()` with stat-gated shot mode selection — power ≥50/70, accuracy ≥60, spin ≥40/70, positioning ≥50, focus ≥60 unlock different modes; own stamina system with sprint decisions based on ball distance
- **Side-out singles scoring**: only the server scores; non-server winning a rally causes side-out (serve switches); first to 11, win by 2
- **Serve mechanics**: player serves via swipe (same as drill scene), NPC auto-serves after 1.5s pause; server positions at correct side (even score = right, odd = left), receiver mirrors cross-court
- **NPC boss bar**: name + DUPR label + stamina bar above opponent sprite, updates in real-time
- **Match score HUD**: top-center scoreboard with serving indicator (pickle icon), player stamina bar, stamina warnings
- **Match type picker**: Simulated/Interactive segmented control on CourtDetailSheet (singles only), feeds through wager flow
- **Full result integration**: interactive matches produce `MatchResult` that feeds into existing pipeline — DUPR, XP, coins, loot, durability, match history, daily challenges, wagers all work identically
- **Instruction overlay**: NPC info, difficulty badge, control reminders before match starts
- **Result overlay**: Win/Loss banner, final score, match stats (aces, winners, errors, best rally), DUPR change, XP earned
- **Resign support**: exit button produces loss result with current score, `wasResigned = true`

### Architecture
```
CourtDetailSheet (Simulated/Interactive picker)
    ↓ interactive selected
MapContentView → WagerSelectionSheet → matchVM.startInteractiveMatch()
    ↓
MatchHubView routes .interactiveMatch → InteractiveMatchView (SwiftUI wrapper)
    ↓
InteractiveMatchScene (SpriteKit) — reuses drill subsystems:
  - CourtRenderer, DrillBallSimulation, DrillShotCalculator
  - Joystick, shot mode buttons, stamina system
  - SpriteSheetAnimator for character animations
    ↓
MatchAI — strategic opponent using NPC stats + shot modes
    ↓
Match end → MatchResult → existing processResult() pipeline
```

### New files (3)
- `Engine/Match/MatchAI.swift` — strategic AI with stat-gated shot modes, stamina, positioning, serve/receive logic
- `Views/Match/InteractiveMatchScene.swift` — SpriteKit match scene with scoring, serve rotation, phases, HUD
- `Views/Match/InteractiveMatchView.swift` — SwiftUI wrapper with instruction/result overlays

### Modified files (6)
- `GameConstants.swift` — `InteractiveMatch` section (pointsToWin, winByMargin, maxScore, pause durations, XP values)
- `MatchConfig.swift` — `MatchPlayMode` enum (simulated/interactive)
- `MatchViewModel.swift` — `.interactiveMatch` state, `startInteractiveMatch()`, `computeRewardsPreviewForInteractive()`
- `MatchHubView.swift` — `.interactiveMatch` routing to `InteractiveMatchView`, updated navigationTitle
- `CourtDetailSheet.swift` — `matchPlayMode` binding, Simulated/Interactive segmented picker
- `MapContentView.swift` — `matchPlayMode` state, passed to CourtDetailSheet, branching in wager onAccept

---

## Post-Milestone 10: AI Training System + Shot Quality Rewards

**Commit**: `a3577b6`

### What was built
- **AI Training System**: Evolution Strategy optimizer that runs NPC-vs-NPC simulations across DUPR pairings (2.0-8.0) to tune rally probability constants. Uses Natural Evolution Strategy with population 20, sigma 0.05, evaluating 200 matches per test pair per candidate. Accessible via Dev Mode > AI Tools > AI Trainer.
- **SimulationParameters**: mutable struct mirroring `GameConstants.Rally` values with array conversion for ES vector operations and clamping for valid ranges.
- **LightweightMatchSimulator**: synchronous match simulator (no actors/async) that mirrors `RallySimulator` logic but uses mutable parameters instead of `GameConstants`. Runs full matches to 11 with side-out scoring.
- **TrainingSession**: `@Observable @MainActor` class managing the ES optimization loop with live progress tracking (generation, fitness, win rate table).
- **TrainingReport**: captures results with formatted plaintext report + `ShareLink` for sharing via AirDrop/Messages.
- **Shot Quality System**: player shot selection now affects NPC error rates in interactive matches:
  - Good shots (power on high balls, topspin/angle cross-court, reset under pressure, focus on easy balls) increase NPC error rate by up to +25%
  - Bad shots (power on low fast balls, reset on sitters, no modes on high balls) decrease NPC error rate by up to -20%
- **DUPR Gap Scaling**: NPC error rates scale with the DUPR gap between player and NPC — stronger NPCs make fewer baseline errors (down to 30% of base), weaker NPCs make more (up to 2x).

### New files (6)
- `Engine/AITrainer/SimulationParameters.swift` — tunable rally constants with ES vector operations
- `Engine/AITrainer/LightweightMatchSimulator.swift` — synchronous match simulator
- `Engine/AITrainer/TrainingSession.swift` — ES optimization loop with live UI updates
- `Engine/AITrainer/TrainingReport.swift` — training results + formatted report
- `ViewModels/AITrainerViewModel.swift` — view model for training UI
- `Views/Player/AITrainerView.swift` — training controls, live progress, win rate table, share report

### Modified files (4)
- `Engine/Match/MatchAI.swift` — added `playerDUPR`, `lastPlayerShotModes/Height/Difficulty`, `assessPlayerShotQuality()`, DUPR gap scaling in `shouldMakeError()`
- `Views/Match/InteractiveMatchScene.swift` — tracks player shot context before each hit, passes `playerDUPR` to MatchAI
- `Models/Common/GameConstants.swift` — shot quality constants in NPCStrategy (goodShotErrorBonus, badShotErrorPenalty, duprGapErrorScale, maxDuprErrorReduction, maxDuprErrorBoost)
- `Views/Player/DevModeView.swift` — "AI Tools" section with NavigationLink to AITrainerView

---

## Post-Milestone 10b: DUPR Gap Calibration

**Commit**: `7037b04`

### What was built
- **Stat sensitivity knob** (`Rally.statSensitivity = 0.16`): master multiplier on all stat-differential terms in `RallySimulator`. At 1.0 (old default), a 0.1 DUPR gap produced ~5.5 point margin due to side-out scoring amplification. At 0.16, it produces ~1.2 points — matching real DUPR calibration.
- **Exponential DUPR error scaling** in `MatchAI.shouldMakeError()`: replaced linear scaling with `exp(-gap * 3.0)` for stronger NPCs and `exp(gap * 1.5)` for weaker. A +0.1 gap NPC now makes 26% fewer errors (was 1.5%); a +1.0 gap NPC makes 95% fewer (was 15%).
- **Rally pressure system** in `InteractiveMatchScene`: cumulative shot difficulty during a rally. When pressure exceeds a threshold (scaled by player's defensive stats), forced error rate increases. Models how sustained quality play breaks down the weaker player.
- **DUPR forced error amplifier**: player whiff rate scales with NPC DUPR advantage — 0.1 gap = 1.2x, 0.5 gap = 2x, 1.0 gap = 3x.
- **Monte Carlo calibration tests** (5 tests): verify equal stats → near-zero margin, 0.1 gap → 0.3-2.5 margin, 1.0 gap → decisive win (>4.0 margin, >85% win rate), monotonic increase, high-level consistency.

### Modified files (4)
- `GameConstants.swift` — `Rally.statSensitivity`, `NPCStrategy` exponential DUPR constants + pressure system + forced error amplifier
- `RallySimulator.swift` — apply `statSensitivity` to 5 differential functions (ace, winner, forced error, dink winner, overall advantage)
- `MatchAI.swift` — exponential DUPR error scaling in `shouldMakeError()`
- `InteractiveMatchScene.swift` — `rallyPressure` property, pressure accumulation + DUPR forced error amplifier in `checkPlayerHit()`

### New files (1)
- `PickleQuestTests/Engine/MatchCalibrationTests.swift` — Monte Carlo verification of DUPR gap calibration

---

## Post-Milestone 10c: Equipment Power Budget & Trait System

### What was built
- **Stat budget rebalance**: reduced base stat values (common 3→2, legendary 16→9) and bonus stat budgets (common 0→0, legendary 16→8) so a full 6x legendary loadout gives ~0.5-0.7 DUPR advantage instead of the old ~3.0+ DUPR
- **Level multiplier nerf**: reduced from +5% per level (max 2.2x at level 25) to +1% per level (max 1.24x at level 25)
- **Per-stat equipment cap**: any single stat's total equipment contribution capped at 15 points, preventing extreme stacking
- **Trait system**: passive stat-modifying traits replace the unused `EquipmentAbility` system as the primary rarity differentiator:
  - **5 minor traits** (rare+): small trade-offs (e.g., Lightfoot: +2 speed, -1 power)
  - **5 major traits** (epic+): multi-stat boosts (e.g., Rally Grinder: +3 consistency, +2 stamina)
  - **3 unique traits** (legendary only): strong effects (e.g., All-Rounder: +2 to all 11 stats)
- **Trait slot system**: rare gets 1 minor, epic gets 1 minor + 1 major, legendary gets 1 minor + 1 major + 1 unique
- **Trait stat integration**: traits resolve to stat modifiers applied in `StatCalculator` alongside equipment and set bonuses, all under the per-stat cap
- **View updates**: trait badges with tier-based colors (teal/purple/orange) on equipment cards and detail views
- **Backward compatibility**: `traits` field uses `decodeIfPresent` with empty array default; existing saved equipment decodes cleanly
- **Ability deprecation**: new items no longer generate abilities; old items retain them for display
- **Balance tests**: 9 new tests verifying power budget, per-stat cap, trait application, level multiplier, backward compat, and trait generation

### Files modified (7) + 2 new
- `EquipmentRarity.swift` — rebalanced baseStatValue, bonusStatBudget, bonusStatCount; added traitSlots and hasTrait
- `Equipment.swift` — added `traits: [EquipmentTrait]` with backward-compatible Codable
- `GameConstants.swift` — `statPercentPerLevel` 0.05→0.01, added `maxEquipmentBonusPerStat: 15`
- `StatCalculator.swift` — per-stat cap enforcement, `aggregateTraitBonuses()` method
- `LootGenerator.swift` — `generateTraits()` method, abilities deprecated for new items
- `EquipmentDetailView.swift` — traits section with tier badges
- `EquipmentCardView.swift` — trait names with tier colors
- NEW: `EquipmentTrait.swift` — TraitType, TraitTier, EquipmentTrait with statModifiers
- NEW: `EquipmentBalanceTests.swift` — 9 balance verification tests

---

## Post-Milestone 10d: Headless Interactive Match Simulator

### What was built
- **HeadlessMatchSimulator**: Runs the same physics, AI, and shot mechanics as `InteractiveMatchScene` at 120Hz fixed timestep without SpriteKit rendering. Mirrors the full game loop: serve, rally, hit detection, ball state, scoring, match-over logic.
- **SimulatedPlayerAI**: Human-player simulator that replaces joystick input. Uses raw stats (no stat boost), player-side hitbox constants, reaction delay (0.20s beginner → 0.03s expert), positioning noise (computed once per ball approach), and skill-gated shot mode selection (competence scales with skill²).
- **@MainActor removal**: Removed class-level `@MainActor` from `DrillBallSimulation` (kept only on `screenPosition()` and `shadowScreenPosition()`) and `MatchAI`, enabling nonisolated use by the headless simulator while maintaining compatibility with `InteractiveMatchScene`.
- **Training integration**: Added `HeadlessInteractiveEntry` to `TrainingReport` and a validation pass in `TrainingSession` that runs headless matches at DUPR [2.0, 3.0, 4.0, 5.0, 6.0] after ES training completes.
- **Test suite**: 3 tests verifying match completion, DUPR discrimination (higher DUPR wins more), and bounded rally length.

### Architecture notes
- Each `HeadlessMatchSimulator` instance owns its own `DrillBallSimulation`, `MatchAI`, and `SimulatedPlayerAI` — no cross-isolation sharing.
- `SimulatedPlayerAI` differs from `MatchAI` by design: no stat boost, smaller hitbox, reaction delay, positioning noise. This accurately reflects the NPC's +20 stat boost being a compensation for human joystick advantage.
- Rally lengths are shorter than real pickleball (~1.1 avg) because the simulated player lacks joystick advantage but faces the same boosted NPC. This is expected and documented.

### Files created (3)
- `Engine/AITrainer/HeadlessMatchSimulator.swift` — match orchestrator
- `Engine/AITrainer/SimulatedPlayerAI.swift` — human-player AI
- `PickleQuestTests/Engine/HeadlessMatchSimulatorTests.swift` — 3 tests

### Files modified (4)
- `Engine/Training/DrillBallSimulation.swift` — removed class-level `@MainActor`, added to 2 screen methods
- `Engine/Match/MatchAI.swift` — removed class-level `@MainActor`
- `Engine/AITrainer/TrainingReport.swift` — added `HeadlessInteractiveEntry`, `headlessInteractiveTable` field, report formatting
- `Engine/AITrainer/TrainingSession.swift` — added `evaluateHeadlessInteractive()` validation pass

---

## Milestone 7c: Persistence Polish, Cloud Prep, Multiplayer Prep (Planned)

### Goals
- Cloud save preparation (protocol-based storage layer)
- UI polish pass (animations, haptics, sound effects)
- Multiplayer architecture prep (real-time match protocol)
