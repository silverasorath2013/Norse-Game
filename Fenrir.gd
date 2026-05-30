extends "res://scripts/EnemyBase.gd"

# ============================================================
# Fenrir.gd  —  The Unchained Wolf  (Floor 2 Boss)
# ============================================================
# Fenrir is the giant wolf bound by the gods — until now.
# Tonally different from Jormungandr: faster, more visceral,
# less methodical. He's rage and hunger made flesh.
#
# ── PHASE 1  (100%–60% HP)  "BOUND" ────────────────────────
#   Fenrir is still partially restrained by magical chains.
#   Slower, but chains spawn ice hazards when they crack.
#   Attacks: Lunge, Pack Call, Snap
#
# ── PHASE 2  (60%–30% HP)  "BREAKING FREE" ─────────────────
#   Chains shatter. Fenrir goes berserk.
#   Attacks: Savage Rush, Ice Howl, Chain Shards
#   Speed significantly increased.
#
# ── PHASE 3  (30%–0%)  "UNCHAINED" ─────────────────────────
#   Full speed, constant pack wolves, screen-edge ice walls.
#   Attacks: Frenzy Bite, Frost Maul, Howl of Niflheim
#
# ── UNIQUE MECHANIC: CHAIN BREAK ────────────────────────────
#   In Phase 1, Fenrir has 4 "chains" (hit points separate from
#   HP) shown as glowing links near his portrait.
#   Breaking a chain is done by shooting his paws specifically
#   (a secondary hurtbox). Each broken chain:
#     - Grants the player a temporary +5 damage buff (10s)
#     - Enrages Fenrir slightly (+5 speed, new attack)
#   All 4 chains breaking early triggers a Phase 2 transition
#   regardless of HP.
#
# ── PACK: SPAWNS ICE WOLVES ─────────────────────────────────
#   "Pack Call" (Phase 1): spawns 2 IceWolves.
#   "Howl of Niflheim" (Phase 3): spawns 4 IceWolves + howl
#   buff immediately applied.
#
# STATS:
#   HP: 400   Phase 1 speed: 90   Phase 2: 130   Phase 3: 165
# ============================================================

signal phase_changed(new_phase: int)
signal boss_died()
signal chain_broken(chains_remaining: int)

# ── PHASES ────────────────────────────────────────────────────
enum FenrirPhase { BOUND, BREAKING, UNCHAINED }
var fenrir_phase: FenrirPhase = FenrirPhase.BOUND

const BOSS_MAX_HP:       int   = 400
const PHASE_2_THRESHOLD: float = 0.60
const PHASE_3_THRESHOLD: float = 0.30

# Chain mechanic
var chains_intact:   int  = 4
const MAX_CHAINS:    int  = 4

# Speed per phase
const PHASE_SPEEDS = {
	FenrirPhase.BOUND:     90.0,
	FenrirPhase.BREAKING:  130.0,
	FenrirPhase.UNCHAINED: 165.0,
}

# ── ATTACK STATES ─────────────────────────────────────────────
enum FenrirState {
	IDLE_CHASE,   # Default: charge toward player
	LUNGE,        # Phase 1: targeted dash
	SNAP,         # Phase 1: bite attack — short range huge damage
	PACK_CALL,    # Phase 1: howl to summon 2 wolves
	SAVAGE_RUSH,  # Phase 2: 3 consecutive lunges
	ICE_HOWL,     # Phase 2: ring of ice shards
	CHAIN_SHARDS, # Phase 2: broken chains fire as projectiles
	FRENZY_BITE,  # Phase 3: rapid bite spam
	FROST_MAUL,   # Phase 3: ice AoE slam
	NIFL_HOWL,    # Phase 3: summon 4 wolves + howl buff
	PHASE_TRANS,  # Transition stagger
	DYING,
}

var fenrir_state:   FenrirState = FenrirState.IDLE_CHASE
var state_timer:    float       = 0.0

