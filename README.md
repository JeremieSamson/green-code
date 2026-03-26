# green-code

Track your AI carbon footprint and plant trees to compensate.

## What it does

- Silently tracks your Claude Code token consumption at each session end
- Estimates energy use (kWh) and CO2 emissions based on published research
- Two modes: **auto** (plant trees automatically at threshold) or **manual** (track and plant on demand)
- Plants real trees via [Tree-Nation](https://tree-nation.com) API

## Install

```bash
/plugin marketplace add jsamson/green-code
/plugin install green-code@green-code-marketplace
```

On first launch, the plugin asks for your Tree-Nation API token and preferences.

## Commands

| Command | Description |
|---------|-------------|
| `/green:status` | View your carbon footprint and tree balance |
| `/green:plant` | Plant trees to offset accumulated CO2 |
| `/green:plant 3` | Plant a specific number of trees |
| `/green:config` | View current configuration |
| `/green:config mode auto` | Switch to auto-plant mode |

## How it works

### Token tracking

At each session end, the plugin reads `~/.claude/stats-cache.json` and computes the delta since the last check.

### Energy estimation

| Token type | Wh per token | Rationale |
|------------|-------------|-----------|
| Output (generation) | 0.002 | Full GPU forward pass + sampling |
| Input (fresh) | 0.0005 | Prefill, parallelizable |
| Cache creation | 0.0005 | Same as prefill |
| Cache read | 0.00002 | Memory I/O, minimal compute |

### CO2 conversion

- Default: US energy mix at 380 gCO2/kWh (IEA 2024)
- PUE 1.2 for datacenter overhead (cooling, networking)
- 1 tree = 10 kg CO2 (configurable)

### Tree-Nation

Trees are planted via the [Tree-Nation REST API](https://kb.tree-nation.com/knowledge/api-availability). You need a Tree-Nation account and API token.

## Sources

- IEA, "Electricity 2024" -- iea.org/reports/electricity-2024
- de Vries A., "The growing energy footprint of AI", Joule 2023
- Luccioni et al., "Power Hungry Processing", ACM FAccT 2024
- Patterson et al., "Carbon Footprint of ML Training", IEEE 2022

## Limitations

- Energy estimates have ~x2 uncertainty -- no AI provider publishes per-token energy data
- Claude's exact architecture (dense vs MoE) is not public
- CO2 depends on datacenter location; US mix is the default assumption
- `stats-cache.json` may not update in real-time in all Claude Code versions

## Prerequisites

- `jq` (JSON processor) -- install: `sudo apt install jq` / `brew install jq`
- `bc` (calculator) -- usually pre-installed on Linux/macOS
- `curl` -- usually pre-installed
- Tree-Nation account + API token

## License

MIT
