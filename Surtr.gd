extends "res://scripts/EnemyBase.gd"

# ============================================================
# Surtr.gd  —  Lord of Flames  (Floor 3 Boss)
# ============================================================
# Surtr is a massive fire giant wielding a flaming sword.
# His arena mechanic: the floor gradually fills with lava
# patches, shrinking the safe area over time.
#
# ── PHASE 1  "THE FORGE"  (100%→65%) ────────────────────────
#   Slow, deliberate. Floor lava spawns every 6s.
#   SWORD SLAM: raises sword, massive AoE 4s later, telegraphed
#   CINDER THROW: 5-shot spread of fire bullets
#   FORGE STEP: each step leaves 2 lava patches
#
# ── PHASE 2  "FLAMES UNLEASHED"  (65%→35%) ──────────────────
#   Speed up. Floor lava every 3s.
#   INFERNO SWEEP: wide arc sword swing, leaves lava wall
#   FIRE RING: 16-bullet ring at medium speed
#   METEOR RAIN: 5 random positions marked, then lava slams
#
# ── PHASE 3  "RAGNARÖK"  (35%→0%) ────────────────────────────
#   Fast. Floor lava every 1.5s. Fire all around.
#   SWORD WHIRL: spins sword, 360° lava + bullets
#   LAVA GEYSER: 8 geysers erupt in a cross+diagonal pattern
#   CONSUME: lunges at max speed, deals 3 damage, explodes
#
# CHAIN: none (no alternate hitbox)
# UNLOCK: Tyr
# STATS: HP 450, P1 speed 60, P2 80, P3 110
# ============================================================

signal phase_changed(phase: int)
signal boss_died()

const BOSS_MAX_HP = 450
const P2_THRESH   = 0.65
const P3_THRESH   = 0.35
const SPEEDS      = {1: 60.0, 2: 80.0, 3: 110.0}
const LAVA_RATES  = {1: 6.0,  2: 3.0,  3: 1.5}

enum SurtrState {
	CHASE, SWORD_SLAM, CINDER_THROW, FORGE_STEP,
	INFERNO_SWEEP, FIRE_RING, METEOR_RAIN,
	SWORD_WHIRL, LAVA_GEYSER, CONSUME,
	PHASE_TRANS, DYING
}

var surtr_state:  SurtrState = SurtrState.CHASE
var cur_phase:    int        = 1
var state_timer:  float      = 2.0  # Intro delay
var lava_timer:   float      = 6.0
var meteor_marks: Array      = []   # Marked positions for meteor rain

var cd_slam:    float = 5.0
var cd_cinder:  float = 3.5
var cd_forge:   float = 4.0
var cd_sweep:   float = 4.5
var cd_ring:    float = 5.0
var cd_meteor:  float = 7.0
var cd_whirl:   float = 5.0
var cd_geyser:  float = 7.0
var cd_consume: float = 8.0

const LAVA_PATH  = "res://scenes/floor3/LavaPatch.tscn"
const FIRE_COLOR = Color(1.0, 0.45, 0.05)
const LAVA_COLOR = Color(1.0, 0.25, 0.0)

@onready var hitbox:       Area2D  = $Hitbox
@onready var detect_zone:  Area2D  = $DetectionZone
@onready var body_sprite:  Node2D  = $BodySprite


func _ready():
	enemy_name     = "Surtr"
	max_health     = BOSS_MAX_HP
	current_health = max_health
	damage         = 2
	contact_damage_cooldown = 1.0
	add_to_group("enemies"); add_to_group("boss")
	if hitbox:
		hitbox.area_entered.connect(func(a):
			if a.is_in_group("player_bullets"):
				take_damage(a.get("damage") if a.get("damage") else 10))
	if detect_zone:
		detect_zone.body_entered.connect(func(b):
			if b.is_in_group("player"): player_ref = b)
	print("[Surtr] The giant stirs. The forge ignites.")


func _physics_process(delta: float):
	if surtr_state == SurtrState.DYING: return
	state_timer -= delta
	_tick_cds(delta)
	# Floor lava
	lava_timer -= delta
	if lava_timer <= 0:
		lava_timer = LAVA_RATES.get(cur_phase, 6.0)
		_spawn_random_lava()
	_run_state(delta)
	move_and_slide()
	_check_contact_damage()


