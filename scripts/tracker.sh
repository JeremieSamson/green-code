#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"
USAGE_FILE="${DATA_DIR}/usage.json"
STATS_FILE="${HOME}/.claude/stats-cache.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Exit silently if not configured or no stats
[ -f "$CONFIG_FILE" ] || exit 0
[ -f "$USAGE_FILE" ] || exit 0
[ -f "$STATS_FILE" ] || exit 0
command -v jq &>/dev/null || exit 0

# Read current totals from stats-cache.json
curr_input=$(jq '[.modelUsage[].inputTokens] | add // 0' "$STATS_FILE")
curr_output=$(jq '[.modelUsage[].outputTokens] | add // 0' "$STATS_FILE")
curr_cache_read=$(jq '[.modelUsage[].cacheReadInputTokens] | add // 0' "$STATS_FILE")
curr_cache_create=$(jq '[.modelUsage[].cacheCreationInputTokens] | add // 0' "$STATS_FILE")

# Read last snapshot from usage.json
prev_input=$(jq '.lastSnapshot.inputTokens // 0' "$USAGE_FILE")
prev_output=$(jq '.lastSnapshot.outputTokens // 0' "$USAGE_FILE")
prev_cache_read=$(jq '.lastSnapshot.cacheReadInputTokens // 0' "$USAGE_FILE")
prev_cache_create=$(jq '.lastSnapshot.cacheCreationInputTokens // 0' "$USAGE_FILE")

# Compute deltas (only positive, stats may reset)
delta_input=$((curr_input - prev_input))
delta_output=$((curr_output - prev_output))
delta_cache_read=$((curr_cache_read - prev_cache_read))
delta_cache_create=$((curr_cache_create - prev_cache_create))

[ "$delta_input" -lt 0 ] && delta_input=0
[ "$delta_output" -lt 0 ] && delta_output=0
[ "$delta_cache_read" -lt 0 ] && delta_cache_read=0
[ "$delta_cache_create" -lt 0 ] && delta_cache_create=0

# Skip if no change
if [ "$delta_input" -eq 0 ] && [ "$delta_output" -eq 0 ] && \
   [ "$delta_cache_read" -eq 0 ] && [ "$delta_cache_create" -eq 0 ]; then
  exit 0
fi

# Token -> kWh conversion (Wh per token)
# output: 0.002 Wh, input+cache_create: 0.0005 Wh, cache_read: 0.00002 Wh
delta_wh=$(echo "scale=6; \
  $delta_output * 0.002 + \
  $delta_input * 0.0005 + \
  $delta_cache_create * 0.0005 + \
  $delta_cache_read * 0.00002" | bc)

# Read config
pue=$(jq '.pue // 1.2' "$CONFIG_FILE")
co2_g_per_kwh=$(jq '.co2_grams_per_kwh // 380' "$CONFIG_FILE")
threshold=$(jq '.threshold_co2_kg // 10' "$CONFIG_FILE")
mode=$(jq -r '.mode // "manual"' "$CONFIG_FILE")

# Apply PUE and convert to kWh
delta_kwh=$(echo "scale=6; $delta_wh / 1000 * $pue" | bc)

# kWh -> CO2 (kg)
delta_co2=$(echo "scale=6; $delta_kwh * $co2_g_per_kwh / 1000" | bc)

# Update accumulated values
prev_kwh=$(jq '.accumulated.kwh // 0' "$USAGE_FILE")
prev_co2=$(jq '.accumulated.co2_kg // 0' "$USAGE_FILE")

new_kwh=$(echo "scale=6; $prev_kwh + $delta_kwh" | bc)
new_co2=$(echo "scale=6; $prev_co2 + $delta_co2" | bc)

# Update usage.json
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq \
  --argjson ci "$curr_input" \
  --argjson co "$curr_output" \
  --argjson ccr "$curr_cache_read" \
  --argjson ccc "$curr_cache_create" \
  --arg ts "$NOW" \
  --argjson nkwh "$new_kwh" \
  --argjson nco2 "$new_co2" \
  '
  .lastSnapshot.inputTokens = $ci |
  .lastSnapshot.outputTokens = $co |
  .lastSnapshot.cacheReadInputTokens = $ccr |
  .lastSnapshot.cacheCreationInputTokens = $ccc |
  .lastSnapshot.timestamp = $ts |
  .accumulated.kwh = $nkwh |
  .accumulated.co2_kg = $nco2
  ' "$USAGE_FILE" > "${USAGE_FILE}.tmp" && mv "${USAGE_FILE}.tmp" "$USAGE_FILE"

# Check auto-plant threshold
if [ "$mode" = "auto" ]; then
  trees_to_plant=$(echo "$new_co2 / $threshold" | bc)
  if [ "$trees_to_plant" -gt 0 ] 2>/dev/null; then
    "${PLUGIN_ROOT}/scripts/treenation.sh" plant "$trees_to_plant"
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
      remainder=$(echo "scale=6; $new_co2 - ($trees_to_plant * $threshold)" | bc)
      jq --argjson r "$remainder" '.accumulated.co2_kg = $r' \
        "$USAGE_FILE" > "${USAGE_FILE}.tmp" && mv "${USAGE_FILE}.tmp" "$USAGE_FILE"
    fi
  fi
fi
