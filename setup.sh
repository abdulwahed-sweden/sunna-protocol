#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  Sunna Protocol — Local Setup Script
#  Author: Abdulwahed Mansour / Sweden
#  Run this in your sunna-protocol directory after extracting files.
# ═══════════════════════════════════════════════════════════════════

set -e

echo "══════════════════════════════════════════"
echo "  Sunna Protocol — Setup"
echo "  Abdulwahed Mansour / Sweden"
echo "══════════════════════════════════════════"

# 1. Git configuration
echo "[1/5] Configuring Git author..."
git config user.name "Abdulwahed Mansour"
git config user.email "abdulwahed.mansour@protonmail.com"

# 2. Initialize Foundry (if not already)
echo "[2/5] Initializing Foundry..."
if [ ! -d "lib/forge-std" ]; then
    forge install foundry-rs/forge-std --no-commit
fi

# 3. Install dependencies
echo "[3/5] Installing dependencies..."
if [ ! -d "lib/openzeppelin-contracts" ]; then
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
fi

# 4. Build
echo "[4/5] Building contracts..."
forge build

# 5. Test
echo "[5/5] Running tests..."
forge test -v

echo ""
echo "══════════════════════════════════════════"
echo "  ✓ Sunna Protocol — Ready"
echo "  Contracts: $(find src -name '*.sol' | wc -l)"
echo "  Tests: $(find test -name '*.sol' | wc -l)"
echo "══════════════════════════════════════════"
