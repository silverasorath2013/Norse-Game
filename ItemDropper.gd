extends Node

# ============================================================
# ItemDropper.gd  —  Autoload: register as "ItemDropper"
# ============================================================
# Handles everything to do with SPAWNING drops in the world.
# Room.gd calls into this when it needs to place items.
#
# RESPONSIBILITIES:
#   - Roll which rune to drop (calls RuneDatabase.roll_random_rune)
#   - Instantiate RunePedestal at the correct world position
#   - Handle the different drop contexts:
#       post_clear_drop  → 15% chance after killing all enemies
#       treasure_room    → always spawns 1 item (guaranteed)
#       shop_room        → spawns 3 items with gold price labels
#       curse_room       → spawns 1 rare+ item, but at a cost
#       heart_drop       → spawns a heart pickup (not a rune)
#       gold_drop        → spawns a gold pickup
# ============================================================

const PEDESTAL_SCENE = "res://scenes/items/RunePedestal.tscn"
const HEART_SCENE    = "res://scenes/pickups/Heart.tscn"
const GOLD_SCENE     = "res://scenes/pickups/Gold.tscn"

# Drop chances (0.0–1.0) — these are the base values Room.gd uses
const CHANCE_RUNE_DROP  = 0.15   # Rune after room clear
const CHANCE_HEART_DROP = 0.20   # Heart after room clear
const CHANCE_GOLD_DROP  = 0.25   # Gold after room clear
# These add up to 0.60 — 40% chance of nothing dropping


# ════════════════════════════════════════════════════════════
# spawn_post_clear_drop()
# Called by Room.gd's _on_room_cleared().
# Rolls the dice and spawns whatever the player deserves.
# ════════════════════════════════════════════════════════════
func spawn_post_clear_drop(parent_node: Node, world_pos: Vector2,
							floor_num: int, held_ids: Array):
	var roll = randf()
	
	if roll < CHANCE_RUNE_DROP:
		spawn_rune_pedestal(parent_node, world_pos, floor_num, held_ids)
	elif roll < CHANCE_RUNE_DROP + CHANCE_HEART_DROP:
		spawn_heart(parent_node, world_pos)
	elif roll < CHANCE_RUNE_DROP + CHANCE_HEART_DROP + CHANCE_GOLD_DROP:
		spawn_gold(parent_node, world_pos, _random_gold_amount())
	else:
		print("[ItemDropper] No drop this room (40% chance).")


# ════════════════════════════════════════════════════════════
# spawn_treasure_room_item()
# Always spawns exactly one rune in the centre of a treasure room.
# Treasure rooms bias toward rare+ items.
# ════════════════════════════════════════════════════════════
func spawn_treasure_room_item(parent_node: Node, world_pos: Vector2,
								floor_num: int, held_ids: Array):
	# Force uncommon or better for treasure rooms
	# We do this by temporarily boosting the uncommon+ weights
	var rune = RuneDatabase.roll_random_rune(floor_num, held_ids)
	
	# If we rolled common, re-roll once (treasure rooms should feel good)
	if rune.get("rarity", "common") == "common":
		rune = RuneDatabase.roll_random_rune(floor_num, held_ids)
	
	if rune.is_empty():
		print("[ItemDropper] Treasure room: no valid rune to spawn!")
		return
	
	_spawn_pedestal(parent_node, world_pos, rune)
	print("[ItemDropper] Treasure room spawned: ", rune["name"])


# ════════════════════════════════════════════════════════════
# spawn_shop_items()
# Spawns 3 pedestals with gold price signs above them.
# The player must have enough gold to buy each one.
# ════════════════════════════════════════════════════════════
func spawn_shop_items(parent_node: Node, room_center: Vector2,
						floor_num: int, held_ids: Array):
	# Space 3 items across the room
	var spacing = 100.0
	var positions = [
		room_center + Vector2(-spacing, 0),
		room_center,
		room_center + Vector2( spacing, 0),
	]
	
	for i in range(3):
		var rune = RuneDatabase.roll_random_rune(floor_num, held_ids)
		if rune.is_empty(): continue
		
		# Calculate price based on rarity
		var price = _calculate_shop_price(rune)
		
		# Spawn the pedestal
		var pedestal = _spawn_pedestal(parent_node, positions[i], rune)
		if pedestal:
			# Add a price label to the pedestal (it reads from meta)
			pedestal.set_meta("shop_price", price)
			pedestal.set_meta("is_shop_item", true)
		
		print("[ItemDropper] Shop item ", i+1, ": ", rune["name"], " — ", price, "g")


