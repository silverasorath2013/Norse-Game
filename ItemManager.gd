extends Node

# ============================================================
# ItemManager.gd
# ============================================================
# Attach this as a child of the Player/Hero node.
# It is the hero's "item brain" — it:
#   1. Holds the hero's inventory (up to MAX_SLOTS runes)
#   2. Applies stat_mods to the hero when a rune is picked up
#   3. Routes trigger events (on_kill, on_hit_taken, etc.)
#      to ItemEffects.gd for processing
#   4. Detects and broadcasts active synergies
#   5. Emits signals so the HUD can update
#
# USAGE IN HERO.GD:
#   In Hero._ready():     $ItemManager.initialise(self)
#   In Hero.take_damage(): $ItemManager.notify_hit_taken(amount)
#   In Hero._on_hit_landed(): $ItemManager.notify_hit_dealt(target)
#   In Hero._die(): nothing — ItemManager cleans up with the hero
#
# In Room.gd, when an enemy dies:
#   GameData.current_player.get_node("ItemManager").notify_kill(enemy_pos)
#
# In RoomManager, when room clears:
#   GameData.current_player.get_node("ItemManager").notify_room_clear()
# ============================================================

signal inventory_changed(items: Array)         # HUD listens: redraw slots
signal synergy_activated(synergy_name: String) # HUD can flash a synergy popup
signal rune_picked_up(rune: Dictionary)        # For sound/visual feedback

const MAX_SLOTS: int = 4   # Isaac-style: 4 item slots max

var hero: Node = null           # The Hero node this manager belongs to
var inventory: Array = []       # Array of rune Dictionaries (up to 4)
var active_synergies: Array = []  # Currently active synergy names

# ════════════════════════════════════════════════════════════
# initialise()  —  call from Hero._ready()
# ════════════════════════════════════════════════════════════
func initialise(hero_node: Node):
	hero = hero_node
	
	# Apply the hero's starting item from their profile
	if not hero.items_held.is_empty():
		for item_name in hero.items_held:
			_apply_starting_item_by_name(item_name)
	
	print("[ItemManager] Initialised for ", hero.hero_name,
		". Max slots: ", MAX_SLOTS)

# ════════════════════════════════════════════════════════════
# try_pick_up()
# Called when the hero walks over a RunePedestal pickup.
# Returns true if pickup succeeded, false if inventory full.
# ════════════════════════════════════════════════════════════
func try_pick_up(rune: Dictionary) -> bool:
	if inventory.size() >= MAX_SLOTS:
		print("[ItemManager] Inventory full! Drop an item first.")
		return false
	
	if rune.is_empty():
		push_warning("[ItemManager] Tried to pick up empty rune dict")
		return false
	
	# Check for duplicate (can't hold two of the same rune)
	for held in inventory:
		if held["id"] == rune["id"]:
			print("[ItemManager] Already holding: ", rune["id"])
			return false
	
	# Add to inventory
	inventory.append(rune)
	
	# Apply flat stat modifiers
	_apply_stat_mods(rune)
	
	# Fire on_pickup effect
	if has_node("/root/ItemEffects"):
		ItemEffects.dispatch_on_pickup(hero, rune)
	
	# Check for new synergies
	_check_synergies()
	
	# Update GameData run log
	if has_node("/root/GameData"):
		GameData.current_run["items_collected"].append(rune["id"])
	
	emit_signal("inventory_changed", inventory)
	emit_signal("rune_picked_up", rune)
	
	print("[ItemManager] Picked up: ", rune["name"],
		" (", rune["rarity"], "). Inventory: ", inventory.size(), "/", MAX_SLOTS)
	return true

