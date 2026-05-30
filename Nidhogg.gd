extends "res://scripts/EnemyBase.gd"

# ============================================================
# Nidhogg.gd  —  The Root Gnawer  (Floor 4 Boss)
# ============================================================
# Nidhogg is a serpent of shadow and decay. Its arena has
# roots that erupt from the floor as obstacles.
#
# ── PHASE 1  "GNAWING"  (100%→60%) ──────────────────────────
#   BURROW NET: dives into a root on the floor, travels the
#     root network, erupts elsewhere.
#   VOID SPIT: 3 slow soul bolts that home slightly.
#   ROOT SPIKE: erupts 3 roots from floor near player.
#
# ── PHASE 2  "DECAYING"  (60%→30%) ──────────────────────────
#   HP DRAIN AURA: player within 110px loses 1 HP every 2s.
#   DARK COIL: body wraps around arena edge, fires inward.
#   ROOT WALL: 6 roots erupt in a line across the room.
#
# ── PHASE 3  "UNRAVELLING"  (30%→0%) ────────────────────────
#   SOUL SCREAM: stuns player for 0.8s + void burst.
#   CORRUPTION WAVE: rolling dark wave across room.
#   ROOT CRUSH: all roots explode simultaneously.
#
# UNLOCK: Hel
# STATS: HP 420, Drain aura (P2+), Root hazards (persistent)
# ============================================================

signal phase_changed(phase: int)
signal boss_died()

const BOSS_HP    = 420
const P2_THRESH  = 0.60
const P3_THRESH  = 0.30
const SPEEDS     = {1: 70.0, 2: 90.0, 3: 120.0}

enum NState {
	CHASE, BURROW, BURROWING, VOID_SPIT, ROOT_SPIKE,
	DRAIN_AURA, DARK_COIL, ROOT_WALL,
	SOUL_SCREAM, CORRUPT_WAVE, ROOT_CRUSH,
	PHASE_TRANS, DYING
}

var nstate:       NState = NState.CHASE
var cur_phase:    int    = 1
var state_timer:  float  = 2.2
var burrow_pos:   Vector2 = Vector2.ZERO

var cd_burrow:    float = 6.0
var cd_spit:      float = 4.0
var cd_root:      float = 5.5
var cd_coil:      float = 6.0
var cd_wall:      float = 7.0
var cd_scream:    float = 7.0
var cd_wave:      float = 8.0
var cd_crush:     float = 10.0
var drain_timer:  float = 2.0

# Spawned root objects (so we can crush them in P3)
var active_roots: Array = []

const VOID_COLOR   = Color(0.4, 0.1, 0.6)
const ROOT_PATH    = "res://scenes/floor4/ShadowRoot.tscn"
const BULLET_PATH  = "res://scenes/enemies/EnemyBullet.tscn"

@onready var hitbox:      Area2D = $Hitbox
@onready var detect_zone: Area2D = $DetectionZone
@onready var body_sprite: Node2D = $BodySprite


func _ready():
	enemy_name     = "Nidhogg"
	max_health     = BOSS_HP
	current_health = max_health
	damage         = 1
	contact_damage_cooldown = 1.0
	add_to_group("enemies"); add_to_group("boss")
	if hitbox:
		hitbox.area_entered.connect(func(a):
			if a.is_in_group("player_bullets"):
				take_damage(a.get("damage") if a.get("damage") else 10))
	if detect_zone:
		detect_zone.body_entered.connect(func(b):
			if b.is_in_group("player"): player_ref = b)
	print("[Nidhogg] The root gnawer wakes.")


func _physics_process(delta: float):
	if nstate == NState.DYING: return
	state_timer -= delta
	_tick_cds(delta)
	if cur_phase >= 2: _tick_drain(delta)
	_run_state(delta)
	move_and_slide()
	if nstate == NState.CHASE: _check_contact_damage()


