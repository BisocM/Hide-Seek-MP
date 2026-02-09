# Hide & Seek \[MP] (Teardown)

A multiplayer hide & seek gamemode for Teardown with a clean, modern HUD, round flow, and configurable rules.

## Features

- Team selection + host settings menu
- Round flow: Setup → Hiding → Seeking → Intermission
- Tagging mode (seekers catch hiders with `E`) or damage-based catching
- Optional infection mode (caught hiders convert to seekers for the current round)
- Hider abilities: Dash + Super Jump (cooldown-based, optional)
- Seeker-only hider trails (optional)
- Spectating after elimination (follows a living teammate when possible)
- Time synchronization for consistent timers across clients
- Localization: English + Russian (uses the game language setting)

## Install

1. Place this folder in your Teardown mods directory (Steam default):
   - Windows: `Documents/Teardown/mods/Hide & Seek [MP]/`
2. Ensure `gamemodes.txt` is present in the mod root.
3. Launch Teardown and select the **Hide and Seek** gamemode when starting a multiplayer session.

## How To Play

1. Host starts the session and opens the gamemode setup menu.
2. Players pick teams in the team selection screen.
3. The host starts the match.
4. **Hiding phase:** seekers are locked/blinded while hiders move.
5. **Seeking phase:** seekers hunt hiders until time runs out or all hiders are caught.
6. **Intermission:** short break, then the next round begins.

## Controls

- **Tag (Seekers):** `E` (Interact) when tagging is enabled.
  - A hand icon prompt appears when a hider is in range and in the crosshair.
- **Dash (Hiders):** `Q`
- **Super Jump (Hiders):** `F` to arm, then your next jump triggers the boost.
- **Admin menu (Host):** `F6` (also available as **HS Admin** in the pause menu)

Key bindings for abilities are defined in `hs/shared/input.lua:1`.

## Settings (Host)

Settings are grouped in the host menu and persisted in the savegame.

**Loadouts (Host/Admin)**
- Host-only admin menu to assign which team can use each tool/weapon (Off / Seekers / Hiders / Both)
- Includes one-click actions like "Disable all" and a "Refresh tools" button to detect modded tools

**Round**
- Hiding time
- Seeking time
- Intermission time
- Rounds (0 = infinite)

**Teams**
- Infection mode (caught hiders become seekers for the current round)
- Swap roles each round (seekers/hiders swap between rounds)
- Max team difference (limits team stacking)

**Tagging**
- Tagging enabled (seekers catch via `E`)
- Tag only (disables PvP damage; catching is via tagging only)
- Tag range

**Gameplay**
- Seeker grace (absolute invulnerability for seekers for a few seconds after seeking starts)
- Hiders can kill seekers (enables PvP damage from hiders to seekers outside grace)
- Hider abilities (dash/super jump)
- Health regeneration
- Hider trail
- Seeker map (allow/disallow seekers opening the map)

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

- `hs/` – gamemode code (server/client/shared)
- `ui/` – icons and UI assets
- `gamemodes.txt` – gamemode registration for Teardown