extends Node

# ============================================================
# NiflheimEffects.gd
# ============================================================
# Effect implementations for all 8 Niflheim runes.
# These follow the exact same pattern as ItemEffects.gd
# but live in a separate file to keep things organised.
#
# ItemEffects.gd calls into this file via a reference.
#
# WIRING in ItemEffects.gd:
#   1. Add at the top:
#        @onready var niflheim = $"/root/NiflheimEffects"
#        (or: var niflheim = preload... — depends on Autoload)
#
#   2. In dispatch_on_pickup/kill/etc, add after the existing call:
#        if NiflheimEffects.has_method(fn):
#            NiflheimEffects.call(fn, hero, ...)
#
# Alternatively (simpler): register NiflheimEffects as an Autoload
# and call its functions directly from the rune effect strings.
# The dispatch in ItemEffects will find them if you extend
# _should_proc and routing to check both scripts.
# ============================================================

# ── RUNTIME STATE ────────────────────────────────────────────
# Key: hero instance ID + rune ID
var _state: Dictionary = {}

func _skey(hero: Node, id: String) -> String:
	return str(hero.get_instance_id()) + "_" + id


# ════════════════════════════════════════════════════════════
# FROST SHARD RUNE
# ════════════════════════════════════════════════════════════

func enable_frost_shots(hero: Node, _rune: Dictionary):
	hero.set_meta("frost_shots", true)
	print("[NiflheimEffects] Frost shots enabled")

func frost_chill_on_hit(hero: Node, target: Node):
	# Applied when a bullet hits an enemy — slow them briefly
	if not is_instance_valid(target): return
	if target.get_meta("frost_chilled", false): return   # Already chilled
	
	target.set_meta("frost_chilled", true)
	
	# Slow the enemy
	if "move_speed" in target:
		target.move_speed *= 0.55   # 45% slow
	
	# Remove after 1.5s
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(target):
			target.set_meta("frost_chilled", false)
			if "move_speed" in target:
				target.move_speed /= 0.55
	)


# ════════════════════════════════════════════════════════════
# YMIR'S MARROW
# ════════════════════════════════════════════════════════════

func ymir_absorb(hero: Node, _amount: int):
	# Absorbs the first hit each room — set by ymir_reset_shield
	if not hero.get_meta("ymir_shield_active", false): return
	
	# Block the damage (we need to intercept BEFORE it's applied)
	# In practice this works by checking in Hero.take_damage:
	#   if get_meta("ymir_shield_active", false):
	#       set_meta("ymir_shield_active", false)
	#       return   # Damage blocked
	# We set the flag here and Hero.take_damage checks it.
	# For now we flag it and the hero checks on next hit.
	hero.set_meta("ymir_shield_active", false)
	print("[NiflheimEffects] Ymir's Marrow absorbed a hit!")
	
	# Visual: flash the sprite ice-blue
	if hero.has_node("Sprite2D"):
		var tween = hero.create_tween()
		tween.tween_property(hero.get_node("Sprite2D"), "modulate",
			Color(0.7, 0.9, 1.0), 0.1)
		tween.tween_property(hero.get_node("Sprite2D"), "modulate",
			Color.WHITE, 0.2)

func ymir_reset_shield(hero: Node):
	# Reset the shield at the start of each new room (on_room_clear fires at clear)
	hero.set_meta("ymir_shield_active", true)
	print("[NiflheimEffects] Ymir's shield refreshed")


# ════════════════════════════════════════════════════════════
# MIST VEIL
# ════════════════════════════════════════════════════════════

func extend_iframes_quarter(hero: Node, _rune: Dictionary):
	# +0.25s to i-frames (additive with Einherjar's Fragment)
	var current_bonus = hero.get_meta("iframe_bonus", 0.0)
	hero.set_meta("iframe_bonus", current_bonus + 0.25)
	print("[NiflheimEffects] i-frames extended by 0.25s  total bonus: ",
		hero.get_meta("iframe_bonus"))


# ════════════════════════════════════════════════════════════
# BLIZZARD STRIDE
# ════════════════════════════════════════════════════════════

func register_blizzard_stride(hero: Node, _rune: Dictionary):
	# Flag checked in IcePatch._on_body_entered:
	#   if body.get_meta("blizzard_stride", false):
	#       don't apply slow, instead boost speed
	hero.set_meta("blizzard_stride", true)
	print("[NiflheimEffects] Blizzard Stride active — ice patches now speed boosts")

