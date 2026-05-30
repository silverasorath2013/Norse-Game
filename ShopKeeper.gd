extends Node2D

# ============================================================
# ShopKeeper.gd  —  Complete Shop Room
# ============================================================
# The full merchant experience:
#
#   LAYOUT:
#     • Merchant NPC in the upper centre (drawn in _draw)
#     • 3 rune pedestals spread across the room
#     • Price signs drawn above each pedestal
#     • Gold display in bottom-left of room
#
#   INTERACTIONS:
#     • Walk into pedestal range + press E → attempt purchase
#     • If broke: "Need Xg" label flashes on the pedestal,
#       merchant says a dismissive line
#     • If full inventory: "Bag Full!" flashes, merchant reacts
#     • REROLL (R key near counter): pay 15g to swap all 3 items
#       for fresh rolls. Can only reroll once per room.
#     • STEAL (hold E for 2s near pedestal): take item for free.
#       Merchant becomes hostile — spawns 3 angry Draugr,
#       leaves the room, and the shop is permanently "CURSED"
#       (items cost double in all future shops this run).
#
#   MERCHANT DIALOGUE:
#     Greets on entry, reacts to purchases, curses on theft.
#
# SCENE TREE for ShopKeeper.tscn:
#   ShopKeeper  [Node2D]        ← this script
#   ├── MerchantBody  [Node2D]  ← merchant NPC (drawn in _draw)
#   ├── Counter  [Node2D]       ← shop counter visual
#   ├── DialogueLabel  [Label]  ← merchant speech
#   ├── RerollSign  [Area2D]    ← interact zone for reroll
#   │   └── CollisionShape2D   (rect)
#   └── GoldDisplay  [Label]    ← shows player's current gold
# ============================================================

# ── SIGNALS ─────────────────────────────────────────────────
signal shop_stolen_from()   # Room.gd / RoomManager listen for enemy spawn

# ── CONSTANTS ────────────────────────────────────────────────
const REROLL_COST:       int   = 15
const STEAL_HOLD_TIME:   float = 2.0   # Seconds to hold E for steal
const HOSTILE_SPAWN_COUNT: int = 3
const ROOM_W: float = 16 * 40.0
const ROOM_H: float = 12 * 40.0

# Item positioning (world space)
const PEDESTAL_Y:     float = ROOM_H * 0.42
const MERCHANT_POS:   Vector2 = Vector2(ROOM_W * 0.5, ROOM_H * 0.26)
const COUNTER_Y:      float = ROOM_H * 0.33
const REROLL_POS:     Vector2 = Vector2(ROOM_W * 0.5, ROOM_H * 0.31)

# Rarity colours (match RuneDatabase)
const RARITY_COLORS = {
	"common":    Color(0.75, 0.75, 0.75),
	"uncommon":  Color(0.2,  0.75, 0.35),
	"rare":      Color(0.4,  0.6,  1.0),
	"legendary": Color(0.9,  0.7,  0.15),
}

# Merchant dialogue pools
const GREET_LINES = [
	"Ah, a warrior! Browse freely.",
	"Welcome, wanderer. Gold speaks louder than steel.",
	"The Norns led you here. Spend wisely.",
	"Runes of power, priced to move!",
	"Don't touch what you can't afford.",
]
const PURCHASE_LINES = [
	"Excellent taste. May it serve you well.",
	"A fine choice. The Norns approve.",
	"Gold well spent, warrior.",
	"Use it wisely. Death is permanent.",
	"I have more where that came from.",
]
const BROKE_LINES = [
	"Your purse is as thin as your prospects.",
	"Come back when you have gold, pauper.",
	"The rune laughs at your empty hands.",
	"Perhaps try killing more things.",
	"Poverty is not a discount.",
]
const STEAL_WARNING_LINES = [  # Shown while player holds E to steal
	"...are you sure about this?",
	"I see your hands moving...",
	"You wouldn't dare.",
	"My guards are very large.",
]
const HOSTILE_LINES = [
	"THIEF! GUARDS! KILL THEM!",
	"You'll regret this, cur!",
	"Your blood will pay the price!",
]
const REROLL_LINES = [
	"New stock, fresh from Yggdrasil.",
	"The Norns have reshuffled your fate.",
	"Let's see if luck favours you now.",
]

