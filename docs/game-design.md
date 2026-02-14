# PickleQuest Game Design

## Concept
A Pokemon Go-like pickleball RPG where players physically explore their city to find opponents, collect equipment, train at real courts, and compete in tournaments. Matches are simulated point-by-point.

## Milestone Roadmap

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Foundation + Match Engine | **Complete** |
| 2 | Inventory, Equipment, Store, Leveling | **Complete** |
| 2.5 | SUPR Rating System | **Complete** |
| 3 | Map + Location + NPC World | Planned |
| 4 | SpriteKit Match Visualization | Planned |
| 5 | Doubles, Team Synergy, Tournaments | Planned |
| 6 | Training, Coaching, Energy + Economy | Planned |
| 7 | Persistence, Polish, Multiplayer Prep | Planned |

## 10-Stat System

Scale: 1-99, maps to DUPR 2.0-8.0

### Offensive
- **Power**: Affects serve speed, smash damage, ace chance
- **Accuracy**: Hit placement, winner chance, reduced errors
- **Spin**: Ball movement, makes shots harder to return
- **Speed**: Court coverage, ability to reach difficult shots

### Defensive
- **Defense**: Shot blocking, returning hard hits
- **Reflexes**: Reaction time, returning quick shots, ace defense
- **Positioning**: Court awareness, optimal placement

### Mental
- **Clutch**: Performance boost in close game situations
- **Stamina**: Reduces energy drain per rally shot
- **Consistency**: Reduces unforced error chance

## Equipment System

### Slots (6)
Paddle, Shirt, Shoes, Shorts, Eyewear, Wristband

### Rarities (5)
| Rarity | Max Stat Bonus | Has Ability | Drop Rate |
|--------|---------------|-------------|-----------|
| Common | +5 | No | 45% |
| Uncommon | +10 | No | 30% |
| Rare | +15 | No | 15% |
| Epic | +20 | Yes | 8% |
| Legendary | +25 | Yes | 2% |

### Diminishing Returns
- Linear scaling below 60
- 0.7x scaling 60-80
- 0.4x scaling 80+
- Hard cap at 99

### Abilities (Epic+ only)
Triggered on: serve, match point, 3-point streak, low energy, clutch situation
Effects: stat boost (temporary), energy restore, momentum boost

## Loot System (Milestone 2)

### Match Drops
- Win: guaranteed 1 equipment drop
- Loss: 30% chance of 1 drop
- Higher difficulty opponents boost rare+ drop rates (beginner +0%, master +25%)

### Stat Bonuses per Rarity
| Rarity | Bonus Stats | Range |
|--------|------------|-------|
| Common | 1-2 | distributed across max 5 |
| Uncommon | 1-3 | distributed across max 10 |
| Rare | 2-3 | distributed across max 15 |
| Epic | 2-4 | distributed across max 20 |
| Legendary | 3-4 | distributed across max 25 |

### Procedural Naming
Each item gets a rarity-appropriate prefix + slot-appropriate base name (e.g., "Elite Court Shoes", "Champion's Blade").

## Store System (Milestone 2)

- 8 items per stock rotation
- Weighted rarity: Common 30%, Uncommon 35%, Rare 20%, Epic 12%, Legendary 3%
- Prices scale with rarity (50-100 common, up to 1000-2500 legendary)
- Refresh costs 50 coins and generates new stock
- Purchased items marked as sold out until refresh

## Match Simulation

### Point Resolution Flow
1. **Serve Phase**: Ace check (power vs reflexes)
2. **Rally Phase**: Shot-by-shot (winner/unforced error/forced error checks)
3. **Clutch Modifier**: Bonus from clutch stat in close games

### Momentum System
- 2+ consecutive points: +2% to +7% bonus (scaling with streak)
- Opponent on streak: -1% to -5% penalty
- Resets between games

### Fatigue System
- 100% starting energy, drains per rally shot
- Stamina stat reduces drain rate
- Thresholds: 70% (-3% stats), 50% (-8%), 30% (-15%)
- Rest between games restores 10%

### Equipment in Matches
- Equipped items resolved from UUID → Equipment at match creation time
- StatCalculator applies equipment bonuses with diminishing returns
- LootGenerator injected into MatchEngine; loot generated in buildResult()

## NPC Difficulty Tiers
| Tier | Stat Range | Reward Multiplier |
|------|-----------|-------------------|
| Beginner | ~10-15 avg | 1.0x |
| Intermediate | ~15-25 avg | 1.5x |
| Advanced | ~20-30 avg | 2.0x |
| Expert | ~30-40 avg | 3.0x |
| Master | ~40-50 avg | 5.0x |

## Economy
- Starting coins: 500
- Match win: 100 base + difficulty bonus
- Match loss: 25 base
- XP per match: 50 base + 30 win bonus
- Level-up: exponential curve (base 100, growth 1.3x), 3 stat points per level
- Equipment sell prices: 15-600+ base (scales with rarity + bonus value)

## Leveling & Stat Allocation (Milestone 2)
- Each level-up grants 3 stat points
- Points allocated manually to any of the 10 stats
- Profile shows base stats vs effective stats (with equipment bonuses)
- Stat allocation available from Profile view when points are available

## SUPR Rating System (Milestone 2.5)

Performance-based rating using margin-of-victory Elo. See [docs/supr-algorithm.md](supr-algorithm.md) for full details.

### Key Properties
- **Range**: 2.00 - 8.00, starting as NR (Not Rated) at 2.00
- **Margin matters**: Score differential determines rating change, not just win/loss
- **Close loss to stronger opponent can gain rating**: Incentivizes competitive play
- **Reliability system**: K-factor (64 → 32 → 16) decreases as match depth/breadth/recency improve
- **Rated vs unrated**: Toggle on NPC picker; auto-unrate if rating gap > 1.0
- **NPCs have fixed ratings**: Only the player's SUPR changes dynamically

### UI Surfaces
- **Profile**: SUPR score with reliability progress bar
- **NPC Picker**: Opponent SUPR scores, rated/unrated toggle, auto-unrate warning
- **Match Results**: SUPR change badge (+0.05 green / -0.03 red / "Unrated" gray)
- **Match Hub**: SUPR score displayed on idle screen
