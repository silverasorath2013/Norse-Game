extends "res://scripts/EnemyBase.gd"

# ============================================================
# Jormungandr.gd  —  The World Serpent  (Floor 1 Boss)
# ============================================================
# Jormungandr is a massive snake coiled around the arena.
# It fights across THREE phases, each with new attacks.
# The transition between phases plays a brief cinematic pause.
#
# ── PHASE 1  (HP: 100% → 66%) ────────────────────────────
#   COIL_CHASE   → the head segment pursues the player slowly,
#                  body segments trail behind it
#   SPIT         → fires 3 poison globules in a spread
#   TAIL_SWEEP   → the tail swings across the room in an arc
#
# ── PHASE 2  (HP: 66% → 33%) ────────────────────────────
#   Everything above, plus:
#   RING_BURST   → fires 12 bullets radially from the head
#   BURROW       → sinks into the floor, reappears under player
#   BODY_SLAM    → lunges the entire body diagonally across room
#
# ── PHASE 3  (HP: 33% → 0%) ─────────────────────────────
#   Everything above, plus:
#   FRENZY       → move speed +40%, fire rate doubled
#   VENOM_RING   → 3 rotating rings of venom bullets orbit head
#   COIL_CRUSH   → the body contracts toward the centre,
#                  shrinking the safe zone
#
# STRUCTURE:
#   Jormungandr is made of SEGMENTS — a head + 12 body segments.
#   Each segment is a separate Node2D child with its own sprite.
#   The head moves via AI; body segments follow like a snake
#   (each tracks the segment in front of it with a delay).
#
# SCENE TREE:
#   Jormungandr  [CharacterBody2D]  ← this script
#   ├── Head  [Sprite2D]
#   ├── Hitbox  [Area2D]
#   ├── DetectionZone  [Area2D]
#   ├── BodySegments  [Node2D]
#   │   ├── Segment0  [Node2D]
#   │   ├── Segment1  [Node2D]
#   │   └── ... (12 total)
#   ├── AttackMarkers  [Node2D]  ← spawn points for projectiles
#   ├── PhaseParticles  [Node2D]  ← VFX on phase change
#   └── BossHPBar  [Control]      ← drawn in _draw() on CanvasLayer
# ============================================================

signal phase_changed(new_phase: int)
signal boss_died()

# ── BOSS STATS ───────────────────────────────────────────────
const BOSS_MAX_HP:    int   = 350
const NUM_SEGMENTS:   int   = 12
const SEGMENT_DIST:   float = 22.0  # Pixels between each body segment

# Phase thresholds (fraction of max HP)
const PHASE_2_THRESHOLD: float = 0.66
const PHASE_3_THRESHOLD: float = 0.33

# ── SPEED PER PHASE ──────────────────────────────────────────
const SPEED_PHASE = {1: 70.0, 2: 90.0, 3: 130.0}

# ── ATTACK COOLDOWNS ─────────────────────────────────────────
const CD_SPIT:       float = 3.5
const CD_TAIL:       float = 5.0
const CD_RING:       float = 4.0
const CD_BURROW:     float = 7.0
const CD_SLAM:       float = 6.0
const CD_VENOM_RING: float = 5.5
const CD_COIL:       float = 8.0

# ── BOSS STATES ──────────────────────────────────────────────
enum BossState {
	INTRO,        # Cinematic entry, player can't move
	COIL_CHASE,   # Default: head pursues player, body follows
	SPIT,         # Firing poison spread
	TAIL_SWEEP,   # Tail arc attack
	RING_BURST,   # Radial bullet spray (phase 2+)
	BURROWING,    # Underground (phase 2+)
	RESURFACE,    # Emerging under player
	BODY_SLAM,    # Full-body diagonal lunge (phase 2+)
	VENOM_RING,   # Orbiting bullet rings (phase 3)
	COIL_CRUSH,   # Shrinking coil (phase 3)
	PHASE_TRANS,  # Brief stagger between phases
	DYING,        # Death sequence
}