# ── RUNTIME STATE ────────────────────────────────────────────
var floor_num:         int    = 1
var held_ids:          Array  = []
var shop_pedestals:    Array  = []  # Array of {pedestal, rune, price} Dicts
var has_been_stolen:   bool   = false
var is_hostile:        bool   = false
var has_rerolled:      bool   = false
var player_in_range:   Node   = null
var steal_hold_timer:  float  = 0.0
var steal_target_pedestal: Node = null
var _merchant_bob:     float  = 0.0
var _dialogue_timer:   float  = 0.0
var _current_dialogue: String = ""
var _reroll_zone_active: bool = false

# @onready refs (set manually since scene may not have all nodes)
var dialogue_label: Label = null
var gold_display:   Label = null
var reroll_area:    Area2D = null


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	dialogue_label = get_node_or_null("DialogueLabel")
	gold_display   = get_node_or_null("GoldDisplay")
	reroll_area    = get_node_or_null("RerollSign")
	
	if reroll_area:
		reroll_area.body_entered.connect(_on_reroll_zone_entered)
		reroll_area.body_exited.connect(_on_reroll_zone_exited)
	
	add_to_group("shop")


# ════════════════════════════════════════════════════════════
# setup()  —  called by Room.gd after instantiation
# ════════════════════════════════════════════════════════════
func setup(f_num: int, h_ids: Array):
	floor_num = f_num
	held_ids  = h_ids
	
	_spawn_all_pedestals()
	_say(_random(GREET_LINES), 3.5)
	print("[ShopKeeper] Shop '", _random_shop_name(), "' open on floor ", floor_num)


# ════════════════════════════════════════════════════════════
# _process()
# ════════════════════════════════════════════════════════════
func _process(delta: float):
	_merchant_bob += delta
	
	# Update dialogue timer
	if _dialogue_timer > 0:
		_dialogue_timer -= delta
		if _dialogue_timer <= 0:
			_set_dialogue("")
	
	# Update gold display
	if gold_display and has_node("/root/GameData"):
		gold_display.text = "Your gold: " + str(GameData.current_run.get("gold", 0)) + "g"
	
	# Steal hold mechanic
	if steal_target_pedestal != null and Input.is_action_pressed("interact"):
		steal_hold_timer += delta
		_update_steal_progress(steal_hold_timer / STEAL_HOLD_TIME)
		
		if steal_hold_timer >= STEAL_HOLD_TIME:
			_execute_steal(steal_target_pedestal)
			steal_target_pedestal = null
			steal_hold_timer      = 0.0
	else:
		if steal_hold_timer > 0:
			steal_hold_timer = 0.0
			_update_steal_progress(0.0)
	
	queue_redraw()


# ════════════════════════════════════════════════════════════
# _draw()  —  merchant NPC + counter + reroll sign
# ════════════════════════════════════════════════════════════
func _draw():
	var font = ThemeDB.fallback_font
	
	# ── MERCHANT BODY ────────────────────────────────────────
	var bob  = sin(_merchant_bob * 1.2) * 2.0
	var mx   = MERCHANT_POS.x
	var my   = MERCHANT_POS.y + bob
	
	if is_hostile:
		# Red angry merchant
		_draw_merchant(mx, my, Color(0.8, 0.1, 0.1))
	else:
		# Normal robed figure
		_draw_merchant(mx, my, Color(0.4, 0.35, 0.6))
	
	# ── COUNTER ──────────────────────────────────────────────
	draw_rect(Rect2(ROOM_W * 0.2, COUNTER_Y, ROOM_W * 0.6, 14),
		Color(0.28, 0.2, 0.12))
	draw_rect(Rect2(ROOM_W * 0.2, COUNTER_Y, ROOM_W * 0.6, 14),
		Color(0.4, 0.3, 0.2), false, 1.0)
	
	# ── REROLL SIGN ──────────────────────────────────────────
	var reroll_color = Color(0.5, 0.5, 0.55, 0.5) if has_rerolled else Color(0.8, 0.7, 0.2)
	draw_rect(Rect2(ROOM_W * 0.5 - 42, COUNTER_Y - 22, 84, 16),
		Color(0.12, 0.1, 0.08))
	draw_rect(Rect2(ROOM_W * 0.5 - 42, COUNTER_Y - 22, 84, 16),
		reroll_color, false, 0.75)
	var reroll_text = "[R] Reroll  " + str(REROLL_COST) + "g" if not has_rerolled else "Rerolled"
	draw_string(font, Vector2(ROOM_W * 0.5 - 36, COUNTER_Y - 8),
		reroll_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, reroll_color)
	
	# ── SHOP NAME BANNER ────────────────────────────────────
	draw_string(font, Vector2(ROOM_W * 0.5 - 60, ROOM_H * 0.08),
		_random_shop_name() if not has_been_stolen else "★ CURSED WARES ★",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.75, 0.65, 0.3) if not has_been_stolen else Color(0.7, 0.1, 0.7))


