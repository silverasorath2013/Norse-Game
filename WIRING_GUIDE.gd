# ============================================================
# ITEM SYSTEM WIRING GUIDE
# ============================================================
# This file shows EXACTLY which lines to add to existing
# scripts to connect the item system. Do NOT copy this whole
# file — add only the marked sections to the relevant scripts.
# ============================================================


# ════════════════════════════════════════════════════════════
# 1. HERO.GD  —  Add ItemManager as a child node in the scene,
#                then wire it in _ready() and event methods.
# ════════════════════════════════════════════════════════════

# In Hero.tscn scene tree, add a child node:
#   Hero  [CharacterBody2D]
#   ├── Sprite2D
#   ├── CollisionShape2D
#   ├── Hitbox  [Area2D]
#   ├── ShootOrigin  [Marker2D]
#   └── ItemManager  [Node]     ← ADD THIS, attach ItemManager.gd

# In Hero.gd, add this to _ready():
func _ready_ADDITION():
	# ... existing _ready() code above this ...
	$ItemManager.initialise(self)   # ← ADD THIS LINE


# In Hero.gd take_damage(), add AFTER taking damage:
func take_damage_ADDITION(amount: int):
	# ... existing damage code ...
	# ← ADD THIS after applying damage, before _die() check:
	if has_node("ItemManager"):
		$ItemManager.notify_hit_taken(amount)


# In Hero.gd _fire_projectile(), connect bullet hit signal:
func _fire_projectile_ADDITION(direction: Vector2):
	# ... existing spawn code ...
	# ← ADD after bullet is created:
	if bullet.has_signal("hit_enemy"):
		bullet.hit_enemy.connect(_on_bullet_hit_enemy)

# New function to add to Hero.gd:
func _on_bullet_hit_enemy(target: Node):
	if has_node("ItemManager"):
		$ItemManager.notify_hit_dealt(target)
	# Also call the existing passive hook:
	if has_method("_on_hit_landed"):
		_on_hit_landed(target.global_position)


# ════════════════════════════════════════════════════════════
# 2. BULLET.GD  —  Add a signal so Hero.gd knows when a hit lands
# ════════════════════════════════════════════════════════════

# At the top of Bullet.gd, add:
signal hit_enemy(target: Node)   # ← ADD THIS

# In Bullet.gd _on_body_entered() / _on_area_entered(),
# BEFORE calling _destroy(), add:
#   emit_signal("hit_enemy", body)    # (for body_entered version)
#   emit_signal("hit_enemy", enemy)   # (for area_entered version)


# ════════════════════════════════════════════════════════════
# 3. ROOM.GD  —  Wire drops, notify kills, notify room clear
# ════════════════════════════════════════════════════════════

# In Room.gd _on_enemy_died(), add after the enemies_alive decrement:
func _on_enemy_died_ADDITION():
	# ... existing code ...
	# ← ADD: notify the player's ItemManager about the kill
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var mgr = players[0].get_node_or_null("ItemManager")
		if mgr:
			# enemy_death_position must be stored when enemy dies
			# (capture it in a variable when the enemy signals)
			mgr.notify_kill(Vector2.ZERO)   # Replace ZERO with actual pos


# In Room.gd _on_room_cleared(), add:
func _on_room_cleared_ADDITION(room_data):
	# ... existing unlock_doors() and signal code ...
	
	# ← ADD: notify ItemManager that room was cleared
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var mgr = players[0].get_node_or_null("ItemManager")
		if mgr:
			mgr.notify_room_clear()
	
	# ← REPLACE the existing _spawn_room_reward() call with ItemDropper:
	var player     = players[0] if not players.is_empty() else null
	var held_ids   = []
	if player and player.has_node("ItemManager"):
		held_ids = player.get_node("ItemManager").get_held_ids()
	
	var drop_pos   = Vector2(ROOM_WIDTH * TILE_SIZE / 2, ROOM_HEIGHT * TILE_SIZE / 2)
	ItemDropper.spawn_post_clear_drop(self, drop_pos,
		room_data.floor_number if "floor_number" in room_data else 1, held_ids)


