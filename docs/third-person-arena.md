# Third Person Arena prototype

Personal SM64coopdx shooter experiment. Enable only this game-mode mod.

## Play

Build on macOS with `sh tools/build-arena-macos.sh`, then launch with
`sh tools/run-arena-macos.sh host`. Join with
`sh tools/run-arena-macos.sh client HOST_IP`. Each player needs their own supported
ROM and the same build. ROMs and extracted assets are excluded from git.

- Mouse/right stick: aim using the shoulder camera.
- Mouse 1, B or R binding: fire. B is consumed so firing does not punch/kick.
- L binding: switch shoulder.
- Native movement/jump/crouch controls retain Mario movement.
- `/bots 0` through `/bots 4`: host sets Koopa opponent count (default two).
- `/tps`: toggle shooter mode and the normal third-person camera.
- Choose characters through coopdx's existing player settings.

The shared pistol follows the animated right hand. Normal standing, running and
jumping use forward holding poses; special acrobatics retain their native poses.
The camera stays third person, checks walls and converges shots on the reticle.

## Combat and limitations

Host resolves wall-obstructed hitscan shots, sequence/cooldown/area checks and
player capsule hits. Human shots deal two wedges; bot shots deal one. Bots roam,
fire after the first player shot, die in three hits and respawn after six seconds.
Death creates a cosmetic constrained ragdoll made of simple proxy parts; this is
not yet the selected character's fully skinned body or a networked physics body.

All fighting players must be in the host's course, act and area because only that
area's collision is loaded on the host. Native stage warps remain available.
Other-area simulation, lag compensation and a full deathmatch respawn/scoreboard
are not implemented. Use trusted friends: Lua shot validation is not an
anti-cheat/authenticated sender boundary.

## Validation

`lua tests/third-person-arena.lua` checks shot geometry, wall/area isolation,
replays, cooldowns, third-person camera, bot lifecycle, ragdoll constraints and
consumption of both attack bindings. `tests/tps-network-probe.lua` is an optional
isolated engine fixture; never include it in a normal play session.

The macOS app bundle is for this development machine and references local build
resources and Homebrew libraries. It is not a standalone distributable.