func _tick_cds(d: float):
	for cd in ["cd_slam","cd_cinder","cd_forge","cd_sweep",
			   "cd_ring","cd_meteor","cd_whirl","cd_geyser","cd_consume"]:
		if get(cd) > 0: set(cd, get(cd) - d)


func _run_state(delta: float):
	match surtr_state:
		SurtrState.CHASE:        _do_chase()
		SurtrState.SWORD_SLAM:   _do_slam(delta)
		SurtrState.CINDER_THROW: _do_cinder(delta)
		SurtrState.FORGE_STEP:   _do_forge(delta)
		SurtrState.INFERNO_SWEEP:_do_sweep(delta)
		SurtrState.FIRE_RING:    _do_ring(delta)
		SurtrState.METEOR_RAIN:  _do_meteor(delta)
		SurtrState.SWORD_WHIRL:  _do_whirl(delta)
		SurtrState.LAVA_GEYSER:  _do_geyser(delta)
		SurtrState.CONSUME:      _do_consume(delta)
		SurtrState.PHASE_TRANS:  _do_phase_trans(delta)


# ── CHASE ────────────────────────────────────────────────────
func _do_chase():
	if player_ref == null: return
	if state_timer > 0: velocity = Vector2.ZERO; return
	var to = player_ref.global_position - global_position
	velocity = to.normalized() * SPEEDS.get(cur_phase, 60.0)
	if body_sprite and velocity.x != 0: body_sprite.scale.x = sign(velocity.x)
	# Attack selection
	match cur_phase:
		1:
			if cd_slam   <= 0: _enter(SurtrState.SWORD_SLAM, 2.5)
			elif cd_cinder <= 0: _enter(SurtrState.CINDER_THROW, 0.9)
		2:
			if cd_meteor <= 0: _enter(SurtrState.METEOR_RAIN, 3.5)
			elif cd_sweep  <= 0: _enter(SurtrState.INFERNO_SWEEP, 1.0)
			elif cd_ring   <= 0: _enter(SurtrState.FIRE_RING, 0.6)
		3:
			if cd_geyser  <= 0: _enter(SurtrState.LAVA_GEYSER, 1.5)
			elif cd_whirl  <= 0: _enter(SurtrState.SWORD_WHIRL, 1.2)
			elif cd_consume <= 0: _enter(SurtrState.CONSUME, 0.5)


func _enter(s: SurtrState, duration: float):
	surtr_state  = s
	state_timer  = duration
	velocity     = Vector2.ZERO


# ── PHASE 1 ATTACKS ──────────────────────────────────────────
func _do_slam(delta: float):
	velocity = Vector2.ZERO
	# At halfway: mark + warning
	if state_timer <= 1.2 and state_timer > 1.15 and player_ref:
		# Warn via colour flash
		if body_sprite: body_sprite.modulate = Color(2.0, 0.6, 0.1)
	# At end: AoE slam
	if state_timer <= 0:
		cd_slam = 6.0
		var slam_pos = player_ref.global_position if player_ref else global_position
		# Lava ring at slam position
		for i in range(8):
			var a = (TAU/8.0)*i
			_spawn_lava(slam_pos + Vector2(cos(a), sin(a)) * 50.0)
		_spawn_lava(slam_pos)
		if body_sprite: body_sprite.modulate = _phase_color()
		surtr_state = SurtrState.CHASE; state_timer = 0.5

