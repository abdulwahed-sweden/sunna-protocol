# Sunna Protocol

![Build](https://img.shields.io/badge/build-passing-brightgreen)
![Tests](https://img.shields.io/badge/tests-87%2F87-brightgreen)
![Solidity](https://img.shields.io/badge/solidity-0.8.24-363636)
![Foundry](https://img.shields.io/badge/foundry-latest-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**The Right Path to Decentralized Finance**

بروتوكول السُّنَّة — الطريق الصحيح للتمويل اللامركزي

---

## What is Sunna Protocol?

Sunna Protocol is a mathematically-verified DeFi ecosystem that enforces financial fairness through immutable code. It eliminates **Asymmetric Deficit Socialization (ADS)** — a $98.6M+ vulnerability class we discovered in major DeFi lending protocols.

> *"We do not ask for trust — we prove it with mathematics."*

## The Problem

Major DeFi protocols extract fees from accrued interest **before** verifying collectibility. The treasury captures 100% of profits while depositors absorb 100% of losses.

| Protocol     | Phantom Yield Exposure |
| ------------ | ---------------------- |
| Aave V4      | ~$96M (97.3%)          |
| Morpho Blue  | ~$2M (2.0%)            |
| Curve crvUSD | ~$585K (0.6%)          |
| **Total**    | **$98.6M+**            |

## The Solution: 4 Layers

### Layer 1: Sunna Core (Constitutional)

Six mathematical invariants that cannot be bypassed by governance, upgrades, or any external force:

- **SE-1**: Solvency Equilibrium — `totalAssets ≥ totalLiabilities` at all times
- **PY-1**: Phantom Yield Prevention — No fee extraction when losses exist
- **SD-1**: Shared Deficit — Fee recipients share losses proportionally
- **CLA-1**: Claimable Yield Authenticity — No distribution of unrealized gains
- **CHC-1**: Conservation of Holdings — Perfect accounting of all deposits
- **DFB-1**: Deficit Floor Bound — No unbounded negative equity

### Layer 2: Sunna Shield (Adapter)

ERC-4626 wrapper that forces Sunna invariants onto existing protocols — without their cooperation or code changes.

### Layer 3: Sunna Mudaraba (Investment)

Complete profit-loss sharing platform with **world's first on-chain effort measurement**:

- **MudarabaEngine** — Profit/loss distribution enforcing Ghunm bil-Ghurm
- **SunnaLedger** — JHD (Effort) units tracking with Burned M-Effort
- **Efficiency Ratio** — Compare manager performance: `(Profit × 100) / JHD`

### Layer 4: $HELAL Governance

Ethical governance token. Can adjust parameters. **Cannot** override constitutional invariants.

## Core Innovation: SunnaLedger (JHD)

For the first time in DeFi, **human effort is measured, recorded, and permanently stored on-chain**:

| Action              | JHD Value | Proof         |
| ------------------- | --------- | ------------- |
| Trade executed      | 5 JHD     | Tx hash       |
| Report submitted    | 10 JHD    | IPFS hash     |
| Strategy update     | 8 JHD     | Contract call |
| Portfolio rebalance | 15 JHD    | Multi-call    |
| Monitoring hour     | 1 JHD     | Heartbeat     |

**Efficiency = (Profit × 100) / JHD**

When a project fails, the manager's JHD is permanently **burned** — effort was real but produced no return. This is the on-chain enforcement of Islamic finance's risk-sharing principle.

## Project Structure

```
sunna-protocol/
├── src/
│   ├── core/                    # Layer 1: Constitutional Invariants
│   │   ├── SolvencyGuard.sol    # SE-1 enforcement
│   │   ├── ShariaGuard.sol      # Halal whitelist + living Sharia document
│   │   ├── TakafulBuffer.sol    # Fee escrow until solvency confirmed
│   │   ├── FeeController.sol    # PY-1: no phantom yield
│   │   └── ConstitutionalGuard.sol
│   ├── shield/                  # Layer 2: Protocol Adapter
│   │   └── SunnaShield.sol      # ERC-4626 wrapper
│   ├── mudaraba/                # Layer 3: Investment Platform
│   │   ├── SunnaVault.sol       # Capital custody
│   │   ├── SunnaShares.sol      # Dynamic investment shares
│   │   ├── MudarabaEngine.sol   # Profit-loss sharing
│   │   ├── SunnaLedger.sol      # JHD effort tracking (WORLD FIRST)
│   │   └── OracleValidator.sol  # Stale data prevention
│   ├── governance/              # Layer 4: $HELAL
│   │   └── HELALToken.sol
│   └── libraries/               # Shared utilities
│       ├── SunnaMath.sol
│       ├── SunnaErrors.sol
│       └── SunnaEvents.sol
├── test/                        # Unit, fuzz, and invariant tests
├── script/                      # Deployment scripts
├── docs/                        # Full documentation
│   ├── ARCHITECTURE.md
│   ├── INVARIANTS.md
│   ├── SHARIA_COMPLIANCE.md
│   ├── REGULATORY_COMPLIANCE.md
│   ├── JHD_SPECIFICATION.md
│   ├── BURNED_M_EFFORT.md
│   ├── EFFICIENCY_RATIO.md
│   ├── SECURITY.md
│   └── GLOSSARY.md
└── audit/                       # ADS research and analysis
```

## Compliance

| Standard  | Requirement               | Sunna Protocol        |
| --------- | ------------------------- | --------------------- |
| IFRS 15   | Revenue on satisfied obligations | ✔ PY-1 + FeeController |
| US GAAP   | Matching Principle        | ✔ MudarabaEngine       |
| Basel III | Capital adequacy buffers  | ✔ SE-1 + TakafulBuffer |
| AAOIFI    | Mudaraba/Musharaka standards | ✔ Full alignment     |
| Sharia    | Risk-sharing (Ghunm bil-Ghurm) | ✔ Enforced in code  |

## Quick Start

```bash
# Build
forge build

# Test
forge test

# Test with verbosity
forge test -vvv

# Fuzz tests
forge test --match-test testFuzz
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | 4-layer system design and contract dependencies |
| [Invariants](docs/INVARIANTS.md) | Six mathematical invariants with formal definitions |
| [JHD Specification](docs/JHD_SPECIFICATION.md) | Effort unit system and calculation |
| [Burned M-Effort](docs/BURNED_M_EFFORT.md) | Manager effort loss mechanism |
| [Efficiency Ratio](docs/EFFICIENCY_RATIO.md) | Performance measurement system |
| [Sharia Compliance](docs/SHARIA_COMPLIANCE.md) | Sharia principles mapped to code |
| [Regulatory Compliance](docs/REGULATORY_COMPLIANCE.md) | IFRS/GAAP/Basel III/AAOIFI alignment |
| [Security](docs/SECURITY.md) | Threat model and audit readiness |
| [Glossary](docs/GLOSSARY.md) | All Sunna-specific terminology |

## Commit History

| Hash | Message |
|------|---------|
| `6245a14` | chore: initial repository setup |
| `c7a6aec` | chore: initialize Foundry project configuration |
| `29531be` | feat(lib): add shared libraries — SunnaMath, SunnaErrors, SunnaEvents |
| `e697a7c` | feat(interfaces): add protocol interfaces |
| `e2f53c1` | feat(core): add Sunna Core — constitutional invariant layer |
| `7f689c4` | feat(shield): add SunnaShield — ERC-4626 adapter layer |
| `8f6c85b` | feat(mudaraba): add Sunna Mudaraba layer — profit-loss sharing engine |
| `629386b` | feat(governance): add HELAL governance token — ERC-20 with mint/burn |
| `98e99f2` | test: add comprehensive test suite — unit, fuzz, and invariant tests |
| `771d5ca` | script: add deployment scripts — mainnet and Sepolia |
| `2796ae4` | chore: verify build and test integrity — 87/87 tests pass |

## Author

**Abdulwahed Mansour** — Invariant Labs / Red Wolves Security

## License

MIT
