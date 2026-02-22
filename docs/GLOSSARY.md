# Sunna Protocol — Glossary

**Author:** Abdulwahed Mansour

---

## A

**ADS (Asymmetric Deficit Socialization)**
A vulnerability class in DeFi protocols where fee recipients extract value during
periods of unrealized loss, socializing the deficit onto depositors. Discovered by
Abdulwahed Mansour. Estimated $98.6M+ exposure across major protocols.

---

## B

**Burned M-Effort**
When a Mudaraba project fails (net loss), the manager's accumulated JHD (effort units)
for that project are permanently burned. This is the on-chain enforcement of the manager
bearing effort loss under Ghunm bil-Ghurm. See `BURNED_M_EFFORT.md`.

**Burn Ratio**
The proportion of a manager's lifetime effort that has been burned due to failed
projects. Calculated as `Burned_JHD / Lifetime_JHD`. A high ratio signals higher
risk to potential investors.

---

## C

**Constitutional Guard**
An immutable smart contract layer (`ConstitutionalGuard.sol`) that protects the
protocol's six core invariants (SE-1 through DFB-1). Cannot be overridden by
governance votes or admin actions. This is the "supreme court" of Sunna Protocol.

---

## D

**DeFi (Decentralized Finance)**
Financial services built on blockchain technology, operating without centralized
intermediaries. Sunna Protocol is a mathematically-verified DeFi framework.

---

## E

**Efficiency Ratio**
A performance metric measuring profit generated per unit of effort. Calculated as
`(Net_Profit × 100) / Total_JHD`. Used to compare manager performance across projects
and displayed via the traffic-light system (Green > 10, Yellow 3–10, Red < 3).
See `EFFICIENCY_RATIO.md`.

---

## F

**FeeController**
The smart contract (`FeeController.sol`) that enforces PY-1: no fee extraction when
unrealized losses exist. All fee calculations pass through this controller before
any treasury distribution.

---

## G

**Gharar**
Excessive uncertainty or ambiguity in contract terms, prohibited in Islamic finance.
Sunna Protocol prevents gharar by making all parameters transparent and immutable,
and by validating oracle data for freshness via `OracleValidator`.

**Ghunm bil-Ghurm**
An Arabic principle meaning "gain comes with risk" or "whoever gains must bear the
loss." A foundational principle of Islamic finance enforced by `MudarabaEngine`. The
investor risks capital; the manager risks effort.

---

## H

**Halal**
Permissible under Islamic law. In Sunna Protocol, assets and protocols must be on
the halal whitelist (maintained by `ShariaGuard`) to interact with the system.

**Haram**
Forbidden under Islamic law. Includes interest (Riba), gambling (Maysir), and excessive
uncertainty (Gharar). The protocol's design prevents haram activities by construction.

**HELAL ($HELAL)**
The governance token of Sunna Protocol. The name combines Hilal (هلال — crescent/upward
trajectory) and Halal (حلال — pure money). Token holders vote on protocol parameters
but CANNOT override constitutional invariants. See `HELALToken.sol`.

---

## I

**Invariant**
A mathematical property that must hold true at all times during protocol operation.
Sunna Protocol enforces six invariants: SE-1, PY-1, SD-1, CLA-1, CHC-1, and DFB-1.
See `INVARIANTS.md`.

---

## J

**JHD (Juhd)**
From Arabic "Juhd" meaning effort. The on-chain unit measuring verified human effort
in Sunna Protocol. 1 JHD = 1 verified unit of effort. Non-transferable and soulbound.
JHD is the world's first on-chain effort measurement system. See `JHD_SPECIFICATION.md`.

---

## M

**Maysir**
Gambling or speculation, prohibited in Islamic finance. Sunna Protocol ensures all
returns are tied to real economic activity and verified effort, never to chance.

**Mudaraba**
An Islamic finance partnership where one party provides capital (Rabb al-Mal) and the
other provides effort and management (Mudarib). Profits are shared per agreement;
losses are borne by the capital provider (financially) and the manager (effort).

**MudarabaEngine**
The core profit-loss sharing smart contract (`MudarabaEngine.sol`). Enforces Ghunm
bil-Ghurm by distributing profit based on agreed ratios and recording Burned M-Effort
on loss. Uses multiply-before-divide to prevent precision loss.

---

## O

**OracleValidator**
The smart contract (`OracleValidator.sol`) that validates price feed data from external
oracles (Chainlink, Pyth). Rejects stale data by checking `answeredInRound >= roundId`
and `updatedAt` freshness. Prevents phantom yield from outdated valuations.

---

## P

**PY-1 (Phantom Yield Prevention)**
Invariant that ensures no fees are extracted when unrealized losses exist.
`ΔTreasury ≡ 0 IF ΔLoss > 0`. Enforced by `FeeController`.

---

## R

**Rabb al-Mal**
The capital provider (investor/funder) in a Mudaraba partnership. Bears financial
loss in case of project failure.

**Riba**
Arabic term for interest or usury, strictly prohibited in Islamic finance. Sunna
Protocol generates returns exclusively through profit-sharing, never through interest.

---

## S

**SE-1 (Solvency Equilibrium)**
The primary solvency invariant: `∀t: totalAssets(t) ≥ totalLiabilities(t)`.
Enforced by `SolvencyGuard` on every state-changing transaction.

**Sharia**
Islamic law derived from the Quran and Sunnah. Governs all aspects of Muslim life,
including financial transactions. Sunna Protocol is designed for full Sharia compliance.

**ShariaGuard**
The smart contract (`ShariaGuard.sol`) that acts as a "living Sharia document" —
scholars review the code directly rather than paper promises. Maintains the halal asset
whitelist and enforces no-fee-on-loss, no-gharar, and no-capital-guarantee invariants.

**Sunna (Sunnah)**
The teachings and practices of Prophet Muhammad (peace be upon him). The protocol is
named after this concept, reflecting its commitment to ethical principles and the
correct path in finance.

**SunnaLedger**
The smart contract (`SunnaLedger.sol`) that records, measures, and permanently stores
human effort (JHD units) on-chain. The world's first on-chain effort measurement
system. Tracks activity, burned effort, and calculates efficiency ratios.

**SunnaShares**
ERC-20 investment share tokens (`SunnaShares.sol`) representing proportional ownership
in a Mudaraba project. Share value fluctuates based on actual investment performance
— never fixed, reflecting true risk-sharing.

**SunnaShield**
The adapter layer smart contract (`SunnaShield.sol`) built on ERC-4626. Wraps existing
DeFi protocols and forces Sunna invariants onto them retroactively — without requiring
the wrapped protocol's cooperation or code changes.

**SunnaVault**
The capital custody contract (`SunnaVault.sol`). Receives and secures funder deposits
(USDT/USDC). Applies multiply-before-divide for precision and uses `>=` comparisons
to prevent off-by-one withdrawal blocks.

---

## T

**Takaful**
Islamic cooperative insurance. In Sunna Protocol, `TakafulBuffer` acts as a cooperative
fee escrow, holding fees until solvency is confirmed before distribution. In crisis,
$HELAL holders can stake tokens into the buffer to protect depositors.

**Traffic-Light System**
The visual efficiency rating system on the Sunna Dashboard. Green (Efficiency > 10):
strong invest signal. Yellow (3–10): moderate confidence. Red (< 3 or Burned):
caution required.

---

*Last updated: 2026-02-22*
