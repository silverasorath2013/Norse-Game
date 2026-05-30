extends Node

# ============================================================
# FloorRunes_Effects_3_4_5.gd  —  Autoload: "FloorRuneEffects"
# ============================================================
# Effect implementations for Muspelheim, Helheim, Asgard runes.
# Wire into ItemEffects.gd dispatch functions the same way
# NiflheimEffects is wired: check FloorRuneEffects.has_method(fn)
# ============================================================


# ════════════════════════════════════════════════════════════
# MUSPELHEIM EFFECTS
# ════════════════════════════════════════════════════════════

func ember_brand_burn(hero: Node, target: Node):
	# Apply burn to the enemy hit
	if not is_instance_valid(target): return
	if target.get_meta("burning", false): return
	target.set_meta("burning", true)
	_burn_enemy(target)

func _burn_enemy(target: Node):
	for i in range(3):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(target): return
		if target.has_method("take_damage"):
			target.take_damage(4)   # 4 dmg/s burn on enemy
	if is_instance_valid(target):
		target.set_meta("burning", false)

func register_heat_ward(hero: Node, _rune: Dictionary):
	hero.set_meta("heat_ward", true)
	# Hero.take_damage and LavaPatch._apply_burn should check:
	# if player.get_meta("heat_ward", false): damage /= 2

func surtr_explosion(hero: Node, enemy_pos: Vector2):
	if randf() > 0.10: return   # 10% chance
	print("[FloorRuneEffects] Surtr's Blessing explosion!")
	var enemies = hero.get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.global_position.distance_to(enemy_pos) <= 60.0:
			if e.has_method("take_damage"):
				e.take_damage(15)
	# TODO: spawn fire particle effect at enemy_pos

func register_lava_heart(hero: Node, _rune: Dictionary):
	hero.set_meta("lava_heart_active", false)
	print("[FloorRuneEffects] Lava Heart registered")

func lava_heart_check(hero: Node, _amount: int):
	var below = hero.get_health_percent() < 0.40
	var was   = hero.get_meta("lava_heart_active", false)
	if below and not was:
		hero.set_meta("lava_heart_active", true)
		hero.set_meta("heat_ward", true)   # Fire immunity
		hero.base_damage += 8
		if hero.has_node("Sprite2D"):
			hero.get_node("Sprite2D").modulate = Color(1.0, 0.5, 0.1)
		print("[FloorRuneEffects] Lava Heart activated!")
	elif not below and was:
		hero.set_meta("lava_heart_active", false)
		hero.set_meta("heat_ward", false)
		hero.base_damage -= 8
		if hero.has_node("Sprite2D"):
			hero.get_node("Sprite2D").modulate = Color.WHITE

func giants_ember_burst(hero: Node):
	if not hero.has_method("_fire_projectile"): return
	print("[FloorRuneEffects] Giant's Ember burst!")
	for i in range(12):
		var angle = (TAU / 12.0) * i
		hero._fire_projectile(Vector2(cos(angle), sin(angle)))


# ════════════════════════════════════════════════════════════
# HELHEIM EFFECTS
# ════════════════════════════════════════════════════════════

func souls_weight_heal(hero: Node, _enemy_pos: Vector2):
	hero.heal(2)

func extend_iframes_half(hero: Node, _rune: Dictionary):
	var b = hero.get_meta("iframe_bonus", 0.0)
	hero.set_meta("iframe_bonus", b + 0.5)
	print("[FloorRuneEffects] i-frames +0.5s  total: ", hero.get_meta("iframe_bonus"))

func register_void_mantle(hero: Node, _rune: Dictionary):
	hero.set_meta("void_mantle", true)

func void_mantle_dodge(hero: Node, amount: int):
	# 10% chance to completely negate the hit
	# This must be checked BEFORE damage is applied in Hero.take_damage
	# The meta flag is read there; we set a "dodge this hit" flag here
	if randf() < 0.10:
		hero.set_meta("void_dodge_this", true)
		print("[FloorRuneEffects] Void Mantle dodge!")
	# Hero.take_damage checks: if get_meta("void_dodge_this", false): clear flag; return

func hels_bargain_heal(hero: Node):
	hero.heal(hero.max_health)   # Full restore on room clear
	print("[FloorRuneEffects] Hel's Bargain: fully healed!")

func register_nidhogg_fang(hero: Node, _rune: Dictionary):
	hero.set_meta("nidhogg_fang", true)
	print("[FloorRuneEffects] Nidhogg's Fang active")

func nidhogg_fang_heal(hero: Node, _target: Node):
	hero.heal(3)

func override_special_teleport(hero: Node, _rune: Dictionary):
	# Overrides the hero's special to be a Loki-style teleport
	# regardless of which hero is chosen
	hero.set_meta("special_override", "realm_walker_teleport")
	print("[FloorRuneEffects] Realm Walker: special ability overridden to teleport")

# Called from Hero._special_ability() when special_override meta is set:
# func realm_walker_teleport(hero):
#   var target = hero.get_global_mouse_position()
#   var room_rect = Rect2(42, 42, 16*40-84, 12*40-84)
#   target = Vector2(clampf(target.x,...), clampf(target.y,...))
#   hero.global_position = target
#   hero.is_invincible = true
#   hero.invincibility_timer = 0.65


# ════════════════════════════════════════════════════════════
# ASGARD EFFECTS
# ════════════════════════════════════════════════════════════

func enable_divine_shots(hero: Node, _rune: Dictionary):
	hero.set_meta("divine_shots", true)
	print("[FloorRuneEffects] Divine shots enabled — shots glow gold")

func register_runic_mastery(hero: Node, _rune: Dictionary):
	# Set a multiplier that ItemEffects dispatch checks
	# When runic_mastery is held, each dispatch fires twice
	hero.set_meta("rune_proc_multiplier", 2)
	print("[FloorRuneEffects] Runic Mastery: all procs doubled")
	# In ItemEffects dispatch functions, add after each call():
	#   var mult = hero.get_meta("rune_proc_multiplier", 1)
	#   if mult > 1: call(fn, hero, ...)   # Call again

func valkyrie_grace_heart(hero: Node):
	print("[FloorRuneEffects] Valkyrie's Grace: spawning heart pickup")
	var path = "res://scenes/pickups/Heart.tscn"
	if ResourceLoader.exists(path):
		var heart = load(path).instantiate()
		# Place at room centre
		heart.global_position = Vector2(16*40/2.0, 12*40/2.0)
		hero.get_parent().add_child(heart)
	else:
		# Fallback: just heal 20
		hero.heal(20)

func allfather_reveal_all(hero: Node, _rune: Dictionary):
	print("[FloorRuneEffects] Allfather's Eye: revealing all rooms!")
	if has_node("/root/DungeonGenerator") and DungeonGenerator.current_floor:
		for pos in DungeonGenerator.current_floor.rooms:
			DungeonGenerator.current_floor.rooms[pos].visited = true
	# Also enable homing (Odin's passive)
	hero.set_meta("bullet_homing", true)
	# Stats already applied via stat_mods (+15 dmg, +20 speed)