func _draw_merchant(x: float, y: float, robe_color: Color):
	var font = ThemeDB.fallback_font
	# Head
	draw_circle(Vector2(x, y - 18), 9, Color(0.8, 0.7, 0.55))
	# Robe body
	draw_rect(Rect2(x - 10, y - 10, 20, 24), robe_color)
	# Hood
	draw_rect(Rect2(x - 11, y - 26, 22, 12), robe_color.darkened(0.2))
	# Eyes
	draw_circle(Vector2(x - 3, y - 19), 1.5, Color(0.1, 0.1, 0.15))
	draw_circle(Vector2(x + 3, y - 19), 1.5, Color(0.1, 0.1, 0.15))
	# Name above
	draw_string(font, Vector2(x - 28, y - 42),
		"Völundr" if not is_hostile else "HOSTILE!",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.7, 0.7, 0.75) if not is_hostile else Color(1.0, 0.2, 0.2))


# ════════════════════════════════════════════════════════════
# PEDESTAL SPAWNING
# ════════════════════════════════════════════════════════════
func _spawn_all_pedestals():
	# Clear old pedestals if rerolling
	for entry in shop_pedestals:
		if is_instance_valid(entry["pedestal"]):
			entry["pedestal"].queue_free()
	shop_pedestals.clear()
	
	var positions = [
		Vector2(ROOM_W * 0.25, PEDESTAL_Y),
		Vector2(ROOM_W * 0.5,  PEDESTAL_Y),
		Vector2(ROOM_W * 0.75, PEDESTAL_Y),
	]
	
	# If shop has been stolen from this run, prices are doubled
	var price_mult = 2 if has_node("/root/GameData") and \
		GameData.current_run.get("shop_cursed", false) else 1
	
	for i in range(3):
		var rune  = RuneDatabase.roll_random_rune(floor_num, held_ids)
		if rune.is_empty(): continue
		
		var price = _calculate_price(rune) * price_mult
		var ped   = _spawn_one_pedestal(positions[i], rune, price)
		if ped:
			shop_pedestals.append({"pedestal": ped, "rune": rune, "price": price})


func _spawn_one_pedestal(world_pos: Vector2, rune: Dictionary, price: int) -> Node:
	var path = "res://scenes/items/RunePedestal.tscn"
	var ped: Node
	
	if ResourceLoader.exists(path):
		ped = load(path).instantiate()
		ped.global_position = world_pos
		get_parent().add_child(ped)
		ped.setup(rune)
	else:
		# Placeholder if scene not yet made
		ped = Node2D.new()
		ped.global_position = world_pos
		get_parent().add_child(ped)
		print("[ShopKeeper] Pedestal placeholder for: ", rune.get("name","?"))
	
	# Tag the pedestal as a shop item
	ped.set_meta("shop_price",   price)
	ped.set_meta("is_shop_item", true)
	ped.set_meta("shop_keeper",  self)
	
	# Add the visible price sign
	_attach_price_sign(ped, price, rune.get("rarity","common"), rune.get("name","?"))
	
	# Wire steal detection: pedestal's body_entered signals to us
	if ped.has_signal("body_entered"):
		ped.body_entered.connect(_on_pedestal_player_proximity.bind(ped))
	
	return ped


