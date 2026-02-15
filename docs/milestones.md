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
