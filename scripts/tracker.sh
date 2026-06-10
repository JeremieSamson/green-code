#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"
USAGE_FILE="${DATA_DIR}/usage.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

[ -f "$CONFIG_FILE" ] || exit 0
command -v jq &>/dev/null || exit 0
command -v bc &>/dev/null || exit 0

hook_input=$(cat 2>/dev/null || true)
transcript_path=$(jq -r '.transcript_path // empty' <<<"$hook_input" 2>/dev/null || true)
session_id=$(jq -r '.session_id // empty' <<<"$hook_input" 2>/dev/null || true)
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0
[ -n "$session_id" ] || exit 0

# Bootstrap usage.json if missing (fallback for manual config setup)
if [ ! -f "$USAGE_FILE" ]; then
  "${PLUGIN_ROOT}/scripts/bootstrap.sh" >/dev/null 2>&1 || exit 0
  [ -f "$USAGE_FILE" ] || exit 0
fi

pue=$(jq '.pue // 1.15' "$CONFIG_FILE")
co2_g_per_kwh=$(jq '.co2_grams_per_kwh // 320' "$CONFIG_FILE")
threshold=$(jq '.threshold_co2_kg // 10' "$CONFIG_FILE")
mode=$(jq -r '.mode // "manual"' "$CONFIG_FILE")

# Token source: the current session transcript (plus its subagent transcripts).
# ~/.claude/stats-cache.json is no longer written by recent Claude Code
# versions, so usage is read straight from the session JSONL files. Lines are
# deduplicated by message id (the same message is appended several times as
# streaming progresses).
transcripts=("$transcript_path")
subagents_dir="${transcript_path%.jsonl}/subagents"
if [ -d "$subagents_dir" ]; then
  while IFS= read -r f; do transcripts+=("$f"); done \
    < <(find "$subagents_dir" -name '*.jsonl' -type f)
fi

cur=$(jq -nR '
  [ inputs | fromjson? | .message?
    | select(. != null and .usage != null and .id != null and .model != null)
    | select(.model != "<synthetic>")
    | {id, model, usage} ]
  | group_by(.id) | map(.[-1])
  | group_by(.model)
  | map({key: .[0].model, value: {
      inputTokens: ([.[].usage.input_tokens // 0] | add),
      outputTokens: ([.[].usage.output_tokens // 0] | add),
      cacheReadInputTokens: ([.[].usage.cache_read_input_tokens // 0] | add),
      cacheCreationInputTokens: ([.[].usage.cache_creation_input_tokens // 0] | add)
    }})
  | from_entries
  ' "${transcripts[@]}")

[ "$cur" = "{}" ] && exit 0

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CUTOFF=$(date -u -d "30 days ago" +%Y-%m-%dT%H:%M:%SZ)

# Per-model energy in Wh per output token. Other token types are derived as
# ratios of the model's output cost (aligned with Anthropic API pricing tiers,
# which track compute cost). Sources: TokenPowerBench (AAAI 2026), Luccioni et
# al. 2024, Anthropic prompt-caching docs (~90% reduction for cache reads).
#   ratios: input=0.20, cache_create=0.25, cache_read=0.02 (relative to output)
jq \
  --argjson cur "$cur" \
  --arg sid "$session_id" \
  --arg ts "$NOW" \
  --arg cutoff "$CUTOFF" \
  --argjson pue "$pue" \
  --argjson g "$co2_g_per_kwh" \
  '
  def base_wh(name):
    if   name | test("opus")   then 0.002
    elif name | test("sonnet") then 0.0008
    elif name | test("haiku")  then 0.0003
    else                            0.001
    end;
  def clamp: if . < 0 then 0 else . end;
  (.sessions[$sid].models // {}) as $prev |
  ([ $cur | to_entries[] |
    . as $m |
    base_wh($m.key) as $b |
    ($prev[$m.key] // {}) as $p |
    (($m.value.outputTokens // 0) - ($p.outputTokens // 0) | clamp) as $do |
    (($m.value.inputTokens // 0) - ($p.inputTokens // 0) | clamp) as $di |
    (($m.value.cacheCreationInputTokens // 0) - ($p.cacheCreationInputTokens // 0) | clamp) as $dcc |
    (($m.value.cacheReadInputTokens // 0) - ($p.cacheReadInputTokens // 0) | clamp) as $dcr |
    ($do * $b + $di * $b * 0.20 + $dcc * $b * 0.25 + $dcr * $b * 0.02)
  ] | add // 0 | . / 1000 * $pue) as $dkwh |
  del(.lastSnapshot, .lastSnapshotTimestamp) |
  .sessions = ((.sessions // {}) | with_entries(select(.value.updatedAt > $cutoff))) |
  .sessions[$sid] = {updatedAt: $ts, models: $cur} |
  .accumulated.kwh = ((.accumulated.kwh // 0) + $dkwh) |
  .accumulated.co2_kg = ((.accumulated.co2_kg // 0) + ($dkwh * $g / 1000))
  ' "$USAGE_FILE" > "${USAGE_FILE}.tmp" && mv "${USAGE_FILE}.tmp" "$USAGE_FILE"

if [ "$mode" = "auto" ]; then
  new_co2=$(jq '.accumulated.co2_kg // 0' "$USAGE_FILE")
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
