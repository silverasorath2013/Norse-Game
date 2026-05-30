extends "res://scripts/EnemyBase.gd"

# ============================================================
# VoidHound.gd  —  The Shadow Mimic  (Floor 4)
# ============================================================
# MECHANICS:
#   SHADOW CLONES: spawns 2 decoys on room entry that mirror
#     its position with a slight offset + frame delay.
#     Decoys have 12 HP and absorb bullets. Don't deal damage.
#     The real hound is slightly brighter in modulate.
#   VOID LUNGE: charges at 210 px/s after a windup.
#     On contact: destroys all decoys + spawns 4 void shards.
#   CLONE REFORM: if all clones are destroyed, reforms them
#     after 5 seconds (one-time per room).
# STATS: HP 30, Speed 88, Damage 1
# ============================================================

const LUNGE_SPEED:   float = 210.0
const LUNGE_CD:      float = 4.0
const WINDUP_TIME:   float = 0.5
const REFORM_TIME:   float = 5.0
const CLONE_HP:      int   = 12

const STATE_WINDUP = 10
const STATE_LUNGE  = 11

var hound_state:    int     = -1
var lunge_cd:       float   = LUNGE_CD * randf_range(0.4, 0.7)
var lunge_dir:      Vector2 = Vector2.ZERO
var state_timer:    float   = 0.0
var clones:         Array   = []
var reform_timer:   float   = -1.0
var has_reformed:   bool    = false

const VOID_COLOR  = Color(0.25, 0.10, 0.40)
const CLONE_COLOR = Color(0.18, 0.08, 0.30, 0.65)


func _ready():
	super()
	enemy_name     = "Void Hound"
	max_health     = 30
	current_health = max_health
	move_speed     = 88.0
	damage         = 1
	contact_damage_cooldown = 0.8
	detection_range = 310.0
	if sprite: sprite.modulate = VOID_COLOR
	# Spawn clones slightly after ready so we're in the scene tree
	call_deferred("_spawn_clones")


func _physics_process(delta: float):
	if lunge_cd    > 0: lunge_cd    -= delta
	if reform_timer > 0:
		reform_timer -= delta
		if reform_timer <= 0 and not has_reformed:
			has_reformed = true
			_spawn_clones()

	_sync_clones()

	match hound_state:
		STATE_WINDUP: _do_windup(delta)
		STATE_LUNGE:  _do_lunge(delta)
		_:            super(delta)
	move_and_slide()


func _idle_behaviour(_d: float):
	velocity = Vector2.ZERO
	if player_ref: state = State.CHASE


func _chase_behaviour(_delta: float):
	if player_ref == null: state = State.IDLE; return
	var to = player_ref.global_position - global_position
	if to.length() > detection_range * 1.4: state = State.IDLE; return
	velocity = to.normalized() * move_speed
	if sprite and velocity.x != 0: sprite.scale.x = sign(velocity.x)
	if lunge_cd <= 0 and to.length() < 180:
		_enter_windup(to.normalized())


# ── WINDUP / LUNGE ───────────────────────────────────────────
func _enter_windup(dir: Vector2):
	hound_state  = STATE_WINDUP
	lunge_dir    = dir
	lunge_cd     = LUNGE_CD
	state_timer  = WINDUP_TIME
	velocity     = Vector2.ZERO
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(0.5, 0.2, 0.8), 0.25)

func _do_windup(delta: float):
	state_timer -= delta; velocity = Vector2.ZERO
	if state_timer <= 0: hound_state = STATE_LUNGE; state_timer = 0.35

func _do_lunge(delta: float):
	state_timer -= delta
	velocity = lunge_dir * LUNGE_SPEED
	if state_timer <= 0 or get_slide_collision_count() > 0:
		hound_state = -1; state = State.CHASE
		if sprite:
			var tw = create_tween()
			tw.tween_property(sprite, "modulate", VOID_COLOR, 0.15)
		_on_lunge_end()

func _on_lunge_end():
	# Destroy all clones + void shard burst
	for c in clones:
		if is_instance_valid(c): c.queue_free()
	clones.clear()
	_spawn_void_shards()
	# Start reform timer
	if not has_reformed:
		reform_timer = REFORM_TIME


# ── CLONES ───────────────────────────────────────────────────
func _spawn_clones():
	clones.clear()
	for i in range(2):
		var clone = _make_clone(i)
		get_parent().add_child(clone)
		clones.append(clone)

func _make_clone(index: int) -> Node2D:
	# A simple Node2D that draws itself and absorbs bullets
	var clone = Area2D.new()
	clone.name = "VoidClone" + str(index)
	clone.collision_layer = 3   # enemy_hurtboxes
	clone.collision_mask  = 5   # player_bullets

	var shape_node = CollisionShape2D.new()
	var circle     = CircleShape2D.new()
	circle.radius  = 10.0
	shape_node.shape = circle
	clone.add_child(shape_node)

	var clone_hp    = CLONE_HP
	var owner_ref   = self
	var clone_color = CLONE_COLOR

	# Inline script for the clone
	var s = GDScript.new()
	s.source_code = """extends Area2D
var hp = %d
var owner_hound = null
var _bob = 0.0
func _ready():
	add_to_group("void_clones")
	area_entered.connect(_on_hit)
func _process(d):
	_bob += d * 2.2
	queue_redraw()
func _draw():
	draw_circle(Vector2.ZERO, 9.0, Color(0.18, 0.08, 0.30, 0.6 + sin(_bob)*0.1))
	draw_circle(Vector2.ZERO, 9.0, Color(0.35, 0.15, 0.55, 0.7), false, 1.0)
func _on_hit(area):
	if area.is_in_group("player_bullets"):
		hp -= area.get("damage") if area.get("damage") else 5
		if hp <= 0: queue_free()
""" % CLONE_HP
	clone.set_script(s)
	clone.global_position = global_position + \
		Vector2(randf_range(-25, 25), randf_range(-25, 25))
	return clone

func _sync_clones():
	# Clones mirror the hound's position with slight offset
	for i in range(clones.size()):
		if not is_instance_valid(clones[i]):
			clones.remove_at(i)
			continue
		var offset = Vector2(
			sin(Time.get_ticks_msec() * 0.003 + i * 2.1) * 20,
			cos(Time.get_ticks_msec() * 0.002 + i * 1.7) * 15
		)
		clones[i].global_position = global_position + offset


# ── VOID SHARDS on lunge end ─────────────────────────────────
func _spawn_void_shards():
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	for i in range(4):
		var a = (TAU / 4.0) * i
		var b = load(path).instantiate()
		b.global_position = global_position
		b.direction = Vector2(cos(a), sin(a))
		b.speed = 160.0; b.damage = 6
		if b.has_node("Sprite2D"):
			b.get_node("Sprite2D").modulate = Color(0.5, 0.15, 0.75)
		get_parent().add_child(b)


# ── DEATH ────────────────────────────────────────────────────
func _die():
	for c in clones:
		if is_instance_valid(c):
			c.queue_free()
	clones.clear()
	_spawn_void_shards()
	super()