# In Room.gd _setup_room_type_content(), REPLACE the print stubs:
func _setup_room_type_content_ADDITION(room_type: int):
	var center     = Vector2(ROOM_WIDTH * TILE_SIZE / 2, ROOM_HEIGHT * TILE_SIZE / 2)
	var players    = get_tree().get_nodes_in_group("player")
	var held_ids   = []
	var floor_num  = 1
	if not players.is_empty() and players[0].has_node("ItemManager"):
		held_ids  = players[0].get_node("ItemManager").get_held_ids()
	if has_node("/root/GameData"):
		floor_num = GameData.current_run.get("floor", 1)
	
	match room_type:
		RoomType.TREASURE:
			ItemDropper.spawn_treasure_room_item(self, center, floor_num, held_ids)
		
		RoomType.SHOP:
			if ResourceLoader.exists("res://scenes/ShopKeeper.tscn"):
				var shop = load("res://scenes/ShopKeeper.tscn").instantiate()
				shop.global_position = Vector2(center.x, center.y - 60)
				add_child(shop)
				shop.setup(floor_num, held_ids)
			else:
				ItemDropper.spawn_shop_items(self, center, floor_num, held_ids)
		
		RoomType.CURSE:
			ItemDropper.spawn_curse_room_item(self, center, floor_num, held_ids)
		
		RoomType.BOSS:
			pass   # Boss spawned separately
		
		RoomType.EXIT:
			pass   # Staircase spawned after boss death


# ════════════════════════════════════════════════════════════
# 4. GAME.GD  —  Connect ItemHUD and wire the full HUD
# ════════════════════════════════════════════════════════════

# In Game.gd _ready(), after connect_to_player():
func _ready_GAME_ADDITION():
	# ... existing code ...
	$HUD.connect_to_player($Player)          # already there
	
	# ← ADD: connect ItemHUD to ItemManager
	if $Player.has_node("ItemManager") and has_node("HUD/ItemHUD"):
		$HUD/ItemHUD.connect_to_item_manager($Player.get_node("ItemManager"))


# ════════════════════════════════════════════════════════════
# 5. AUTOLOADS TO REGISTER  (Project > Project Settings > Autoload)
# ════════════════════════════════════════════════════════════
#
# ADD THESE (in addition to GameData, DungeonGenerator, InputSetup):
#
#   Path                               Name
#   res://scripts/items/RuneDatabase.gd  → RuneDatabase
#   res://scripts/items/ItemEffects.gd   → ItemEffects
#   res://scripts/items/ItemDropper.gd   → ItemDropper
#
# Final Autoload order (order matters!):
#   1. InputSetup
#   2. GameData
#   3. DungeonGenerator
#   4. RuneDatabase
#   5. ItemEffects
#   6. ItemDropper


# ════════════════════════════════════════════════════════════
# 6. SCENE FILES TO CREATE
# ════════════════════════════════════════════════════════════
#
# res://scenes/items/RunePedestal.tscn
#   Root: Area2D  → attach RunePedestal.gd
#   Children:
#     CollisionShape2D  (CircleShape2D r=14)
#     Sprite2D          (pedestal base)
#     RuneSprite [Sprite2D]
#     InteractLabel [Label]  (visible=false by default)
#   Collision: Layer 8 (pickups), Mask 1 (player)
#
# res://scenes/pickups/Heart.tscn
#   Root: Area2D  → attach Heart.gd
#   Children:
#     CollisionShape2D  (CircleShape2D r=10)
#   Collision: Layer 8, Mask 1
#
# res://scenes/pickups/Gold.tscn
#   Root: Area2D  → attach Gold.gd
#   Children:
#     CollisionShape2D  (CircleShape2D r=8)
#   Collision: Layer 8, Mask 1
#
# res://scenes/ShopKeeper.tscn
#   Root: Node2D  → attach ShopKeeper.gd
#   Children:
#     Sprite2D  (merchant NPC art or ColorRect placeholder)
#     NameLabel [Label]
#
# Also add Layer 8 = "pickups" in:
#   Project > Project Settings > Physics > 2D