func _do_cinder(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.45 and state_timer > 0.4 and player_ref:
		var base = (player_ref.global_position - global_position).normalized()
		for a in [-0.4, -0.2, 0.0, 0.2, 0.4]:
			_fire(base.rotated(a), 185.0, 10, FIRE_COLOR)
	if state_timer <= 0: cd_cinder = 4.0; surtr_state = SurtrState.CHASE; state_timer = 0.5

func _do_forge(delta: float):
	# Walk and leave lava patches more frequently
	if player_ref:
		velocity = (player_ref.global_position - global_position).normalized() * 45.0
	if int(state_timer * 5) % 2 == 0: _spawn_lava(global_position)
	if state_timer <= 0: cd_forge = 5.0; surtr_state = SurtrState.CHASE; state_timer = 0.3


# ── PHASE 2 ATTACKS ──────────────────────────────────────────
func _do_sweep(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.5 and state_timer > 0.45:
		# Wide arc of bullets + lava wall
		if player_ref:
			var base = (player_ref.global_position - global_position).normalized()
			for a in [-0.7,-0.5,-0.3,-0.1,0.0,0.1,0.3,0.5,0.7]:
				_fire(base.rotated(a), 200.0, 10, LAVA_COLOR)
			# Lava line
			for i in range(5):
				_spawn_lava(global_position + base * (60.0 + i * 30.0))
	if state_timer <= 0: cd_sweep = 5.5; surtr_state = SurtrState.CHASE; state_timer = 0.5

func _do_ring(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.3 and state_timer > 0.25:
		for i in range(16):
			var a = (TAU/16.0)*i
			_fire(Vector2(cos(a), sin(a)), 160.0, 9, FIRE_COLOR)
	if state_timer <= 0: cd_ring = 5.5; surtr_state = SurtrState.CHASE; state_timer = 0.5

func _do_meteor(delta: float):
	# Phase 1: mark 5 positions. Phase 2: slam them all.
	velocity = Vector2.ZERO
	if state_timer > 1.5 and meteor_marks.is_empty():
		# Mark 5 random room positions
		for i in range(5):
			meteor_marks.append(Vector2(randf_range(60, 16*40-60), randf_range(60, 12*40-60)))
	if state_timer <= 0.5 and state_timer > 0.45:
		for pos in meteor_marks:
			_spawn_lava(pos)
			# Burst at each mark
			for j in range(4):
				var a = (TAU/4.0)*j
				_fire(Vector2(cos(a), sin(a)), 110.0, 8, LAVA_COLOR)
		meteor_marks.clear()
	if state_timer <= 0: cd_meteor = 8.0; surtr_state = SurtrState.CHASE; state_timer = 0.5


# ── PHASE 3 ATTACKS ──────────────────────────────────────────
func _do_whirl(delta: float):
	velocity = Vector2.ZERO
	# Fires 6 waves of 12 bullets while "spinning"
	if int(state_timer * 5) % 2 == 0 and state_timer > 0.1:
		var offset = state_timer * 8.0  # Rotating offset
		for i in range(12):
			var a = (TAU/12.0)*i + offset
			_fire(Vector2(cos(a), sin(a)), 145.0, 9, FIRE_COLOR)
		_spawn_lava(global_position + Vector2(randf_range(-20,20), randf_range(-20,20)))
	if state_timer <= 0: cd_whirl = 6.0; surtr_state = SurtrState.CHASE; state_timer = 0.5

func _do_geyser(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.75 and state_timer > 0.7:
		# 8 geysers in cross + diagonal pattern
		for i in range(8):
			var a = (TAU/8.0)*i
			var gpos = global_position + Vector2(cos(a), sin(a)) * 110.0
			_spawn_lava(gpos)
			for j in range(3):
				var ba = a + randf_range(-0.4, 0.4)
				_fire(Vector2(cos(ba), sin(ba)), 130.0, 10, LAVA_COLOR)
	if state_timer <= 0: cd_geyser = 8.0; surtr_state = SurtrState.CHASE; state_timer = 0.5

func _do_consume(delta: float):
	if state_timer > 0.3:
		velocity = Vector2.ZERO
	else:
		if player_ref: velocity = (player_ref.global_position - global_position).normalized() * 340.0
	if state_timer <= 0:
		# On impact: 3 damage + explosion
		if player_ref and global_position.distance_to(player_ref.global_position) < 50:
			if player_ref.has_method("take_damage"):
				if "last_hit_source" in player_ref: player_ref.last_hit_source = "Surtr's Consume"
				player_ref.take_damage(3)
		for i in range(12):
			var a = (TAU/12.0)*i
			_fire(Vector2(cos(a), sin(a)), 180.0, 10, LAVA_COLOR)
		for i in range(4):
			_spawn_lava(global_position + Vector2(randf_range(-40,40), randf_range(-40,40)))
		cd_consume = 9.0; surtr_state = SurtrState.CHASE; state_timer = 0.6


# ── PHASE TRANSITIONS ────────────────────────────────────────
func _do_phase_trans(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0:
		surtr_state = SurtrState.CHASE; state_timer = 0.5
		_halve_cds()

func _halve_cds():
	for cd in ["cd_slam","cd_cinder","cd_sweep","cd_ring",
			   "cd_meteor","cd_whirl","cd_geyser","cd_consume"]:
		set(cd, get(cd) / 2.0)

func _check_phase():
	var pct = float(current_health) / float(max_health)
	if cur_phase == 1 and pct <= P2_THRESH: _advance_phase(2)
	elif cur_phase == 2 and pct <= P3_THRESH: _advance_phase(3)

func _advance_phase(p: int):
	cur_phase   = p
	surtr_state = SurtrState.PHASE_TRANS
	state_timer = 2.0
	emit_signal("phase_changed", p)
	# Burst + speed explosion at transition
	for i in range(if p == 2: 12 else 20):
		var a = (TAU / (12 if p == 2 else 20)) * i
		_fire(Vector2(cos(a), sin(a)), 200.0, 0, FIRE_COLOR)
	print("[Surtr] Phase ", p, " — ", ["","Forge heats","Flames unleashed","Ragnarök!"][p])


# ── TAKE DAMAGE ──────────────────────────────────────────────
func take_damage(amount: int):
	if surtr_state == SurtrState.DYING: return
	current_health = max(0, current_health - amount)
	if body_sprite:
		var tw = create_tween()
		tw.tween_property(body_sprite, "modulate", Color(2.0, 0.5, 0.3), 0.06)
		tw.tween_property(body_sprite, "modulate", _phase_color(), 0.08)
	_check_phase()
	if current_health <= 0: _die()

func _phase_color() -> Color:
	match cur_phase:
		1: return Color(0.9, 0.45, 0.1)
		2: return Color(1.0, 0.3, 0.05)
		3: return Color(1.0, 0.15, 0.02)
	return Color.WHITE


# ── DEATH ────────────────────────────────────────────────────
func _die():
	surtr_state = SurtrState.DYING; velocity = Vector2.ZERO
	if hitbox: hitbox.set_deferred("monitoring", false)
	emit_signal("died"); emit_signal("boss_died")
	if has_node("/root/GameData"): GameData.unlock_hero("Tyr"); print("[Surtr] Tyr UNLOCKED!")
	_death_sequence()

func _death_sequence():
	for i in range(10):
		await get_tree().create_timer(0.14).timeout
		for j in range(6):
			var a = (TAU/6.0)*j + i*0.3
			_fire(Vector2(cos(a), sin(a)), 80.0, 0, FIRE_COLOR)
		_spawn_random_lava()
	await get_tree().create_timer(0.5).timeout
	if body_sprite:
		var tw = create_tween()
		tw.tween_property(body_sprite, "modulate:a", 0.0, 1.0)
		await tw.finished
	if has_node("/root/ItemDropper") and has_node("/root/RuneDatabase"):
		var players = get_tree().get_nodes_in_group("player")
		var held = []
		if not players.is_empty() and players[0].has_node("ItemManager"):
			held = players[0].get_node("ItemManager").get_held_ids()
		var rune = RuneDatabase.roll_random_rune(3, held)
		if rune.get("rarity","c") in ["common","uncommon"]:
			rune = RuneDatabase.roll_random_rune(3, held)
		ItemDropper._spawn_pedestal(get_parent(), global_position, rune)
	queue_free()


# ── HELPERS ──────────────────────────────────────────────────
func _spawn_random_lava():
	var rw = 16*40.0; var rh = 12*40.0
	_spawn_lava(Vector2(randf_range(40,rw-40), randf_range(40,rh-40)))

func _spawn_lava(pos: Vector2):
	if ResourceLoader.exists(LAVA_PATH):
		var p = load(LAVA_PATH).instantiate()
		p.global_position = pos; get_parent().add_child(p)

func _fire(dir: Vector2, spd: float, dmg: int, col: Color):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	var b = load(path).instantiate()
	b.global_position = global_position
	b.direction = dir; b.speed = spd; b.damage = dmg
	if b.has_node("Sprite2D"): b.get_node("Sprite2D").modulate = col
	get_parent().add_child(b)

func _check_contact_damage():
	if player_ref == null or contact_damage_timer > 0: return
	if global_position.distance_to(player_ref.global_position) <= 40:
		var extra = player_ref.get_meta("curse_extra_damage", 0)
		if "last_hit_source" in player_ref: player_ref.last_hit_source = "Surtr"
		player_ref.take_damage(damage + extra)
		contact_damage_timer = contact_damage_cooldown
