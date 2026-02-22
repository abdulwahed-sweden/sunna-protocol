# Burned M-Effort — Manager Effort Loss Concept

**Author:** Abdulwahed Mansour

---

## Overview

Burned M-Effort (Burned Manager Effort) is a core concept in the Sunna Protocol that
implements the Islamic finance principle of **Ghunm bil-Ghurm** — whoever gains must
also bear the risk of loss.

When a Mudaraba project results in a net loss, the manager (Mudarib) loses their
accumulated effort (JHD) for that project. This effort is permanently "burned."

---

## Mechanism

### When Does Burning Occur?

Burning occurs when a Mudaraba project is finalized with a **net negative return**:

```
IF project.netProfit < 0:
    manager.burnedJHD += project.managerJHD
    project.status = BURNED
```

The burn is triggered automatically by the `MudarabaEngine` during project settlement.

### What Gets Burned?

- All JHD accumulated by the manager on the specific failed project.
- Only effort on the failed project is affected — other projects remain intact.
- The burned amount is the full JHD balance for that project, not a partial amount.

### What Does NOT Happen?

- The manager is NOT financially penalized beyond effort loss.
- No tokens are slashed or confiscated.
- No reputation "penalty" is applied — the burn IS the consequence.

---

## Sharia Justification

In classical Mudaraba contracts:

- The **investor (Rabb al-Mal)** provides capital and bears financial loss.
- The **manager (Mudarib)** provides effort and bears effort loss.

This is the principle of **Ghunm bil-Ghurm**: the right to profit comes with the
obligation to share in loss. The Sunna Protocol enforces this digitally.

| Party     | Contributes | On Profit         | On Loss              |
|-----------|-------------|-------------------|----------------------|
| Investor  | Capital     | Profit share      | Capital loss         |
| Manager   | Effort      | Profit share      | Effort burned (JHD)  |

Burning is **not punitive**. It is the natural, agreed-upon consequence of a failed
venture. Just as the investor cannot recover lost capital from the manager, the manager
cannot recover burned effort from the investor.

---

## On-Chain Recording

Burned M-Effort is recorded permanently on the `SunnaLedger`:

```solidity
struct BurnRecord {
    uint256 projectId;
    address manager;
    uint256 burnedJHD;
    uint256 projectLoss;
    uint256 timestamp;
}
```

- Records are immutable once written.
- Any party can query a manager's burn history.
- Burn records are factored into the manager's lifetime efficiency score.

---

## Impact on Reputation

Burned M-Effort directly affects a manager's on-chain reputation:

- **Lifetime Efficiency** decreases because burned projects contribute zero profit
  but non-zero effort to the denominator.
- **Burn Ratio** = `Burned_JHD / Lifetime_JHD` — a high ratio signals higher risk.
- Investors can query these metrics before committing capital to a manager.

---

## Example

A manager runs two projects:

| Project | JHD  | Net Profit | Status  |
|---------|------|------------|---------|
| Alpha   | 200  | +$10,000   | Active  |
| Beta    | 150  | -$5,000    | Burned  |

- **Lifetime JHD:** 350
- **Burned JHD:** 150
- **Burn Ratio:** 150 / 350 = 42.8%
- **Lifetime Efficiency:** ($10,000 × 100) / 350 = 2,857

---

*Last updated: 2026-02-22*
