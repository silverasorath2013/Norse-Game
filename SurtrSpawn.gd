extends "res://scripts/EnemyBase.gd"

# ============================================================
# SurtrSpawn.gd  —  Fire Elemental Grunt  (Floor 3)
# ============================================================
# MECHANICS:
#   FIRE TRAIL: leaves lava patches (damage=2) as it moves
#   EMBER BURST: on death, 8 fire bullets + 3 lava patches
#   HEAT AURA: player within 70px takes 1 dmg every 2s (passive)
#   IGNITE: contact damage also sets a burn (1 dmg/s for 3s)
#
# STATS: HP 35, Speed 65, Damage 1 + burn
# ============================================================

const HEAT_RANGE:     float = 70.0
const HEAT_TICK_CD:   float = 2.0
const BURN_DURATION:  float = 3.0
const TRAIL_CD:       float = 0.7

var trail_timer:   float = TRAIL_CD
var heat_timer:    float = HEAT_TICK_CD
var wander_dir:    Vector2 = Vector2.RIGHT
var wander_timer:  float   = 1.0

const LAVA_PATCH_SCENE = "res://scenes/floor3/LavaPatch.tscn"
const FIRE_COLOR = Color(1.0, 0.45, 0.05)


func _ready():
	super()
	enemy_name   = "Surtr's Spawn"
	max_health   = 35
	current_health = max_health
	move_speed   = 65.0
	damage       = 1
	contact_damage_cooldown = 0.8
	detection_range = 260.0
	if sprite:
		sprite.modulate = FIRE_COLOR


func _physics_process(delta: float):
	trail_timer -= delta
	heat_timer  -= delta
	if trail_timer <= 0:
		trail_timer = TRAIL_CD
		if velocity.length() > 5: _spawn_lava_patch(global_position)
	if heat_timer <= 0 and player_ref:
		heat_timer = HEAT_TICK_CD
		_heat_aura_tick()
	super(delta)


func _idle_behaviour(delta: float):
	wander_timer -= delta
	if wander_timer <= 0:
		wander_dir   = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
		wander_timer = randf_range(0.8, 1.8)
	velocity = wander_dir * move_speed * 0.4
	if player_ref: state = State.CHASE


func _chase_behaviour(_delta: float):
	if player_ref == null: state = State.IDLE; return
	var to = player_ref.global_position - global_position
	if to.length() > detection_range * 1.4: state = State.IDLE; return
	velocity = to.normalized() * move_speed
	if sprite and velocity.x != 0: sprite.scale.x = sign(velocity.x)


func _heat_aura_tick():
	if player_ref == null: return
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < HEAT_RANGE and player_ref.has_method("take_damage"):
		if "last_hit_source" in player_ref:
			player_ref.last_hit_source = "Heat Aura"
		player_ref.take_damage(1)


func _deal_contact(amount: int):
	if player_ref == null or contact_damage_timer > 0: return
	var dist = global_position.distance_to(player_ref.global_position)
	if dist <= attack_range + 16:
		var extra = player_ref.get_meta("curse_extra_damage", 0)
		if "last_hit_source" in player_ref: player_ref.last_hit_source = enemy_name
		player_ref.take_damage(amount + extra)
		contact_damage_timer = contact_damage_cooldown
		# Apply burn debuff
		_apply_burn(player_ref)


func _apply_burn(player: Node):
	if player.get_meta("burn_active", false): return
	player.set_meta("burn_active", true)
	# Burn ticks handled by a coroutine
	_burn_coroutine(player)

func _burn_coroutine(player: Node):
	var ticks = int(BURN_DURATION)
	for i in range(ticks):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(player): return
		if player.has_method("take_damage"):
			if "last_hit_source" in player: player.last_hit_source = "Burn"
			player.take_damage(1)
	if is_instance_valid(player):
		player.set_meta("burn_active", false)


func _die():
	# Ember burst
	for i in range(8):
		var angle = (TAU / 8.0) * i
		_fire_bullet(Vector2(cos(angle), sin(angle)), 160.0, 8, FIRE_COLOR)
	for i in range(3):
		var offset = Vector2(randf_range(-30,30), randf_range(-30,30))
		_spawn_lava_patch(global_position + offset)
	super()


func _spawn_lava_patch(pos: Vector2):
	if ResourceLoader.exists(LAVA_PATCH_SCENE):
		var p = load(LAVA_PATCH_SCENE).instantiate()
		p.global_position = pos
		get_parent().add_child(p)

func _fire_bullet(dir: Vector2, spd: float, dmg: int, col: Color):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	var b = load(path).instantiate()
	b.global_position = global_position
	b.direction = dir; b.speed = spd; b.damage = dmg
	if b.has_node("Sprite2D"):
		b.get_node("Sprite2D").modulate = col
	get_parent().add_child(b)
