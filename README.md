# Hide & Seek \[MP] (Teardown)

[![Steam Workshop](https://img.shields.io/badge/Steam-Workshop%20Page-blue?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=3624969238)

A multiplayer hide & seek gamemode for Teardown with a clean, modern HUD, round flow, and configurable rules.

## Features

- Team selection during setup (Seekers/Hiders/Spectator)
- Host-controlled match start
- Round flow: Setup → Hiding → Seeking → Intermission
- Tagging mode (seekers catch hiders with `E`) and damage/elimination handling
- Optional infection mode (caught hiders convert to seekers for the current round)
- Hider abilities: Dash + Super Jump (cooldown-based)
- Spectating after elimination
- Time synchronization for consistent timers across clients
- Localization: English + Russian (uses the game language setting)

## Install

1. Place this folder in your Teardown mods directory (Steam default):
   - Windows: `Documents/Teardown/mods/Hide & Seek [MP]/`
2. Ensure `gamemodes.txt` is present in the mod root.
3. Launch Teardown and select the **Hide and Seek** gamemode when starting a multiplayer session.

## How To Play

1. Host starts the session.
2. Players pick teams in setup (`Q` seekers, `F` hiders, `X` spectator).
3. Host starts the match (`F6`).
4. **Hiding phase:** seekers are locked/blinded while hiders move.
5. **Seeking phase:** seekers hunt hiders until time runs out or all hiders are caught.
6. **Intermission:** short break, then the next round begins.

## Controls

- **Tag (Seekers):** `E` (Interact) when tagging is enabled.
- **Dash (Hiders):** `Q`
- **Super Jump (Hiders):** `F` to arm, then your next jump triggers the boost.
- **Team Select (Setup):**
  - `Q` join Seekers
  - `F` join Hiders
  - `X` switch to Spectator
- **Start Match (Host):** `F6`

Key bindings for abilities are defined in `hs/shared/input.lua:1`.

## Settings (Host)

Host settings are normalized by `hs/shared/settings.lua` and applied through `start_match`.
Key groups include:
- Round timing and round count
- Team rules (infection, swap roles, max team difference)
- Tagging rules (enabled, range, tag-only mode)
- Gameplay toggles (seeker grace, hider abilities, regeneration, trails, seeker map)
- Loadout policy in `settings.loadout`

## Team Balance & Join-In-Progress

- **Join-in-progress:** players who connect mid-match are moved to spectator and auto-assigned for the next round.
- **Per-round balancing:** at the start of each round, the gamemode restores intended roles, assigns late joiners, ensures at least one seeker and one hider, then balances teams to satisfy `maxTeamDiff` (with sensible handling for odd player counts).
- **Swap roles each round:** swapping is based on each player’s intended round role, so infection conversions during a round do not break the next round’s swap.

## Localization

The gamemode uses the game language setting to select translations. English (`en`) and Russian (`ru`) are included in `hs/shared/i18n.lua:1`.

## Troubleshooting

- **Selected gamemode but loaded into sandbox:** verify `gamemodes.txt` exists and points to `hs/main.lua`.
- **Missing icons:** icons are loaded from `ui/icons/*.png`. If your Teardown build does not support image probing, icons are still drawn by path.
- **Logs:** the mod prints lines prefixed with `[HS]` via Teardown’s logging/console mechanisms (`DebugPrint`/`print`). Where they appear depends on your Teardown version and platform.

## License

Apache License 2.0. See `LICENSE` and `NOTICE`.

## Project Layout

- `hs/domain` – deterministic gameplay/domain rules
- `hs/app` – orchestration, command intake, reducer execution, stores
- `hs/infra` – Teardown-facing transport/adapters (RPC ingress, effects, snapshot writer)
- `hs/contracts` – command/event/snapshot contract schemas + validation
- `hs/presentation/client` – client presentation runtime
- `hs/` – active runtime modules used by the game mode
- `ui/` – icons and UI assets
- `gamemodes.txt` – gamemode registration for Teardown
