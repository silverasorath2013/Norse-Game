extends Node

# ============================================================
# ItemEffects.gd  —  Autoload: register as "ItemEffects"
# ============================================================
# Every item effect function lives here.
# RuneDatabase stores the function NAME as a string.
# ItemManager calls ItemEffects.call(function_name, hero, ...).
#
# WHY CENTRALISE HERE?
# It keeps RuneDatabase as pure data (no code),
# and keeps Hero.gd clean (no item-specific logic cluttering it).
# Adding a new item = add its data to RuneDatabase + its
# effect function here. Nothing else needs changing.
#
# FUNCTION SIGNATURES:
#   on_pickup(hero)              → called once when item picked up
#   on_kill(hero, enemy_pos)     → called when hero kills an enemy
#   on_hit_dealt(hero, target)   → called when a bullet lands
#   on_hit_taken(hero, amount)   → called when hero takes damage
#   on_room_clear(hero)          → called when room is cleared
# ============================================================

# Tracks per-rune runtime state that needs to persist
# (kill counters, cooldown timers, etc.)
# Key = hero node instance ID + rune ID
var _runtime_state: Dictionary = {}

func _state_key(hero: Node, rune_id: String) -> String:
	return str(hero.get_instance_id()) + "_" + rune_id


# ════════════════════════════════════════════════════════════
# ON PICKUP EFFECTS
# ════════════════════════════════════════════════════════════

func heal_on_pickup(hero: Node, rune: Dictionary):
	# Also heals the amount of max_health the rune gives
	var heal_amount = rune["stat_mods"].get("max_health", 10)
	if hero.has_method("heal"):
		hero.heal(heal_amount)
	print("[ItemEffects] heal_on_pickup: healed ", heal_amount)

func full_heal(hero: Node, _rune: Dictionary):
	if hero.has_method("heal"):
		hero.heal(hero.max_health)
	print("[ItemEffects] full_heal: restored to max HP")

func clamp_health(hero: Node, _rune: Dictionary):
	# After reducing max_health, make sure current_health doesn't exceed the new cap
	hero.current_health = min(hero.current_health, hero.max_health)
	hero.emit_signal("health_changed", hero.current_health, hero.max_health)

func extend_iframes(hero: Node, _rune: Dictionary):
	# Adds 0.3s to the hero's I_FRAME_TIME constant at runtime
	# We store the extension on the hero as a dynamic property
	hero.set_meta("iframe_bonus", hero.get_meta("iframe_bonus", 0.0) + 0.3)
	print("[ItemEffects] i-frames extended by 0.3s, total bonus: ",
		hero.get_meta("iframe_bonus", 0.0))

func enable_piercing(hero: Node, _rune: Dictionary):
	# Sets a flag on the hero that Bullet.gd reads when spawning
	hero.set_meta("bullet_piercing", true)
	print("[ItemEffects] Piercing bullets enabled")

func enable_homing(hero: Node, _rune: Dictionary):
	hero.set_meta("bullet_homing", true)
	print("[ItemEffects] Homing bullets enabled")

func enable_bouncing(hero: Node, _rune: Dictionary):
	# World Serpent's Fang: shots bounce once, +5 dmg on bounce
	var current = hero.get_meta("bullet_bounces", 0)
	hero.set_meta("bullet_bounces", current + 1)
	hero.set_meta("bounce_damage_bonus", 5)
	print("[ItemEffects] Bouncing bullets enabled (bounces: ", current + 1, ")")

func register_shot_counter(hero: Node, _rune: Dictionary):
	# Mead of Poetry: every 10th shot is a triple burst
	hero.set_meta("mead_shot_count", 0)
	print("[ItemEffects] Mead of Poetry shot counter registered")

func register_berserk(hero: Node, _rune: Dictionary):
	hero.set_meta("berserk_active", false)
	print("[ItemEffects] Berserker Blood registered")

func double_dodge(hero: Node, _rune: Dictionary):
	# Sleipnir's Hoof: 2nd dodge charge
	hero.set_meta("dodge_charges", hero.get_meta("dodge_charges", 1) + 1)
	print("[ItemEffects] Dodge charges: ", hero.get_meta("dodge_charges", 1))

