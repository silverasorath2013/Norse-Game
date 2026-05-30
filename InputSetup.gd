extends Node

# ============================================================
# InputSetup.gd  —  Autoload: "InputSetup"
# ============================================================
# Registers ALL input actions in code so the project works
# immediately without manual Project Settings configuration.
# ============================================================

func _ready():
	_register_all_actions()
	print("[InputSetup] All input actions registered.")

func _register_all_actions():
	# ── MOVEMENT ─────────────────────────────────────────────
	_add_key("move_left",  KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("move_up",    KEY_W)
	_add_key("move_down",  KEY_S)

	# ── SHOOTING ─────────────────────────────────────────────
	_add_key("shoot_up",    KEY_UP)
	_add_key("shoot_down",  KEY_DOWN)
	_add_key("shoot_left",  KEY_LEFT)
	_add_key("shoot_right", KEY_RIGHT)
	_add_mouse("shoot_mouse", MOUSE_BUTTON_LEFT)

	# ── DODGE ────────────────────────────────────────────────
	_add_key("dodge", KEY_SHIFT)
	_add_joypad("dodge", JOY_BUTTON_LEFT_SHOULDER)

	# ── SPECIAL ABILITY ───────────────────────────────────────
	_add_key("special_ability", KEY_SPACE)
	_add_key_to("special_ability", KEY_Q)
	_add_joypad("special_ability", JOY_BUTTON_RIGHT_SHOULDER)

	# ── INTERACT (E key — pick up runes, shop) ────────────────
	_add_key("interact", KEY_E)
	_add_key_to("interact", KEY_ENTER)
	_add_joypad("interact", JOY_BUTTON_A)

	# ── PAUSE ─────────────────────────────────────────────────
	_add_key("pause", KEY_ESCAPE)
	_add_joypad("pause", JOY_BUTTON_START)

	# ── SHOP REROLL (R near merchant counter) ─────────────────
	_add_key("reroll_shop", KEY_R)

	# ── MAP TOGGLE ────────────────────────────────────────────
	_add_key("toggle_map", KEY_TAB)
	_add_joypad("toggle_map", JOY_BUTTON_BACK)


func _add_key(action: String, keycode: int):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_key_to(action: String, keycode: int):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_mouse(action: String, button_index: int):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventMouseButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)

func _add_joypad(action: String, button_index: int):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventJoypadButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)
