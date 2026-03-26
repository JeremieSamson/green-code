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

read -rp "Tree-Nation Planter ID: " planter_id
if [ -z "$planter_id" ]; then
  echo "No planter ID provided. Run /green:config later to set it."
  planter_id=""
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
  "planter_id": "${planter_id}",
  "mode": "${mode}",
  "threshold_co2_kg": ${threshold},
  "co2_grams_per_kwh": 380,
  "pue": 1.2
}
EOF

# Initialize usage.json with current stats snapshot
STATS_FILE="${HOME}/.claude/stats-cache.json"
USAGE_FILE="${DATA_DIR}/usage.json"

input=0; output=0; cache_read=0; cache_create=0
if [ -f "$STATS_FILE" ] && command -v jq &>/dev/null; then
  input=$(jq '[.modelUsage[].inputTokens] | add // 0' "$STATS_FILE")
  output=$(jq '[.modelUsage[].outputTokens] | add // 0' "$STATS_FILE")
  cache_read=$(jq '[.modelUsage[].cacheReadInputTokens] | add // 0' "$STATS_FILE")
  cache_create=$(jq '[.modelUsage[].cacheCreationInputTokens] | add // 0' "$STATS_FILE")
fi

cat > "$USAGE_FILE" << EOF
{
  "lastSnapshot": {
    "inputTokens": ${input},
    "outputTokens": ${output},
    "cacheReadInputTokens": ${cache_read},
    "cacheCreationInputTokens": ${cache_create},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "accumulated": {
    "kwh": 0,
    "co2_kg": 0,
    "since": "$(date +%Y-%m-%d)"
  },
  "history": [],
  "trees": {
    "total": 0,
    "planted": []
  }
}
EOF

echo ""
echo "green-code configured! Mode: ${mode}, threshold: ${threshold} kg CO2."
echo "Use /green:status to see your carbon footprint."
echo ""
