# Battlefront-inspired death impacts

The reference is interpreted as DICE's Star Wars Battlefront II (2017).
No verified numerical death-impulse values were found in the public sources below.
This tuning is an adaptation for SM64's scale and 30 Hz simulation, not a copy of
Frostbite's implementation or a claim about its force constants.

## Primary sources

- [EA/Frostbite, GDC 2018: Physics Driven Ragdolls and Animation at EA: From Sports to Star Wars](https://www.gdcvault.com/play/1025210/Physics-Driven-Ragdolls-and-Animation).
  The session describes animation-following physics, interaction-driven reactions,
  avoiding bad poses, performance and networking. Its public overview does not
  provide Battlefront weapon/death impulse parameters.
- [StarWars.com: The Making of Star Wars Battlefront II](https://www.starwars.com/news/the-making-of-star-wars-battlefront-ii).
  The developer interview describes enabling physics for Force knockback and
  recovering afterward. That is a Force ability discussion, not a numerical
  description of blaster deaths.

## Applied design

The previous implementation launched every joint with the same horizontal kick
and a fixed upward boost. It also discarded the victim's running/jumping velocity
and stopped physics after 120 ticks, even if the body was still falling.

The replacement preserves 85% of pre-hit velocity, adds a directional whole-body
kick, and adds a stronger local impulse near the actual ray impact. Different
joint velocities create torque, so opposite-side hits tumble differently. The
hit point and original velocity travel with the synchronized death state.
Environmental deaths inherit motion without inventing a blaster impulse.

Mass-weighted constraints make the torso harder to displace than extremities.
Pose-support braces relax over eight ticks while anatomical links retain their
lengths. This is a lightweight approximation of a controlled-to-passive transition;
it does not implement Frostbite's animation-following controller.

Contact friction is applied once per simulation tick, rather than once on each of
eight constraint iterations. A small bounce remains. Sleeping requires sustained
low energy and at least two ground contacts; elapsed age alone cannot freeze a fall.
Existing corpse expiry and player respawn times still apply.

## Current tuning

`FpsRagdoll.impactProfile` in `ab-ragdoll.lua` centralizes the art-directed values:

| Setting | Value | Meaning |
| --- | ---: | --- |
| bodyKick | 7 | directional velocity added to all joints |
| localKick | 16 | additional velocity at the impact point |
| lift | 2 | modest upward velocity for blaster deaths |
| spread | 75 | impact falloff radius in SM64 world units |
| inherit | 0.85 | fraction of pre-hit movement retained |
| maxSpeed | 38 | maximum initial joint speed |

Velocity values use world units per tick, not Newtons. These are this project's
chosen values, not measured Battlefront numbers. No explosion or Force-power
weapon has been added; the change applies to existing death ragdolls.

Run `lua tests/tps-ragdoll-impact.lua` for direction/torque, momentum inheritance,
lift, environmental falls, speed bounds, settling and joint-length regressions.