# Attack cooldowns
var cd_lunge:        float = 3.0
var cd_snap:         float = 5.0
var cd_pack:         float = 12.0
var cd_rush:         float = 5.0
var cd_ice_howl:     float = 6.0
var cd_chain_shards: float = 7.0
var cd_frenzy:       float = 4.0
var cd_maul:         float = 7.0
var cd_nifl:         float = 10.0

# Rush attack tracking
var rush_count:      int     = 0
var rush_direction:  Vector2 = Vector2.ZERO

# Snap / Maul
var snap_pos:        Vector2 = Vector2.ZERO

# Phase transition
var phase_trans_done: bool = false

# Ice wall timer (Phase 3)
var ice_wall_timer:  float = 0.0

# @onready
@onready var head_sprite:    Node2D  = $HeadSprite
@onready var body_sprite:    Node2D  = $BodySprite
@onready var paw_hurtbox:    Area2D  = $PawHurtbox     # Chain hurtbox
@onready var main_hurtbox:   Area2D  = $Hitbox


func _ready():
	# Don't call super() — Fenrir is fully custom
	enemy_name     = "Fenrir"
	max_health     = BOSS_MAX_HP
	current_health = max_health
	damage         = 2
	contact_damage_cooldown = 0.9
	detection_range = 9999.0
	
	add_to_group("enemies")
	add_to_group("boss")
	
	if main_hurtbox:
		main_hurtbox.area_entered.connect(_on_main_hurtbox_hit)
	
	# Paw hurtbox — shoots here to break chains
	if paw_hurtbox:
		paw_hurtbox.area_entered.connect(_on_paw_hurtbox_hit)
	
	if has_node("DetectionZone"):
		$DetectionZone.body_entered.connect(_on_detection_body_entered)
	
	_play_intro()


func _play_intro():
	fenrir_state = FenrirState.IDLE_CHASE
	state_timer  = 2.2   # Brief growl before attacking
	print("[Fenrir] The chains strain. The wolf awakens.")


# ════════════════════════════════════════════════════════════
# _physics_process
# ════════════════════════════════════════════════════════════
func _physics_process(delta: float):
	if fenrir_state == FenrirState.DYING: return
	
	state_timer -= delta
	_tick_cooldowns(delta)
	
	# Phase 3: spawn ice walls from screen edges
	if fenrir_phase == FenrirPhase.UNCHAINED:
		ice_wall_timer -= delta
		if ice_wall_timer <= 0:
			ice_wall_timer = 5.0
			_spawn_ice_wall_edge()
	
	match fenrir_state:
		FenrirState.IDLE_CHASE:   _state_chase(delta)
		FenrirState.LUNGE:        _state_lunge(delta)
		FenrirState.SNAP:         _state_snap(delta)
		FenrirState.PACK_CALL:    _state_pack_call(delta)
		FenrirState.SAVAGE_RUSH:  _state_savage_rush(delta)
		FenrirState.ICE_HOWL:     _state_ice_howl(delta)
		FenrirState.CHAIN_SHARDS: _state_chain_shards(delta)
		FenrirState.FRENZY_BITE:  _state_frenzy_bite(delta)
		FenrirState.FROST_MAUL:   _state_frost_maul(delta)
		FenrirState.NIFL_HOWL:    _state_nifl_howl(delta)
		FenrirState.PHASE_TRANS:  _state_phase_trans(delta)
	
	move_and_slide()
	_check_contact_damage()


func _tick_cooldowns(delta: float):
	if cd_lunge > 0:        cd_lunge        -= delta
	if cd_snap > 0:         cd_snap         -= delta
	if cd_pack > 0:         cd_pack         -= delta
	if cd_rush > 0:         cd_rush         -= delta
	if cd_ice_howl > 0:     cd_ice_howl     -= delta
	if cd_chain_shards > 0: cd_chain_shards -= delta
	if cd_frenzy > 0:       cd_frenzy       -= delta
	if cd_maul > 0:         cd_maul         -= delta
	if cd_nifl > 0:         cd_nifl         -= delta


