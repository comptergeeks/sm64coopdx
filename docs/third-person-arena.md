# Mario Arena

A personal-use third-person shooter built on SM64coopdx, retaining Mario's native
movement. This mode adds a shoulder camera, pistol, bots, ragdolls, scores and respawns.

## Start playing on this Mac

Double-click **Play Mario Arena.command** in the repository to host a match.
Double-click **Join Mario Arena.command** to enter another host's IP address.
The native application is `build/us_pc/Mario Arena.app`.

From a terminal:

```sh
sh tools/build-arena-macos.sh
sh tools/run-arena-macos.sh host
# On a friend's machine with the same build:
sh tools/run-arena-macos.sh client HOST_IP
```

Each computer needs its own supported ROM for runtime assets. The ROM and extracted
assets are excluded from git. The build includes native renderer/model extensions;
copying only the Lua mod into an unmodified upstream game is insufficient.

For a local network, connect using the host's LAN address. For friends elsewhere,
use a reachable private-network address or configure UDP port 7777 on the host's
network. The development build has the CoopNet service disabled and uses Direct
Connection. The shipped `.app` references this checkout and local Homebrew libraries;
friends should build this fork on their own machine using the upstream build guide.

## Controls and commands

- Mouse/right stick: aim. The view always stays third person.
- Mouse 1, B binding, or R binding: fire. Holding fires repeatedly; it does not punch.
- L binding: switch shoulder.
- Native movement/jump/crouch controls: Mario movement, including acrobatics.
- Select Mario, Luigi, Toad, Waluigi or Wario in coopdx's player settings.
- `/bots 0` through `/bots 4`: set the host's Koopa opponent count (default two).
- `/stage bob`: move everyone to Bob-omb Battlefield. Other names: `castle`, `wf`,
  `jrb`, `ccm`, `bbh`, `hmc`, `lll`, `ssl`, `ddd`, `sl`, `wdw`, `ttm`, `thi`, `ttc`, `rr`.
- `/join`: travel to the host's current stage/area.
- `/match`: host resets scores, health and bots for a fresh match.
- `/scores`: show/hide the kill/death scoreboard.
- `/tps`: switch between shooter mode and the normal third-person camera.

Native doors, paintings and stage warps remain available. Players can fight in
another area while the lobby host stays elsewhere. Each occupied area elects its
lowest connected global player ID to resolve shots using locally loaded collision.
The lobby host records scores for the whole session. Bots currently inhabit the
host's area; use `/stage` to move the bot match together.

## Match behavior

Shots converge on the reticle from the hand-mounted pistol and stop at walls.
Humans take two health wedges per hit; bot shots deal one. Koopa bots have three
hits of health, display health bars, avoid hazardous ground, and respawn after
six seconds. They start firing after the first player shot.

Eliminated players ragdoll for three seconds, then respawn at recorded safe ground
with full health and three seconds of protection. If no safe point exists, the
area is re-entered at its native spawn. Respawns prefer distance from opponents.
The match is an open-ended free-for-all; `/match` starts a fresh score tally.

Player ragdolls use the selected character's actual mesh and palette, driven by a
constrained physics skeleton. Koopa corpses use the original body's component
meshes and persist for ten seconds. Ragdolls are cosmetic local simulations and
do not block movement or decide hits. Normal acrobatics and nonlethal knockback
retain native animations; ordinary movement uses a forward weapon-holding pose.

This is for trusted friends. Referee checks cover shape, origin, range, replay,
fire rate, area and wall collision, but Lua packets are not an authenticated
anti-cheat boundary. There is no competitive lag compensation or public-server
hardening. Custom character packs with incompatible skeletons are not validated.

## Verification

```sh
lua tests/third-person-arena.lua
lua tests/tps-weapon.lua
```

Real-engine fixtures live in `tests/tps-*-probe.lua`. They are opt-in development
tests that automate shots, positions, deaths or stage changes. Never include them
in a normal session; the build script removes `a-probe.lua` from the built mod.

Validated on this Mac: bot aiming/elimination/respawn; all five built-in character
holding poses/ragdolls/respawns; bidirectional two-player hits; multiplayer lethal
hits, scoring, respawn and stage travel; and three-process combat in an area away
from the host, including global score propagation. Remote internet latency has
not been play-tested with a friend.