func _tick_cds(d: float):
	var cds = ["cd_burrow","cd_spit","cd_root","cd_coil",
			   "cd_wall","cd_scream","cd_wave","cd_crush"]
	for c in cds: if get(c) > 0: set(c, get(c) - d)


func _tick_drain(delta: float):
	drain_timer -= delta
	if drain_timer <= 0 and player_ref:
		drain_timer = 2.0
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < 110 and player_ref.has_method("take_damage"):
			if "last_hit_source" in player_ref:
				player_ref.last_hit_source = "Nidhogg's Aura"
			player_ref.take_damage(1)


func _run_state(delta: float):
	match nstate:
		NState.CHASE:        _do_chase()
		NState.BURROWING:    _do_burrowing(delta)
		NState.VOID_SPIT:    _do_spit(delta)
		NState.ROOT_SPIKE:   _do_root_spike(delta)
		NState.DARK_COIL:    _do_dark_coil(delta)
		NState.ROOT_WALL:    _do_root_wall(delta)
		NState.SOUL_SCREAM:  _do_scream(delta)
		NState.CORRUPT_WAVE: _do_wave(delta)
		NState.ROOT_CRUSH:   _do_crush(delta)
		NState.PHASE_TRANS:  _do_phase_trans(delta)


func _do_chase():
	if player_ref == null: return
	if state_timer > 0: velocity = Vector2.ZERO; return
	var to = player_ref.global_position - global_position
	velocity = to.normalized() * SPEEDS.get(cur_phase, 70.0)
	if body_sprite and velocity.x != 0: body_sprite.scale.x = sign(velocity.x)
	# Attack selection
	match cur_phase:
		1:
			if cd_burrow <= 0: _enter(NState.BURROWING, 1.0)
			elif cd_spit  <= 0: _enter(NState.VOID_SPIT, 0.8)
			elif cd_root  <= 0: _enter(NState.ROOT_SPIKE, 1.2)
		2:
			if cd_coil <= 0: _enter(NState.DARK_COIL, 2.0)
			elif cd_wall <= 0: _enter(NState.ROOT_WALL, 1.5)
			elif cd_spit <= 0: _enter(NState.VOID_SPIT, 0.8)
		3:
			if cd_crush  <= 0: _enter(NState.ROOT_CRUSH, 2.5)
			elif cd_scream <= 0: _enter(NState.SOUL_SCREAM, 1.0)
			elif cd_wave   <= 0: _enter(NState.CORRUPT_WAVE, 1.8)


func _enter(s: NState, dur: float):
	nstate = s; state_timer = dur; velocity = Vector2.ZERO


