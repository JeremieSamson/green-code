#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./i18n.sh
. "${SCRIPT_DIR}/i18n.sh"

export LC_ALL=C

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"
USAGE_FILE="${DATA_DIR}/usage.json"

BOLD=$'\033[1m'
DIM=$'\033[2m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'
CYAN=$'\033[1;36m'
RESET=$'\033[0m'

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

label="${GREEN}${BOLD}green-code${RESET}"

sep_line="${DIM}${GREEN}──────────────────────────────────────────────────────────────${RESET}"

is_negative_or_zero=$(echo "$debt <= 0" | bc)
if [ "$is_negative_or_zero" = "1" ]; then
  body="${label}  ${co2_fmt} kg CO2 ${DIM}${T_EMITTED}${RESET}  ${DIM}·${RESET}  ${trees} ${T_TREES_PLANTED}  ${DIM}·${RESET}  ${GREEN}${BOLD}${T_CARBON_NEUTRAL}${RESET}"
  msg=$(printf "\n%s\n%s\n%s" "$sep_line" "$body" "$sep_line")
  emit_json "$msg"
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

bar_full=""
for ((i=0; i<filled; i++)); do bar_full+="█"; done
bar_empty=""
for ((i=0; i<empty; i++)); do bar_empty+="░"; done
bar="${GREEN}${bar_full}${DIM}${bar_empty}${RESET}"

line1=$(printf "%s  %s%s kg CO2%s %s%s%s  %s·%s  %s%s %s%s  %s·%s  %s%s %s kg%s %s(%s %s)%s" \
  "$label" "$BOLD" "$co2_fmt" "$RESET" "$DIM" "$T_EMITTED" "$RESET" "$DIM" "$RESET" "$BOLD" "$trees" "$T_TREES_PLANTED" "$RESET" "$DIM" "$RESET" "$GREEN" "$T_DEBT" "$debt_fmt" "$RESET" "$DIM" "$trees_owed" "$T_TREES_OWED_LABEL" "$RESET")

line2=$(printf "%s%s%s  %s  %s%s%%%s  %s(%s / %s kg)%s" \
  "$DIM" "$T_NEXT_TREE" "$RESET" "$bar" "$GREEN" "$percent" "$RESET" "$DIM" "$remainder_fmt" "$threshold_fmt" "$RESET")

msg=$(printf "\n%s\n%s\n%s\n%s" "$sep_line" "$line1" "$line2" "$sep_line")
emit_json "$msg"