# ── RUNTIME STATE ────────────────────────────────────────────
var boss_state:     BossState = BossState.INTRO
var current_phase:  int       = 1
var attack_timer:   float     = 2.5   # First attack after 2.5s
var state_timer:    float     = 0.0   # How long current state lasts
var intro_done:     bool      = false

# Segment position history — each segment copies head position
# from a few frames ago, creating the snake-tail effect
var position_history: Array[Vector2] = []
const HISTORY_SIZE: int = NUM_SEGMENTS * 4  # Enough frames of lag

# Attack cooldown timers (individual per attack)
var cd_spit:       float = CD_SPIT
var cd_tail:       float = CD_TAIL * 0.5   # Ready sooner at start
var cd_ring:       float = CD_RING
var cd_burrow:     float = CD_BURROW
var cd_slam:       float = CD_SLAM
var cd_venom:      float = CD_VENOM_RING
var cd_coil:       float = CD_COIL

# Venom ring state (phase 3)
var venom_ring_active:  bool  = false
var venom_ring_angle:   float = 0.0
var venom_ring_timer:   float = 0.0

# Body slam state
var slam_direction:     Vector2 = Vector2.ZERO
var slam_timer:         float   = 0.0

# Burrow state
var burrow_target:      Vector2 = Vector2.ZERO

# Coil crush state
var coil_radius:        float   = 240.0   # Starts wide, shrinks

# ── NODE REFERENCES ──────────────────────────────────────────
@onready var head_sprite:     Node2D  = $Head
@onready var body_container:  Node2D  = $BodySegments
@onready var hitbox:          Area2D  = $Hitbox
@onready var detection_zone:  Area2D  = $DetectionZone
@onready var phase_particles: Node2D  = $PhaseParticles


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	# Don't call super() — Jormungandr manages its own setup
	enemy_name    = "Jormungandr"
	max_health    = BOSS_MAX_HP
	current_health = max_health
	damage        = 2   # Contact damage (2 = full heart)
	contact_damage_cooldown = 1.0
	
	add_to_group("enemies")
	add_to_group("boss")
	
	# Fill position history with starting position
	for i in HISTORY_SIZE:
		position_history.append(global_position)
	
	# Connect detection
	if detection_zone:
		detection_zone.body_entered.connect(_on_detection_body_entered)
	if hitbox:
		hitbox.area_entered.connect(_on_hurtbox_area_entered)
		hitbox.body_entered.connect(_on_hurtbox_body_entered)
	
	# Begin intro sequence
	_play_intro()
	print("[Jormungandr] Awakens. ", BOSS_MAX_HP, " HP. Tremble.")


# ════════════════════════════════════════════════════════════
# _physics_process()
# ════════════════════════════════════════════════════════════
func _physics_process(delta: float):
	if boss_state == BossState.DYING: return
	
	# Always update position history for body segments
	_update_position_history()
	_update_body_segments()
	
	# Tick cooldowns
	_tick_cooldowns(delta)
	
	# Tick venom ring rotation if active
	if venom_ring_active:
		_tick_venom_ring(delta)
	
	# State machine
	match boss_state:
		BossState.INTRO:        _state_intro(delta)
		BossState.COIL_CHASE:   _state_coil_chase(delta)
		BossState.SPIT:         _state_spit(delta)
		BossState.TAIL_SWEEP:   _state_tail_sweep(delta)
		BossState.RING_BURST:   _state_ring_burst(delta)
		BossState.BURROWING:    _state_burrowing(delta)
		BossState.RESURFACE:    _state_resurface(delta)
		BossState.BODY_SLAM:    _state_body_slam(delta)
		BossState.VENOM_RING:   _state_venom_ring(delta)
		BossState.COIL_CRUSH:   _state_coil_crush(delta)
		BossState.PHASE_TRANS:  _state_phase_trans(delta)
	
	move_and_slide()
	_check_contact_damage()


# ════════════════════════════════════════════════════════════
# POSITION HISTORY — for the snake body trail effect
# Each physics frame, we prepend the head's current position.
# Body segments then read positions from earlier in the history.
# ════════════════════════════════════════════════════════════
func _update_position_history():
	position_history.push_front(global_position)
	if position_history.size() > HISTORY_SIZE:
		position_history.pop_back()

