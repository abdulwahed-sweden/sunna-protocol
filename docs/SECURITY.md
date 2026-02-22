# Sunna Protocol — Security Model

**Author:** Abdulwahed Mansour

---

## Overview

The Sunna Protocol's security model is built on defense-in-depth. Multiple independent
layers of protection ensure that no single vulnerability can compromise the protocol.

---

## Threat Model

### 1. Reentrancy Attacks

**Threat:** A malicious contract re-enters a Sunna function during execution to
manipulate state before the original call completes.

**Mitigation:**
- All state-changing functions use OpenZeppelin's `ReentrancyGuard`.
- Checks-Effects-Interactions (CEI) pattern enforced across all contracts.
- External calls are made only after all state updates are finalized.

### 2. Oracle Manipulation

**Threat:** An attacker manipulates oracle price feeds to inflate asset valuations,
triggering phantom yield extraction.

**Mitigation:**
- `OracleValidator` rejects price data older than a configurable staleness threshold.
- Round completeness check: `answeredInRound >= roundId` prevents stale round data.
- Multi-oracle aggregation where available (Chainlink, Pyth, TWAP).
- Price deviation checks reject updates that exceed reasonable bounds.
- SolvencyGuard re-validates after every oracle update.

### 3. Phantom Yield Extraction (ADS)

**Threat:** Fees are extracted based on unrealized gains while the protocol carries
unrealized losses. This is the Asymmetric Deficit Socialization (ADS) vulnerability
discovered by Abdulwahed Mansour across major DeFi protocols ($98.6M+ exposure).

**Mitigation:**
- `FeeController` enforces PY-1: `ΔTreasury ≡ 0 IF ΔLoss > 0`.
- `TakafulBuffer` holds fees in escrow until solvency is confirmed.
- `SolvencyGuard` blocks any withdrawal that would violate SE-1.
- `reportLoss()` function physically cannot mint fees — by construction.

### 4. Governance Attacks

**Threat:** A malicious governance proposal attempts to disable safety invariants.

**Mitigation:**
- `ConstitutionalGuard` makes invariants SE-1 through DFB-1 immutable.
- No governance proposal can modify or bypass constitutional checks.
- Time-lock on all proposals allows community review.
- $HELAL governance is bounded: can adjust parameters, cannot touch invariants.

### 5. Flash Loan Exploits

**Threat:** An attacker uses flash loans to temporarily inflate balances and extract
value within a single transaction.

**Mitigation:**
- Share price calculations use time-weighted averages, not spot values.
- Deposit and withdrawal in the same block are restricted.
- SolvencyGuard validates state before AND after every operation.

### 6. Precision Loss Attacks

**Threat:** Exploiting integer division rounding to steal fractional amounts over
many transactions (dust attacks, off-by-one exploits).

**Mitigation:**
- All financial calculations use multiply-before-divide ordering.
- Boundary comparisons use `>=` (not `>`) to prevent off-by-one rejections.
- `SunnaMath` library provides safe arithmetic operations with explicit rounding.
- Fuzz testing with edge-case values (0, 1, type(uint256).max).

### 7. Stale Data Exploitation

**Threat:** Using outdated oracle prices to execute trades or settlements at
advantageous but incorrect prices. Discovered in Moonwell audit by Abdulwahed Mansour.

**Mitigation:**
- `OracleValidator` checks `answeredInRound`, `updatedAt`, and price positivity.
- Configurable staleness threshold (default: 1 hour).
- Zero and negative prices are rejected immediately.

---

## Audit Readiness Checklist

| Item                                  | Status       | Notes                          |
|---------------------------------------|--------------|--------------------------------|
| Six invariants formally specified     | Complete     | See INVARIANTS.md              |
| Unit test suite                       | Complete     | Per-contract coverage          |
| Fuzz testing suite (Foundry)          | Complete     | 256+ runs per function         |
| Invariant-based fuzz testing          | Complete     | SE-1 and PY-1 property tests   |
| Static analysis (Slither)             | Planned      | Pre-audit phase                |
| Symbolic execution (Halmos/Certora)   | Planned      | Pre-audit phase                |
| External security audit               | Planned      | Trail of Bits / Spearbit       |
| Bug bounty program                    | Planned      | Post-mainnet via Immunefi      |
| Incident response plan                | Documented   | See below                      |

---

## Invariant Testing Strategy

### Unit Testing
- Each invariant has dedicated test cases for normal, edge, and failure scenarios.
- Tests verify that violating transactions revert with the correct custom error.
- Boundary conditions tested: zero values, maximum uint256, exact-equality cases.

### Fuzz Testing
- Foundry fuzz tests with randomized inputs for all public functions.
- Invariant-based fuzzing that checks SE-1 through DFB-1 after every action sequence.
- Minimum 256 runs per fuzz test (10,000+ for critical financial paths).
- Special attention to precision loss scenarios (odd numbers, small amounts).

### Integration Testing
- Multi-contract scenarios simulating real user flows.
- Adversarial scenarios testing all attack vectors listed in the threat model.
- End-to-end Mudaraba lifecycle tests (creation → effort recording → settlement/burn).
- Oracle failure scenarios (stale data, zero price, negative price, round mismatch).

### Formal Verification (Planned)
- Symbolic execution of SolvencyGuard and FeeController critical paths.
- Proof that SE-1 and PY-1 hold under all reachable states.
- Property: `reportLoss()` can never result in fee share minting.
- Property: JHD balance is monotonically non-decreasing per manager.

---

## Incident Response Plan

1. **Detection:** On-chain monitoring for invariant violations via event listeners.
2. **Assessment:** Severity classification (Critical / High / Medium / Low).
3. **Containment:** Emergency pause via ConstitutionalGuard (if applicable).
4. **Communication:** Immediate disclosure to $HELAL governance and affected users.
5. **Resolution:** Deploy fix through Sunna Shield adapter or governance proposal.
6. **Post-mortem:** Public report with root cause analysis and prevention measures.

---

*Last updated: 2026-02-22*
