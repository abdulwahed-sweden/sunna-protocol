# Sunna Protocol — System Architecture

**Author:** Abdulwahed Mansour

---

## Overview

The Sunna Protocol is a Sharia-compliant DeFi framework built on a 4-layer architecture.
Each layer enforces a distinct set of responsibilities, ensuring that Islamic finance
principles are upheld at every level of the protocol stack.

| Layer | Name              | Responsibility                          |
|-------|-------------------|-----------------------------------------|
| 1     | Sunna Core        | Invariant enforcement and fee control   |
| 2     | Sunna Shield      | ERC-4626 adapter for external protocols |
| 3     | Sunna Mudaraba    | Profit-loss sharing engine              |
| 4     | HELAL Governance  | On-chain governance (bounded)           |

---

## Layer 1 — Sunna Core

The foundational layer that guarantees protocol-wide invariants.

- **SolvencyGuard (SE-1):** Enforces `totalAssets >= totalLiabilities` at all times.
  Every state-changing function passes through this guard before and after execution.
- **ShariaGuard:** Maintains a halal whitelist of approved assets and protocols.
  Any interaction with a non-whitelisted address reverts immediately.
- **TakafulBuffer:** A fee escrow mechanism that holds collected fees in a buffer
  before distribution. Fees are only released when solvency is confirmed.
- **FeeController (PY-1):** Prevents phantom yield by blocking fee extraction when
  unrealized losses exist. Implements `ΔTreasury ≡ 0 IF ΔLoss > 0`.
- **ConstitutionalGuard:** Immutable protection layer that cannot be overridden by
  governance. Hardcodes invariants SE-1, PY-1, SD-1, CLA-1, CHC-1, and DFB-1.

---

## Layer 2 — Sunna Shield

An ERC-4626 compatible adapter that wraps existing DeFi protocols (e.g., Aave, Morpho)
and applies Sunna Core invariants on top. This allows users to interact with external
yield sources while maintaining Sharia compliance and solvency guarantees.

- Accepts deposits via standard ERC-4626 `deposit()` / `withdraw()`.
- Routes capital to underlying protocols through ShariaGuard-approved vaults.
- Intercepts fee distributions via FeeController before passing yield to users.

---

## Layer 3 — Sunna Mudaraba

The profit-loss sharing engine implementing classical Islamic Mudaraba contracts.

- **MudarabaEngine:** Orchestrates the relationship between capital providers (Rabb al-Mal)
  and managers (Mudarib). Enforces Ghunm bil-Ghurm — who gains must bear loss.
- **SunnaLedger:** Records all JHD (effort units) on-chain. Tracks manager contributions,
  burned effort, and lifetime efficiency scores.
- **SunnaVault:** Capital custody contract. Holds investor funds and enforces withdrawal
  conditions based on project status and solvency checks.
- **SunnaShares:** ERC-20 investment share tokens representing proportional ownership
  in a Mudaraba project.
- **OracleValidator:** Validates oracle data freshness and rejects stale price feeds.
  Prevents phantom yield from propagating through outdated valuations.

---

## Layer 4 — HELAL Governance

HELAL is the governance token of the Sunna Protocol.

- Token holders can vote on protocol parameters (fee rates, whitelist additions).
- **Constitutional Boundary:** Governance CANNOT override invariants protected by
  ConstitutionalGuard. No vote can disable SE-1, PY-1, or any core invariant.
- Proposals require quorum and time-lock before execution.

---

## Contract Dependency Graph

```
┌─────────────────────────────────────────────────┐
│              HELAL Governance (L4)               │
│         [propose, vote, execute]                 │
└──────────────────┬──────────────────────────────┘
                   │ bounded by
┌──────────────────▼──────────────────────────────┐
│              Sunna Mudaraba (L3)                 │
│  MudarabaEngine ─► SunnaLedger                  │
│       │                │                         │
│  SunnaVault ◄──── SunnaShares                   │
│       │                                          │
│  OracleValidator                                 │
└──────────────────┬──────────────────────────────┘
                   │ routes through
┌──────────────────▼──────────────────────────────┐
│              Sunna Shield (L2)                   │
│         [ERC-4626 Adapter Layer]                 │
└──────────────────┬──────────────────────────────┘
                   │ enforced by
┌──────────────────▼──────────────────────────────┐
│              Sunna Core (L1)                     │
│  SolvencyGuard ── FeeController                  │
│       │               │                          │
│  ShariaGuard ──── TakafulBuffer                  │
│       │                                          │
│  ConstitutionalGuard (immutable)                 │
└─────────────────────────────────────────────────┘
```

---

*Last updated: 2026-02-22*
