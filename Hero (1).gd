extends CharacterBody2D

# ============================================================
# Hero.gd  —  Base Class for ALL playable heroes
# ============================================================
# CONTROLS (Isaac-style split input):
#   WASD          → Move
#   Arrow Keys    → Shoot in that cardinal direction
#   Left Mouse    → Shoot toward cursor (alternative)
#   SPACE / Q     → Special Ability (per-hero, on cooldown)
#   SHIFT         → Dodge roll (brief i-frames + burst of speed)
#
# Each hero script EXTENDS this file and overrides:
#   _special_ability()       ← the unique skill logic
#   special_cooldown_max     ← how long their cooldown lasts
#   (optionally) _fire_projectile() for custom shot patterns
#
# IMPORTANT GODOT CONCEPTS IN THIS FILE:
#   velocity  → a built-in Vector2 on CharacterBody2D that
#               move_and_slide() uses to move the body
#   delta     → seconds since last frame (use to make timers
#               framerate-independent — always multiply!)
#   signal    → a named event this node can broadcast
#   @onready  → grab a child node when the scene is ready
# ============================================================

# ── SIGNALS ─────────────────────────────────────────────────
signal health_changed(current: int, maximum: int)
signal died()
signal special_used(cooldown_max: float)

# ── EXPORTED STATS ───────────────────────────────────────────
# @export = visible & editable in the Godot Inspector panel
# Great for tweaking without touching code
@export var hero_name:            String = "Hero"
@export var max_health:           int    = 100
@export var move_speed:           float  = 110.0   # pixels per second
@export var base_damage:          int    = 10
@export var fire_rate:            float  = 0.38    # seconds between shots
@export var projectile_speed:     float  = 280.0   # bullet travel speed
@export var special_cooldown_max: float  = 6.0     # override per hero subclass

# ── RUNTIME STATE ────────────────────────────────────────────
var current_health:      int
var shoot_cooldown:      float  = 0.0
var special_cooldown:    float  = 0.0   # counts DOWN — 0 means ready
var is_invincible:       bool   = false
var invincibility_timer: float  = 0.0
var is_rolling:          bool   = false
var roll_timer:          float  = 0.0
var roll_direction:      Vector2 = Vector2.ZERO
var facing_direction:    Vector2 = Vector2.RIGHT
var aim_direction:       Vector2 = Vector2.RIGHT
var items_held:          Array   = []
var last_hit_source:     String  = "the darkness"

# ── NODE REFERENCES ──────────────────────────────────────────
@onready var sprite:       Node2D    = $Sprite2D
@onready var shoot_origin: Marker2D  = $ShootOrigin  # bullet spawn point
@onready var hitbox:       Area2D    = $Hitbox

# ── CONSTANTS ────────────────────────────────────────────────
const ROLL_SPEED:    float = 240.0  # px/sec during a roll
const ROLL_DURATION: float = 0.22   # seconds a roll lasts
const I_FRAME_TIME:  float = 1.0    # invincibility seconds after hit


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	current_health = max_health
	add_to_group("player")
	if has_node("/root/GameData"):
		GameData.start_run()
	
	if has_node("/root/GameData") and not GameData.chosen_hero.is_empty():
		_apply_hero_data(GameData.chosen_hero)
	
	emit_signal("health_changed", current_health, max_health)


# ════════════════════════════════════════════════════════════
# _physics_process(delta)
# ════════════════════════════════════════════════════════════
func _physics_process(delta: float):
	_tick_timers(delta)
	
	if is_rolling:
		_handle_roll_movement()
	else:
		_handle_movement()
		_handle_shooting()
		_handle_special_input()
	
	move_and_slide()


# ════════════════════════════════════════════════════════════
# _tick_timers()
# ════════════════════════════════════════════════════════════
func _tick_timers(delta: float):
	if shoot_cooldown   > 0: shoot_cooldown   -= delta
	if special_cooldown > 0: special_cooldown -= delta
	
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			if sprite: sprite.modulate = Color.WHITE
	
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			velocity   = Vector2.ZERO
			if sprite: sprite.modulate.a = 1.0


# ════════════════════════════════════════════════════════════
# MOVEMENT
# ════════════════════════════════════════════════════════════
func _handle_movement():
	var mx  = Input.get_axis("move_left",  "move_right")
	var my  = Input.get_axis("move_up",    "move_down")
	var dir = Vector2(mx, my)
	
	if dir.length() > 0:
		dir              = dir.normalized()
		facing_direction = dir
	
	velocity = dir * move_speed
	
	# Flip sprite horizontally to face movement direction
	if sprite and mx != 0:
		sprite.scale.x = sign(mx)
	
	# Dodge roll — only triggers when moving
	if Input.is_action_just_pressed("dodge") and dir.length() > 0:
		_start_roll(dir)

func _start_roll(dir: Vector2):
	is_rolling          = true
	is_invincible       = true
	roll_direction      = dir
	roll_timer          = ROLL_DURATION
	invincibility_timer = ROLL_DURATION + 0.1
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.35, 0.06)
		tween.tween_property(sprite, "modulate:a", 1.0,  0.12)

