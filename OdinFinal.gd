extends "res://scripts/EnemyBase.gd"

# ============================================================
# OdinFinal.gd  —  The Allfather  (Floor 5 Final Boss)
# ============================================================
# Odin is the hardest boss. He fights in 3 phases and has
# the SACRIFICE mechanic: he drains HIS OWN HP to power up
# his deadliest attacks. The player can exploit this by
# surviving those moves and letting Odin weaken himself.
#
# ── PHASE 1  "THE WANDERER"  (100%→60%) ─────────────────────
#   Disguised — appears as a cloaked stranger. Slower, testing.
#   GUNGNIR THROW: powerful spear hurl, 18 dmg, piercing
#   HUGINN + MUNINN: 2 orbital ravens that fire every 3s
#   RUNE WALL: 7 rune pillars erupt in a line
#   WISDOM DRAIN: player within 100px loses 2 HP + Odin heals 2
#
# ── PHASE 2  "THE ALLFATHER REVEALED"  (60%→25%) ────────────
#   Cloak drops. True form — one-eyed, imposing.
#   SACRIFICE I: costs Odin 30 HP → fires VORTEX (18 bullets
#     spiral inward, player must move outward)
#   ALLSEEING BEAM: slow rotating beam of rune light
#   STORM CALL: 20 lightning bolts at random positions
#
# ── PHASE 3  "RAGNARÖK COME"  (25%→0%) ──────────────────────
#   Odin near death. Desperate and deadly.
#   SACRIFICE II: costs 50 HP → arena fills with 12 rune walls
#     and 20 bolts simultaneously
#   FINAL WISDOM: homing orbs that split on hit
#   ALL-FATHER'S WRATH: continuous rune beam that rotates
#     360° over 4s, walls follow behind it
#
# After death: Victory screen triggers directly.
# STATS: HP 500, P1 speed 65, P2 90, P3 120
# ============================================================

signal phase_changed(phase: int)
signal boss_died()

const BOSS_HP    = 500
const P2_THRESH  = 0.60
const P3_THRESH  = 0.25
const SPEEDS     = {1: 65.0, 2: 90.0, 3: 120.0}

enum OState {
	CHASE, GUNGNIR, RUNE_WALL, SACRIFICE, VORTEX,
	BEAM, STORM, FINAL_WISDOM, WRATH, PHASE_TRANS, DYING
}

var o_state:      OState = OState.CHASE
var cur_phase:    int    = 1
var state_timer:  float  = 2.5
var raven_angle:  float  = 0.0
var raven_cd:     float  = 3.0
var beam_angle:   float  = 0.0

var cd_gungnir:   float = 4.0
var cd_wall:      float = 5.5
var cd_sacr:      float = 10.0
var cd_vortex:    float = 7.0
var cd_beam:      float = 6.0
var cd_storm:     float = 7.0
var cd_wisdom:    float = 6.0
var cd_wrath:     float = 9.0
var drain_timer:  float = 2.0

const GOLD_COLOR = Color(1.0, 0.88, 0.3)
const RUNE_COLOR = Color(0.8, 0.6, 1.0)
const BULLET_PATH = "res://scenes/enemies/EnemyBullet.tscn"

@onready var hitbox:      Area2D = $Hitbox
@onready var detect_zone: Area2D = $DetectionZone
@onready var body_sprite: Node2D = $BodySprite


func _ready():
	enemy_name     = "Odin"
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
	print("[Odin] The Allfather regards you.")


func _physics_process(delta: float):
	if o_state == OState.DYING: return
	state_timer -= delta
	_tick_cds(delta)
	# Raven orbitals
	_tick_ravens(delta)
	# Wisdom drain (P1+)
	_tick_drain(delta)
	_run_state(delta)
	move_and_slide()
	if o_state == OState.CHASE: _check_contact()


func _tick_cds(d: float):
	for c in ["cd_gungnir","cd_wall","cd_sacr","cd_vortex",
			  "cd_beam","cd_storm","cd_wisdom","cd_wrath"]:
		if get(c) > 0: set(c, get(c) - d)


