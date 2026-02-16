# PickleQuest Economy Design

## Currency: Coins

Coins are the primary in-game currency used for coaching, equipment repairs, consumables, and store purchases.

### Earning Coins

| Source | Amount | Notes |
|--------|--------|-------|
| Starting balance | 500 | New player starting coins |
| Rec matches | 0 | No coin rewards for regular ladder/rec games |
| Tournaments | TBD | Primary coin income source (future) |
| Wager matches | TBD | Risk/reward coin income (future) |
| Daily challenges | 50-200 each | Per-challenge reward |
| Daily challenge bonus | 500 | Completing all 3 daily challenges |

### Design Philosophy

Rec matches (court ladder, casual play) do not award coins. This keeps coins scarce and meaningful — players earn coins through tournaments and wagers, which carry higher stakes. XP and SUPR rating are the primary rewards for regular play.

---

## Coaching Fees

Coaching fees are based on realistic pickleball coaching rates. Coach level maps to real-world coach tiers.

### Fee Schedule

| Level | Coach Type | Fee | With Alpha Discount (50%) |
|-------|-----------|-----|---------------------------|
| 1 | Public court coach | $40 | $20 |
| 2 | Intermediate coach | $75 | $37 |
| 3 | Club head pro | $150 | $75 |
| 4 | Expert / touring pro | $500 | $250 |
| 5 | Master / elite coach | $1,500 | $750 |

- **Alpha discount**: Defeating the court alpha unlocks 50% off coaching at that court.
- **Coach energy**: Each coach has 100% energy per day, draining 20% per session (5 sessions max).
- **Player energy**: Training costs 15% player energy per session.

### Training Rewards

Stat gains scale with coach level (higher-tier coaches give disproportionately more per session):

| Level | Max Stat Gain | XP Earned | Cost per Stat Point |
|-------|--------------|-----------|---------------------|
| 1 | +2 | 50 | ~$20/pt |
| 2 | +3 | 100 | ~$25/pt |
| 3 | +4 | 150 | ~$38/pt |
| 4 | +6 | 200 | ~$83/pt |
| 5 | +8 | 250 | ~$188/pt |

- Stat gains are modified by `(playerEnergy% × coachEnergy%)` — training at low energy yields fewer points.
- Higher-level coaches cost more per point but require fewer sessions, saving player energy and real time.
- Coaching stat boosts are permanent and stack with equipment bonuses.

### Real-World Reference

| Tier | Real-World Rate | Game Fee |
|------|----------------|----------|
| Public court volunteer / rec coach | $40-$60/hr | $40 |
| Club instructor | $60-$100/hr | $75 |
| Club head pro / certified coach | $100-$200/hr | $150 |
| Touring pro / elite instructor | $300-$600/hr | $500 |
| Pro trainer / celebrity coach | $1,000-$3,000/hr | $1,500 |

---

## Equipment Economy

### Repair Costs (~30% of rarity base price)

| Rarity | Base Price | Repair Cost |
|--------|-----------|-------------|
| Common | 50 | 15 |
| Uncommon | 100 | 30 |
| Rare | 250 | 75 |
| Epic | 500 | 150 |
| Legendary | 1,000 | 300 |

### Durability

- Only paddles and shoes take wear damage.
- Win wear: flat 3% per match.
- Loss wear: 5% base + SUPR gap bonus (capped at 15% max per match).
- Equipment at 0% condition is broken and auto-unequipped.
