---
name: config
description: Configure the green-code plugin - set Tree-Nation API key, planter ID, mode (auto/manual), CO2 threshold, and energy mix. Use when the user wants to set up or modify green-code settings.
---

# green-code: Configuration

Read and modify the green-code plugin configuration.

## Config file

Location: `~/.claude/plugins/data/green-code/config.json`

Fields:
- `treenation_api_key` (string) -- Tree-Nation Bearer token
- `planter_id` (string) -- Tree-Nation planter/user ID
- `mode` (string) -- "auto" or "manual"
- `threshold_co2_kg` (number) -- kg CO2 per tree, default 10
- `co2_grams_per_kwh` (number) -- carbon intensity, default 380 (US mix)
- `pue` (number) -- Power Usage Effectiveness, default 1.2

## Behavior

**If called without arguments** (`/green:config`):
- Read the config file and display current settings
- Mask the API key (show first 4 chars + "..." + last 4 chars)
- Show the mode with a brief explanation

**If called with arguments** (e.g., `/green:config mode auto`):
- Parse the argument as `key value`
- Validate:
  - `mode` must be "auto" or "manual"
  - `threshold_co2_kg` must be a positive number
  - `co2_grams_per_kwh` must be a positive number
  - `pue` must be between 1.0 and 2.0
  - `treenation_api_key` and `planter_id` accept any non-empty string
- Update the config file using jq or direct JSON edit
- Confirm the change

## If config file doesn't exist

Run the setup script:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh"
```

Or create the config directory and file manually by asking the user for each field.

## After config creation or update

If `~/.claude/plugins/data/green-code/usage.json` does not exist, run the bootstrap script to perform an initial analysis of historical token usage:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh"
```

This reads `~/.claude/stats-cache.json`, computes accumulated CO2 from all past usage, and creates `usage.json`. Show the bootstrap output to the user.

## Display format

    green-code -- Configuration

      API Key:      abc1...xyz9
      Planter ID:   12345
      Mode:         manual (track only, plant with /green:plant)
      Threshold:    10 kg CO2 per tree
      Energy mix:   380 gCO2/kWh (US average)
      PUE:          1.2

      To change: /green:config <key> <value>
      Keys: mode, threshold_co2_kg, co2_grams_per_kwh, pue, treenation_api_key, planter_id
