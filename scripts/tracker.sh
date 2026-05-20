#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"
USAGE_FILE="${DATA_DIR}/usage.json"
STATS_FILE="${HOME}/.claude/stats-cache.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

[ -f "$CONFIG_FILE" ] || exit 0
[ -f "$STATS_FILE" ] || exit 0
command -v jq &>/dev/null || exit 0

# Bootstrap usage.json if missing (fallback for manual config setup)
if [ ! -f "$USAGE_FILE" ]; then
  "${PLUGIN_ROOT}/scripts/bootstrap.sh" 2>/dev/null || exit 0
  [ -f "$USAGE_FILE" ] || exit 0
fi

pue=$(jq '.pue // 1.15' "$CONFIG_FILE")
co2_g_per_kwh=$(jq '.co2_grams_per_kwh // 320' "$CONFIG_FILE")
threshold=$(jq '.threshold_co2_kg // 10' "$CONFIG_FILE")
mode=$(jq -r '.mode // "manual"' "$CONFIG_FILE")

# Migrate old single-snapshot format to per-model. The first post-migration run
# uses current stats as the baseline so no delta is double-counted.
if jq -e '.lastSnapshot.inputTokens != null' "$USAGE_FILE" >/dev/null 2>&1; then
  baseline=$(jq '.modelUsage | with_entries(.value = {
    inputTokens: .value.inputTokens,
    outputTokens: .value.outputTokens,
    cacheReadInputTokens: .value.cacheReadInputTokens,
    cacheCreationInputTokens: .value.cacheCreationInputTokens
  })' "$STATS_FILE")
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq --argjson b "$baseline" --arg ts "$NOW" \
    '.lastSnapshot = $b | .lastSnapshotTimestamp = $ts' \
    "$USAGE_FILE" > "${USAGE_FILE}.tmp" && mv "${USAGE_FILE}.tmp" "$USAGE_FILE"
  exit 0
fi

# Per-model energy in Wh per output token. Other token types are derived as
# ratios of the model's output cost (aligned with Anthropic API pricing tiers,
# which track compute cost). Sources: TokenPowerBench (AAAI 2026), Luccioni et
# al. 2024, Anthropic prompt-caching docs (~90% reduction for cache reads).
#   ratios: input=0.20, cache_create=0.25, cache_read=0.02 (relative to output)
delta_kwh=$(jq -n \
  --slurpfile stats "$STATS_FILE" \
  --slurpfile usage "$USAGE_FILE" \
  --argjson pue "$pue" \
  '
  def base_wh(name):
    if   name | test("opus")   then 0.002
    elif name | test("sonnet") then 0.0008
    elif name | test("haiku")  then 0.0003
    else                            0.001
    end;
  def clamp: if . < 0 then 0 else . end;
  ($stats[0].modelUsage // {}) as $cur |
  ($usage[0].lastSnapshot // {}) as $prev |
  [ $cur | to_entries[] |
    . as $m |
    base_wh($m.key) as $b |
    ($prev[$m.key] // {}) as $p |
    (($m.value.outputTokens // 0) - ($p.outputTokens // 0) | clamp) as $do |
    (($m.value.inputTokens // 0) - ($p.inputTokens // 0) | clamp) as $di |
    (($m.value.cacheCreationInputTokens // 0) - ($p.cacheCreationInputTokens // 0) | clamp) as $dcc |
    (($m.value.cacheReadInputTokens // 0) - ($p.cacheReadInputTokens // 0) | clamp) as $dcr |
    ($do * $b + $di * $b * 0.20 + $dcc * $b * 0.25 + $dcr * $b * 0.02)
  ] | add // 0 | . / 1000 * $pue
  ')

is_zero=$(echo "$delta_kwh == 0" | bc -l)
if [ "$is_zero" = "1" ]; then
  exit 0
fi

delta_co2=$(echo "scale=6; $delta_kwh * $co2_g_per_kwh / 1000" | bc)

prev_kwh=$(jq '.accumulated.kwh // 0' "$USAGE_FILE")
prev_co2=$(jq '.accumulated.co2_kg // 0' "$USAGE_FILE")
new_kwh=$(echo "scale=6; $prev_kwh + $delta_kwh" | bc)
new_co2=$(echo "scale=6; $prev_co2 + $delta_co2" | bc)

new_snapshot=$(jq '.modelUsage | with_entries(.value = {
  inputTokens: .value.inputTokens,
  outputTokens: .value.outputTokens,
  cacheReadInputTokens: .value.cacheReadInputTokens,
  cacheCreationInputTokens: .value.cacheCreationInputTokens
})' "$STATS_FILE")

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq \
  --argjson snap "$new_snapshot" \
  --arg ts "$NOW" \
  --argjson nkwh "$new_kwh" \
  --argjson nco2 "$new_co2" \
  '
  .lastSnapshot = $snap |
  .lastSnapshotTimestamp = $ts |
  .accumulated.kwh = $nkwh |
  .accumulated.co2_kg = $nco2
  ' "$USAGE_FILE" > "${USAGE_FILE}.tmp" && mv "${USAGE_FILE}.tmp" "$USAGE_FILE"

if [ "$mode" = "auto" ]; then
  trees_to_plant=$(echo "$new_co2 / $threshold" | bc)
  if [ "$trees_to_plant" -gt 0 ] 2>/dev/null; then
    "${PLUGIN_ROOT}/scripts/treenation.sh" plant "$trees_to_plant"
    if [ $? -eq 0 ]; then
      remainder=$(echo "scale=6; $new_co2 - ($trees_to_plant * $threshold)" | bc)
      jq --argjson r "$remainder" '.accumulated.co2_kg = $r' \
        "$USAGE_FILE" > "${USAGE_FILE}.tmp" && mv "${USAGE_FILE}.tmp" "$USAGE_FILE"
    fi
  fi
fi