# ── BURROW ───────────────────────────────────────────────────
func _do_burrowing(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.5 and state_timer > 0.45:
		if body_sprite:
			var tw = create_tween()
			tw.tween_property(body_sprite, "modulate:a", 0.0, 0.4)
		if hitbox: hitbox.set_deferred("monitorable", false)
	if state_timer <= 0:
		if player_ref: burrow_pos = player_ref.global_position
		global_position = burrow_pos
		if body_sprite:
			var tw = create_tween()
			tw.tween_property(body_sprite, "modulate:a", 1.0, 0.3)
		if hitbox: hitbox.set_deferred("monitorable", true)
		# Burst on emerge
		for i in range(8):
			var a = (TAU/8.0)*i
			_fire(Vector2(cos(a), sin(a)), 150.0, 10, VOID_COLOR)
		cd_burrow = 7.0; nstate = NState.CHASE; state_timer = 0.5


# ── VOID SPIT (homing bolts) ─────────────────────────────────
func _do_spit(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.4 and state_timer > 0.35 and player_ref:
		var base = (player_ref.global_position - global_position).normalized()
		for a in [-0.3, 0.0, 0.3]:
			var b = _make_bullet(base.rotated(a), 130.0, 11, VOID_COLOR)
			if b: b.set_meta("homing_target", player_ref)
	if state_timer <= 0: cd_spit = 5.0; nstate = NState.CHASE; state_timer = 0.4


# ── ROOT SPIKE ───────────────────────────────────────────────
func _do_root_spike(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.6 and state_timer > 0.55 and player_ref:
		for i in range(3):
			var offset = Vector2(randf_range(-55,55), randf_range(-55,55))
			_spawn_root(player_ref.global_position + offset)
	if state_timer <= 0: cd_root = 6.0; nstate = NState.CHASE; state_timer = 0.4


# ── DARK COIL ────────────────────────────────────────────────
func _do_dark_coil(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 1.0 and state_timer > 0.95:
		# Fire inward from all 4 edges
		var rw = 16*40.0; var rh = 12*40.0
		var edges = [
			Vector2(40, rh/2), Vector2(rw-40, rh/2),
			Vector2(rw/2, 40), Vector2(rw/2, rh-40)
		]
		for epos in edges:
			var to_centre = (Vector2(rw/2,rh/2) - epos).normalized()
			for a in [-0.3,-0.15,0.0,0.15,0.3]:
				var b = _make_bullet_at(epos, to_centre.rotated(a), 150.0, 10, VOID_COLOR)
	if state_timer <= 0: cd_coil = 7.0; nstate = NState.CHASE; state_timer = 0.5


# ── ROOT WALL ────────────────────────────────────────────────
func _do_root_wall(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.75 and state_timer > 0.7:
		var rw = 16*40.0; var rh = 12*40.0
		# Horizontal line of roots
		for i in range(6):
			var rx = 60.0 + i * (rw - 120.0) / 5.0
			_spawn_root(Vector2(rx, rh/2 + randf_range(-20,20)))
	if state_timer <= 0: cd_wall = 8.0; nstate = NState.CHASE; state_timer = 0.5


# ── SOUL SCREAM ──────────────────────────────────────────────
func _do_scream(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.5 and state_timer > 0.45 and player_ref:
		# Stun player briefly
		player_ref.set_meta("stunned_timer", 0.8)
		# Void burst
		for i in range(14):
			var a = (TAU/14.0)*i
			_fire(Vector2(cos(a),sin(a)), 180.0, 9, VOID_COLOR)
	if state_timer <= 0: cd_scream = 8.0; nstate = NState.CHASE; state_timer = 0.5


# ── CORRUPTION WAVE ──────────────────────────────────────────
func _do_wave(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.9 and state_timer > 0.85:
		# 5 rows of bullets sweeping across the room
		for row in range(5):
			var y = 60.0 + row * (12*40.0 - 120.0) / 4.0
			_fire_wave_row(y)
	if state_timer <= 0: cd_wave = 9.0; nstate = NState.CHASE; state_timer = 0.5

func _fire_wave_row(y: float):
	if not ResourceLoader.exists(BULLET_PATH): return
	for i in range(7):
		var b = load(BULLET_PATH).instantiate()
		b.global_position = Vector2(40.0 + i*70.0, y)
		b.direction = Vector2(0, 1 if y < 12*40.0/2.0 else -1)
		b.speed = 120.0; b.damage = 9
		if b.has_node("Sprite2D"):
			b.get_node("Sprite2D").modulate = VOID_COLOR
		get_parent().add_child(b)


# ── ROOT CRUSH ───────────────────────────────────────────────
func _do_crush(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 1.3 and state_timer > 1.25:
		# All roots explode
		for root in active_roots:
			if is_instance_valid(root) and root.has_method("explode"):
				root.explode()
		active_roots.clear()
	if state_timer <= 0: cd_crush = 12.0; nstate = NState.CHASE; state_timer = 0.6


# ── PHASE TRANSITION ─────────────────────────────────────────
func _do_phase_trans(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0:
		nstate = NState.CHASE; state_timer = 0.5
		_halve_cds()

func _halve_cds():
	for c in ["cd_burrow","cd_spit","cd_root","cd_coil",
			  "cd_wall","cd_scream","cd_wave","cd_crush"]:
		set(c, get(c)/2.0)

func _check_phase():
	var pct = float(current_health)/float(max_health)
	if cur_phase==1 and pct<=P2_THRESH: _advance(2)
	elif cur_phase==2 and pct<=P3_THRESH: _advance(3)

func _advance(p: int):
	cur_phase = p; nstate = NState.PHASE_TRANS; state_timer = 2.0
	emit_signal("phase_changed", p)
	for i in range(if p==2: 10 else 18):
		var a = (TAU/(10 if p==2 else 18))*i
		_fire(Vector2(cos(a),sin(a)), 190.0, 0, VOID_COLOR)
	print("[Nidhogg] Phase ", p)


# ── TAKE DAMAGE / DEATH ──────────────────────────────────────
func take_damage(amount: int):
	if nstate == NState.DYING: return
	if nstate == NState.BURROWING and \
	   body_sprite and body_sprite.modulate.a < 0.3: return  # Immune while phasing
	current_health = max(0, current_health - amount)
	_check_phase()
	if current_health <= 0: _die()

func _die():
	nstate = NState.DYING; velocity = Vector2.ZERO
	if hitbox: hitbox.set_deferred("monitoring", false)
	emit_signal("died"); emit_signal("boss_died")
	if has_node("/root/GameData"): GameData.unlock_hero("Hel")
	print("[Nidhogg] The roots go still. Hel UNLOCKED!")
	_death_seq()

func _death_seq():
	for root in active_roots:
		if is_instance_valid(root): root.queue_free()
	for i in range(12):
		await get_tree().create_timer(0.12).timeout
		for j in range(5):
			var a = (TAU/5.0)*j + i*0.25
			_fire(Vector2(cos(a),sin(a)), 70.0, 0, VOID_COLOR)
	await get_tree().create_timer(0.5).timeout
	if body_sprite:
		var tw = create_tween()
		tw.tween_property(body_sprite,"modulate:a",0.0,1.0)
		await tw.finished
	if has_node("/root/ItemDropper") and has_node("/root/RuneDatabase"):
		var players = get_tree().get_nodes_in_group("player")
		var held = players[0].get_node("ItemManager").get_held_ids() \
			if not players.is_empty() and players[0].has_node("ItemManager") else []
		var rune = RuneDatabase.roll_random_rune(4, held)
		if rune.get("rarity","c") in ["common","uncommon"]:
			rune = RuneDatabase.roll_random_rune(4, held)
		ItemDropper._spawn_pedestal(get_parent(), global_position, rune)
	queue_free()


# ── HELPERS ──────────────────────────────────────────────────
func _spawn_root(pos: Vector2):
	if ResourceLoader.exists(ROOT_PATH):
		var r = load(ROOT_PATH).instantiate()
		r.global_position = pos
		get_parent().add_child(r)
		active_roots.append(r)
	else:
		print("[Nidhogg] Root at ", pos)

func _fire(dir: Vector2, spd: float, dmg: int, col: Color):
	var b = _make_bullet(dir, spd, dmg, col)

func _make_bullet(dir: Vector2, spd: float, dmg: int, col: Color) -> Node:
	return _make_bullet_at(global_position, dir, spd, dmg, col)

func _make_bullet_at(pos: Vector2, dir: Vector2, spd: float, dmg: int, col: Color) -> Node:
	if not ResourceLoader.exists(BULLET_PATH): return null
	var b = load(BULLET_PATH).instantiate()
	b.global_position = pos
	b.direction=dir; b.speed=spd; b.damage=dmg
	if b.has_node("Sprite2D"): b.get_node("Sprite2D").modulate=col
	get_parent().add_child(b); return b

func _check_contact_damage():
	if player_ref==null or contact_damage_timer>0: return
	if global_position.distance_to(player_ref.global_position)<=38:
		var extra=player_ref.get_meta("curse_extra_damage",0)
		if "last_hit_source" in player_ref: player_ref.last_hit_source="Nidhogg"
		player_ref.take_damage(damage+extra)
		contact_damage_timer=contact_damage_cooldown
