#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"
USAGE_FILE="${DATA_DIR}/usage.json"
STATS_FILE="${HOME}/.claude/stats-cache.json"

# Idempotent: skip if usage.json already exists
[ -f "$USAGE_FILE" ] && exit 0

# Require config and jq
[ -f "$CONFIG_FILE" ] || { echo "ERROR: config.json not found. Run /green:config first." >&2; exit 1; }
command -v jq &>/dev/null || { echo "ERROR: jq is required." >&2; exit 1; }
command -v bc &>/dev/null || { echo "ERROR: bc is required." >&2; exit 1; }

# Read config
pue=$(jq '.pue // 1.2' "$CONFIG_FILE")
co2_g_per_kwh=$(jq '.co2_grams_per_kwh // 380' "$CONFIG_FILE")
threshold=$(jq '.threshold_co2_kg // 10' "$CONFIG_FILE")

# Read current token totals from stats-cache
input=0; output=0; cache_read=0; cache_create=0
first_session=""
if [ -f "$STATS_FILE" ]; then
  input=$(jq '[.modelUsage[].inputTokens] | add // 0' "$STATS_FILE")
  output=$(jq '[.modelUsage[].outputTokens] | add // 0' "$STATS_FILE")
  cache_read=$(jq '[.modelUsage[].cacheReadInputTokens] | add // 0' "$STATS_FILE")
  cache_create=$(jq '[.modelUsage[].cacheCreationInputTokens] | add // 0' "$STATS_FILE")
  first_session=$(jq -r '.firstSessionDate // empty' "$STATS_FILE" | cut -dT -f1)
fi

since="${first_session:-$(date +%Y-%m-%d)}"

# Compute historical energy (Wh)
total_wh=$(echo "scale=6; \
  $output * 0.002 + \
  $input * 0.0005 + \
  $cache_create * 0.0005 + \
  $cache_read * 0.00002" | bc)

# Apply PUE -> kWh
total_kwh=$(echo "scale=6; $total_wh / 1000 * $pue" | bc)

# kWh -> CO2 kg
total_co2=$(echo "scale=6; $total_kwh * $co2_g_per_kwh / 1000" | bc)

# Compute trees needed
trees_needed=$(echo "$total_co2 / $threshold" | bc)

# Create usage.json with historical accumulation
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p "$DATA_DIR"
cat > "$USAGE_FILE" << EOF
{
  "lastSnapshot": {
    "inputTokens": ${input},
    "outputTokens": ${output},
    "cacheReadInputTokens": ${cache_read},
    "cacheCreationInputTokens": ${cache_create},
    "timestamp": "${NOW}"
  },
  "accumulated": {
    "kwh": ${total_kwh},
    "co2_kg": ${total_co2},
    "since": "${since}"
  },
  "history": [],
  "trees": {
    "total": 0,
    "planted": []
  }
}
EOF

# Summary output
total_tokens=$((input + output + cache_read + cache_create))
echo ""
echo "=== green-code: initial analysis ==="
echo ""
echo "  Period:       since ${since}"
echo "  Tokens:       $(printf "%'d" "$total_tokens")"
echo "  Energy:       ${total_kwh} kWh (PUE ${pue})"
echo "  CO2:          ${total_co2} kg"
echo "  Trees needed: ${trees_needed} (at ${threshold} kg/tree)"
echo ""
echo "  Tracking is now active."
echo "  Use /green:status for details, /green:plant to offset."
echo ""
