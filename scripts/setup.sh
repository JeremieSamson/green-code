#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"

# Skip if already configured
if [ -f "$CONFIG_FILE" ]; then
  exit 0
fi

mkdir -p "$DATA_DIR"

echo ""
echo "=== green-code setup ==="
echo ""
echo "This plugin tracks your AI carbon footprint and lets you"
echo "plant trees via Tree-Nation to compensate."
echo ""
echo "You need a Tree-Nation API token."
echo "Request one at: https://kb.tree-nation.com/knowledge/api-availability"
echo "Or email: integration@tree-nation.com"
echo ""

read -rp "Tree-Nation API token: " api_key
if [ -z "$api_key" ]; then
  echo "No API key provided. Run /green:config later to set it up."
  api_key=""
fi

read -rp "Tree-Nation Forest ID (numeric): " forest_id
if [ -z "$forest_id" ]; then
  echo "No forest ID provided. Run /green:config later to set it."
  forest_id=0
fi

echo ""
echo "Mode:"
echo "  auto   - Plant a tree automatically when threshold is reached"
echo "  manual - Track only, plant manually with /green:plant"
echo ""
read -rp "Mode [manual]: " mode
mode="${mode:-manual}"
if [ "$mode" != "auto" ] && [ "$mode" != "manual" ]; then
  mode="manual"
fi

read -rp "CO2 threshold per tree in kg [10]: " threshold
threshold="${threshold:-10}"

cat > "$CONFIG_FILE" << EOF
{
  "treenation_api_key": "${api_key}",
  "forest_id": ${forest_id},
  "mode": "${mode}",
  "threshold_co2_kg": ${threshold},
  "co2_grams_per_kwh": 380,
  "pue": 1.2
}
EOF

# Bootstrap usage.json with historical analysis
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"${SCRIPT_DIR}/bootstrap.sh"

echo "green-code configured! Mode: ${mode}, threshold: ${threshold} kg CO2."
echo ""