func spawn_orbitals(hero: Node, _rune: Dictionary):
	# Huginn & Muninn: spawn 2 orbital ravens
	# We defer this so the hero is fully in the scene tree
	hero.call_deferred("_spawn_orbital_ravens")
	print("[ItemEffects] Orbital ravens queued for spawn")


# ════════════════════════════════════════════════════════════
# ON KILL EFFECTS
# ════════════════════════════════════════════════════════════

func bloodied_axe_stack(hero: Node, _enemy_pos: Vector2):
	# +1 damage per kill this room, tracked in runtime state
	var key = _state_key(hero, "bloodied_axe")
	_runtime_state[key] = _runtime_state.get(key, 0) + 1
	hero.base_damage += 1
	print("[ItemEffects] Bloodied Axe stacked. Dmg now: ", hero.base_damage)

func fenrir_gold_drop(hero: Node, enemy_pos: Vector2):
	if randf() < 0.15:
		# Spawn a gold pickup at the enemy's death position
		_spawn_pickup_at("gold_small", enemy_pos, hero)
		print("[ItemEffects] Fenrir gold drop!")

func ragnarok_explosion(hero: Node, enemy_pos: Vector2):
	# Flame eruption — deal 20 damage to all enemies within 80px
	print("[ItemEffects] Ragnarök explosion at ", enemy_pos)
	var enemies = hero.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var dist = enemy.global_position.distance_to(enemy_pos)
		if dist <= 80.0 and enemy.has_method("take_damage"):
			enemy.take_damage(20)
	# TODO: spawn flame particle effect at enemy_pos

func lifesteal_on_kill(hero: Node, _enemy_pos: Vector2):
	if randf() < 0.08:
		hero.heal(1)
		print("[ItemEffects] Lifesteal: restored 1 HP")


# ════════════════════════════════════════════════════════════
# ON HIT DEALT EFFECTS
# ════════════════════════════════════════════════════════════

func mead_shot_count(hero: Node, _target: Node):
	# Every 10th hit fires a triple spread
	var count = hero.get_meta("mead_shot_count", 0) + 1
	hero.set_meta("mead_shot_count", count)
	
	if count % 10 == 0:
		print("[ItemEffects] Mead of Poetry: triple burst!")
		# Fire 3 spread shots around current aim direction
		if hero.has_method("_fire_projectile"):
			var aim = hero.aim_direction
			hero._fire_projectile(aim.rotated(-0.25))
			hero._fire_projectile(aim)
			hero._fire_projectile(aim.rotated(0.25))


# ════════════════════════════════════════════════════════════
# ON HIT TAKEN EFFECTS
# ════════════════════════════════════════════════════════════

func serpent_retaliation(hero: Node, _amount: int):
	var key = _state_key(hero, "serpent_scale")
	var last_time = _runtime_state.get(key, -999.0)
	var now = Time.get_ticks_msec() / 1000.0
	
	# 2-second cooldown between retaliation bursts
	if now - last_time < 2.0:
		return
	_runtime_state[key] = now
	
	print("[ItemEffects] Serpent Scale: retaliation burst!")
	# Fire 6 shots in a ring
	if hero.has_method("_fire_projectile"):
		for i in range(6):
			var angle = (TAU / 6.0) * i
			hero._fire_projectile(Vector2(cos(angle), sin(angle)))

func berserker_check(hero: Node, _amount: int):
	var below_threshold = hero.get_health_percent() < 0.3
	var was_active = hero.get_meta("berserk_active", false)
	
	if below_threshold and not was_active:
		# Enter berserk
		hero.set_meta("berserk_active", true)
		hero.base_damage  += 8
		hero.move_speed   += 20.0
		if hero.has_node("Sprite2D"):
			hero.get_node("Sprite2D").modulate = Color(1.0, 0.4, 0.2)
		print("[ItemEffects] Berserker Blood: BERSERK!")
	elif not below_threshold and was_active:
		# Exit berserk (healed back above threshold)
		hero.set_meta("berserk_active", false)
		hero.base_damage  -= 8
		hero.move_speed   -= 20.0
		if hero.has_node("Sprite2D"):
			hero.get_node("Sprite2D").modulate = Color.WHITE
		print("[ItemEffects] Berserker Blood: calmed down")


