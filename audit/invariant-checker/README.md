# ADS-Checker — Invariant Verification Tool

**Author:** Abdulwahed Mansour

---

## Purpose

ADS-Checker is an automated tool for detecting the Asymmetric Deficit Socialization
(ADS) vulnerability in DeFi protocols. It analyzes smart contract fee mechanisms to
determine whether fee extraction can occur during periods of unrealized loss.

---

## 10-Module Architecture

### Module 1: Contract Loader
Loads and parses smart contract source code or bytecode from target protocols.
Supports Solidity source, verified Etherscan contracts, and raw bytecode.

### Module 2: Fee Flow Analyzer
Identifies all fee extraction points in the protocol: functions that transfer value
to treasury, fee recipients, or governance addresses.

### Module 3: Solvency State Detector
Maps all state variables that contribute to the protocol's solvency calculation
(total assets, total liabilities, reserves, bad debt counters).

### Module 4: Invariant Extractor
Extracts existing invariant checks (require/assert statements) around fee functions.
Identifies whether solvency is checked before fee extraction.

### Module 5: Loss Path Tracer
Traces execution paths where asset values decrease (bad debt creation, liquidation
shortfalls, oracle price drops) and checks if fee extraction is reachable.

### Module 6: Virtual Accounting Analyzer
Detects virtual accounting patterns (e.g., monotonically increasing indices) that
may mask real asset losses from fee calculation logic.

### Module 7: Cross-Function Dependency Mapper
Maps dependencies between fee functions and solvency-related state. Identifies
whether fee functions read solvency state before executing.

### Module 8: ADS Vulnerability Scorer
Assigns a risk score (0-100) based on findings from modules 2-7. Considers:
- Number of unguarded fee extraction points.
- Presence/absence of solvency checks.
- Virtual accounting gap potential.

### Module 9: Report Generator
Produces a structured report with:
- Vulnerability summary and risk score.
- Affected functions and code locations.
- Recommended mitigations.
- Comparison with Sunna Protocol invariants.

### Module 10: Continuous Monitor
On-chain monitoring daemon that watches for real-time ADS conditions:
- Tracks protocol solvency state.
- Alerts when fee extraction occurs during detected loss periods.
- Logs events for post-hoc analysis.

---

## Usage

### Installation

```bash
# Clone the repository
git clone https://github.com/sunna-protocol/ads-checker.git
cd ads-checker

# Install dependencies
npm install

# Configure target protocol
cp .env.example .env
# Edit .env with target protocol addresses and RPC URL
```

### Running an Analysis

```bash
# Analyze a specific protocol
npx ads-checker analyze --protocol aave-v3 --chain mainnet

# Run with custom contract addresses
npx ads-checker analyze --address 0x... --chain mainnet

# Generate report
npx ads-checker report --output ./reports/aave-v3.md
```

### Running the Monitor

```bash
# Start continuous monitoring
npx ads-checker monitor --protocol aave-v3 --alert webhook

# Monitor multiple protocols
npx ads-checker monitor --config ./monitor-config.json
```

---

## Output Example

```
ADS-Checker Analysis Report
===========================
Protocol: Aave V3
Chain: Ethereum Mainnet
Risk Score: 78/100 (HIGH)

Fee Extraction Points: 3
  - ReserveLogic.updateState() [UNGUARDED]
  - Pool.mintToTreasury() [UNGUARDED]
  - FlashLoanLogic.executeBorrow() [PARTIAL]

Solvency Checks Found: 0/3 fee paths
Virtual Accounting Gap: DETECTED (liquidity index)

Recommendation: Add solvency validation before fee accrual.
```

---

## Supported Protocols

| Protocol     | Status      |
|--------------|-------------|
| Aave V3/V4   | Supported   |
| Morpho Blue  | Supported   |
| Curve crvUSD | Supported   |
| Compound V3  | Planned     |
| Euler V2     | Planned     |

---

*Last updated: 2026-02-22*
