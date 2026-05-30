extends Area2D

# ============================================================
# LavaPatch.gd  —  Floor 3 Environmental Hazard
# ============================================================
# Spawned by SurtrSpawn, LavaStalker, CinderWolf, and Surtr.
# Similar to IcePatch but HURTS instead of slows.
# Fire-tagged bullets spread lava instead of destroying it.
# ICE bullets (from Niflheim runes) instantly extinguish it.
#
# BEHAVIOUR:
#   - Player contact: 2 damage + burn (1 dmg/s for 3s)
#   - Contact cooldown: 1.5s (lava is continuous)
#   - HP: 20 (tougher than ice)
#   - Normal bullets deal 5 dmg
#   - ICE bullets (is_ice_shard meta) instantly destroy it
#   - Lasts 15 seconds then cools and vanishes
#   - Drawn as a glowing orange-red polygon
# ============================================================

const BURN_DURATION:  float = 3.0
const PATCH_LIFETIME: float = 15.0
const PATCH_HP:       int   = 20
const CONTACT_CD:     float = 1.5

var current_hp:       int   = PATCH_HP
var lifetime:         float = PATCH_LIFETIME
var contact_timer:    float = 0.0
var players_on:       Array = []
var _glow:            float = 0.0

const LAVA_COLORS = [
	Color(0.95, 0.30, 0.02, 0.85),
	Color(1.00, 0.40, 0.05, 0.80),
	Color(0.90, 0.22, 0.01, 0.88),
]
var patch_color: Color


func _ready():
	patch_color = LAVA_COLORS[randi() % LAVA_COLORS.size()]
	add_to_group("lava_patches")
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)


func _process(delta: float):
	_glow    += delta
	lifetime -= delta
	if contact_timer > 0: contact_timer -= delta
	# Damage players standing on lava
	if contact_timer <= 0 and not players_on.is_empty():
		contact_timer = CONTACT_CD
		for p in players_on:
			if is_instance_valid(p) and p.has_method("take_damage"):
				if "last_hit_source" in p: p.last_hit_source = "Lava"
				p.take_damage(2)
				_apply_burn(p)
	if lifetime <= 0: queue_free()
	queue_redraw()


func _draw():
	var a = patch_color.a * (lifetime / PATCH_LIFETIME if lifetime < 3.0 else 1.0)
	var glow = sin(_glow * 3.5) * 0.08
	var c = Color(patch_color.r + glow, patch_color.g, patch_color.b, a)
	# Irregular lava blob — hexagon with random noise
	var pts = PackedVector2Array()
	var size = 16.0
	for i in range(6):
		var angle = (TAU / 6.0) * i
		var r     = size * (0.85 + sin(_glow * 2.0 + i) * 0.15)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(pts, c)
	# Hot centre
	draw_circle(Vector2.ZERO, size * 0.35,
		Color(1.0, 0.8, 0.3, a * (0.5 + sin(_glow * 4.0) * 0.2)))


func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		players_on.append(body)

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		players_on.erase(body)


func _on_area_entered(area: Area2D):
	if not area.is_in_group("player_bullets"): return
	# Ice bullets extinguish lava
	if area.get_meta("is_ice_shard", false):
		queue_free(); return
	current_hp -= area.get("damage") if area.get("damage") != null else 5
	if current_hp <= 0: queue_free()


func _apply_burn(player: Node):
	if player.get_meta("burn_active", false): return
	player.set_meta("burn_active", true)
	_burn_tick(player)

func _burn_tick(player: Node):
	for i in range(int(BURN_DURATION)):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(player): return
		if player.has_method("take_damage"):
			if "last_hit_source" in player: player.last_hit_source = "Burn"
			player.take_damage(1)
	if is_instance_valid(player):
		player.set_meta("burn_active", false)
