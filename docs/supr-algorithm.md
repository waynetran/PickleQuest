# SUPR Rating System

SUPR (internally "DUPR") is PickleQuest's performance-based player rating system. It uses a margin-of-victory Elo algorithm where score differential matters, not just win/loss.

## Rating Change Formula

```
ratingChange = K * (actualScore - expectedScore) / 200
```

### Expected Score

Standard Elo expected score scaled for the DUPR rating range:

```
expectedScore = 1 / (1 + 10^(gap / 400))
```

Where `gap = (opponentRating - playerRating) * 100`. The `100` factor converts the DUPR scale (2.0-8.0) to Elo-equivalent points (1.0 DUPR gap = 100 Elo).

- Equal ratings: expected = 0.50
- 0.5 DUPR higher: expected ≈ 0.43 (57% win chance for stronger)
- 1.0 DUPR higher: expected ≈ 0.36 (64% win chance for stronger)
- 2.0 DUPR higher: expected ≈ 0.24 (76% win chance for stronger)

### Actual Score

Normalized 0.0-1.0 from margin of victory using a tanh curve:

```
normalizedMargin = (playerPoints - opponentPoints) / pointsToWin
actualScore = 0.5 + tanh(normalizedMargin * 1.5) * 0.5
```

The `1.5` exponent controls curve steepness. Example values (game to 11):

| Score | Actual Score |
|-------|-------------|
| 11-2 (blowout win) | ~0.92 |
| 11-5 (solid win) | ~0.80 |
| 11-9 (close win) | ~0.63 |
| 9-11 (close loss) | ~0.37 |
| 5-11 (solid loss) | ~0.20 |
| 2-11 (blowout loss) | ~0.08 |

### Key Insight: Gain Rating on a Close Loss

Because `ratingChange = K * (actual - expected)`, if the actual score exceeds the expected score, you gain rating even in a loss. A 3.0-rated player losing 9-11 to a 4.5-rated player:
- expected ≈ 0.30 (they're expected to get crushed)
- actual ≈ 0.37 (they kept it close)
- change = positive

This incentivizes competitive play against strong opponents over farming weak NPCs.

### Divisor (200)

The `/200` divisor scales raw Elo changes to the DUPR range (2.0-8.0). This produces changes like:
- Blowout win vs equal (K=64): ~+0.13
- Close win vs equal (K=64): ~+0.04
- Close loss vs equal (K=64): ~-0.04
- Blowout loss vs weaker (K=64): ~-0.15

## K-Factor (Rating Volatility)

K-factor decreases as a player's rating becomes more established, determined by reliability:

| Reliability | K-Factor | Player Type |
|-------------|----------|-------------|
| < 0.3 | 64 | New player — rating converges quickly |
| 0.3 - 0.7 | 32 | Developing — moderate volatility |
| > 0.7 | 16 | Established — stable, small adjustments |

## Reliability (0.0 - 1.0)

Composite score from three weighted components:

```
reliability = depth * 0.4 + breadth * 0.3 + recency * 0.3
```

### Depth (40% weight)
Rated matches played, linearly scaling to 1.0 at 30 matches.

```
depth = min(1.0, matchCount / 30)
```

### Breadth (30% weight)
Unique opponents faced, linearly scaling to 1.0 at 15 unique opponents.

```
breadth = min(1.0, uniqueOpponents / 15)
```

### Recency (30% weight)
Days since last rated match. Full credit within 7 days, linear decay to 0.3 at 90+ days.

```
if daysSince <= 7:   recency = 1.0
if daysSince >= 90:  recency = 0.3
else:                recency = 1.0 - 0.7 * (daysSince - 7) / 83
```

No matches played: recency = 0.0.

## Constraints

| Constraint | Value |
|-----------|-------|
| Rating range | 2.00 - 8.00 |
| Starting state | NR (Not Rated) |
| Starting rating | 2.00 (once first rated match is played) |
| Auto-unrate threshold | > 1.0 rating gap |

### Auto-Unrate
Matches where the rating gap exceeds 1.0 are automatically unrated. This prevents:
- Farming weak NPCs to inflate rating
- Losing rating to vastly superior opponents

### NPC Ratings
NPCs have fixed DUPR ratings derived from their stat averages at creation time. Only the player's rating changes dynamically.

## Implementation

| File | Purpose |
|------|---------|
| `Models/Player/DUPRProfile.swift` | Stores rating, match count, unique opponents, last match date; computes reliability and K-factor |
| `Engine/Rating/DUPRCalculator.swift` | Static methods for expectedScore, actualScore, ratingChange, reliability, auto-unrate |
| `Models/Common/GameConstants.swift` | `DUPRRating` enum with all tuning constants |

## Tuning Constants

```swift
enum DUPRRating {
    // Rating bounds
    static let minRating = 2.00
    static let maxRating = 8.00
    static let startingRating = 2.00  // players start as NR until first rated match

    // K-factor tiers
    static let kFactorNew = 64.0         // reliability < 0.3
    static let kFactorDeveloping = 32.0  // reliability 0.3-0.7
    static let kFactorEstablished = 16.0 // reliability > 0.7

    // Reliability weights
    static let depthWeight = 0.4
    static let breadthWeight = 0.3
    static let recencyWeight = 0.3

    // Reliability thresholds
    static let depthMax = 30
    static let breadthMax = 15
    static let recencyFullDays = 7
    static let recencyDecayDays = 90
    static let recencyMinimum = 0.3

    // Margin-of-victory
    static let marginExponent = 1.5

    // Elo parameters
    static let eloScaleFactor = 400.0
    static let duprToEloScale = 100.0
    static let ratingChangeDivisor = 200.0

    // Auto-unrate
    static let maxRatedGap = 1.0
}
```
