# Sunna Protocol — Mathematical Invariants

**Author:** Abdulwahed Mansour

---

## Overview

The Sunna Protocol enforces six mathematical invariants that are protected by the
ConstitutionalGuard. These invariants cannot be overridden by governance and are
checked on every state-changing transaction.

---

## SE-1: Solvency Equilibrium

**Formal Definition:**

```
∀t: totalAssets(t) ≥ totalLiabilities(t)
```

At every point in time `t`, the total assets held by the protocol must be greater than
or equal to the total liabilities owed to depositors. If this invariant would be violated
by a transaction, the transaction reverts.

**Enforced by:** `SolvencyGuard`

---

## PY-1: Phantom Yield Prevention

**Formal Definition:**

```
ΔTreasury ≡ 0  IF  ΔLoss > 0
```

No fees may be extracted from the protocol when unrealized losses exist. The treasury
balance change must be zero whenever the protocol is experiencing a loss delta. This
prevents fee recipients from profiting while depositors bear losses.

**Enforced by:** `FeeController`

---

## SD-1: Shared Deficit

**Formal Definition:**

```
∀i ∈ FeeRecipients: Loss_i = Loss_total × (Fee_i / Fee_total)
```

When a deficit occurs, all fee recipients share the loss proportionally to their fee
allocation. No single party can externalize losses onto others.

**Enforced by:** `TakafulBuffer`

---

## CLA-1: Claimable Yield Authenticity

**Formal Definition:**

```
∀u: claimableYield(u) ≤ realizedProfit(u)
```

For every user `u`, the yield they can claim must be less than or equal to the realized
(not unrealized) profit attributable to their position. This prevents distribution of
paper gains that may later reverse.

**Enforced by:** `MudarabaEngine`, `FeeController`

---

## CHC-1: Conservation of Holdings

**Formal Definition:**

```
totalDeposits = Σ(deposit_i)  for all i ∈ Users
```

The sum of all individual deposit records must equal the protocol's total deposit
accounting. No tokens may be created or destroyed outside of defined mint/burn paths.

**Enforced by:** `SunnaVault`, `SunnaShares`

---

## DFB-1: Deficit Floor Bound

**Formal Definition:**

```
deficit ≤ totalProtocolAssets
```

The protocol's deficit can never exceed the total assets under management. This ensures
the protocol cannot enter a state of unbounded negative equity.

**Enforced by:** `SolvencyGuard`, `ConstitutionalGuard`

---

## Invariant Testing Strategy

Each invariant is tested via:

1. **Unit tests:** Isolated contract-level checks.
2. **Fuzz tests:** Randomized inputs to stress-test boundary conditions.
3. **Formal verification:** Symbolic execution of critical paths.
4. **Integration tests:** Multi-contract interaction scenarios.

---

*Last updated: 2026-02-22*