func _attach_price_sign(pedestal: Node, price: int, rarity: String, item_name: String):
	# Price label
	var price_label = Label.new()
	price_label.name = "PriceLabel"
	price_label.text = str(price) + "g"
	price_label.position = Vector2(-14, -48)
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.add_theme_color_override("font_color",
		RARITY_COLORS.get(rarity, Color.WHITE))
	pedestal.add_child(price_label)
	
	# Item name label (smaller, below price)
	var name_label = Label.new()
	name_label.name = "ItemNameLabel"
	name_label.text = item_name
	name_label.position = Vector2(-40, -36)
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	pedestal.add_child(name_label)


# ════════════════════════════════════════════════════════════
# try_purchase()  —  called by RunePedestal when player presses E
# ════════════════════════════════════════════════════════════
func try_purchase(price: int, player: Node) -> bool:
	if is_hostile:
		_say(_random(HOSTILE_LINES), 2.5)
		return false
	
	if not has_node("/root/GameData"):
		return true
	
	var gold = GameData.current_run.get("gold", 0)
	
	if gold < price:
		_say(_random(BROKE_LINES), 2.5)
		_flash_label_on_pedestal(_find_pedestal_near(player), "Need " + str(price) + "g!", Color.RED)
		return false
	
	# Inventory full check
	var mgr = player.get_node_or_null("ItemManager")
	if mgr and mgr.is_full():
		_say("You're carrying too much already.", 2.5)
		_flash_label_on_pedestal(_find_pedestal_near(player), "Bag Full!", Color.YELLOW)
		return false
	
	# Deduct gold and confirm sale
	GameData.current_run["gold"] -= price
	GameData.track_gold_spent(price)
	_say(_random(PURCHASE_LINES), 2.5)
	print("[ShopKeeper] Sold for ", price, "g. Gold remaining: ",
		GameData.current_run["gold"])
	return true


# ════════════════════════════════════════════════════════════
# REROLL  —  swap all 3 items for 15 gold
# ════════════════════════════════════════════════════════════
func _input(event: InputEvent):
	if event.is_action_just_pressed("reroll_shop") and _reroll_zone_active:
		_attempt_reroll()

func _attempt_reroll():
	if has_rerolled:
		_say("I only restock once, friend.", 2.5)
		return
	
	if not has_node("/root/GameData"):
		return
	
	var gold = GameData.current_run.get("gold", 0)
	if gold < REROLL_COST:
		_say("Restock costs " + str(REROLL_COST) + "g. You're short.", 2.5)
		return
	
	GameData.current_run["gold"] -= REROLL_COST
	has_rerolled = true
	_spawn_all_pedestals()
	_say(_random(REROLL_LINES), 3.0)
	print("[ShopKeeper] Rerolled for ", REROLL_COST, "g")


# ════════════════════════════════════════════════════════════
# STEAL SYSTEM
# Hold E on a pedestal for STEAL_HOLD_TIME to steal for free.
# Triggers merchant hostility.
# ════════════════════════════════════════════════════════════
func _on_pedestal_player_proximity(body: Node2D, pedestal: Node):
	if body.is_in_group("player"):
		steal_target_pedestal = pedestal
		# Show a faint "Hold E to steal..." hint near the pedestal
		_flash_label_on_pedestal(pedestal, "Hold E to steal...", Color(0.5, 0.5, 0.55))

func _update_steal_progress(fraction: float):
	# As the player holds E, change the merchant's dialogue
	if fraction > 0.1 and fraction < 1.0:
		var idx = int(fraction * STEAL_WARNING_LINES.size())
		idx = clampi(idx, 0, STEAL_WARNING_LINES.size() - 1)
		_set_dialogue(STEAL_WARNING_LINES[idx])
	elif fraction <= 0:
		_set_dialogue("")

func _execute_steal(pedestal: Node):
	if is_hostile: return   # Can't steal twice
	
	# Find which item this pedestal holds
	var rune_entry = {}
	for entry in shop_pedestals:
		if entry["pedestal"] == pedestal:
			rune_entry = entry
			break
	
	if rune_entry.is_empty(): return
	
	# Give the item to the player for free
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	var player = players[0]
	
	var mgr = player.get_node_or_null("ItemManager")
	if mgr:
		mgr.try_pick_up(rune_entry["rune"])
	
	# Remove the pedestal
	if is_instance_valid(pedestal):
		pedestal.queue_free()
	shop_pedestals.erase(rune_entry)
	
	# Trigger hostility
	_go_hostile()
	
	# Mark shop as cursed for the rest of the run (double prices)
	if has_node("/root/GameData"):
		GameData.current_run["shop_cursed"] = true
	
	print("[ShopKeeper] STOLEN! Shop cursed for this run.")
	emit_signal("shop_stolen_from")