func _tick_ravens(delta: float):
	raven_angle += delta * 1.8   # Ravens orbit Odin
	raven_cd    -= delta
	if raven_cd <= 0 and player_ref:
		raven_cd = 3.0
		# Fire from both raven positions
		for i in range(2):
			var a   = raven_angle + (TAU / 2.0) * i
			var rpos = global_position + Vector2(cos(a), sin(a)) * 55.0
			var dir  = (player_ref.global_position - rpos).normalized()
			_fire_at(rpos, dir, 190.0, 9, GOLD_COLOR)


func _tick_drain(delta: float):
	drain_timer -= delta
	if drain_timer <= 0 and player_ref:
		drain_timer = 2.0
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < 100:
			if player_ref.has_method("take_damage"):
				if "last_hit_source" in player_ref:
					player_ref.last_hit_source = "Odin's Wisdom Drain"
				player_ref.take_damage(2)
			# Odin heals from the drain
			current_health = min(current_health + 2, max_health)


func _run_state(delta: float):
	match o_state:
		OState.CHASE:        _do_chase()
		OState.GUNGNIR:      _do_gungnir(delta)
		OState.RUNE_WALL:    _do_rune_wall(delta)
		OState.SACRIFICE:    _do_sacrifice(delta)
		OState.VORTEX:       _do_vortex(delta)
		OState.BEAM:         _do_beam(delta)
		OState.STORM:        _do_storm(delta)
		OState.FINAL_WISDOM: _do_wisdom(delta)
		OState.WRATH:        _do_wrath(delta)
		OState.PHASE_TRANS:  _do_phase_trans(delta)


func _do_chase():
	if player_ref == null: return
	if state_timer > 0: velocity = Vector2.ZERO; return
	var to = player_ref.global_position - global_position
	velocity = to.normalized() * SPEEDS.get(cur_phase, 65.0)
	if body_sprite and velocity.x != 0: body_sprite.scale.x = sign(velocity.x)
	match cur_phase:
		1:
			if cd_gungnir <= 0: _enter(OState.GUNGNIR, 1.2)
			elif cd_wall   <= 0: _enter(OState.RUNE_WALL, 1.5)
		2:
			if cd_sacr  <= 0: _enter(OState.SACRIFICE, 0.8)
			elif cd_beam <= 0: _enter(OState.BEAM, 4.0)
			elif cd_storm <= 0: _enter(OState.STORM, 1.5)
		3:
			if cd_wrath  <= 0: _enter(OState.WRATH, 4.0)
			elif cd_wisdom <= 0: _enter(OState.FINAL_WISDOM, 1.0)
			elif cd_sacr   <= 0: _enter(OState.SACRIFICE, 0.8)

func _enter(s: OState, dur: float):
	o_state = s; state_timer = dur; velocity = Vector2.ZERO