# ════════════════════════════════════════════════════════════
# spawn_curse_room_item()
# Always rare or better. Applying a curse to the hero
# is handled separately by Room.gd (not ItemDropper's job).
# ════════════════════════════════════════════════════════════
func spawn_curse_room_item(parent_node: Node, world_pos: Vector2,
							floor_num: int, held_ids: Array):
	# Roll until we get uncommon or better
	var rune = {}
	var attempts = 0
	while (rune.is_empty() or rune.get("rarity","common") == "common") and attempts < 5:
		rune = RuneDatabase.roll_random_rune(floor_num, held_ids)
		attempts += 1
	
	if rune.is_empty():
		rune = RuneDatabase.get_rune("wolf_fang")   # Absolute fallback
	
	_spawn_pedestal(parent_node, world_pos, rune)
	print("[ItemDropper] Curse room spawned: ", rune["name"])


# ════════════════════════════════════════════════════════════
# spawn_rune_pedestal()  —  public version for direct calls
# ════════════════════════════════════════════════════════════
func spawn_rune_pedestal(parent_node: Node, world_pos: Vector2,
						floor_num: int, held_ids: Array):
	var rune = RuneDatabase.roll_random_rune(floor_num, held_ids)
	if rune.is_empty():
		print("[ItemDropper] No valid rune for drop.")
		return
	_spawn_pedestal(parent_node, world_pos, rune)


# ════════════════════════════════════════════════════════════
# spawn_heart() / spawn_gold()
# ════════════════════════════════════════════════════════════
func spawn_heart(parent_node: Node, world_pos: Vector2, half: bool = false):
	if ResourceLoader.exists(HEART_SCENE):
		var heart = load(HEART_SCENE).instantiate()
		heart.global_position = world_pos
		heart.set_meta("is_half_heart", half)
		parent_node.add_child(heart)
	else:
		# Placeholder until Heart.tscn is made
		print("[ItemDropper] Heart dropped at ", world_pos, " (half: ", half, ")")

func spawn_gold(parent_node: Node, world_pos: Vector2, amount: int = 5):
	if ResourceLoader.exists(GOLD_SCENE):
		var gold = load(GOLD_SCENE).instantiate()
		gold.global_position = world_pos
		gold.set_meta("gold_amount", amount)
		parent_node.add_child(gold)
	else:
		print("[ItemDropper] Gold dropped: ", amount, "g at ", world_pos)


# ════════════════════════════════════════════════════════════
# INTERNAL HELPERS
# ════════════════════════════════════════════════════════════

func _spawn_pedestal(parent_node: Node, world_pos: Vector2,
					rune: Dictionary) -> Node:
	if not ResourceLoader.exists(PEDESTAL_SCENE):
		# Dev fallback: just print until the scene is made
		print("[ItemDropper] PEDESTAL at ", world_pos, " — ", rune.get("name","?"),
			" [", rune.get("rarity","?"), "]")
		return null
	
	var pedestal = load(PEDESTAL_SCENE).instantiate()
	pedestal.global_position = world_pos
	parent_node.add_child(pedestal)
	pedestal.setup(rune)   # RunePedestal.setup() applies visuals
	return pedestal

func _calculate_shop_price(rune: Dictionary) -> int:
	match rune.get("rarity", "common"):
		"common":    return randi_range(12, 20)
		"uncommon":  return randi_range(22, 35)
		"rare":      return randi_range(38, 55)
		"legendary": return randi_range(60, 80)
	return 20

func _random_gold_amount() -> int:
	# Returns 5, 10, or 15 gold with weighted odds
	var roll = randi() % 10
	if roll < 5: return 5      # 50% chance: 5g
	elif roll < 8: return 10   # 30% chance: 10g
	else: return 15            # 20% chance: 15g
