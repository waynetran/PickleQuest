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

- **Player**: identity, stats, progression, equipment slots, wallet
- **PlayerStats**: 10-stat system with DUPR mapping
- **Equipment**: 6 slots, 5 rarities, stat bonuses, triggered abilities (epic+)
- **Match types**: MatchConfig, MatchPoint, MatchEvent, MatchResult
- **NPC**: difficulty tiers, personality archetypes, dialogue
- **Economy**: Wallet, Consumable

### Engine (`Engine/MatchSimulation/`)
The match simulation engine runs as an `actor` and emits events via `AsyncStream<MatchEvent>`.

**Pipeline**: StatCalculator → FatigueModel → MomentumTracker → RallySimulator → PointResolver → MatchEngine

1. **StatCalculator**: Base stats + equipment bonuses (with diminishing returns) + fatigue penalties + momentum modifiers
2. **FatigueModel**: Energy drain per rally shot, thresholds at 70/50/30% with increasing stat penalties
3. **MomentumTracker**: Consecutive point streaks give +2% to +7% bonus; opponent streaks give -1% to -5% penalty
4. **RallySimulator**: Serve phase (ace check) → shot-by-shot rally resolution (winner/error/forced error checks per shot)
5. **PointResolver**: Orchestrates a single point combining all modifiers
6. **MatchEngine**: Runs full match loop (games → points), tracks stats, calculates rewards

### Services (`Services/`)
All services are protocol-based. Current implementations are in-memory mocks.

- **PlayerService**: CRUD for player data, stat allocation
- **MatchService**: Creates match engine instances, processes results
- **NPCService**: NPC catalog
- **InventoryService**: Equipment inventory management

### Dependency Injection
`DependencyContainer` holds all service instances and is injected via `@EnvironmentObject`. `AppState` holds the current player and UI state, injected via `.environment()`.

## Concurrency Model
- Swift 6 strict concurrency throughout
- `MatchEngine` is an `actor` — safe to run simulations concurrently
- Mutable service mocks use `actor` isolation
- ViewModels are `@MainActor` for UI thread safety
- `RandomSource` protocol enables deterministic testing via `SeededRandomSource`
