extends "res://scripts/Hero.gd"

# ============================================================
# Tyr.gd — God of Justice & War
# SPECIAL: IRON VOW  (Cooldown: 12s)
# For 4 seconds, every hit Tyr receives empowers him instead:
# +5 damage per hit taken. Takes only half damage during vow.
# ============================================================

var _vow_active: bool  = false
var _vow_timer:  float = 0.0
var _vow_stacks: int   = 0
const VOW_DURATION := 4.0

func _ready():
	super()
	hero_name            = "Tyr"
	max_health           = 140
	current_health       = max_health
	move_speed           = 95.0
	base_damage          = 14
	fire_rate            = 0.50
	special_cooldown_max = 12.0

func _physics_process(delta: float):
	super(delta)
	if _vow_active:
		_vow_timer -= delta
		if _vow_timer <= 0: _end_vow()

func _special_ability():
	print("[Tyr] IRON VOW active!")
	_vow_active = true
	_vow_timer  = VOW_DURATION
	_vow_stacks = 0
	if sprite: sprite.modulate = Color(1.0, 0.82, 0.2)

func _end_vow():
	_vow_active = false
	base_damage -= _vow_stacks * 5
	_vow_stacks  = 0
	if sprite: sprite.modulate = Color.WHITE

func take_damage(amount: int):
	if _vow_active:
		_vow_stacks += 1
		base_damage  += 5
		super(amount / 2)
	else:
		super(amount)
