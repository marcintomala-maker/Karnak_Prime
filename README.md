# Karnak Prime

A short sci-fi horror FPS made in **Godot 4.7** from free, human-made assets by the
**Unvanquished**, **Duelyst** (OpenDuelyst, CC0) and **0 A.D.** projects. Full credits are in
[`CREDITS.txt`](CREDITS.txt) and in the game's Credits menu.

## Run / build
* Open the folder in **Godot 4.7.x** (standard build, not .NET) and press Play.
* Windows build: *Project → Export → Windows Desktop* (preset included). Prebuilt zips are on the
  GitHub Releases page.
* Dev flags (after `--`): `--skip-intro` (straight to menu), `--game` (straight into a mission).

## Controls
| Action | Key |
|---|---|
| Move | W A S D |
| Sprint (louder) | Shift |
| Dash (left / right / back; no input = back) | Space |
| Jump | Space while holding W (forward dodges are not allowed, so forward + Space jumps) |
| Fire / repair beam | Left mouse |
| Flare | Right mouse |
| Lantern on/off | Tab |
| Build menu (construction kit only) | F |
| Weapons | 1 kit, 2 chaingun, 3 lasgun · E / Q · mouse wheel |
| Pause | Esc |

## Objectives
1. Destroy all **621 eggs** (clusters of 3-6 on walls and streets).
2. Destroy all **6 Overminds** (bullet- and bomb-proof). Build an *Overmind Destroyer* near
   one (needs a Reactor in range), then survive the 60 s **SWARM** within 40 m of it.

## Project layout
```
assets/        converted models (glb), textures, sounds (ogg), music, UI sprites, world data
scripts/       autoload (settings, sound, flow, overlay) · game · player · aliens · buildables · ui · world · fx
shaders/       building cladding, terrain, toxic water, ground fog, holograms
tools/         Python pipeline used to convert the source assets and generate the world (run once)
tests/         headless smoke tests used during development
```

## How it was made (truthfully)
* **World**: generated **once** by `tools/worldgen.py` (seeded) and shipped as data:
  heightfield, nav heights, water levels, walkability and city layout. Objectives, eggs,
  traps and aliens are **randomised every mission** at runtime.
* **Models**: Unvanquished `.iqe` → glTF with a custom converter (skeletons + all animations
  kept). 0 A.D. `.dae` → glTF (geometry only); their own textures are replaced in-game by
  world-projected Unvanquished sci-fi textures.
* **Things that are code-drawn, not image files**: the HUD frame/scanner/arcs, the hexagram
  and triangle lines of the sacred geometry (the rings themselves are Duelyst sprites), the
  ziggurat/bridges (boxes clad in Unvanquished textures), the crashed capsule shell, the noise
  rings and holograms, and the sunrise sky gradient in the ending. **No AI-generated images
  or sounds are used anywhere.**

## Known gaps / substitutions
* Unvanquished's asset repositories contain **no music tracks**, so in-game music uses dark
  Duelyst tracks (Abyssian, Duskfall, Age of Disjunction) plus Unvanquished ambient wind and drones.
* There is **no breathing sample** in the packs; heavy toxicity plays the Unvanquished heartbeat instead.
* The Unvanquished **Repeater model no longer exists**: it became the Drill. The Bomb uses the
  Drill model (as requested), so the Overmind Destroyer uses the Telenode model + Repeater sounds.
* The Trapper is a stationary turret in Unvanquished; here its model is used as a mobile alien
  (it has no walk animation, so it skitters in its idle pose).
* Wall-climbing is a visual approximation (aliens turn to the wall and crawl up its face);
  pathfinding is on a 2 m grid.
* The chaingun view model's upstream source (a Sketchfab model linked from the Unvanquished
  repo) should have its license double-checked before any commercial release.
* Duelyst's commercial fonts (Trump Gothic, Averta) are **not** used; only Lato (SIL OFL).

## Licenses
Code: MIT (see `LICENSE`). Assets keep their original licenses (see `CREDITS.txt`): many are
CC BY-SA, so modified assets must stay CC BY-SA and be credited. Selling the game is allowed
by these licenses.
