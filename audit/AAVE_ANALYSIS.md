# Aave V3/V4 — Invariant Analysis

**Author:** Abdulwahed Mansour

---

## Overview

This document analyzes the Asymmetric Deficit Socialization (ADS) vulnerability in
Aave V3 and V4. Aave represents the largest exposure in the ADS vulnerability class,
with an estimated **~$96M** at risk (97.3% of total ADS exposure).

---

## Fee Calculation During Loss Periods

Aave's reserve factor mechanism collects a percentage of all interest paid by borrowers.
This fee accrues to the protocol treasury regardless of the reserve's net position.

### The Problem

```
Interest Accrued = borrowRate × totalBorrows × timeDelta
Reserve Fee = Interest Accrued × reserveFactor

// Fee is collected even when:
// totalAssets(reserve) < totalDeposits(reserve) + accruedFees
```

When bad debt accumulates or underlying collateral depreciates, the reserve's actual
asset value may fall below its liabilities. However, the interest accrual and fee
extraction mechanism does not check this condition.

---

## Virtual Accounting Gap

Aave uses a virtual accounting model where:

- **aToken balance** represents a depositor's claim on the pool.
- **Scaled balance × liquidity index** determines the current value.
- **Liquidity index** only increases (it never decreases to reflect losses).

This creates a gap between what depositors believe they own (virtual balance) and what
the pool actually holds (real assets). The gap widens when:

1. Bad debt is generated (borrower liquidation shortfall).
2. Underlying assets depreciate.
3. Reserve fees continue to be extracted despite the gap.

```
Virtual Balance:  aToken holders think they have $100M
Real Assets:      Pool actually holds $96M
Extracted Fees:   $4M already sent to treasury
Gap:              $4M deficit socialized onto depositors
```

---

## Exposure Estimate

| Component              | Value          |
|------------------------|----------------|
| Aave V3 TVL            | ~$12B          |
| Average Reserve Factor | 10-20%         |
| Estimated Bad Debt      | ~$200M         |
| Fee Extraction on Gap  | ~$96M          |
| Share of Total ADS     | 97.3%          |

The $96M estimate is derived from analyzing fee extraction events during periods where
reserve health factors indicated underwater positions.

---

## Comparison with Sunna Protocol

| Aspect                    | Aave V3/V4                    | Sunna Protocol              |
|---------------------------|-------------------------------|-----------------------------|
| Fee extraction check      | None (always accrues)         | PY-1 blocks during loss     |
| Solvency validation       | Not enforced per-tx           | SE-1 enforced every tx      |
| Bad debt handling          | Socialized onto depositors    | SD-1 proportional sharing   |
| Virtual accounting         | Gap can grow silently         | Real-time solvency checks   |
| Fee escrow                | No (direct to treasury)       | TakafulBuffer holds fees    |
| Deficit detection          | Post-hoc governance action    | Automatic invariant revert  |

---

## Recommendations for Aave

1. **Solvency Check on Fee Accrual:** Add a check that reserve assets exceed
   liabilities before accruing reserve factor fees.
2. **Bad Debt Attribution:** Attribute bad debt proportionally to fee recipients,
   not exclusively to depositors.
3. **Fee Clawback Mechanism:** Allow governance to reclaim fees extracted during
   periods that are later identified as insolvent.
4. **Liquidity Index Correction:** Allow the liquidity index to decrease when
   real asset losses are detected, reflecting true depositor claims.

---

*Last updated: 2026-02-22*