# ── GUNGNIR ──────────────────────────────────────────────────
func _do_gungnir(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.6 and state_timer > 0.55 and player_ref:
		var dir = (player_ref.global_position - global_position).normalized()
		var b   = _make_bullet(dir, 260.0, 18, GOLD_COLOR)
		if b: b.set_meta("piercing_count", 3)   # Pierces 3 enemies
	if state_timer <= 0:
		cd_gungnir = 5.0; o_state = OState.CHASE; state_timer = 0.5


# ── RUNE WALL ────────────────────────────────────────────────
func _do_rune_wall(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.75 and state_timer > 0.7:
		var rw = 16*40.0; var rh = 12*40.0
		# Rune pillars in a line through room centre (if player is on one side)
		var side = 1 if player_ref == null or player_ref.global_position.x > rw/2 else -1
		for i in range(7):
			var rx = rw/2 + side*20 + i * 40.0 * sign(side) * -1
			var b  = _make_bullet_at(Vector2(rx, rh/2), Vector2(0,0), 0, 12, RUNE_COLOR)
			if b:
				b.lifetime = 3.0   # Stationary rune pillar
				b.speed    = 0
	if state_timer <= 0:
		cd_wall = 6.0; o_state = OState.CHASE; state_timer = 0.5


# ── SACRIFICE + VORTEX ───────────────────────────────────────
func _do_sacrifice(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.4 and state_timer > 0.35:
		# Cost HP to power up
		var cost = 30 if cur_phase == 2 else 50
		current_health = max(1, current_health - cost)
		print("[Odin] SACRIFICE — paid ", cost, " HP for power!")
		if body_sprite:
			var tw = create_tween()
			tw.tween_property(body_sprite, "modulate", Color(0.3,0.3,1.0), 0.15)
			tw.tween_property(body_sprite, "modulate", _phase_color(),      0.3)
	if state_timer <= 0:
		cd_sacr = 12.0
		if cur_phase == 2: _enter(OState.VORTEX, 2.0)
		else: _launch_p3_sacrifice()

func _do_vortex(delta: float):
	velocity = Vector2.ZERO
	# Spiral bullets inward from edges
	if int(state_timer * 10) % 3 == 0:
		var rw = 16*40.0; var rh = 12*40.0
		var cx = rw/2; var cy = rh/2
		var a  = state_timer * 4.0
		var radius = 200.0
		var epos   = Vector2(cx + cos(a)*radius, cy + sin(a)*radius)
		var inward = (Vector2(cx,cy) - epos).normalized()
		_fire_at(epos, inward, 145.0, 11, RUNE_COLOR)
	if state_timer <= 0:
		cd_vortex = 8.0; o_state = OState.CHASE; state_timer = 0.5

func _launch_p3_sacrifice():
	# Massive: 12 rune walls + 20 bolts simultaneously
	for i in range(20):
		var a = (TAU/20.0)*i
		_fire(Vector2(cos(a),sin(a)), 175.0, 12, RUNE_COLOR)
	for i in range(6):
		var rw=16*40.0; var rh=12*40.0
		_fire_at(Vector2(randf_range(60,rw-60), randf_range(60,rh-60)),
			Vector2.ZERO, 0, 10, GOLD_COLOR)
	o_state = OState.CHASE; state_timer = 0.8


# ── ROTATING BEAM ────────────────────────────────────────────
func _do_beam(delta: float):
	velocity = Vector2.ZERO
	beam_angle += delta * (PI / 2.0)   # 90°/s rotation
	_fire(Vector2(cos(beam_angle), sin(beam_angle)), 220.0, 11, RUNE_COLOR)
	_fire(Vector2(cos(beam_angle + PI), sin(beam_angle + PI)), 220.0, 11, RUNE_COLOR)
	if state_timer <= 0:
		cd_beam = 7.0; o_state = OState.CHASE; state_timer = 0.5


# ── STORM CALL ───────────────────────────────────────────────
func _do_storm(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 1.0 and state_timer > 0.95:
		var rw=16*40.0; var rh=12*40.0
		for i in range(20):
			var pos = Vector2(randf_range(60,rw-60), randf_range(60,rh-60))
			_fire_at(pos, Vector2.DOWN, 200.0, 10, GOLD_COLOR)
	if state_timer <= 0:
		cd_storm = 8.0; o_state = OState.CHASE; state_timer = 0.5


# ── FINAL WISDOM (homing orbs) ───────────────────────────────
func _do_wisdom(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.5 and state_timer > 0.45 and player_ref:
		for i in range(5):
			var a   = (TAU/5.0)*i
			var dir = Vector2(cos(a),sin(a))
			var b   = _make_bullet(dir, 120.0, 12, RUNE_COLOR)
			if b: b.set_meta("homing_target", player_ref)
	if state_timer <= 0:
		cd_wisdom = 7.0; o_state = OState.CHASE; state_timer = 0.5


# ── ALL-FATHER'S WRATH ───────────────────────────────────────
func _do_wrath(delta: float):
	velocity = Vector2.ZERO
	beam_angle += delta * (TAU / 4.0)   # Full rotation in 4s
	for i in range(3):
		var a = beam_angle + (TAU/3.0)*i
		_fire(Vector2(cos(a),sin(a)), 200.0, 13, GOLD_COLOR)
	if state_timer <= 0:
		cd_wrath = 10.0; o_state = OState.CHASE; state_timer = 0.6


# ── PHASE TRANSITIONS ────────────────────────────────────────
func _do_phase_trans(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0:
		o_state = OState.CHASE; state_timer = 0.6
		_halve_cds()

func _halve_cds():
	for c in ["cd_gungnir","cd_wall","cd_sacr","cd_beam",
			  "cd_storm","cd_wisdom","cd_wrath"]:
		set(c, get(c)/2.0)

func _check_phase():
	var pct = float(current_health)/float(max_health)
	if cur_phase==1 and pct<=P2_THRESH: _advance(2)
	elif cur_phase==2 and pct<=P3_THRESH: _advance(3)

func _advance(p: int):
	cur_phase = p; o_state = OState.PHASE_TRANS; state_timer = 2.2
	emit_signal("phase_changed", p)
	for i in range(if p==2: 14 else 24):
		var a = (TAU/(14 if p==2 else 24))*i
		_fire(Vector2(cos(a),sin(a)), 200.0, 0, GOLD_COLOR if p==2 else RUNE_COLOR)
	print("[Odin] Phase ", p)

func _phase_color() -> Color:
	match cur_phase:
		1: return Color(0.9, 0.75, 0.3)
		2: return Color(1.0, 0.9, 0.5)
		3: return Color(1.0, 1.0, 0.7)
	return Color.WHITE


# ── TAKE DAMAGE / DEATH ──────────────────────────────────────
func take_damage(amount: int):
	if o_state == OState.DYING: return
	current_health = max(0, current_health - amount)
	if body_sprite:
		var tw = create_tween()
		tw.tween_property(body_sprite,"modulate",Color(2.0,1.5,0.5),0.06)
		tw.tween_property(body_sprite,"modulate",_phase_color(),     0.08)
	_check_phase()
	if current_health <= 0: _die()


func _die():
	o_state = OState.DYING; velocity = Vector2.ZERO
	if hitbox: hitbox.set_deferred("monitoring", false)
	emit_signal("died"); emit_signal("boss_died")
	print("[Odin] The Allfather falls. The saga is complete.")
	_death_seq()

func _death_seq():
	for i in range(14):
		await get_tree().create_timer(0.12).timeout
		for j in range(6):
			var a = (TAU/6.0)*j + i*0.22
			_fire(Vector2(cos(a),sin(a)), 75.0, 0, GOLD_COLOR)
	await get_tree().create_timer(0.6).timeout
	if body_sprite:
		var tw = create_tween()
		tw.tween_property(body_sprite,"modulate:a",0.0,1.2)
		await tw.finished
	# No item drop — Odin IS the reward (Victory screen)
	if has_node("/root/GameData"):
		GameData.end_run(true, "")
	get_tree().change_scene_to_file("res://scenes/VictoryScreen.tscn")
	queue_free()


# ── HELPERS ──────────────────────────────────────────────────
func _fire(dir: Vector2, spd: float, dmg: int, col: Color):
	_fire_at(global_position, dir, spd, dmg, col)

func _fire_at(pos: Vector2, dir: Vector2, spd: float, dmg: int, col: Color):
	_make_bullet_at(pos, dir, spd, dmg, col)

func _make_bullet(dir: Vector2, spd: float, dmg: int, col: Color) -> Node:
	return _make_bullet_at(global_position, dir, spd, dmg, col)

func _make_bullet_at(pos: Vector2, dir: Vector2, spd: float, dmg: int, col: Color) -> Node:
	if not ResourceLoader.exists(BULLET_PATH): return null
	var b = load(BULLET_PATH).instantiate()
	b.global_position=pos; b.direction=dir; b.speed=spd; b.damage=dmg
	if b.has_node("Sprite2D"): b.get_node("Sprite2D").modulate=col
	get_parent().add_child(b); return b

func _check_contact():
	if player_ref==null or contact_damage_timer>0: return
	if global_position.distance_to(player_ref.global_position)<=42:
		var extra=player_ref.get_meta("curse_extra_damage",0)
		if "last_hit_source" in player_ref: player_ref.last_hit_source="Odin"
		player_ref.take_damage(damage+extra)
		contact_damage_timer=contact_damage_cooldown
