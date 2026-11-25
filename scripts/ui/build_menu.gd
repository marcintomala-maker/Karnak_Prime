class_name BuildMenu
extends Control
## Build menu: Duelyst black cards with Unvanquished buildable icons, cost and energy.
## Opened with F (construction kit). Esc or the big X closes it. Unaffordable = red.

var game: Game
var cards: Array = []
var points_label: Label
var _row: HBoxContainer

func _ready() -> void:
	UIKit.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new(); dim.color = Color(0, 0.02, 0.03, 0.55); UIKit.fullscreen(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 26)
	UIKit.fullscreen(v)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = UIKit.ui("icon_mana")
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(icon)
	points_label = UIKit.label("400", 48, UIKit.TEAL)
	top.add_child(points_label)
	v.add_child(top)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 22)
	v.add_child(_row)
	for k in Defs.BUILD_ORDER:
		var card := _make_card(k)
		_row.add_child(card)
		cards.append(card)
	var close := TextureButton.new()
	close.texture_normal = UIKit.ui("button_close")
	close.texture_hover = UIKit.ui("button_close_glow")
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close.custom_minimum_size = Vector2(120, 120)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.position = Vector2(-170, 50)
	close.size = Vector2(120, 120)
	close.pressed.connect(close_menu)
	add_child(close)

func _make_card(k: String) -> Control:
	var d: Dictionary = Defs.BUILDABLES[k]
	var card := TextureButton.new()
	card.texture_normal = UIKit.ui("unusable_unit")
	card.ignore_texture_size = true
	card.stretch_mode = TextureButton.STRETCH_SCALE
	card.custom_minimum_size = Vector2(226, 296)
	card.set_meta("kind", k)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % d.model)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(48, 46); ic.size = Vector2(130, 120)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.name = "Icon"
	card.add_child(ic)
	var nm := UIKit.label(d.name, 19, UIKit.WHITE, "Black")
	nm.position = Vector2(8, 172); nm.size = Vector2(210, 44)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD
	nm.name = "Name"
	card.add_child(nm)
	var cost := HBoxContainer.new()
	cost.position = Vector2(20, 222); cost.size = Vector2(186, 40)
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_theme_constant_override("separation", 6)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mi := TextureRect.new(); mi.texture = UIKit.ui("icon_mana"); mi.custom_minimum_size = Vector2(30, 30)
	mi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; mi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost.add_child(mi)
	var cl := UIKit.label(str(d.cost), 26, UIKit.TEAL); cl.name = "Cost"
	cost.add_child(cl)
	var ei := TextureRect.new(); ei.texture = load("res://assets/icons/energy.png"); ei.custom_minimum_size = Vector2(26, 30)
	ei.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ei.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ei.modulate = Color(1.0, 0.95, 0.5)
	cost.add_child(ei)
	var el := UIKit.label(str(d.energy), 26, Color(1.0, 0.95, 0.5))
	cost.add_child(el)
	cost.name = "CostRow"
	card.add_child(cost)
	card.mouse_entered.connect(func():
		Sfx.play_ui("ui/hover", -8.0)
		card.scale = Vector2(1.05, 1.05))
	card.mouse_exited.connect(func(): card.scale = Vector2.ONE)
	card.pivot_offset = Vector2(113, 148)
	card.pressed.connect(_choose.bind(k))
	return card

func open() -> void:
	visible = true
	game.player.in_menu = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_ui("ui/panel_open", -4.0)
	_refresh()

func close_menu() -> void:
	if not visible:
		return
	visible = false
	game.player.in_menu = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play_ui("ui/panel_close", -4.0)

func _refresh() -> void:
	var pts: float = game.player.weapons.ammo[Weapons.CKIT]
	points_label.text = str(int(pts))
	for card in cards:
		var k: String = card.get_meta("kind")
		var d: Dictionary = Defs.BUILDABLES[k]
		var ok: bool = pts >= d.cost
		if ok:
			var reason := game.can_place(k, game.player.global_position + (-game.player.global_transform.basis.z) * 4.0)
			ok = reason == "" or reason == "blocked"
		card.modulate = Color(1, 1, 1) if ok else Color(1.0, 0.3, 0.28)

func _process(_d: float) -> void:
	if visible:
		_refresh()

func _choose(k: String) -> void:
	var d: Dictionary = Defs.BUILDABLES[k]
	var reason := game.can_place(k, game.player.global_position + (-game.player.global_transform.basis.z) * 4.0)
	if game.player.weapons.ammo[Weapons.CKIT] < d.cost or (reason != "" and reason != "blocked"):
		Sfx.play_ui("ui/error", -4.0)
		return
	Sfx.play_ui("ui/select", -4.0)
	close_menu()
	game.player.weapons.begin_placement(k)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("build_menu")):
		get_viewport().set_input_as_handled()
		close_menu()