# ════════════════════════════════════════════════════════════
# IDLE CHASE — main movement + attack selection
# ════════════════════════════════════════════════════════════
func _state_chase(delta: float):
	if player_ref == null: return
	
	var spd = PHASE_SPEEDS.get(fenrir_phase, 90.0)
	var to_player = player_ref.global_position - global_position
	velocity = to_player.normalized() * spd
	
	if head_sprite and velocity.x != 0:
		head_sprite.scale.x = sign(velocity.x)
	
	# Attack selection (priority order per phase)
	match fenrir_phase:
		FenrirPhase.BOUND:
			if cd_snap <= 0 and to_player.length() < 80:
				_enter_snap()
			elif cd_lunge <= 0:
				_enter_lunge()
			elif cd_pack <= 0:
				_enter_pack_call()
		
		FenrirPhase.BREAKING:
			if cd_frenzy <= 0 and to_player.length() < 90:
				_enter_frenzy_bite()
			elif cd_rush <= 0:
				_enter_savage_rush()
			elif cd_ice_howl <= 0:
				_enter_ice_howl()
			elif cd_chain_shards <= 0 and chains_intact < MAX_CHAINS:
				_enter_chain_shards()
		
		FenrirPhase.UNCHAINED:
			if cd_maul <= 0 and to_player.length() < 100:
				_enter_frost_maul()
			elif cd_frenzy <= 0:
				_enter_frenzy_bite()
			elif cd_nifl <= 0:
				_enter_nifl_howl()
			elif cd_rush <= 0:
				_enter_savage_rush()


# ════════════════════════════════════════════════════════════
# PHASE 1 ATTACKS
# ════════════════════════════════════════════════════════════

func _enter_lunge():
	fenrir_state = FenrirState.LUNGE
	cd_lunge     = 3.5
	state_timer  = 0.6   # Wind up then dash
	if player_ref:
		rush_direction = (player_ref.global_position - global_position).normalized()
	velocity = Vector2.ZERO

func _state_lunge(delta: float):
	if state_timer > 0.3:
		velocity = Vector2.ZERO   # Wind up
	else:
		velocity = rush_direction * 280.0   # Lunge
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE


func _enter_snap():
	fenrir_state = FenrirState.SNAP
	cd_snap      = 5.5
	state_timer  = 0.5
	velocity     = Vector2.ZERO
	if player_ref:
		snap_pos = player_ref.global_position

func _state_snap(delta: float):
	velocity = Vector2.ZERO
	# Deal high contact damage at snap position
	if state_timer <= 0.25 and state_timer > 0.2 and player_ref:
		var dist = snap_pos.distance_to(player_ref.global_position)
		if dist < 60 and player_ref.has_method("take_damage"):
			if "last_hit_source" in player_ref:
				player_ref.last_hit_source = "Fenrir's Jaws"
			player_ref.take_damage(3)   # 3 damage — devastating
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE


func _enter_pack_call():
	fenrir_state = FenrirState.PACK_CALL
	cd_pack      = 14.0
	state_timer  = 1.2
	velocity     = Vector2.ZERO
	print("[Fenrir] PACK CALL!")

