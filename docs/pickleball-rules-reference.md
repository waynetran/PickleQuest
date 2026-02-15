# Pickleball Rules Reference

Reference for PickleQuest match simulation and visual representation.

## Court Dimensions

- **Full court**: 20ft wide x 44ft long
- **Each half**: 22ft deep (net to baseline)
- **Kitchen (NVZ)**: 7ft from net on each side (7/22 = 0.318 ratio)
- **Service boxes**: 15ft deep (kitchen line to baseline), 10ft wide each (split by centerline)
- **Net height**: 36in at sidelines, 34in at center
- **Centerline**: Only in service areas (kitchen line → baseline), NOT through kitchen

## Scoring

### Singles
- Two numbers: server score - receiver score (e.g., "3-2")
- Games to 11, win by 2
- Only server can score
- One serve per side-out (lose rally → opponent serves)

### Doubles
- Three numbers: serving team - receiving team - server number (e.g., "4-2-1")
- Both players serve before side-out (except game start: only Server 2 serves → "0-0-2")
- When scoring, server and partner swap sides
- After side-out, server numbers reset by court position (right = Server 1)

## Serving Rules

- **Underhand** with upward arc, contact below waist
- Server must have **at least one foot behind baseline** — cannot touch baseline or court
- Serve is **diagonal/cross-court** into opponent's service box
- Ball must clear kitchen and kitchen line
- **Even score** → serve from right/even side
- **Odd score** → serve from left/odd side
- 10-second serve clock

## Two-Bounce Rule

1. Serve must bounce before receiver hits it
2. Return of serve must bounce before server hits it (third shot)
3. After both bounces, either side may volley or groundstroke

**Implication**: Server is forced to stay near baseline for the third shot, giving receiver the advantage to approach the kitchen line first.

## Kitchen / Non-Volley Zone (NVZ)

- Cannot volley while touching the kitchen or kitchen line
- May enter kitchen at any time — just can't volley there
- **Momentum rule**: if volley momentum carries you into kitchen, it's a fault (even after ball is dead)
- Can hit balls that have bounced in the kitchen (dinks, groundstrokes)

## Player Positioning by Phase

### Singles

| Phase | Server | Returner |
|-------|--------|----------|
| Serve | Behind baseline, R/L by score | Diagonal box, near baseline |
| After serve | Stays near baseline (two-bounce) | Advances toward kitchen |
| Third shot | Near baseline, drive or drop | Approaching/at kitchen line |
| Rally | Transitioning forward | At kitchen line |

### Doubles

| Phase | Serving Team | Receiving Team |
|-------|-------------|----------------|
| Serve | Server behind baseline; partner at NVZ or baseline | Returner near baseline; partner at NVZ line |
| After serve | Both near baseline (two-bounce) | Returner advances; partner already at NVZ |
| Third shot | Server hits drop/drive from baseline; partner advancing | Both at/near kitchen line |
| Rally | Both working to reach kitchen line | Both at kitchen line; dinking |

## Key Strategy

### Singles
- **Return and rush**: returner hits deep return, immediately advances to kitchen line
- **Third shot**: server's most important decision — drive, drop, or lob
- **Kitchen line control**: player at kitchen line wins majority of rallies
- **Drives more effective** than in doubles (more open court for passing shots)
- **More physical**: covering full court alone, faster fatigue

### Doubles
- **Get both to kitchen**: the team that controls the kitchen line wins ~65% of points
- **Third shot drop**: soft shot into opponents' kitchen, allows serving team to advance
- **Move as a unit**: maintain ~10ft spacing, slide laterally together
- **Attack the middle**: creates confusion, reduces angles
- **Dinking battles**: soft exchanges at kitchen line, waiting for pop-up to attack

## Simulation Implications

- **Serving team disadvantage**: two-bounce rule means receiver gets to kitchen first
- **Third shot is pivotal**: quality determines whether server can equalize
- **Kitchen line = winning position**: heavily weight this in point probability
- **Singles rallies shorter** but more explosive than doubles
- **Stamina drains faster** in singles (more court to cover)
- **Score parity determines serve side** (even=right, odd=left) — affects serve diagonal