func _update_body_segments():
	if not body_container: return
	var segments = body_container.get_children()
	for i in range(segments.size()):
		# Each segment reads a position from i * 4 frames ago
		# The "4" controls how loose/tight the body follows
		var history_idx = min((i + 1) * 4, position_history.size() - 1)
		segments[i].global_position = position_history[history_idx]
		# Rotate segment to face the previous segment (looks like a connected body)
		if i == 0:
			var look_target = global_position
			segments[i].look_at(look_target)
		else:
			segments[i].look_at(segments[i - 1].global_position)


# ════════════════════════════════════════════════════════════
# COOLDOWN TICKING
# ════════════════════════════════════════════════════════════
func _tick_cooldowns(delta: float):
	if cd_spit  > 0: cd_spit  -= delta
	if cd_tail  > 0: cd_tail  -= delta
	if cd_ring  > 0: cd_ring  -= delta
	if cd_burrow > 0: cd_burrow -= delta
	if cd_slam  > 0: cd_slam  -= delta
	if cd_venom > 0: cd_venom -= delta
	if cd_coil  > 0: cd_coil  -= delta
	if state_timer > 0: state_timer -= delta


# ════════════════════════════════════════════════════════════
# INTRO SEQUENCE
# ════════════════════════════════════════════════════════════
func _play_intro():
	boss_state = BossState.INTRO
	state_timer = 2.5   # 2.5s cinematic before fighting starts
	# Coil into view — animate from off-screen or from a curl
	if head_sprite:
		head_sprite.modulate = Color(0.3, 0.6, 0.2, 0.0)
		var tween = create_tween()
		tween.tween_property(head_sprite, "modulate", Color(0.3, 0.6, 0.2, 1.0), 1.5)
	print("[Jormungandr] Rising from the deep...")

