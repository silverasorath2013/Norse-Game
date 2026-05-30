# ============================================================
# SHOP & CURSE ROOM WIRING GUIDE
# ============================================================


## ── ROOM.GD ADDITIONS ───────────────────────────────────────

### 1. Replace _setup_room_type_content() SHOP and CURSE cases:

func _setup_room_type_content(room_type: int):
	var center    = Vector2(ROOM_WIDTH * TILE_SIZE / 2, ROOM_HEIGHT * TILE_SIZE / 2)
	var players   = get_tree().get_nodes_in_group("player")
	var held_ids  = []
	var floor_num = 1
	if not players.is_empty() and players[0].has_node("ItemManager"):
		held_ids  = players[0].get_node("ItemManager").get_held_ids()
	if has_node("/root/GameData"):
		floor_num = GameData.current_run.get("floor", 1)

	match room_type:
		RoomType.SHOP:
			var shop = load("res://scenes/items/ShopKeeper.tscn").instantiate()
			shop.global_position = Vector2.ZERO   # ShopKeeper draws in world space
			add_child(shop)
			shop.setup(floor_num, held_ids)
			# Listen for steal event to lock doors and spawn enemies
			shop.shop_stolen_from.connect(_on_shop_stolen)

		RoomType.CURSE:
			var curse_ctrl = load("res://scenes/items/CurseRoom.tscn").instantiate()
			curse_ctrl.global_position = Vector2.ZERO
			add_child(curse_ctrl)
			curse_ctrl.setup(floor_num, held_ids)
			# Curse altar activates only after all enemies are killed
			curse_ctrl.set_meta("pending_altar", true)


### 2. Add _on_shop_stolen() to Room.gd:

func _on_shop_stolen():
	# Lock doors — player must fight their way out
	lock_doors()
	# The ShopKeeper itself spawns the 3 guard Draugr.
	# Room.gd needs to track them so doors unlock when they die.
	# Add newly spawned enemies to the enemies_alive count:
	await get_tree().create_timer(0.9).timeout   # Wait for guards to spawn
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)
			enemies_alive += 1


### 3. In Room.gd _on_room_cleared(), activate the curse altar:

func _on_room_cleared(room_data):
	unlock_doors()
	_spawn_room_reward()   # Normal drop

	# If this is a curse room, activate the altar now
	var curse_ctrl = get_node_or_null("CurseRoom")
	if curse_ctrl and curse_ctrl.has_meta("pending_altar"):
		curse_ctrl.activate_altar()

	emit_signal("room_cleared", room_data)


## ── CURSE EFFECTS THAT NEED RUNTIME CHECKS ──────────────────

Some curses set meta flags that other systems must check:

### "marked_for_death" — EnemyBase.gd, in _deal_contact():
	var extra = player.get_meta("curse_extra_damage", 0)
	player.take_damage(damage + extra)

### "cursed_gold" — Gold.gd, in _on_body_entered():
	var amount = gold_amount
	if has_node("/root/GameData") and GameData.current_run.get("gold_curse", false):
		amount = int(amount * 0.5)   # Halved
	GameData.current_run["gold"] += amount

### "hungry_runes" — ItemEffects.gd, in every dispatch function:
	# At the top of dispatch_on_kill / dispatch_on_hit_dealt / etc:
	var proc_chance = hero.get_meta("rune_proc_chance", 1.0)
	if randf() > proc_chance:
		return   # Rune effect doesn't trigger this time

### "cracked_defence" — Hero.gd, in take_damage():
	var iframe_bonus = get_meta("iframe_bonus", 0.0)   # Can be negative from curse
	invincibility_timer = max(0.1, I_FRAME_TIME + iframe_bonus)


## ── SCENE FILES TO CREATE ───────────────────────────────────

### res://scenes/items/ShopKeeper.tscn
	Root: Node2D → attach ShopKeeper.gd
	Children:
	  MerchantBody  [Node2D]      (no script — drawn by parent _draw)
	  DialogueLabel [Label]
	    position: (ROOM_W*0.5 - 80, ROOM_H*0.18)
	    visible: false (set visible in _say())
	    font_size: 12
	  GoldDisplay   [Label]
	    position: (16, ROOM_H - 30)
	    font_size: 11
	  RerollSign    [Area2D]
	    position: (ROOM_W*0.5, ROOM_H*0.31)
	    CollisionShape2D: RectangleShape2D 84×20
	    Collision mask: 1 (player)

### res://scenes/items/CurseRoom.tscn
	Root: Node2D → attach CurseRoom.gd
	(AltarDetector Area2D is created at runtime in _ready())
	No other children needed.


## ── SHOP BEHAVIOUR SUMMARY ──────────────────────────────────

  Normal purchase:
    Walk into pedestal range (r=14) → press E → gold check →
    if broke: "Need Xg!" flashes on pedestal, merchant speaks →
    if full: "Bag Full!" flashes → if ok: gold deducted, item given

  Reroll:
    Walk near counter → RerollSign Area2D fires → press R →
    gold check (15g) → if ok: all 3 pedestals replaced → once only

  Steal:
    Walk into pedestal range → hold E for 2 full seconds →
    merchant gives warnings → item given for free →
    merchant turns hostile → 3 Draugr spawn → doors lock →
    "shop_cursed" flag set in GameData → all future shop prices ×2

  Shop-cursed state:
    ShopKeeper._spawn_all_pedestals() reads GameData["shop_cursed"]
    and multiplies _calculate_price() by 2 on all items.


## ── CURSE ROOM BEHAVIOUR SUMMARY ────────────────────────────

  On enter:
    Room is populated with 4–6 enemies (set in DungeonGenerator
    _populate_rooms() for RoomType.CURSE).
    Altar glows dark with "Clear room first" label.

  After room clear:
    Room.gd calls curse_ctrl.activate_altar().
    Altar crystal lights up purple and pulses.
    Player sees "[E] Bargain" prompt when in range.

  Bargain UI:
    Press E → 3 curse cards slide up from bottom.
    ← / → to browse. Each card shows:
      • Severity (1–3 skull dots)
      • Icon, name, description, flavour text
    Press E on selected card → curse applied → reward spawns.
    Press ESC → UI closes, altar stays active (can return).

  On acceptance:
    Curse applied immediately to player stats/meta.
    Altar shatters visually (fragment scatter animation).
    Guaranteed reward: uncommon+ (floor 1–2), rare+ (floor 3–4),
    legendary (floor 5).
    Curse ID recorded in GameData.current_run["curses"].
