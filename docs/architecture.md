# PickleQuest Architecture

## Overview
PickleQuest follows MVVM + Services architecture with protocol-based dependency injection. All game logic lives in the Engine layer, keeping Views and ViewModels thin.

## Layer Diagram
```
┌─────────────────────────────────┐
│            Views (SwiftUI)       │
├─────────────────────────────────┤
│         ViewModels (@Observable) │
├─────────────────────────────────┤
│     Services (Protocol-based)    │
├──────────┬──────────────────────┤
│  Engine  │      Models          │
└──────────┴──────────────────────┘
```

## Key Components

### Models (`Models/`)
Pure value types (structs/enums) that are `Codable`, `Sendable`, and `Equatable`. No business logic beyond simple computed properties.

- **Player**: identity, stats, progression, equipment slots, wallet, DUPR profile, rep profile, match history, energy, last match date
- **PlayerStats**: 10-stat system with DUPR mapping
- **DUPRProfile**: rating, match count, unique opponents, last match date, computed reliability/K-factor
- **RepProfile**: reputation score, lifetime rep earned, computed title and NPC sell price multiplier
- **Equipment**: 6 slots, 5 rarities, stat bonuses, triggered abilities (epic+), condition (durability for shoes/paddle), flavor text, optional set membership
- **EquipmentSet**: Set templates with tiered cumulative bonuses (5 sets: Court King, Speed Demon, Iron Wall, Mind Games, Endurance Pro)
- **MatchHistoryEntry**: persisted match outcome with opponent, score, SUPR/rep changes, broken equipment
- **Match types**: MatchConfig, MatchPoint, MatchEvent, MatchResult
- **NPC**: difficulty tiers, personality archetypes, dialogue
- **Economy**: Wallet, Consumable, StoreItem

### Engine (`Engine/`)

#### Match Simulation (`Engine/MatchSimulation/`)
The match simulation engine runs as an `actor` and emits events via `AsyncStream<MatchEvent>`.

**Pipeline**: StatCalculator → FatigueModel → MomentumTracker → RallySimulator → PointResolver → MatchEngine

1. **StatCalculator**: Base stats + equipment bonuses + set bonuses (with diminishing returns) + fatigue penalties + momentum modifiers
2. **FatigueModel**: Energy drain per rally shot, thresholds at 70/50/30% with increasing stat penalties
3. **MomentumTracker**: Consecutive point streaks give +2% to +7% bonus; opponent streaks give -1% to -5% penalty
4. **RallySimulator**: Serve phase (ace check) → shot-by-shot rally resolution (winner/error/forced error checks per shot)
5. **PointResolver**: Orchestrates a single point combining all modifiers
6. **MatchEngine**: Runs full match loop (games → points), tracks stats, calculates rewards, generates loot

#### Rating System (`Engine/Rating/`)
- **DUPRCalculator**: Static methods for SUPR rating calculations — expected score (Elo formula), actual score (margin-of-victory via tanh), rating change, reliability computation, K-factor tiers, auto-unrate detection.
- **RepCalculator**: Static methods for reputation change — win/loss base + SUPR gap scaling.

#### Loot Generation (`Engine/LootGeneration/`)
Procedural equipment generation system used for match loot drops and store inventory.

1. **LootGenerator**: Weighted rarity rolls with difficulty boosts, random stat bonuses with rarity-appropriate caps, ability generation for epic+ items, store inventory generation, set piece rolling (rare+ items), flavor text generation
2. **EquipmentNameGenerator**: Procedural names from prefix + base name pools per slot and rarity, flavor text generation from humor pools by slot/stat/rarity

### Services (`Services/`)
All services are protocol-based. Current implementations are in-memory mocks.

- **PlayerService**: CRUD for player data, stat allocation
- **MatchService**: Creates match engine instances (resolves equipped items, passes energy/SUPR gap), processes results (XP, coins, level-up rewards, DUPR rating, reputation, energy drain)
- **NPCService**: NPC catalog
- **InventoryService**: Equipment inventory management (add/remove/batch add/remove, equipped item resolution, condition updates)
- **StoreService**: Procedurally-generated shop items, buy/refresh

### ViewModels
- **MatchViewModel**: Async match flow with loot drops, level-up tracking, rated/unrated toggle, DUPR change, rep change, broken equipment, energy drain display
- **InventoryViewModel**: Load/filter/equip/unequip/sell with stat preview
- **StoreViewModel**: Store loading, purchasing, refreshing
- **PlayerProfileViewModel**: Stat allocation, effective stats with equipment

### Dependency Injection
`DependencyContainer` holds all service instances and is injected via `@EnvironmentObject`. `AppState` holds the current player and UI state, injected via `.environment()`.

**Service wiring**: MockMatchService receives InventoryService to resolve equipment UUIDs → actual Equipment objects before creating MatchEngine instances.

## Concurrency Model
- Swift 6 strict concurrency throughout
- `MatchEngine` is an `actor` — safe to run simulations concurrently
- Mutable service mocks use `actor` isolation
- ViewModels are `@MainActor` for UI thread safety
- `RandomSource` protocol enables deterministic testing via `SeededRandomSource`

## Data Flow: Match → Loot → Inventory → Rating
1. Player selects NPC opponent (rated/unrated toggle, auto-unrate if gap >1.0)
2. MatchService resolves equipped item UUIDs → Equipment via InventoryService
3. MatchEngine creates with player equipment, LootGenerator, and opponent difficulty
4. Engine simulates match, LootGenerator rolls loot in `buildResult()`
5. MatchResult includes loot drops; MatchViewModel surfaces them
6. On continue, MatchHubView processes rewards: XP/coins, loot → InventoryService, DUPR rating update, rep change, energy drain
7. If rated match: DUPRCalculator computes rating change from margin-of-victory; player's DUPRProfile updated
8. RepCalculator computes rep gain/loss based on SUPR gap; player's RepProfile updated
9. On loss: equipment durability applied to shoes/paddle; items at 0% condition break and are removed
10. On loss: persistent energy drained (higher for stronger opponents); recovers over real time
11. MatchHistoryEntry recorded with all outcome data
12. Loot appears in Inventory tab; equipped items affect future matches; history visible in Performance tab
