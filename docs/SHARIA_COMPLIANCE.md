# Sunna Protocol — Sharia Compliance

**Author:** Abdulwahed Mansour

---

## Core Sharia Principles

The Sunna Protocol is designed from the ground up to comply with Islamic finance
principles. Every contract and mechanism maps to a specific Sharia requirement.

### 1. No Riba (Interest / Usury)

Riba is the charging or receiving of interest, which is strictly prohibited in Islam.

- The protocol does not generate yield through lending at interest.
- All returns are derived from profit-sharing (Mudaraba) arrangements.
- Fee structures are based on realized profit, never on principal amounts.
- No code path in any Sunna contract can produce a guaranteed fixed return.

### 2. No Gharar (Excessive Uncertainty)

Gharar refers to excessive uncertainty or ambiguity in contract terms.

- All contract parameters are transparent and immutable once deployed.
- Oracle data is validated for freshness via `OracleValidator`.
- Yield calculations use only realized (not speculative) values.
- Profit-sharing ratios are disclosed and locked at project creation.

### 3. No Maysir (Gambling / Speculation)

Maysir is any transaction where the outcome depends purely on chance.

- No lottery mechanics or random reward distributions.
- Returns are proportional to capital contribution and verified effort (JHD).
- All investment outcomes are tied to real economic activity.

---

## Ghunm bil-Ghurm — Gain with Risk

The principle of Ghunm bil-Ghurm states: **"whoever gains must also bear the loss."**

This is enforced mathematically by the `MudarabaEngine`:

```
Profit Case:  P = max(0, B_final - Capital)
              Funder  = Capital + (P × funderBps / 10000)
              Manager = (P × managerBps / 10000)

Loss Case:    Funder  = B_final  (bears material loss)
              Manager = 0        (bears effort loss — Burned M-Effort)
```

| Role            | Gain                  | Loss                    |
|-----------------|-----------------------|-------------------------|
| Investor        | Share of net profit   | Loss of capital         |
| Manager         | Share of net profit   | Loss of effort (JHD)   |

- When a project profits, both parties share the gains per agreed ratio.
- When a project fails, the investor loses capital and the manager loses effort.
- The manager's lost effort is recorded as "Burned M-Effort" on-chain.
- Neither party can externalize their loss onto the other — by construction.

---

## Halal Whitelist Enforcement

The `ShariaGuard` contract maintains a whitelist of approved assets and protocols.

- Only tokens and protocols on the whitelist can interact with Sunna contracts.
- Adding to the whitelist requires governance approval and Sharia review.
- Removal from the whitelist is immediate upon detection of non-compliance.

**Criteria for whitelist inclusion:**
1. No interest-based revenue model.
2. No gambling or speculative mechanics.
3. Transparent and auditable smart contracts.
4. Underlying assets must be halal.

---

## The Living Sharia Document

Traditional Sharia compliance relies on paper fatwas and periodic reviews. These are
static documents that can become outdated and are difficult to verify.

**Sunna Protocol introduces a fundamentally different approach: the smart contract
itself IS the Sharia document.**

`ShariaGuard.sol` is not a paper certificate — it is executable Sharia law:

- **Scholars review the code directly**, not a summary of intentions.
- **Compliance is verified in real-time** on every transaction, not quarterly.
- **Violations are impossible**, not merely discouraged — non-compliant transactions
  revert automatically before execution.
- **The audit trail is permanent** and publicly verifiable on the blockchain.

This means that when an Islamic institution evaluates Sunna Protocol, they examine
`ShariaGuard.sol` and can mathematically verify that:
- No code path produces Riba (guaranteed return).
- No code path permits Gharar (hidden terms or speculative pricing).
- No code path allows Maysir (chance-based distributions).
- Ghunm bil-Ghurm is enforced in every settlement via `MudarabaEngine`.

**The code does not describe compliance. The code IS compliance.**

---

## Sharia-to-Contract Mapping

| Sharia Principle     | Contract / Module     | Mechanism                      |
|----------------------|-----------------------|--------------------------------|
| No Riba              | FeeController         | Profit-only fee extraction     |
| No Gharar            | OracleValidator       | Stale data rejection           |
| No Maysir            | MudarabaEngine        | Effort-based returns           |
| Ghunm bil-Ghurm      | MudarabaEngine        | Burned M-Effort on loss        |
| Halal Assets         | ShariaGuard           | Whitelist enforcement          |
| Fair Distribution    | TakafulBuffer         | Proportional fee sharing       |
| Capital Preservation | SolvencyGuard         | SE-1 invariant enforcement     |
| Transparency         | SunnaLedger           | Immutable on-chain JHD records |

---

## Compliance Verification Process

For institutions seeking Sharia certification of Sunna Protocol:

1. **Code Review:** Scholars examine `ShariaGuard.sol`, `MudarabaEngine.sol`, and
   `FeeController.sol` source code directly.
2. **Invariant Verification:** Mathematical proof that SE-1 through DFB-1 hold under
   all reachable states (formal verification reports provided).
3. **Test Suite Review:** 256+ fuzz test scenarios demonstrating no-fee-on-loss
   invariant holds under randomized conditions.
4. **Deployment Verification:** Deployed bytecode matches audited source code
   (verified via blockchain explorer).

---

*Last updated: 2026-02-22*