# ════════════════════════════════════════════════════════════
# drop_item()
# Lets the player swap out an existing rune for a new one.
# Removes stat mods from the dropped rune before applying new.
# ════════════════════════════════════════════════════════════
func drop_item(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= inventory.size():
		return {}
	
	var dropped = inventory[slot_index]
	inventory.remove_at(slot_index)
	
	# Remove the stat mods from the dropped item
	_remove_stat_mods(dropped)
	
	# Re-check synergies since we lost a rune
	_check_synergies()
	
	emit_signal("inventory_changed", inventory)
	print("[ItemManager] Dropped: ", dropped["name"])
	return dropped

# ════════════════════════════════════════════════════════════
# STAT MOD APPLICATION
# Reads the rune's stat_mods dict and adds/subtracts from hero
# ════════════════════════════════════════════════════════════
func _apply_stat_mods(rune: Dictionary):
	var mods = rune.get("stat_mods", {})
	for stat in mods:
		if stat in hero:
			hero.set(stat, hero.get(stat) + mods[stat])
			# Clamp health to prevent going below 1
			if stat == "max_health":
				hero.max_health = max(1, hero.max_health)
				# Don't let current health exceed new max
				hero.current_health = min(hero.current_health, hero.max_health)
				hero.emit_signal("health_changed", hero.current_health, hero.max_health)
	
	if not mods.is_empty():
		print("[ItemManager] Applied stat mods: ", mods,
			". Dmg:", hero.base_damage, " HP:", hero.max_health,
			" Speed:", hero.move_speed)

func _remove_stat_mods(rune: Dictionary):
	var mods = rune.get("stat_mods", {})
	for stat in mods:
		if stat in hero:
			hero.set(stat, hero.get(stat) - mods[stat])
			if stat == "max_health":
				hero.max_health = max(1, hero.max_health)
				hero.current_health = min(hero.current_health, hero.max_health)
				hero.emit_signal("health_changed", hero.current_health, hero.max_health)

# ════════════════════════════════════════════════════════════
# EVENT NOTIFICATION — Hero calls these at the right moments
# ════════════════════════════════════════════════════════════

func notify_kill(enemy_pos: Vector2):
	if not has_node("/root/ItemEffects"): return
	for rune in inventory:
		ItemEffects.dispatch_on_kill(hero, enemy_pos, rune)

func notify_hit_dealt(target: Node):
	if not has_node("/root/ItemEffects"): return
	for rune in inventory:
		ItemEffects.dispatch_on_hit_dealt(hero, target, rune)

func notify_hit_taken(amount: int):
	if not has_node("/root/ItemEffects"): return
	for rune in inventory:
		ItemEffects.dispatch_on_hit_taken(hero, amount, rune)

func notify_room_clear():
	if not has_node("/root/ItemEffects"): return
	for rune in inventory:
		ItemEffects.dispatch_on_room_clear(hero, rune)

# ════════════════════════════════════════════════════════════
# SYNERGY SYSTEM
# Checks held rune tags against the synergy table.
# A synergy grants a bonus effect when tag conditions are met.
# ════════════════════════════════════════════════════════════

# Synergy definitions: { "name", "required_tags" (all must be present), "effect" }
const SYNERGIES = [
	{
		"name":          "Serpent's Wrath",
		"required_tags": ["serpent", "on_kill"],
		"description":   "Serpent Scale also triggers on kill (not just on hit taken).",
		"effect":        "serpent_on_kill"
	},
	{
		"name":          "Blood Price",
		"required_tags": ["sacrifice", "berserk"],
		"description":   "Berserker threshold rises to 40% HP.",
		"effect":        "raise_berserk_threshold"
	},
	{
		"name":          "Undying Hunger",
		"required_tags": ["lifesteal", "on_kill"],
		"description":   "Lifesteal chance doubles to 16%.",
		"effect":        "double_lifesteal"
	},
	{
		"name":          "World's Edge",
		"required_tags": ["bouncing", "piercing"],
		"description":   "Bouncing shots also pierce — they bounce AND go through enemies.",
		"effect":        "bounce_pierce_combo"
	},
	{
		"name":          "Thunder Road",
		"required_tags": ["speed", "dodge"],
		"description":   "Dodge roll leaves a brief lightning trail dealing 5 damage.",
		"effect":        "lightning_trail"
	},
	{
		"name":          "Norn's Sight",
		"required_tags": ["minimap", "utility"],
		"description":   "Reveal 2 rooms instead of 1 on room clear.",
		"effect":        "double_reveal"
	},
	{
		"name":          "Jotun Vitality",
		"required_tags": ["health", "giant"],
		"description":   "Heal 2 HP extra whenever any heal effect triggers.",
		"effect":        "heal_bonus"
	},
]

func _check_synergies():
	var held_tags = _get_all_held_tags()
	var newly_active = []
	
	for syn in SYNERGIES:
		var all_present = true
		for required_tag in syn["required_tags"]:
			if required_tag not in held_tags:
				all_present = false
				break
		
		if all_present and syn["name"] not in active_synergies:
			active_synergies.append(syn["name"])
			newly_active.append(syn)
			_apply_synergy(syn)
			print("[ItemManager] SYNERGY ACTIVATED: ", syn["name"])
			emit_signal("synergy_activated", syn["name"])
	
	# Also remove synergies that are no longer valid (if an item was dropped)
	var to_remove = []
	for syn_name in active_synergies:
		var still_valid = false
		for syn in SYNERGIES:
			if syn["name"] == syn_name:
				still_valid = true
				for tag in syn["required_tags"]:
					if tag not in held_tags:
						still_valid = false
						break
				break
		if not still_valid:
			to_remove.append(syn_name)
	
	for syn_name in to_remove:
		active_synergies.erase(syn_name)
		print("[ItemManager] Synergy lost: ", syn_name)

func _get_all_held_tags() -> Array:
	var all_tags = []
	for rune in inventory:
		for tag in rune.get("tags", []):
			if tag not in all_tags:
				all_tags.append(tag)
	return all_tags

func _apply_synergy(syn: Dictionary):
	match syn["effect"]:
		"double_lifesteal":
			hero.set_meta("lifesteal_chance", 0.16)
		"raise_berserk_threshold":
			hero.set_meta("berserk_threshold", 0.4)
		"bounce_pierce_combo":
			hero.set_meta("bullet_piercing", true)
		"heal_bonus":
			hero.set_meta("heal_bonus", hero.get_meta("heal_bonus", 0) + 2)
		# Others handled in ItemEffects via notify calls
		_:
			print("[ItemManager] Synergy effect '", syn["effect"], "' — handled at runtime")

# ════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════

func _apply_starting_item_by_name(item_name: String):
	# Starting items are described by name in hero data, not by rune ID.
	# For now we just log them — future: match name to rune ID
	print("[ItemManager] Starting item noted: ", item_name,
		" (apply on floor 1 setup)")

func has_rune(rune_id: String) -> bool:
	for r in inventory:
		if r["id"] == rune_id: return true
	return false

func get_held_ids() -> Array:
	var ids = []
	for r in inventory: ids.append(r["id"])
	return ids

func get_inventory_size() -> int:
	return inventory.size()

func is_full() -> bool:
	return inventory.size() >= MAX_SLOTS
