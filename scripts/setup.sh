#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./i18n.sh
. "${SCRIPT_DIR}/i18n.sh"

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"

# Skip if already configured
if [ -f "$CONFIG_FILE" ]; then
  exit 0
fi

mkdir -p "$DATA_DIR"

echo ""
echo "$T_SETUP_HEADER"
echo ""
echo "$T_SETUP_DESC_1"
echo "$T_SETUP_DESC_2"
echo ""
echo "$T_SETUP_TOKEN_NEED"
echo "$T_SETUP_TOKEN_REQUEST"
echo "$T_SETUP_TOKEN_EMAIL"
echo ""

read -rp "${T_SETUP_TOKEN_PROMPT}: " api_key
if [ -z "$api_key" ]; then
  echo "$T_SETUP_NO_TOKEN"
  api_key=""
fi

read -rp "${T_SETUP_FOREST_PROMPT}: " forest_id
if [ -z "$forest_id" ]; then
  echo "$T_SETUP_NO_FOREST"
  forest_id=0
fi

echo ""
echo "$T_SETUP_MODE_LABEL"
echo "$T_SETUP_MODE_AUTO"
echo "$T_SETUP_MODE_MANUAL"
echo ""
read -rp "${T_SETUP_MODE_PROMPT}: " mode
mode="${mode:-manual}"
if [ "$mode" != "auto" ] && [ "$mode" != "manual" ]; then
  mode="manual"
fi

read -rp "${T_SETUP_THRESHOLD_PROMPT}: " threshold
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

echo ""
echo "${T_SETUP_DONE_PREFIX} ${mode}, ${T_SETUP_DONE_THRESHOLD} ${threshold} kg CO2."
echo "$T_SETUP_DONE_HINT"
echo ""
