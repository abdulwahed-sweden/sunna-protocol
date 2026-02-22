# Sunna Protocol — Regulatory Compliance

**Author:** Abdulwahed Mansour

---

## Overview

The Sunna Protocol is designed to align with international financial reporting standards
and regulatory frameworks. This document maps protocol mechanisms to specific regulatory
requirements.

---

## IFRS 15 — Revenue from Contracts with Customers

IFRS 15 requires revenue to be recognized only when performance obligations are satisfied
and consideration is received or receivable.

**Sunna Protocol Alignment:**

- Revenue (fees) are recognized only on **realized profit**, never on unrealized gains.
- The `FeeController` enforces PY-1: no fee extraction when losses exist.
- `TakafulBuffer` holds fees in escrow until solvency is confirmed, ensuring revenue
  is only recognized when the obligation (capital preservation) is met.

---

## US GAAP — ASC 606

ASC 606 mirrors IFRS 15 in requiring a five-step revenue recognition model.

**Sunna Protocol Alignment:**

| ASC 606 Step                          | Protocol Mechanism                     |
|---------------------------------------|----------------------------------------|
| 1. Identify the contract              | Mudaraba project creation              |
| 2. Identify performance obligations   | Capital deployment + management effort |
| 3. Determine transaction price        | Agreed profit-sharing ratio            |
| 4. Allocate to obligations            | FeeController allocation               |
| 5. Recognize on satisfaction          | Realized profit check via PY-1         |

---

## Basel III — Capital Adequacy

Basel III establishes minimum capital requirements to ensure financial institutions
can absorb losses.

**Sunna Protocol Alignment:**

- `SolvencyGuard` enforces SE-1: `totalAssets >= totalLiabilities` at all times.
- `TakafulBuffer` acts as a capital conservation buffer, holding fees before release.
- `DFB-1` ensures the deficit can never exceed total protocol assets, preventing
  unbounded negative equity.
- Real-time on-chain verification replaces periodic reporting.

---

## AAOIFI — Accounting and Auditing Organization for Islamic Financial Institutions

AAOIFI sets Sharia standards for Islamic finance products.

### Sharia Standard No. 12 — Mudaraba

Standard No. 12 governs Mudaraba (profit-sharing) contracts.

| AAOIFI Requirement                     | Protocol Implementation                |
|----------------------------------------|----------------------------------------|
| Capital must be known and delivered     | `SunnaVault` holds and tracks capital  |
| Profit ratio must be agreed upfront    | Set at project creation, immutable     |
| Loss borne by capital provider         | Investor absorbs capital loss          |
| Manager loses effort on failure        | Burned M-Effort via `SunnaLedger`      |
| Capital cannot be guaranteed           | No principal guarantee mechanism       |

### Sharia Standard No. 13 — Musharaka

Standard No. 13 governs partnership contracts where multiple parties contribute capital.

| AAOIFI Requirement                     | Protocol Implementation                |
|----------------------------------------|----------------------------------------|
| Partners share profit per agreement    | `SunnaShares` proportional allocation  |
| Loss shared by capital contribution    | SD-1 proportional deficit sharing      |
| Transparent accounting                 | On-chain `SunnaLedger` records         |
| Right to participate in management     | HELAL governance voting                |

---

## Compliance Summary

| Framework     | Key Requirement            | Sunna Mechanism         | Status   |
|---------------|----------------------------|-------------------------|----------|
| IFRS 15       | Realized revenue only      | PY-1 + FeeController    | Aligned  |
| ASC 606       | Five-step recognition      | MudarabaEngine pipeline | Aligned  |
| Basel III     | Capital adequacy           | SE-1 + SolvencyGuard    | Aligned  |
| AAOIFI No. 12 | Mudaraba structure         | MudarabaEngine          | Aligned  |
| AAOIFI No. 13 | Musharaka partnership      | SunnaShares + SD-1      | Aligned  |

---

*Last updated: 2026-02-22*
