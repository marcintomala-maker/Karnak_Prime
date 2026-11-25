class_name Defs
extends RefCounted
## Tuning values in one place.

# --- player
const MAX_HEALTH := 6000.0
const MAX_TOXIC := 6000.0
const WALK_SPEED := 4.6
const SPRINT_SPEED := 7.6
const JUMP_VELOCITY := 5.2
const GRAVITY := 18.0
const DASH_SPEED := 21.0
const DASH_TIME := 0.3
const DASH_COOLDOWN := 0.5
const WATER_TOXIC_PER_SEC := MAX_TOXIC / 3.0     # knee deep: 0 -> 100 % in 3 s
const KNEE_DEPTH := 0.45

# --- noise radii (m) shown by the white rings
const NOISE_WALK := 3.5
const NOISE_SPRINT := 14.0
const NOISE_SHOT := 22.0
const NOISE_DASH := 6.0

# --- lantern (seconds of charge)
const LANTERN_FULL := 120.0
const LANTERN_FADE := 60.0
const LANTERN_MAX := LANTERN_FULL + LANTERN_FADE
const LANTERN_REGEN := 5.0

# --- flare
const FLARE_COOLDOWN := 5.0
const FLARE_LIFE := 10.0
const FLARE_FADE := 5.0
const FLARE_RANGE := 20.0

# --- weapons
const CHAINGUN := {"ammo": 300, "rate": 12.0, "damage": 10.0, "spread": 0.9, "regen_delay": 1.0, "regen_time": 10.0}
const LASGUN := {"ammo": 150, "rate": 4.0, "damage": 30.0, "spread": 0.25, "regen_delay": 1.0, "regen_time": 10.0}
const BUILD_POINTS := 400.0
const BUILD_REGEN := 400.0 / 75.0          # per second
const REPAIR_RANGE := 2.2
const REPAIR_TICK := 0.25
const REPAIR_AMOUNT := 2.0
const MAX_PLAYER_BUILDINGS := 10

# --- buildables: cost, energy, hp, build time (s)
const BUILDABLES := {
	"reactor":   {"name": "REACTOR", "cost": 400, "energy": 0, "hp": 200.0, "time": 20.0, "model": "reactor", "size": 3.2},
	"medstation":{"name": "MED STATION", "cost": 300, "energy": 1, "hp": 220.0, "time": 10.0, "model": "medistat", "size": 2.4},
	"mgturret":  {"name": "MG TURRET", "cost": 200, "energy": 1, "hp": 250.0, "time": 10.0, "model": "mgturret", "size": 2.0},
	"rocket":    {"name": "ROCKET TURRET", "cost": 400, "energy": 1, "hp": 250.0, "time": 15.0, "model": "rocketpod", "size": 2.2},
	"bomb":      {"name": "BOMB", "cost": 100, "energy": 0, "hp": 80.0, "time": 2.0, "model": "drill", "size": 1.6},
	"destroyer": {"name": "OVERMIND DESTROYER", "cost": 50, "energy": 1, "hp": 400.0, "time": 6.0, "model": "telenode", "size": 3.0},
}
const BUILD_ORDER := ["reactor", "medstation", "mgturret", "rocket", "bomb", "destroyer"]
const REACTOR_RANGE := 15.0
const REACTOR_ENERGY := 2
const MED_POOL := 3000.0
const MED_RATE := 200.0
const MG_SHOTS := 200
const MG_RANGE := 24.0
const MG_CONE := 120.0
const ROCKETS := 40
const ROCKET_RANGE := 45.0
const ROCKET_DAMAGE := 260.0
const ROCKET_RADIUS := 4.5
const BOMB_RADIUS := 10.0
const BOMB_PLAYER_DAMAGE := 5000.0
const DESTROYER_RANGE := 40.0
const DESTROYER_TIME := 60.0
const DESTROYER_PLACE_RANGE := 30.0

# --- aliens  (speed m/s, hp, size = model length/height target in m)
const ALIENS := {
	"mantis":   {"hp": 100.0, "speed": 9.2, "size": 2.2, "model": "aliens/mantis", "attack": 12.0, "toxic": 5.0},
	"marauder": {"hp": 100.0, "speed": 8.6, "size": 2.0, "model": "aliens/marauder", "attack": 42.0, "toxic": 0.0},
	"dragoon":  {"hp": 3000.0, "speed": 10.5, "size": 3.4, "model": "aliens/dragoon", "attack": 321.0, "pounce": 534.0, "toxic": 0.0},
	"granger":  {"hp": 20.0, "speed": 8.8, "size": 1.5, "model": "aliens/granger", "attack": 13.0, "toxic": 20.0},
	"trapper":  {"hp": 60.0, "speed": 6.5, "size": 1.8, "model": "buildables/trapper", "attack": 0.0, "toxic": 0.0},
	"tyrant":   {"hp": 5660.0, "speed": 4.6, "size": 6.4, "model": "aliens/tyrant", "attack": 504.0, "toxic": 0.0},
}
const STATIC_HP := {"egg": 10.0, "acid_tube": 30.0, "barricade": 1500.0, "booster": 10.0}
const ALERT_GRACE := 1.5
const ALLY_ALERT_RADIUS := 20.0
const UNAWARE_MULT := 2.0

# --- toxic clouds: damage per second inside, lifetime = 2 s per metre of size
const CLOUD_TOXIC_DPS := 600.0

# --- director
const MAX_MOBILE := 34
const AMBIENT_TARGET := 16
const DESPAWN_DIST := 150.0
const SPAWN_MIN := 45.0
const SPAWN_MAX := 110.0
const EGG_TOTAL := 621
const OVERMIND_TOTAL := 6
