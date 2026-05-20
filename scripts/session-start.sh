#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"
USAGE_FILE="${DATA_DIR}/usage.json"

emit_json() {
  local msg="$1"
  jq -nc \
    --arg ctx "$msg" \
    --arg sys "$msg" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}, systemMessage: $sys}'
}

[ -f "$CONFIG_FILE" ] || exit 0
[ -f "$USAGE_FILE" ] || exit 0
command -v jq &>/dev/null || exit 0
command -v bc &>/dev/null || exit 0

co2=$(jq '.accumulated.co2_kg // 0' "$USAGE_FILE")
trees=$(jq '.trees.total // 0' "$USAGE_FILE")
threshold=$(jq '.threshold_co2_kg // 10' "$CONFIG_FILE")

compensated=$(echo "scale=2; $trees * $threshold" | bc)
debt=$(echo "scale=2; $co2 - $compensated" | bc)

co2_fmt=$(printf "%.2f" "$co2")

is_negative_or_zero=$(echo "$debt <= 0" | bc)
if [ "$is_negative_or_zero" = "1" ]; then
  emit_json "green-code | ${co2_fmt} kg CO2 emis | ${trees} arbres plantes | Carbone neutre"
  exit 0
fi

debt_fmt=$(printf "%.2f" "$debt")
trees_owed=$(echo "$debt / $threshold" | bc)
remainder=$(echo "scale=2; $debt - ($trees_owed * $threshold)" | bc)
remainder_fmt=$(printf "%.2f" "$remainder")
threshold_fmt=$(printf "%.0f" "$threshold")

percent=$(echo "scale=0; $remainder * 100 / $threshold" | bc)
filled=$(echo "scale=0; $remainder * 20 / $threshold" | bc)
empty=$((20 - filled))

bar=""
for ((i=0; i<filled; i++)); do bar="${bar}#"; done
for ((i=0; i<empty; i++)); do bar="${bar}."; done

msg=$(printf "green-code | %s kg CO2 emis | %s arbres plantes\nDette nette: %s kg (%s arbres dus)\nProchain arbre: [%s] %s / %s kg (%s%%)" \
  "$co2_fmt" "$trees" "$debt_fmt" "$trees_owed" "$bar" "$remainder_fmt" "$threshold_fmt" "$percent")

emit_json "$msg"