func _state_pack_call(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.6 and state_timer > 0.55:
		_spawn_ice_wolves(2)
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE


# ════════════════════════════════════════════════════════════
# PHASE 2 ATTACKS
# ════════════════════════════════════════════════════════════

func _enter_savage_rush():
	fenrir_state = FenrirState.SAVAGE_RUSH
	cd_rush      = 5.5
	rush_count   = 3   # 3 consecutive rushes
	state_timer  = 0.3
	if player_ref:
		rush_direction = (player_ref.global_position - global_position).normalized()

func _state_savage_rush(delta: float):
	if state_timer > 0:
		# Brief pause between rushes
		velocity = Vector2.ZERO
		if state_timer <= 0.05 and rush_count > 0:
			# Re-aim for each rush
			if player_ref:
				rush_direction = (player_ref.global_position - global_position).normalized()
	else:
		velocity = rush_direction * 320.0
		if get_slide_collision_count() > 0 or velocity.dot(
				(player_ref.global_position - global_position if player_ref else Vector2.ONE)
			) < 0:
			rush_count -= 1
			if rush_count > 0:
				state_timer = 0.25
			else:
				fenrir_state = FenrirState.IDLE_CHASE


func _enter_ice_howl():
	fenrir_state = FenrirState.ICE_HOWL
	cd_ice_howl  = 6.5
	state_timer  = 0.8
	velocity     = Vector2.ZERO
	print("[Fenrir] ICE HOWL!")

func _state_ice_howl(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.4 and state_timer > 0.35:
		for i in range(14):
			var angle = (TAU / 14.0) * i
			_fire_ice(Vector2(cos(angle), sin(angle)), 180.0, 10)
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE


func _enter_chain_shards():
	fenrir_state = FenrirState.CHAIN_SHARDS
	cd_chain_shards = 8.0
	state_timer     = 0.6
	velocity        = Vector2.ZERO

func _state_chain_shards(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.3 and state_timer > 0.25:
		var broken = MAX_CHAINS - chains_intact
		for i in range(broken * 2):
			var angle = randf_range(0, TAU)
			_fire_ice(Vector2(cos(angle), sin(angle)), 200.0, 8)
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE


# ════════════════════════════════════════════════════════════
# PHASE 3 ATTACKS
# ════════════════════════════════════════════════════════════

func _enter_frenzy_bite():
	fenrir_state = FenrirState.FRENZY_BITE
	cd_frenzy    = 4.5
	state_timer  = 1.0

func _state_frenzy_bite(delta: float):
	if player_ref:
		velocity = (player_ref.global_position - global_position).normalized() * 190.0
	# Rapid damage checks at 3x contact rate
	if contact_damage_timer <= 0 and player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < 40 and player_ref.has_method("take_damage"):
			if "last_hit_source" in player_ref:
				player_ref.last_hit_source = "Fenrir's Frenzy"
			player_ref.take_damage(1)
			contact_damage_timer = 0.3   # Fast bites
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE


func _enter_frost_maul():
	fenrir_state = FenrirState.FROST_MAUL
	cd_maul      = 8.0
	state_timer  = 1.0
	velocity     = Vector2.ZERO
	if player_ref: snap_pos = player_ref.global_position
	print("[Fenrir] FROST MAUL!")

func _state_frost_maul(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.5 and state_timer > 0.45:
		# Slam — AoE ice damage + spawn 3 ice patches
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if global_position.distance_to(p.global_position) < 120:
				if "last_hit_source" in p: p.last_hit_source = "Fenrir's Maul"
				p.take_damage(2)
		for i in range(3):
			var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
			_spawn_ice_patch_at(snap_pos + offset)
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE


func _enter_nifl_howl():
	fenrir_state = FenrirState.NIFL_HOWL
	cd_nifl      = 12.0
	state_timer  = 1.5
	velocity     = Vector2.ZERO
	print("[Fenrir] HOWL OF NIFLHEIM!")

func _state_nifl_howl(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0.75 and state_timer > 0.7:
		_spawn_ice_wolves(4)
		# Ice shard burst outward
		for i in range(10):
			var angle = (TAU / 10.0) * i
			_fire_ice(Vector2(cos(angle), sin(angle)), 155.0, 8)
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE


# ════════════════════════════════════════════════════════════
# PHASE TRANSITION
# ════════════════════════════════════════════════════════════
func _check_phase_transition():
	var pct = float(current_health) / float(max_health)
	
	if fenrir_phase == FenrirPhase.BOUND and pct <= PHASE_2_THRESHOLD:
		_enter_phase(FenrirPhase.BREAKING)
	elif fenrir_phase == FenrirPhase.BREAKING and pct <= PHASE_3_THRESHOLD:
		_enter_phase(FenrirPhase.UNCHAINED)


func _enter_phase(new_phase: FenrirPhase):
	fenrir_phase  = new_phase
	fenrir_state  = FenrirState.PHASE_TRANS
	state_timer   = 2.0
	velocity      = Vector2.ZERO
	emit_signal("phase_changed", new_phase as int)
	
	match new_phase:
		FenrirPhase.BREAKING:
			print("[Fenrir] CHAINS BREAK — PHASE 2!")
			# Chain break animation: fire 12 debris pieces
			for i in range(12):
				var angle = (TAU / 12.0) * i
				_fire_ice(Vector2(cos(angle), sin(angle)), 160.0, 0)
			if head_sprite:
				var tween = create_tween()
				tween.tween_property(head_sprite, "modulate",
					Color(0.85, 0.9, 1.0), 0.3)
		
		FenrirPhase.UNCHAINED:
			print("[Fenrir] FULLY UNCHAINED — PHASE 3!")
			ice_wall_timer = 5.0
			for i in range(20):
				var angle = (TAU / 20.0) * i
				_fire_ice(Vector2(cos(angle), sin(angle)), 200.0, 0)
			if head_sprite:
				var tween = create_tween()
				tween.tween_property(head_sprite, "modulate",
					Color(0.6, 0.8, 1.0), 0.4)


func _state_phase_trans(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0:
		fenrir_state = FenrirState.IDLE_CHASE
		# Halve all cooldowns on phase entry
		cd_lunge /= 2; cd_snap /= 2; cd_pack /= 2
		cd_rush  /= 2; cd_ice_howl /= 2; cd_frenzy /= 2
		cd_maul  /= 2; cd_nifl /= 2


# ════════════════════════════════════════════════════════════
# CHAIN MECHANIC — paw hurtbox
# ════════════════════════════════════════════════════════════
func _on_paw_hurtbox_hit(area: Area2D):
	if not area.is_in_group("player_bullets"): return
	if chains_intact <= 0: return
	
	chains_intact -= 1
	emit_signal("chain_broken", chains_intact)
	print("[Fenrir] Chain broken! Remaining: ", chains_intact)
	
	# Buff the player briefly for breaking a chain
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		p.set_meta("chain_break_bonus", p.get_meta("chain_break_bonus", 0) + 5)
		p.base_damage += 5
		get_tree().create_timer(10.0).timeout.connect(
			func(): if is_instance_valid(p): p.base_damage -= 5
		)
	
	# Enrage slightly
	move_speed = PHASE_SPEEDS.get(fenrir_phase, 90.0) + (MAX_CHAINS - chains_intact) * 5.0
	
	# If all chains broken early → force phase 2
	if chains_intact <= 0 and fenrir_phase == FenrirPhase.BOUND:
		_enter_phase(FenrirPhase.BREAKING)


# ════════════════════════════════════════════════════════════
# TAKE DAMAGE
# ════════════════════════════════════════════════════════════
func _on_main_hurtbox_hit(area: Area2D):
	if not area.is_in_group("player_bullets"): return
	var dmg = area.get("damage") if area.get("damage") != null else 10
	take_damage(dmg)

func take_damage(amount: int):
	if fenrir_state == FenrirState.DYING: return
	
	current_health = max(0, current_health - amount)
	
	if head_sprite:
		var tween = create_tween()
		tween.tween_property(head_sprite, "modulate",
			Color(1.5, 0.8, 0.8), 0.06)
		tween.tween_property(head_sprite, "modulate",
			_get_phase_modulate(), 0.08)
	
	_check_phase_transition()
	if current_health <= 0:
		_die()

func _get_phase_modulate() -> Color:
	match fenrir_phase:
		FenrirPhase.BOUND:     return Color(0.75, 0.88, 1.0)
		FenrirPhase.BREAKING:  return Color(0.85, 0.90, 1.0)
		FenrirPhase.UNCHAINED: return Color(0.60, 0.80, 1.0)
	return Color.WHITE


# ════════════════════════════════════════════════════════════
# DEATH
# ════════════════════════════════════════════════════════════
func _die():
	fenrir_state = FenrirState.DYING
	velocity     = Vector2.ZERO
	
	if main_hurtbox:
		main_hurtbox.set_deferred("monitoring",  false)
		main_hurtbox.set_deferred("monitorable", false)
	
	emit_signal("died")
	emit_signal("boss_died")
	
	print("[Fenrir] The wolf falls. The chains hold — for now.")
	
	if has_node("/root/GameData"):
		GameData.unlock_hero("Loki")
		print("[Fenrir] Loki UNLOCKED!")
	
	_play_death_sequence()


func _play_death_sequence():
	for i in range(8):
		await get_tree().create_timer(0.15).timeout
		for j in range(4):
			var angle = (TAU / 4.0) * j + i * 0.2
			_fire_ice(Vector2(cos(angle), sin(angle)), 90.0, 0)
	
	await get_tree().create_timer(0.5).timeout
	
	if head_sprite:
		var tween = create_tween()
		tween.tween_property(head_sprite, "modulate:a", 0.0, 1.0)
		await tween.finished
	
	# Drop guaranteed rare/legendary
	if has_node("/root/ItemDropper") and has_node("/root/RuneDatabase"):
		var players = get_tree().get_nodes_in_group("player")
		var held    = players[0].get_node("ItemManager").get_held_ids() \
			if not players.is_empty() and players[0].has_node("ItemManager") else []
		var rune    = RuneDatabase.roll_random_rune(2, held)
		if rune.get("rarity","common") in ["common","uncommon"]:
			rune = RuneDatabase.roll_random_rune(2, held)
		ItemDropper._spawn_pedestal(get_parent(), global_position, rune)
	
	queue_free()


# ════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════

func _fire_ice(direction: Vector2, speed: float, dmg: int):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	var b = load(path).instantiate()
	b.global_position = global_position
	b.direction = direction
	b.speed     = speed
	b.damage    = dmg
	if b.has_node("Sprite2D"):
		b.get_node("Sprite2D").modulate = Color(0.65, 0.85, 1.0)
	get_parent().add_child(b)


func _spawn_ice_wolves(count: int):
	var path = "res://scenes/enemies/IceWolf.tscn"
	for i in range(count):
		var angle  = (TAU / count) * i
		var offset = Vector2(cos(angle), sin(angle)) * 100.0
		if ResourceLoader.exists(path):
			var wolf = load(path).instantiate()
			wolf.global_position = global_position + offset
			wolf.add_to_group("enemies")
			get_parent().add_child(wolf)
			# Connect death to Room for door tracking
			var rooms = get_tree().get_nodes_in_group("room")
			if not rooms.is_empty() and rooms[0].has_method("_on_enemy_died"):
				wolf.died.connect(rooms[0]._on_enemy_died)
		else:
			print("[Fenrir] IceWolf ", i, " spawned at ", global_position + offset)


func _spawn_ice_patch_at(pos: Vector2):
	var path = "res://scenes/floor2/IcePatch.tscn"
	if ResourceLoader.exists(path):
		var patch = load(path).instantiate()
		patch.global_position = pos
		get_parent().add_child(patch)


func _spawn_ice_wall_edge():
	# Spawn 3 ice patches along a random room edge
	var room_w = 16 * 40.0
	var room_h = 12 * 40.0
	var edge   = randi() % 4
	for i in range(3):
		var pos: Vector2
		match edge:
			0: pos = Vector2(randf_range(60, room_w - 60), 60)
			1: pos = Vector2(randf_range(60, room_w - 60), room_h - 60)
			2: pos = Vector2(60, randf_range(60, room_h - 60))
			3: pos = Vector2(room_w - 60, randf_range(60, room_h - 60))
		_spawn_ice_patch_at(pos)


func _on_detection_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_ref = body


func _check_contact_damage():
	if player_ref == null or contact_damage_timer > 0: return
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < 40 and player_ref.has_method("take_damage"):
		var extra = player_ref.get_meta("curse_extra_damage", 0)
		if "last_hit_source" in player_ref:
			player_ref.last_hit_source = "Fenrir"
		player_ref.take_damage(damage + extra)
		contact_damage_timer = contact_damage_cooldown