# ════════════════════════════════════════════════════════════
# ON ROOM CLEAR EFFECTS
# ════════════════════════════════════════════════════════════

func bloodied_axe_reset(hero: Node):
	var key = _state_key(hero, "bloodied_axe")
	var stacks = _runtime_state.get(key, 0)
	hero.base_damage -= stacks   # Remove all stacks
	_runtime_state[key] = 0
	print("[ItemEffects] Bloodied Axe reset. Lost ", stacks, " stacks")

func valknut_heal(hero: Node):
	hero.heal(5)
	print("[ItemEffects] Valknut Charm: healed 5 HP on room clear")

func yggdrasil_tick(hero: Node):
	hero.heal(1)
	print("[ItemEffects] Yggdrasil Root: healed 1 HP on room clear")

func norns_thread_reveal(hero: Node):
	# Reveal one adjacent unvisited room on the minimap
	if not has_node("/root/DungeonGenerator") or not DungeonGenerator.current_floor:
		return
	
	var rooms = DungeonGenerator.current_floor.rooms
	var current_pos = Vector2i(-1, -1)
	
	# Find the current room position via RoomManager
	var room_managers = hero.get_tree().get_nodes_in_group("room_manager")
	if not room_managers.is_empty():
		current_pos = room_managers[0].current_room_pos
	
	if current_pos == Vector2i(-1, -1):
		return
	
	# Find the first adjacent unvisited room and reveal it
	for dir_vec in DungeonGenerator.DIRECTIONS.values():
		var neighbor = current_pos + dir_vec
		if rooms.has(neighbor) and not rooms[neighbor].visited:
			rooms[neighbor].visited = true
			print("[ItemEffects] Norn's Thread: revealed room at ", neighbor)
			break


# ════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════

func _spawn_pickup_at(pickup_type: String, pos: Vector2, hero: Node):
	# Spawns a small pickup item in the world
	# pickup_type = "gold_small", "heart_half", etc.
	var path = "res://scenes/pickups/" + pickup_type + ".tscn"
	if ResourceLoader.exists(path):
		var pickup = load(path).instantiate()
		pickup.global_position = pos
		hero.get_parent().add_child(pickup)
	else:
		print("[ItemEffects] Pickup scene not found: ", path)


# ════════════════════════════════════════════════════════════
# ════════════════════════════════════════════════════════════
# PROC CHANCE — "Hungry Runes" curse reduces trigger chance
# ════════════════════════════════════════════════════════════
func _should_proc(hero: Node) -> bool:
	# If hero has "hungry_runes" curse, each trigger only fires at 75%
	var chance = hero.get_meta("rune_proc_chance", 1.0)
	return randf() <= chance

# ════════════════════════════════════════════════════════════
# DISPATCH — called by ItemManager to route effect strings
# ════════════════════════════════════════════════════════════

# dispatch_on_pickup(hero, rune)
func dispatch_on_pickup(hero: Node, rune: Dictionary):
	var fn = rune.get("on_pickup", "")
	if fn != "" and has_method(fn):
		call(fn, hero, rune)

# dispatch_on_kill(hero, enemy_pos, rune)
func dispatch_on_kill(hero: Node, enemy_pos: Vector2, rune: Dictionary):
	var fn = rune.get("on_kill", "")
	if fn != "" and has_method(fn) and _should_proc(hero):
		call(fn, hero, enemy_pos)

# dispatch_on_hit_dealt(hero, target, rune)
func dispatch_on_hit_dealt(hero: Node, target: Node, rune: Dictionary):
	var fn = rune.get("on_hit_dealt", "")
	if fn != "" and has_method(fn) and _should_proc(hero):
		call(fn, hero, target)

# dispatch_on_hit_taken(hero, amount, rune)
func dispatch_on_hit_taken(hero: Node, amount: int, rune: Dictionary):
	var fn = rune.get("on_hit_taken", "")
	if fn != "" and has_method(fn) and _should_proc(hero):
		call(fn, hero, amount)

# dispatch_on_room_clear(hero, rune)
func dispatch_on_room_clear(hero: Node, rune: Dictionary):
	var fn = rune.get("on_room_clear", "")
	if fn != "" and has_method(fn) and _should_proc(hero):
		call(fn, hero)
