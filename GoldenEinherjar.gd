extends "res://scripts/EnemyBase.gd"

# ============================================================
# GoldenEinherjar.gd  —  Elite Celestial Warrior  (Floor 5)
# ============================================================
# An ascended Einherjar reborn in Odin's hall.
# Faster, hits harder, and fires a 3-shot spread instead of
# a single bolt. Its golden armour absorbs the first hit each
# room (DIVINE WARD — like Ymir's Marrow but for enemies).
#
# MECHANICS:
#   DIVINE WARD: absorbs the very first bullet hit each room.
#     Visual: a gold shimmer ring around the sprite shatters.
#   TRIPLE SHOT: 3-spread of golden bolts, faster than Einherjar.
#   DIVINE RETREAT: if player gets within 75px, instantly blinks
#     backwards 80px (1-time per room, short CD).
#   RUNE MARK: on death, leaves a glowing rune on the floor
#     for 4s that boosts the next enemy to step on it.
#     (enemies get +10 speed for 6s — makes room harder mid-clear)
#
# STATS: HP 38, Speed 68, Triple-shot dmg 11 each, CD 2.8s
# ============================================================

const IDEAL_RANGE:   float = 195.0
const RETREAT_DIST:  float = 75.0
const RETREAT_DIST2: float = 80.0   # How far to blink back
const STRAFE_SPEED:  float = 68.0
const RETREAT_SPEED: float = 115.0
const SHOT_CD:       float = 2.8

const STATE_STRAFE  = 10
const STATE_SHOOT   = 11
const STATE_RETREAT = 12

var g_state:       int   = -1
var shot_cd:       float = SHOT_CD * randf_range(0.3, 0.6)
var ward_active:   bool  = true   # First-hit absorb
var blink_cd:      float = 0.0
var strafe_sign:   float = 1.0 if randf() > 0.5 else -1.0
var fire_timer_st: float = 0.0

const GOLD_COLOR = Color(1.0, 0.85, 0.2)


func _ready():
	super()
	enemy_name     = "Golden Einherjar"
	max_health     = 38
	current_health = max_health
	move_speed     = STRAFE_SPEED
	damage         = 0
	contact_damage_cooldown = 1.2
	detection_range = 340.0
	if sprite: sprite.modulate = GOLD_COLOR


func _physics_process(delta: float):
	if shot_cd  > 0: shot_cd  -= delta
	if blink_cd > 0: blink_cd -= delta

	match g_state:
		STATE_STRAFE:  _do_strafe(delta)
		STATE_SHOOT:   _do_shoot(delta)
		STATE_RETREAT: _do_retreat(delta)
		_:             super(delta)
	move_and_slide()


func _idle_behaviour(_d: float):
	velocity = Vector2.ZERO
	if player_ref: g_state = STATE_STRAFE


func _chase_behaviour(_d: float):
	g_state = STATE_STRAFE


func _do_strafe(delta: float):
	if player_ref == null: g_state = -1; state = State.IDLE; return
	var to   = player_ref.global_position - global_position
	var dist = to.length()

	# Blink if player gets too close
	if dist < RETREAT_DIST and blink_cd <= 0:
		_do_blink(to.normalized())
		return

	# Orbit
	var outward = -to.normalized()
	var tangent = outward.rotated(PI * 0.5 * strafe_sign)
	var err     = dist - IDEAL_RANGE
	velocity    = tangent * STRAFE_SPEED + to.normalized() * err * 0.02
	if sprite and velocity.x != 0: sprite.scale.x = sign(velocity.x)

	shot_cd -= delta
	if shot_cd <= 0:
		fire_timer_st = 0.4
		g_state = STATE_SHOOT


func _do_shoot(delta: float):
	velocity = Vector2.ZERO
	fire_timer_st -= delta
	if fire_timer_st <= 0.2 and fire_timer_st > 0.15 and player_ref:
		var base = (player_ref.global_position - global_position).normalized()
		for a in [-0.28, 0.0, 0.28]:
			_fire_bolt(base.rotated(a))
		shot_cd = SHOT_CD
	if fire_timer_st <= 0:
		g_state = STATE_STRAFE


func _do_retreat(delta: float):
	if player_ref == null: g_state = STATE_STRAFE; return
	var away = (global_position - player_ref.global_position).normalized()
	velocity = away * RETREAT_SPEED
	var dist = global_position.distance_to(player_ref.global_position)
	if dist >= IDEAL_RANGE * 0.85:
		g_state = STATE_STRAFE


func _do_blink(toward_player: Vector2):
	blink_cd        = 5.0
	global_position -= toward_player * RETREAT_DIST2
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 0.5)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", GOLD_COLOR, 0.2)


func _fire_bolt(dir: Vector2):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	var b = load(path).instantiate()
	b.global_position = global_position
	b.direction = dir; b.speed = 210.0; b.damage = 11
	if b.has_node("Sprite2D"):
		b.get_node("Sprite2D").modulate = GOLD_COLOR
	get_parent().add_child(b)


# Divine Ward — absorb first bullet hit
func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_bullets"):
		if ward_active:
			ward_active = false
			print("[GoldenEinherjar] Divine Ward absorbed hit!")
			if sprite:
				var tw = create_tween()
				tw.tween_property(sprite, "modulate", Color(2.0,2.0,0.5), 0.08)
				tw.tween_property(sprite, "modulate", GOLD_COLOR,          0.15)
			return   # Block the hit
		var dmg = area.get("damage") if area.get("damage") != null else 10
		take_damage(dmg)


func _die():
	# Rune mark on floor — boosts nearby enemies
	if get_parent():
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and e != self:
				if global_position.distance_to(e.global_position) < 80.0:
					if "move_speed" in e:
						e.move_speed += 10.0
						get_tree().create_timer(6.0).timeout.connect(
							func(): if is_instance_valid(e): e.move_speed -= 10.0)
	super()