func _handle_roll_movement():
	velocity = roll_direction * ROLL_SPEED


# ════════════════════════════════════════════════════════════
# SHOOTING  (Isaac-style: arrow keys = instant directional shot)
# ════════════════════════════════════════════════════════════
func _handle_shooting():
	if shoot_cooldown > 0:
		return
	
	var shot_dir = Vector2.ZERO
	
	# Arrow keys snap to cardinal directions — no mouse needed
	if   Input.is_action_pressed("shoot_up"):    shot_dir = Vector2(0, -1)
	elif Input.is_action_pressed("shoot_down"):  shot_dir = Vector2(0,  1)
	elif Input.is_action_pressed("shoot_left"):  shot_dir = Vector2(-1, 0)
	elif Input.is_action_pressed("shoot_right"): shot_dir = Vector2(1,  0)
	# Mouse aim as an alternative
	elif Input.is_action_pressed("shoot_mouse"):
		var to_mouse = get_global_mouse_position() - global_position
		if to_mouse.length() > 12:
			shot_dir = to_mouse.normalized()
	
	if shot_dir != Vector2.ZERO:
		aim_direction  = shot_dir
		shoot_cooldown = fire_rate
		_fire_projectile(shot_dir)


# ════════════════════════════════════════════════════════════
# _fire_projectile()
# Spawns a Bullet in the given direction.
# Heroes override this for spread shots, bouncing, etc.
# ════════════════════════════════════════════════════════════
func _fire_projectile(direction: Vector2):
	if not ResourceLoader.exists("res://scenes/Bullet.tscn"):
		# Placeholder output until the Bullet scene is made
		print("[", hero_name, "] SHOOT → dir:", direction.snapped(Vector2(0.1,0.1)),
			  "  dmg:", base_damage)
		return
	
	var bullet           = load("res://scenes/Bullet.tscn").instantiate()
	bullet.global_position = (shoot_origin.global_position
							  if shoot_origin else global_position)
	bullet.direction     = direction
	bullet.speed         = projectile_speed
	bullet.damage        = base_damage
	bullet.source_node   = self
	
	# Add to the room/game node so bullets persist when the player moves
	get_parent().add_child(bullet)


# ════════════════════════════════════════════════════════════
# SPECIAL ABILITY
# ════════════════════════════════════════════════════════════
func _handle_special_input():
	if Input.is_action_just_pressed("special_ability"):
		if special_cooldown <= 0:
			special_cooldown = special_cooldown_max
			_special_ability()
			emit_signal("special_used", special_cooldown_max)
		else:
			# Nudge sprite to communicate "not ready"
			if sprite:
				var tween = create_tween()
				tween.tween_property(sprite, "position:x",  3.0, 0.04)
				tween.tween_property(sprite, "position:x", -3.0, 0.04)
				tween.tween_property(sprite, "position:x",  0.0, 0.04)

# Override this in each hero subclass
func _special_ability():
	print("[", hero_name, "] Special — base placeholder, override me!")

# Returns 0.0 (on cooldown) to 1.0 (fully ready) — used by HUD bar
func get_special_cooldown_percent() -> float:
	if special_cooldown_max <= 0: return 1.0
	return 1.0 - clampf(special_cooldown / special_cooldown_max, 0.0, 1.0)


# ════════════════════════════════════════════════════════════
# DAMAGE & HEALTH
# ════════════════════════════════════════════════════════════
func take_damage(amount: int):
	if is_invincible or is_rolling:
		return   # Rolls also grant invincibility
	
	current_health      = max(current_health - amount, 0)
	if has_node("/root/GameData"):
		GameData.track_damage_taken(amount)
	is_invincible       = true
	# "Cracked Defence" curse reduces i-frames; iframe_bonus can be negative
	var iframe_bonus    = get_meta("iframe_bonus", 0.0)
	invincibility_timer = max(0.1, I_FRAME_TIME + iframe_bonus)
	
	emit_signal("health_changed", current_health, max_health)
	_flash_damage()
	
	# Notify ItemManager so on_hit_taken rune effects fire
	if has_node("ItemManager"):
		$ItemManager.notify_hit_taken(amount)
	
	if current_health <= 0:
		_die()

func heal(amount: int):
	# "Jotun Vitality" synergy adds a heal bonus
	var bonus = get_meta("heal_bonus", 0)
	current_health = min(current_health + amount + bonus, max_health)
	emit_signal("health_changed", current_health, max_health)

func _flash_damage():
	if not sprite: return
	var tween = create_tween()
	for i in 3:
		tween.tween_property(sprite, "modulate", Color.RED,   0.07)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)

func _die():
	emit_signal("died")
	if has_node("/root/GameData"):
		GameData.current_run["deaths"] += 1
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.45)
		await tween.finished
	
	if has_node("/root/GameData"):
		GameData.end_run(false, last_hit_source)
	get_tree().change_scene_to_file("res://scenes/DeathScreen.tscn")

func _apply_hero_data(data: Dictionary):
	hero_name      = data.get("name",   hero_name)
	max_health     = data.get("health", max_health)
	current_health = max_health

func get_health_percent() -> float:
	return float(current_health) / float(max_health)