func _go_hostile():
	is_hostile      = true
	has_been_stolen = true
	_say(_random(HOSTILE_LINES), 5.0)
	
	# Visual: merchant turns red, starts shaking
	queue_redraw()
	
	# Spawn 3 Draugr after a brief pause
	await get_tree().create_timer(0.8).timeout
	_spawn_guard_enemies()

func _spawn_guard_enemies():
	var draugr_path = "res://scenes/enemies/Draugr.tscn"
	var spawn_positions = [
		Vector2(ROOM_W * 0.2, ROOM_H * 0.6),
		Vector2(ROOM_W * 0.5, ROOM_H * 0.7),
		Vector2(ROOM_W * 0.8, ROOM_H * 0.6),
	]
	
	for pos in spawn_positions:
		if ResourceLoader.exists(draugr_path):
			var draugr = load(draugr_path).instantiate()
			draugr.global_position = pos
			draugr.add_to_group("enemies")
			get_parent().add_child(draugr)
		else:
			print("[ShopKeeper] Guard spawned at ", pos, " (Draugr.tscn not found)")


# ════════════════════════════════════════════════════════════
# DIALOGUE HELPERS
# ════════════════════════════════════════════════════════════
func _say(text: String, duration: float):
	_set_dialogue(text)
	_dialogue_timer = duration

func _set_dialogue(text: String):
	_current_dialogue = text
	if dialogue_label:
		dialogue_label.text = text
		dialogue_label.visible = text != ""

func _flash_label_on_pedestal(pedestal: Node, text: String, color: Color):
	if pedestal == null: return
	
	# Create or reuse a flash label on the pedestal
	var flash = pedestal.get_node_or_null("FlashLabel")
	if flash == null:
		flash = Label.new()
		flash.name = "FlashLabel"
		flash.position = Vector2(-30, -64)
		flash.add_theme_font_size_override("font_size", 11)
		pedestal.add_child(flash)
	
	flash.text = text
	flash.add_theme_color_override("font_color", color)
	flash.visible = true
	
	# Auto-hide after 1.5s
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): if is_instance_valid(flash): flash.visible = false; flash.modulate.a = 1.0)

func _find_pedestal_near(player: Node) -> Node:
	var closest: Node = null
	var closest_dist  = 999.0
	for entry in shop_pedestals:
		if not is_instance_valid(entry["pedestal"]): continue
		var d = entry["pedestal"].global_position.distance_to(player.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = entry["pedestal"]
	return closest


# ════════════════════════════════════════════════════════════
# ZONE SIGNALS
# ════════════════════════════════════════════════════════════
func _on_reroll_zone_entered(body: Node2D):
	if body.is_in_group("player"):
		_reroll_zone_active = true
		if not has_rerolled:
			_flash_label_on_pedestal(null, "[R] Reroll for " + str(REROLL_COST) + "g", Color(0.8, 0.7, 0.2))

func _on_reroll_zone_exited(body: Node2D):
	if body.is_in_group("player"):
		_reroll_zone_active = false


# ════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════
func _calculate_price(rune: Dictionary) -> int:
	match rune.get("rarity", "common"):
		"common":    return randi_range(12, 20)
		"uncommon":  return randi_range(22, 35)
		"rare":      return randi_range(38, 55)
		"legendary": return randi_range(60, 80)
	return 15

func _random(pool: Array) -> String:
	return pool[randi() % pool.size()]

func _random_shop_name() -> String:
	# Use a stable name per room (seed by position so it doesn't flicker)
	var names = [
		"Völundr's Wares", "The Wandering Merchant",
		"Skáldskapr's Curiosities", "Trade of the Fates",
		"The Blind Rune-Seller", "Mímir's Emporium",
	]
	return names[int(global_position.x + global_position.y) % names.size()]
