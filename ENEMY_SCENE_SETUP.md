# ============================================================
# ENEMY SCENE SETUP GUIDE
# ============================================================
# This file tells you exactly what to create in the Godot editor
# for each enemy. You'll do this once per enemy type.
#
# HOW TO CREATE A SCENE IN GODOT:
#   1. Scene menu → New Scene
#   2. Add the root node (CharacterBody2D)
#   3. Right-click root → Add Child Node for each child
#   4. Save as res://scenes/enemies/EnemyName.tscn
#   5. Attach the script: click root node, Inspector → Script → load
# ============================================================


# ════════════════════════════════════════════════════════════
# DRAUGR.tscn
# ════════════════════════════════════════════════════════════
#
# NODE TREE:
#   Draugr  [CharacterBody2D]          ← attach Draugr.gd here
#   ├── Sprite2D                        ← your 16×16 draugr art
#   │     texture: res://assets/sprites/enemies/draugr.png
#   │     scale: (2.0, 2.0)             ← upscale pixel art 2×
#   ├── CollisionShape2D                ← the physics body shape
#   │     shape: RectangleShape2D
#   │     size: (14, 20)                ← slightly smaller than sprite
#   ├── Hurtbox  [Area2D]               ← bullets hit this
#   │   └── CollisionShape2D
#   │         shape: RectangleShape2D
#   │         size: (12, 18)            ← slightly smaller than physics shape
#   └── DetectionZone  [Area2D]         ← detects the player nearby
#       └── CollisionShape2D
#             shape: CircleShape2D
#             radius: 280              ← matches detection_range in Draugr.gd
#
# COLLISION LAYERS:
#   Draugr (root): Layer 2  (enemies layer)
#   Hurtbox:       Layer 3  (hurtboxes layer)  Mask: none
#   DetectionZone: Layer 4  (detection layer)   Mask: Layer 1 (player)
#
# COLLISION LAYER SETUP (Project Settings → Physics → 2D):
#   Layer 1 = player
#   Layer 2 = enemies
#   Layer 3 = enemy_hurtboxes
#   Layer 4 = detection_zones
#   Layer 5 = player_bullets
#   Layer 6 = enemy_bullets
#   Layer 7 = walls (TileMap)


# ════════════════════════════════════════════════════════════
# EINHERJAR.tscn   (same structure, different script + shape)
# ════════════════════════════════════════════════════════════
#
#   Einherjar  [CharacterBody2D]       ← attach Einherjar.gd
#   ├── Sprite2D                        ← ghost warrior art
#   │     scale: (2.0, 2.0)
#   │     modulate: (0.8, 0.8, 1.0)    ← slight blue tint for ghost feel
#   ├── CollisionShape2D
#   │     shape: CapsuleShape2D         ← capsule fits a floating enemy better
#   │     height: 20  radius: 6
#   ├── Hurtbox  [Area2D]
#   │   └── CollisionShape2D  (CircleShape2D, radius: 10)
#   └── DetectionZone  [Area2D]
#       └── CollisionShape2D  (CircleShape2D, radius: 320)


# ════════════════════════════════════════════════════════════
# WIGHT.tscn   (smaller, faster)
# ════════════════════════════════════════════════════════════
#
#   Wight  [CharacterBody2D]           ← attach Wight.gd
#   ├── Sprite2D
#   │     scale: (1.6, 1.6)            ← slightly smaller than Draugr
#   ├── CollisionShape2D
#   │     shape: CircleShape2D  radius: 7
#   ├── Hurtbox  [Area2D]
#   │   └── CollisionShape2D  (CircleShape2D, radius: 7)
#   └── DetectionZone  [Area2D]
#       └── CollisionShape2D  (CircleShape2D, radius: 300)


# ════════════════════════════════════════════════════════════
# CURSEDWOLF.tscn
# ════════════════════════════════════════════════════════════
#
#   CursedWolf  [CharacterBody2D]      ← attach CursedWolf.gd
#   ├── Sprite2D
#   │     scale: (2.0, 2.0)
#   │     modulate: (0.6, 0.3, 0.2)    ← dark reddish tint
#   ├── CollisionShape2D
#   │     shape: CapsuleShape2D  height: 16, radius: 7
#   ├── Hurtbox  [Area2D]
#   │   └── CollisionShape2D  (CapsuleShape2D, height: 14, radius: 6)
#   └── DetectionZone  [Area2D]
#       └── CollisionShape2D  (CircleShape2D, radius: 290)


# ════════════════════════════════════════════════════════════
# ENEMYBULLET.tscn
# ════════════════════════════════════════════════════════════
#
#   EnemyBullet  [Area2D]              ← attach EnemyBullet.gd
#   ├── CollisionShape2D
#   │     shape: CircleShape2D  radius: 4
#   ├── Sprite2D
#   │     texture: a 8×8 circle sprite (orange-red for enemy bullets)
#   │     scale: (2.0, 2.0)
#   └── VisibleOnScreenNotifier2D       ← auto calls queue_free via:
#         Connect screen_exited → EnemyBullet.queue_free()
#
#   Collision: Layer 6 (enemy_bullets)   Mask: Layer 1 (player)


# ════════════════════════════════════════════════════════════
# PIXEL ART PLACEHOLDER (until you have real sprites)
# ════════════════════════════════════════════════════════════
# If you don't have sprites yet, Godot lets you use a
# ColorRect or a simple placeholder texture.
#
# Quick placeholder in ANY enemy _ready():
#
#   func _ready():
#     super()
#     # Create a coloured square as a sprite placeholder
#     var rect = ColorRect.new()
#     rect.size = Vector2(16, 16)
#     rect.position = Vector2(-8, -8)   # centre it
#     rect.color = Color(0.3, 0.3, 0.7)  # Draugr = blue-grey
#     add_child(rect)
#
# This lets you test movement and combat before any art is made.


# ════════════════════════════════════════════════════════════
# AUTOLOAD REMINDER
# ════════════════════════════════════════════════════════════
# These must be registered in Project > Project Settings > Autoload:
#
#   Name          Path
#   GameData      res://scripts/GameData.gd
#   DungeonGenerator  res://scripts/DungeonGenerator.gd
#   InputSetup    res://scripts/InputSetup.gd
#
# The order matters — InputSetup must load BEFORE any scene
# so keys are registered before _ready() runs.


# ════════════════════════════════════════════════════════════
# HOW ENEMIES CONNECT TO ROOM.GD
# ════════════════════════════════════════════════════════════
#
# In Room.gd _spawn_single_enemy():
#   var enemy = enemy_scene.instantiate()
#   enemy.global_position = spawn_pos
#   enemy.add_to_group("enemies")
#   enemy.died.connect(_on_enemy_died)    ← THIS is how doors unlock
#   enemies_container.add_child(enemy)
#
# When all enemies die → _on_enemy_died fires → enemies_alive hits 0
# → _on_room_cleared() → unlock_doors() → room_cleared signal
# → RoomManager hears it → minimap updates
