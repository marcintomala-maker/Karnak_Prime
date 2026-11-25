extends Node
## Game flow: input map, screen transitions, mission statistics.

var stats := {"kills": 0, "built": 0, "time": 0.0, "eggs": 0, "overminds": 0}
var _current: Node = null

const SCREENS := {
	"seizure": "res://scripts/ui/seizure_warning.gd",
	"intro": "res://scripts/ui/intro_credits.gd",
	"title": "res://scripts/ui/title_card.gd",
	"menu": "res://scripts/ui/main_menu.gd",
	"credits": "res://scripts/ui/credits_screen.gd",
	"game": "res://scripts/game/game.gd",
	"failed": "res://scripts/ui/mission_failed.gd",
	"complete": "res://scripts/ui/mission_complete.gd",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()

func start() -> void:
	var args := OS.get_cmdline_user_args()
	if "--skip-intro" in args:
		goto("menu")
	elif "--game" in args:
		goto("game")
	else:
		goto("seizure")

func goto(screen: String) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_all_3d()
	var old := get_tree().current_scene
	var node: Node
	var script: Script = load(SCREENS[screen])
	if script.get_instance_base_type() == "Node3D":
		node = Node3D.new()
	elif script.get_instance_base_type() == "Control":
		node = Control.new()
	else:
		node = Node.new()
	node.set_script(script)
	node.name = screen.capitalize().replace(" ", "")
	if old:
		old.queue_free()
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	_current = node

func reset_stats() -> void:
	stats = {"kills": 0, "built": 0, "time": 0.0, "eggs": 0, "overminds": 0}

func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var ev: InputEvent
		if k is int and k >= 0:
			var e := InputEventKey.new(); e.physical_keycode = k; ev = e
		else:
			var m := InputEventMouseButton.new(); m.button_index = -int(k); ev = m
		InputMap.action_add_event(action, ev)

func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("sprint", [KEY_SHIFT])
	_key("dash", [KEY_SPACE])
	_key("fire", [-MOUSE_BUTTON_LEFT])
	_key("flare", [-MOUSE_BUTTON_RIGHT])
	_key("lantern", [KEY_TAB])
	_key("build_menu", [KEY_F])
	_key("weapon_next", [KEY_E, -MOUSE_BUTTON_WHEEL_DOWN])
	_key("weapon_prev", [KEY_Q, -MOUSE_BUTTON_WHEEL_UP])
	_key("weapon_1", [KEY_1])
	_key("weapon_2", [KEY_2])
	_key("weapon_3", [KEY_3])
	_key("pause", [KEY_ESCAPE])
