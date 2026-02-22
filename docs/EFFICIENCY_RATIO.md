# Efficiency Ratio — Performance Measurement

**Author:** Abdulwahed Mansour

---

## Overview

The Efficiency Ratio is the primary performance metric for managers (Mudaribs) in the
Sunna Protocol. It measures how effectively a manager converts effort (JHD) into profit
for investors.

---

## Formula

```
Efficiency = (Net_Profit × 100) / Total_JHD
```

Where:
- `Net_Profit` is the realized profit in USD (or base asset denomination).
- `Total_JHD` is the total effort units accumulated by the manager.
- The result is expressed as profit-per-100-JHD.

---

## Per-Project Efficiency

Each Mudaraba project has its own efficiency calculation:

```
Project_Efficiency = (Project_Net_Profit × 100) / Project_JHD
```

- Profitable projects have positive efficiency.
- Failed (burned) projects have zero efficiency (profit is zero, effort is burned).

---

## Lifetime Efficiency

A manager's lifetime efficiency aggregates across all projects:

```
Lifetime_Efficiency = (Σ Net_Profit_i × 100) / Σ JHD_i
```

Where `i` spans all projects (including burned ones).

**Key property:** Burned projects reduce lifetime efficiency because they add JHD to
the denominator but contribute zero (or negative) profit to the numerator.

---

## Cross-Project Comparison

The Efficiency Ratio enables direct comparison between managers regardless of:

- Project size (normalized by effort, not capital).
- Project duration (effort is accumulated over time).
- Strategy type (all actions have defined JHD weights).

| Manager | Total JHD | Total Profit | Efficiency |
|---------|-----------|--------------|------------|
| Alice   | 500       | $25,000      | 5,000      |
| Bob     | 300       | $12,000      | 4,000      |
| Carol   | 800       | $20,000      | 2,500      |

Alice is the most efficient — she generates the most profit per unit of effort.

---

## Impact of Burned Projects

Burned projects significantly reduce a manager's efficiency score.

### Example: Manager with One Burn

| Project  | JHD  | Net Profit | Project Efficiency |
|----------|------|------------|--------------------|
| Alpha    | 200  | +$15,000   | 7,500              |
| Beta     | 300  | +$9,000    | 3,000              |
| Gamma    | 250  | -$8,000    | 0 (burned)         |

**Lifetime Efficiency** = (($15,000 + $9,000 + $0) × 100) / (200 + 300 + 250)

```
= ($24,000 × 100) / 750
= 3,200
```

Without the burned project Gamma:

```
= ($24,000 × 100) / 500
= 4,800
```

The burn reduced lifetime efficiency from 4,800 to 3,200 — a 33% decrease.

---

## Example: Two Managers Compared

**Manager X:**
- 3 projects, 0 burns, 400 total JHD, $20,000 total profit.
- Lifetime Efficiency: 5,000

**Manager Y:**
- 5 projects, 2 burns, 600 total JHD, $18,000 total profit.
- Lifetime Efficiency: 3,000

Despite running more projects, Manager Y's burns drag down their efficiency.
Investors can use this metric to make informed capital allocation decisions.

---

## On-Chain Access

Efficiency scores are computed and queryable via `SunnaLedger`:

```solidity
function getLifetimeEfficiency(address manager) external view returns (uint256);
function getProjectEfficiency(uint256 projectId) external view returns (uint256);
```

---

*Last updated: 2026-02-22*
