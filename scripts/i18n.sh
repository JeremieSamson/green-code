#!/usr/bin/env bash
# green-code i18n: detects locale from $LANG and exposes T_* translation
# variables. Source this from any other script before using T_* vars.
# Supported languages: en (default), fr.

_green_detect_lang() {
  local lc="${LANG:-${LC_MESSAGES:-${LC_ALL:-C}}}"
  lc="${lc%%.*}"
  lc="${lc%%_*}"
  case "$lc" in
    fr) echo "fr" ;;
    *)  echo "en" ;;
  esac
}

GREEN_LANG="$(_green_detect_lang)"

if [ "$GREEN_LANG" = "fr" ]; then
  # session-start.sh
  T_EMITTED="émis"
  T_TREES_PLANTED="arbres plantés"
  T_DEBT="dette"
  T_NEXT_TREE="Prochain arbre"
  T_TREES_OWED_LABEL="arbres dus"
  T_CARBON_NEUTRAL="Carbone neutre"

  # setup.sh
  T_SETUP_HEADER="=== Configuration green-code ==="
  T_SETUP_DESC_1="Ce plugin trace ton empreinte carbone IA"
  T_SETUP_DESC_2="et te permet de planter des arbres via Tree-Nation pour compenser."
  T_SETUP_TOKEN_NEED="Il te faut un token API Tree-Nation."
  T_SETUP_TOKEN_REQUEST="Demande-le sur : https://kb.tree-nation.com/knowledge/api-availability"
  T_SETUP_TOKEN_EMAIL="Ou par email : integration@tree-nation.com"
  T_SETUP_TOKEN_PROMPT="Token API Tree-Nation"
  T_SETUP_NO_TOKEN="Aucune clé API fournie. Lance /green:config plus tard pour configurer."
  T_SETUP_FOREST_PROMPT="Forest ID Tree-Nation (numérique)"
  T_SETUP_NO_FOREST="Aucun forest ID fourni. Lance /green:config plus tard pour le définir."
  T_SETUP_MODE_LABEL="Mode :"
  T_SETUP_MODE_AUTO="  auto   - Plante un arbre automatiquement quand le seuil est atteint"
  T_SETUP_MODE_MANUAL="  manual - Trace seulement, plante manuellement avec /green:plant"
  T_SETUP_MODE_PROMPT="Mode [manual]"
  T_SETUP_THRESHOLD_PROMPT="Seuil CO2 par arbre en kg [10]"
  T_SETUP_DONE_PREFIX="green-code configuré ! Mode :"
  T_SETUP_DONE_THRESHOLD="seuil :"
  T_SETUP_DONE_HINT="Utilise /green:status pour voir ton empreinte carbone."

  # treenation.sh (text after OK:/ERROR: protocol prefix)
  T_TN_NOT_CONFIGURED="green-code n'est pas configuré. Lance /green:config"
  T_TN_JQ_REQUIRED="jq est requis"
  T_TN_NO_API_KEY="Aucune clé API Tree-Nation configurée. Lance /green:config"
  T_TN_NO_FOREST="Aucun forest ID Tree-Nation configuré. Lance /green:config"
  T_TN_TREES_PLANTED="arbres plantés"
  T_TN_OFFSET="kg CO2 compensés"
  T_TN_USAGE="Usage : treenation.sh {plant [N]|forest|species [project_id]}"
else
  # session-start.sh
  T_EMITTED="emitted"
  T_TREES_PLANTED="trees planted"
  T_DEBT="debt"
  T_NEXT_TREE="Next tree"
  T_TREES_OWED_LABEL="trees owed"
  T_CARBON_NEUTRAL="Carbon neutral"

  # setup.sh
  T_SETUP_HEADER="=== green-code setup ==="
  T_SETUP_DESC_1="This plugin tracks your AI carbon footprint and lets you"
  T_SETUP_DESC_2="plant trees via Tree-Nation to compensate."
  T_SETUP_TOKEN_NEED="You need a Tree-Nation API token."
  T_SETUP_TOKEN_REQUEST="Request one at: https://kb.tree-nation.com/knowledge/api-availability"
  T_SETUP_TOKEN_EMAIL="Or email: integration@tree-nation.com"
  T_SETUP_TOKEN_PROMPT="Tree-Nation API token"
  T_SETUP_NO_TOKEN="No API key provided. Run /green:config later to set it up."
  T_SETUP_FOREST_PROMPT="Tree-Nation Forest ID (numeric)"
  T_SETUP_NO_FOREST="No forest ID provided. Run /green:config later to set it."
  T_SETUP_MODE_LABEL="Mode:"
  T_SETUP_MODE_AUTO="  auto   - Plant a tree automatically when threshold is reached"
  T_SETUP_MODE_MANUAL="  manual - Track only, plant manually with /green:plant"
  T_SETUP_MODE_PROMPT="Mode [manual]"
  T_SETUP_THRESHOLD_PROMPT="CO2 threshold per tree in kg [10]"
  T_SETUP_DONE_PREFIX="green-code configured! Mode:"
  T_SETUP_DONE_THRESHOLD="threshold:"
  T_SETUP_DONE_HINT="Use /green:status to see your carbon footprint."

  # treenation.sh (text after OK:/ERROR: protocol prefix)
  T_TN_NOT_CONFIGURED="green-code not configured. Run /green:config"
  T_TN_JQ_REQUIRED="jq is required"
  T_TN_NO_API_KEY="No Tree-Nation API key configured. Run /green:config"
  T_TN_NO_FOREST="No Tree-Nation forest ID configured. Run /green:config"
  T_TN_TREES_PLANTED="trees planted"
  T_TN_OFFSET="kg CO2 offset"
  T_TN_USAGE="Usage: treenation.sh {plant [N]|forest|species [project_id]}"
fi
