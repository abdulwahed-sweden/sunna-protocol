# JHD (Juhd/Effort) Unit Specification

**Author:** Abdulwahed Mansour

---

## Definition

**JHD** (from Arabic "Juhd", meaning effort) is the on-chain unit of verified human effort
within the Sunna Protocol. It quantifies the contributions of managers (Mudaribs) in
Mudaraba partnerships.

```
1 JHD = 1 verified unit of human effort
```

JHD is non-transferable and non-tradeable. It is a soulbound metric recorded permanently
on the `SunnaLedger`.

---

## Action Types and Weights

Each action performed by a manager is assigned a weight reflecting its complexity and
impact on the project.

| Action       | Weight | Description                                  |
|--------------|--------|----------------------------------------------|
| Trade        | 5      | Execution of a buy/sell/swap transaction      |
| Report       | 10     | Submission of a performance or status report  |
| Strategy     | 8      | Design or modification of investment strategy |
| Rebalance    | 15     | Portfolio rebalancing across positions         |
| Monitoring   | 1      | Routine check of positions and risk metrics   |

Weights are set at protocol deployment and can be adjusted via HELAL governance,
subject to ConstitutionalGuard bounds.

---

## JHD Balance Formula

A manager's JHD balance is computed as:

```
JHD_Balance = Σ(Action_i × Weight_i) + Verified_Hours
```

Where:
- `Action_i` is the count of each action type performed.
- `Weight_i` is the weight assigned to that action type.
- `Verified_Hours` represents additional verified time contributions approved
  by the protocol (e.g., research, due diligence).

**Example:**

| Action     | Count | Weight | Subtotal |
|------------|-------|--------|----------|
| Trade      | 20    | 5      | 100      |
| Report     | 4     | 10     | 40       |
| Strategy   | 2     | 8      | 16       |
| Rebalance  | 3     | 15     | 45       |
| Monitoring | 50    | 1      | 50       |
| **Total**  |       |        | **251**  |

With 10 verified hours: `JHD_Balance = 251 + 10 = 261 JHD`

---

## Efficiency Ratio

The Efficiency Ratio measures how effectively a manager converts effort into profit.

```
Efficiency_Ratio = (Net_Profit × 100) / Total_JHD
```

- A higher ratio indicates more productive effort.
- The ratio is calculated per project and aggregated across a manager's lifetime.
- See `EFFICIENCY_RATIO.md` for detailed specification.

---

## Burned M-Effort

When a Mudaraba project results in a net loss, the manager's JHD for that project is
permanently **burned**. Burned JHD:

- Remains recorded on `SunnaLedger` as a historical entry.
- Counts against the manager's lifetime efficiency score.
- Cannot be recovered or reversed.
- See `BURNED_M_EFFORT.md` for detailed specification.

---

## On-Chain Reputation

A manager's on-chain reputation is derived from their JHD history:

- **Lifetime JHD:** Total effort accumulated across all projects.
- **Active JHD:** Effort on currently active (non-burned) projects.
- **Burned JHD:** Effort lost to failed projects.
- **Efficiency Score:** Lifetime efficiency ratio across all projects.

This reputation is fully transparent and queryable on-chain via `SunnaLedger`.

---

*Last updated: 2026-02-22*
