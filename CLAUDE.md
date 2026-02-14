# PickleQuest - Project Instructions

## Overview
PickleQuest is a Pokemon Go-like pickleball RPG for iOS 18+. Players explore their city to find opponents, collect equipment, train at real courts, and compete in tournaments. Matches are simulated point-by-point using a probability engine.

## Tech Stack
- **Language**: Swift 6 (strict concurrency)
- **UI**: SwiftUI + SpriteKit (future milestone)
- **Architecture**: MVVM + Services
- **Data**: Local-only mock data (protocol-based services for future backend)
- **Target**: iOS 18+
- **Package Manager**: SPM (when dependencies are needed)
- **Project Generation**: XcodeGen (`project.yml` → `xcodegen generate`)

## Project Structure
```
PickleQuest/
├── App/              # @main entry, AppState, DI container
├── Models/           # Pure data models (Player, Equipment, Match, NPC, Economy)
├── Engine/           # Match simulation engine (point-by-point probability system)
├── Services/         # Protocol-based services
│   ├── Protocols/    # Service interfaces
│   └── Mock/         # In-memory mock implementations
├── ViewModels/       # @Observable view models
├── Views/            # SwiftUI views organized by feature
├── Extensions/       # Small utilities
└── Resources/        # Assets, mock data JSON
```

## Key Conventions

### Architecture
- All services are **protocol-based** — define interface in `Services/Protocols/`, implement in `Services/Mock/`
- ViewModels use `@Observable` macro (not ObservableObject)
- AppState is `@Observable` and passed via `.environment()`
- DependencyContainer is `@StateObject` passed via `.environmentObject()`
- Match engine is an `actor` emitting events via `AsyncStream`

### Swift Concurrency
- Swift 6 strict concurrency is enabled (`SWIFT_STRICT_CONCURRENCY: complete`)
- All models are `Sendable`
- Services that hold mutable state are `actor`s
- Use `@MainActor` for ViewModels and UI-facing code

### Game Design
- **10-stat system** (1-99 scale): power, accuracy, spin, speed, defense, reflexes, positioning, clutch, stamina, consistency
- **DUPR mapping**: stat average 1-99 maps to DUPR 2.0-8.0
- **Equipment**: 6 slots, 5 rarities, diminishing returns soft cap (linear <60, 0.7x 60-80, 0.4x 80+, hard cap 99)
- **Match engine**: serve phase → rally phase → clutch modifier; momentum streaks; fatigue drain
- All tuning constants live in `GameConstants.swift`

### Testing
- Use Swift Testing framework (`import Testing`, `@Test`, `@Suite`, `#expect`)
- Test files mirror source structure under `PickleQuestTests/`
- Match engine tests validate probability distributions over many simulations

### Build
- Regenerate Xcode project: `xcodegen generate`
- Build: `xcodebuild -project PickleQuest.xcodeproj -scheme PickleQuest -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Test: same command with `test` instead of `build`

## Git Conventions
- No Claude/Anthropic attribution in commits
- Commit at each milestone completion
- Keep `docs/` updated with architecture and design decisions