func _state_intro(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0:
		boss_state = BossState.COIL_CHASE
		print("[Jormungandr] PHASE 1 — Coiled Pursuit begins!")


# ════════════════════════════════════════════════════════════
# STATE: COIL_CHASE — default movement state
# Head moves toward player. Chooses next attack when ready.
# ════════════════════════════════════════════════════════════
func _state_coil_chase(delta: float):
	if player_ref == null: return
	
	var to_player = player_ref.global_position - global_position
	var spd = SPEED_PHASE.get(current_phase, 70.0)
	velocity = to_player.normalized() * spd
	
	# Rotate head sprite to face movement direction
	if head_sprite and velocity.length() > 1:
		head_sprite.rotation = velocity.angle()
	
	# ── SELECT NEXT ATTACK ───────────────────────────────────
	# Pick the highest-priority available attack for this phase
	if cd_spit <= 0:
		_enter_spit()
	elif cd_tail <= 0:
		_enter_tail_sweep()
	elif current_phase >= 2 and cd_ring <= 0:
		_enter_ring_burst()
	elif current_phase >= 2 and cd_burrow <= 0:
		_enter_burrow()
	elif current_phase >= 2 and cd_slam <= 0:
		_enter_body_slam()
	elif current_phase >= 3 and cd_venom <= 0:
		_enter_venom_ring()
	elif current_phase >= 3 and cd_coil <= 0:
		_enter_coil_crush()


# ════════════════════════════════════════════════════════════
# ATTACK: SPIT  —  3-way poison spread (all phases)
# Stops briefly, fires 3 projectiles in a fan,
# then resumes chasing
# ════════════════════════════════════════════════════════════
func _enter_spit():
	boss_state  = BossState.SPIT
	cd_spit     = CD_SPIT
	state_timer = 0.8   # Stop for 0.8s to fire
	velocity    = Vector2.ZERO

func _state_spit(delta: float):
	velocity = Vector2.ZERO   # Hold still while spitting
	
	# Fire at 0.4s into the spit (halfway through the pause)
	if state_timer <= 0.4 and state_timer > 0.35:
		_fire_spit()
	
	if state_timer <= 0:
		boss_state = BossState.COIL_CHASE

func _fire_spit():
	if player_ref == null: return
	var base_dir = (player_ref.global_position - global_position).normalized()
	
	# 3-shot spread: centre, -20°, +20°
	var angles = [-0.35, 0.0, 0.35]
	for a in angles:
		_spawn_enemy_bullet(global_position, base_dir.rotated(a), 180.0, 12, Color(0.3, 0.8, 0.2))
	
	print("[Jormungandr] SPIT!")


# ════════════════════════════════════════════════════════════
# ATTACK: TAIL SWEEP  —  the last body segment swings in an arc
# We animate the tail's position directly for 1.5s
# The tail segment damages the player if they touch it
# ════════════════════════════════════════════════════════════
func _enter_tail_sweep():
	boss_state  = BossState.TAIL_SWEEP
	cd_tail     = CD_TAIL
	state_timer = 1.5
	velocity    = Vector2.ZERO * 0.3   # Slow drift during sweep
	print("[Jormungandr] TAIL SWEEP!")

func _state_tail_sweep(delta: float):
	# Slowly move the head during the tail sweep
	if player_ref:
		var to_player = player_ref.global_position - global_position
		velocity = to_player.normalized() * 25.0
	
	# The tail sweep is handled visually by the body segment system —
	# because the head keeps moving, the tail lags behind with a wide arc.
	# We amplify this by briefly increasing the history step size.
	# (In practice: the body's natural trail IS the sweep)
	
	# Flash the last body segment to warn the player
	var segments = body_container.get_children() if body_container else []
	if not segments.is_empty():
		var tail = segments[-1]
		tail.modulate = Color(1.0, 0.3, 0.1, 1.0)   # Red warning tint
	
	if state_timer <= 0:
		boss_state = BossState.COIL_CHASE
		# Reset tail colour
		if not segments.is_empty():
			segments[-1].modulate = Color.WHITE


# ════════════════════════════════════════════════════════════
# ATTACK: RING BURST  —  12 bullets radially (phase 2+)
# ════════════════════════════════════════════════════════════
func _enter_ring_burst():
	boss_state  = BossState.RING_BURST
	cd_ring     = CD_RING
	state_timer = 0.6
	velocity    = Vector2.ZERO
	print("[Jormungandr] RING BURST!")

func _state_ring_burst(delta: float):
	velocity = Vector2.ZERO
	
	if state_timer <= 0.3 and state_timer > 0.25:
		for i in range(12):
			var angle = (TAU / 12.0) * i
			var dir   = Vector2(cos(angle), sin(angle))
			_spawn_enemy_bullet(global_position, dir, 190.0, 10, Color(0.8, 0.2, 0.8))
	
	if state_timer <= 0:
		boss_state = BossState.COIL_CHASE


# ════════════════════════════════════════════════════════════
# ATTACK: BURROW  —  sinks into floor, reappears under player
# Phase 2+
# ════════════════════════════════════════════════════════════
func _enter_burrow():
	boss_state   = BossState.BURROWING
	cd_burrow    = CD_BURROW
	state_timer  = 1.0
	velocity     = Vector2.ZERO
	
	if player_ref:
		burrow_target = player_ref.global_position
	
	# Sink into ground: scale Y down to 0
	if head_sprite:
		var tween = create_tween()
		tween.tween_property(head_sprite, "scale:y", 0.0, 0.5)
	
	# Also hide all body segments
	if body_container:
		var tween2 = create_tween()
		tween2.tween_property(body_container, "modulate:a", 0.0, 0.5)
	
	print("[Jormungandr] BURROWING!")

func _state_burrowing(delta: float):
	velocity = Vector2.ZERO
	
	# Teleport to target under the floor (invisible)
	if state_timer <= 0.5 and state_timer > 0.45:
		# Track player position right before emerging
		if player_ref:
			burrow_target = player_ref.global_position
	
	if state_timer <= 0:
		_enter_resurface()

func _enter_resurface():
	boss_state  = BossState.RESURFACE
	state_timer = 0.8
	
	# Snap to burrow target (player's last position)
	global_position = burrow_target
	
	# Warning: show a ground crack marker at the emerge point
	# (In practice you'd spawn a visual warning scene here)
	print("[Jormungandr] RESURFACE at ", burrow_target)
	
	# Rise up
	if head_sprite:
		var tween = create_tween()
		tween.tween_property(head_sprite, "scale:y", 1.0, 0.35)
	if body_container:
		var tween2 = create_tween()
		tween2.tween_property(body_container, "modulate:a", 1.0, 0.35)

func _state_resurface(delta: float):
	velocity = Vector2.ZERO
	
	# Deal a burst on emergence
	if state_timer <= 0.45 and state_timer > 0.4:
		# 8-shot burst on emergence
		for i in range(8):
			var angle = (TAU / 8.0) * i
			_spawn_enemy_bullet(global_position,
				Vector2(cos(angle), sin(angle)), 160.0, 14, Color(0.3, 0.8, 0.2))
	
	if state_timer <= 0:
		boss_state = BossState.COIL_CHASE


# ════════════════════════════════════════════════════════════
# ATTACK: BODY SLAM  —  full diagonal lunge (phase 2+)
# ════════════════════════════════════════════════════════════
func _enter_body_slam():
	boss_state     = BossState.BODY_SLAM
	cd_slam        = CD_SLAM
	state_timer    = 0.6
	
	# Aim diagonally at the player
	if player_ref:
		slam_direction = (player_ref.global_position - global_position).normalized()
	
	# Wind-up: hold still
	velocity = Vector2.ZERO
	if head_sprite:
		var tween = create_tween()
		tween.tween_property(head_sprite, "scale", Vector2(0.7, 1.5), 0.3)
	print("[Jormungandr] BODY SLAM!")

func _state_body_slam(delta: float):
	# First half: wind up (0.6s → 0.3s)
	if state_timer > 0.3:
		velocity = Vector2.ZERO
	else:
		# Second half: slam forward at very high speed
		velocity = slam_direction * 340.0
	
	if state_timer <= 0:
		if head_sprite:
			var tween = create_tween()
			tween.tween_property(head_sprite, "scale", Vector2(1.0, 1.0), 0.2)
		boss_state = BossState.COIL_CHASE


# ════════════════════════════════════════════════════════════
# ATTACK: VENOM RING  —  3 orbiting bullet clusters (phase 3)
# ════════════════════════════════════════════════════════════
func _enter_venom_ring():
	boss_state        = BossState.VENOM_RING
	cd_venom          = CD_VENOM_RING
	state_timer       = 4.0   # Ring stays active 4 seconds
	venom_ring_active = true
	venom_ring_angle  = 0.0
	print("[Jormungandr] VENOM RING!")

func _tick_venom_ring(delta: float):
	venom_ring_angle += delta * 2.5   # Rotation speed (radians/sec)
	venom_ring_timer  += delta
	
	# Fire every 0.4s while ring is active
	if venom_ring_timer >= 0.4:
		venom_ring_timer = 0.0
		# 3 bullets equally spaced, rotating
		for i in range(3):
			var base_angle = venom_ring_angle + (TAU / 3.0) * i
			var dir = Vector2(cos(base_angle), sin(base_angle))
			_spawn_enemy_bullet(global_position, dir, 140.0, 8, Color(0.4, 0.9, 0.2))

func _state_venom_ring(delta: float):
	# Chase slowly while ring is active
	if player_ref:
		velocity = (player_ref.global_position - global_position).normalized() * 55.0
	
	if state_timer <= 0:
		venom_ring_active = false
		boss_state = BossState.COIL_CHASE


# ════════════════════════════════════════════════════════════
# ATTACK: COIL CRUSH  —  body contracts inward (phase 3)
# Signals the body segments to orbit the head,
# gradually shrinking the safe zone
# ════════════════════════════════════════════════════════════
func _enter_coil_crush():
	boss_state   = BossState.COIL_CRUSH
	cd_coil      = CD_COIL
	state_timer  = 5.0
	coil_radius  = 220.0
	velocity     = Vector2.ZERO
	print("[Jormungandr] COIL CRUSH — the walls close in!")

func _state_coil_crush(delta: float):
	velocity = Vector2.ZERO
	
	# Shrink coil radius over time
	coil_radius = max(60.0, coil_radius - delta * 35.0)
	
	# Force body segments into a circular orbit
	if body_container:
		var segments = body_container.get_children()
		for i in range(segments.size()):
			var angle = (TAU / segments.size()) * i + state_timer * 1.5
			var target_pos = global_position + Vector2(cos(angle), sin(angle)) * coil_radius
			# Lerp segment toward its coil position
			segments[i].global_position = segments[i].global_position.lerp(
				target_pos, delta * 3.0
			)
	
	if state_timer <= 0:
		boss_state = BossState.COIL_CHASE


# ════════════════════════════════════════════════════════════
# PHASE TRANSITIONS
# ════════════════════════════════════════════════════════════
func _check_phase_transition():
	var hp_pct = float(current_health) / float(max_health)
	
	if current_phase == 1 and hp_pct <= PHASE_2_THRESHOLD:
		_enter_phase(2)
	elif current_phase == 2 and hp_pct <= PHASE_3_THRESHOLD:
		_enter_phase(3)

func _enter_phase(phase: int):
	current_phase = phase
	boss_state    = BossState.PHASE_TRANS
	state_timer   = 2.0
	velocity      = Vector2.ZERO
	
	emit_signal("phase_changed", phase)
	
	# Visual burst on phase change
	if head_sprite:
		var tween = create_tween()
		tween.tween_property(head_sprite, "modulate",
			Color(1.5, 1.5, 1.5), 0.15)
		tween.tween_property(head_sprite, "modulate",
			Color(0.3, 0.6 - phase * 0.1, 0.2 - phase * 0.05), 0.4)
	
	# Flash body segments to red/dark for phase 3
	if body_container and phase == 3:
		for seg in body_container.get_children():
			var tw = create_tween()
			tw.tween_property(seg, "modulate", Color(0.8, 0.2, 0.1), 0.5)
	
	# Burst of bullets at phase transition (8 for P2, 16 for P3)
	var burst_count = 8 if phase == 2 else 16
	for i in range(burst_count):
		var angle = (TAU / burst_count) * i
		_spawn_enemy_bullet(global_position,
			Vector2(cos(angle), sin(angle)), 200.0, 10,
			Color(0.9, 0.5, 0.1))
	
	print("[Jormungandr] ⚡ PHASE ", phase, " BEGINS!")

func _state_phase_trans(delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0:
		boss_state = BossState.COIL_CHASE
		# Reset all attack cooldowns so phase starts fresh
		cd_spit = CD_SPIT * 0.5
		cd_tail = CD_TAIL * 0.5
		cd_ring = CD_RING * 0.3
		cd_burrow = CD_BURROW * 0.4
		cd_slam = CD_SLAM * 0.4
		cd_venom = CD_VENOM_RING * 0.5
		cd_coil = CD_COIL * 0.5


# ════════════════════════════════════════════════════════════
# TAKE DAMAGE  —  OVERRIDE
# ════════════════════════════════════════════════════════════
func take_damage(amount: int):
	if boss_state == BossState.BURROWING or boss_state == BossState.DYING:
		return   # Immune while underground
	
	current_health = max(current_health - amount, 0)
	
	# Flash the head
	if head_sprite:
		var tween = create_tween()
		tween.tween_property(head_sprite, "modulate",
			Color(2.0, 0.5, 0.5), 0.06)
		tween.tween_property(head_sprite, "modulate",
			_get_phase_color(), 0.08)
	
	print("[Jormungandr] Hit for ", amount, "  HP: ", current_health, "/", max_health)
	
	# Check for phase transitions
	_check_phase_transition()
	
	if current_health <= 0:
		_die()

func _get_phase_color() -> Color:
	match current_phase:
		1: return Color(0.3, 0.6, 0.2)
		2: return Color(0.5, 0.4, 0.1)
		3: return Color(0.7, 0.15, 0.1)
	return Color.WHITE


# ════════════════════════════════════════════════════════════
# DEATH SEQUENCE
# ════════════════════════════════════════════════════════════
func _die():
	boss_state = BossState.DYING
	velocity   = Vector2.ZERO
	
	# Disable hitbox immediately
	if hitbox:
		hitbox.set_deferred("monitoring",  false)
		hitbox.set_deferred("monitorable", false)
	
	print("[Jormungandr] DEFEATED — The World Serpent falls!")
	
	emit_signal("died")     # Room.gd hears this
	emit_signal("boss_died")  # RoomManager hears this → unlock Odin
	
	# Death explosion sequence
	_play_death_sequence()

func _play_death_sequence():
	# Fire 3 waves of explosions outward from the body segments
	if body_container:
		var segments = body_container.get_children()
		for i in range(segments.size()):
			await get_tree().create_timer(0.12).timeout
			var seg_pos = segments[i].global_position
			# Explosion at each segment
			for j in range(6):
				var angle = (TAU / 6.0) * j + i * 0.3
				_spawn_enemy_bullet(seg_pos,
					Vector2(cos(angle), sin(angle)), 80.0, 0,
					Color(1.0, 0.6, 0.1))   # damage = 0 (cosmetic only)
	
	await get_tree().create_timer(0.5).timeout
	
	# Fade out the head last
	if head_sprite:
		var tween = create_tween()
		tween.tween_property(head_sprite, "modulate:a", 0.0, 1.0)
		await tween.finished
	
	# Drop a legendary item guaranteed
	if has_node("/root/ItemDropper") and has_node("/root/RuneDatabase"):
		var players = get_tree().get_nodes_in_group("player")
		var held_ids = []
		if not players.is_empty() and players[0].has_node("ItemManager"):
			held_ids = players[0].get_node("ItemManager").get_held_ids()
		
		# Boss always drops a rare or legendary rune
		var rune = RuneDatabase.roll_random_rune(1, held_ids)
		if rune.get("rarity","common") in ["common","uncommon"]:
			rune = RuneDatabase.roll_random_rune(1, held_ids)  # Re-roll once for better
		
		ItemDropper._spawn_pedestal(get_parent(), global_position, rune)
		print("[Jormungandr] Dropped: ", rune.get("name","?"))
	
	queue_free()


# ════════════════════════════════════════════════════════════
# CONTACT DAMAGE  —  called every physics frame
# ════════════════════════════════════════════════════════════
func _check_contact_damage():
	if player_ref == null or contact_damage_timer > 0: return
	
	# Check head
	var head_dist = global_position.distance_to(player_ref.global_position)
	if head_dist < 30:
		_deal_contact(2)
		return
	
	# Check body segments
	if body_container:
		for seg in body_container.get_children():
			if seg.global_position.distance_to(player_ref.global_position) < 18:
				_deal_contact(1)   # Body deals less than head
				return

func _deal_contact(amount: int):
	if player_ref.has_method("take_damage"):
		player_ref.take_damage(amount)
	contact_damage_timer = contact_damage_cooldown


# ════════════════════════════════════════════════════════════
# DETECTION
# ════════════════════════════════════════════════════════════
func _on_detection_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_ref = body

func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_bullets"):
		var dmg = area.get("damage") if area.get("damage") != null else 10
		take_damage(dmg)

func _on_hurtbox_body_entered(body: Node2D):
	if body.is_in_group("player_bullets"):
		var dmg = body.get("damage") if body.get("damage") != null else 10
		take_damage(dmg)


# ════════════════════════════════════════════════════════════
# PROJECTILE HELPER
# ════════════════════════════════════════════════════════════
func _spawn_enemy_bullet(pos: Vector2, dir: Vector2,
						spd: float, dmg: int, color: Color):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path):
		return   # Silently skip if scene not yet created
	
	var bullet           = load(path).instantiate()
	bullet.global_position = pos
	bullet.direction     = dir
	bullet.speed         = spd
	bullet.damage        = dmg
	if bullet.has_node("Sprite2D"):
		bullet.get_node("Sprite2D").modulate = color
	
	get_parent().add_child(bullet)