# IcePatch.gd adds this check in _apply_slow:
#   if player.get_meta("blizzard_stride", false):
#       player.move_speed += 10.0   # Boost
#       get_tree().create_timer(1.5).timeout.connect(
#           func(): if is_instance_valid(player): player.move_speed -= 10.0)
#       return  # Skip the slow


# ════════════════════════════════════════════════════════════
# HOWLING WIND
# ════════════════════════════════════════════════════════════

func howling_wind_push(hero: Node, target: Node):
	# Push the enemy slightly away from the hero on bullet hit
	if not is_instance_valid(target): return
	if not "velocity" in target: return
	
	var push_dir = (target.global_position - hero.global_position).normalized()
	# Apply knockback by temporarily overriding velocity
	# EnemyBase already has knockback_velocity — we just add to it
	if "knockback_velocity" in target:
		target.knockback_velocity += push_dir * 90.0


# ════════════════════════════════════════════════════════════
# FROZEN HEART
# ════════════════════════════════════════════════════════════

func frozen_heart_convert(hero: Node):
	# Convert all ice patches in the room to gold
	var patches = hero.get_tree().get_nodes_in_group("ice_patches")
	var gold_gained = patches.size() * 3
	
	for patch in patches:
		if is_instance_valid(patch):
			patch.queue_free()
	
	if gold_gained > 0 and has_node("/root/GameData"):
		GameData.current_run["gold"] += gold_gained
		print("[NiflheimEffects] Frozen Heart converted ",
			patches.size(), " patches → +", gold_gained, "g")


# ════════════════════════════════════════════════════════════
# JORMUNGANDR'S COLD
# (piercing already handled by enable_piercing in ItemEffects)
# frost_chill_on_hit also reused from Frost Shard above
# ════════════════════════════════════════════════════════════
# No additional effect function needed — the combination of
# enable_piercing (from ItemEffects) + frost_chill_on_hit (above)
# produces the described behaviour.


# ════════════════════════════════════════════════════════════
# GLACIER THRONE
# ════════════════════════════════════════════════════════════

func register_glacier_throne(hero: Node, _rune: Dictionary):
	hero.set_meta("glacier_throne_active",  false)  # Shield not yet active
	hero.set_meta("glacier_still_timer",    0.0)    # How long hero has stood still
	hero.set_meta("glacier_shield_charged", false)  # Shield charged?
	print("[NiflheimEffects] Glacier Throne registered")

func glacier_throne_absorb(hero: Node, _amount: int):
	# Called on_hit_taken — check if shield was up
	if hero.get_meta("glacier_shield_charged", false):
		hero.set_meta("glacier_shield_charged", false)
		hero.set_meta("glacier_throne_active",  false)
		print("[NiflheimEffects] Glacier Throne absorbed a hit!")
		# Visual shield break
		if hero.has_node("Sprite2D"):
			var tween = hero.create_tween()
			tween.tween_property(hero.get_node("Sprite2D"), "modulate",
				Color(0.5, 0.8, 1.0, 0.5), 0.08)
			tween.tween_property(hero.get_node("Sprite2D"), "modulate",
				Color.WHITE, 0.25)
		# NOTE: For the actual damage block to work, Hero.take_damage()
		# must check: if get_meta("glacier_shield_charged", false): block damage
		# Similar to Ymir's Marrow pattern above.

func glacier_throne_refresh(hero: Node):
	# Refresh the "can charge" state on room clear
	hero.set_meta("glacier_still_timer",    0.0)
	hero.set_meta("glacier_shield_charged", false)
	hero.set_meta("glacier_throne_active",  true)   # Now eligible to charge
	print("[NiflheimEffects] Glacier Throne refreshed")

# The still-timer is tracked in Hero._physics_process.
# Add to Hero.gd _physics_process:
#
#   # Glacier Throne: charge shield when standing still
#   if has_node("ItemManager") and $ItemManager.has_rune("glacier_throne"):
#       if velocity.length() < 5.0:
#           var still = get_meta("glacier_still_timer", 0.0) + delta
#           set_meta("glacier_still_timer", still)
#           if still >= 1.5 and not get_meta("glacier_shield_charged", false):
#               set_meta("glacier_shield_charged", true)
#               print("[Hero] Glacier Throne shield CHARGED")
#               # Visual: brief ice crystal aura around hero
#       else:
#           set_meta("glacier_still_timer", 0.0)
