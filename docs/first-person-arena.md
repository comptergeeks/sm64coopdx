# First Person Arena prototype

Personal multiplayer experiment: preserve SM64 movement, add first-person weapons,
then add articulated ragdolls. This is a standalone mod; do not enable the bundled
Arena mod or other camera/game-mode mods alongside it.

## Implemented

- Existing coopdx first-person camera with mouse/controller look, upright roll and 80° FOV.
- Mario's existing movement and selected character model.
- Mouse 1 or the **R button binding** fires a hitscan weapon (6000 units, 12-tick cooldown).
- Host checks shot origin, direction, sequence, cooldown, area and wall collision,
  then selects the nearest player capsule. Crouching reduces hitbox height.
- Two health wedges per hit, brief invulnerability, native airborne knockback.
- Crosshair, shot flash, hit confirmation, and `/fps` view toggle.
- Normal SM64 death/warp behavior remains in use for now.

**This is not yet a ragdoll system or a finished deathmatch game.** There is no
weapon model, score screen, arena respawn system, lag compensation, or physical corpse.
Underwater hits damage without forcing an airborne knockback action.

## First session

1. Build the fork. Place your own supported ROM next to the executable; it loads
   original assets at runtime. Never commit the ROM or extracted assets.
2. Host a Direct Connection game and enable `First Person Arena (Prototype)`.
3. Have a friend join with the same fork/build. Select characters using coopdx's
   existing player settings. Enter the **same course, act and area as the host**.
4. Use the configured movement/jump/crouch controls. Mouse look aims; Mouse 1 or
   the configured R button fires. Map these bindings to your preferred keys.
5. Try a long jump while firing, wall occlusion, crouching under shots and warping.

The prototype intentionally requires the host in the combat area. The host only
has collision geometry loaded for its current area. Warps still connect the stages,
but fights away from the host are disabled. A later version needs area simulation
ownership or additional collision worlds to support simultaneous battles elsewhere.

### macOS development build

Install `make`, `pkgconf`, `glew` and SDL2 using Homebrew. This development command
uses Apple's preprocessor and disables optional Discord, CoopNet and auto-updater:

```sh
sh tools/build-fps-macos.sh
```

It produces `build/us_pc/Mario FPS.app`, a local development bundle linked to the
build resources and this Mac's Homebrew libraries. Put `baserom.us.z64` in
`build/us_pc/`. Direct Connection networking remains enabled. The launcher uses
separate save/config folders for host and client:

```sh
sh tools/run-fps-macos.sh host
sh tools/run-fps-macos.sh client 127.0.0.1
```

For a friend on the same network, replace `127.0.0.1` with the host's LAN address.
Internet connections need a reachable direct connection (or a future CoopNet-enabled build).
The bare macOS executable expects bundle-relative resources; launch the app's
executable through the script so mods and other resources are found correctly.

### Logic tests

From the repository root, using Lua 5.3 or newer:

```sh
lua tests/first-person-arena.lua
```

These test the geometry and engine adapter with controlled snapshots. They do not
replace a real two-player latency/playability test.

An optional engine probe lives at `tests/fps-network-probe.lua`. In an isolated
build, copy it to `build/us_pc/mods/first-person-arena/a-probe.lua` and launch two
**windowed** instances with the scripts above. It pins both players in Castle
Grounds, fires once from each, and prints `FPS_PROBE PASS` after receiving a hit.
Remove that copied file and restart both instances before normal play. Headless
instances are not playable targets and cannot substitute for a fighter in this test.

### Initial verification (2026-09-05)

- Apple Silicon native build completed using the command above.
- 28 Lua geometry/adapter checks passed.
- Computer-use inspection confirmed the first-person view, crosshair and a second player.
- Two real windowed instances joined over loopback, loaded the mod, fired in both
  directions, and each recorded exactly one hit (health 2176 → 1664).
- Internet latency, controller feel and ragdoll behavior are not yet tested.

## Networking limitations

The host adjudicates shots using its latest player positions, without rewind.
Fast movement/high ping can cause misses or origin rejection. Shot rays use the
camera orientation available at input time, before that tick's native camera update.

This version is for trusted friends. Upstream's Lua packet callback does not expose
authenticated sender identity; payload player IDs are not proof of identity. A
modified client can spoof requests/results. Do not treat this as anti-cheat or use
it for public competitive servers. Host validation is gameplay arbitration, not a
security boundary. Engine transport metadata is needed before hardening it.

## Next milestones

1. Play-test first-person movement and shooting on two machines; tune controls and latency.
2. Add a death/respawn state and cosmetic articulated corpses, preserving pose/velocity
   at death and applying shot impulses to the hit body part.
3. Add recoverable knockdowns with authoritative body position and safe get-up checks.
4. Support simultaneous battles in separate stages through area simulation ownership.

Start ragdolls with a small constrained skeleton and static-world collisions. Keep
ordinary Mario locomotion in control while alive. Cosmetic corpses can be simulated
locally from shared death events; bodies that affect gameplay require synchronization.
