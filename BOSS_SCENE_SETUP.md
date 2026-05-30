# ============================================================
# BOSS SCENE SETUP GUIDE
# ============================================================
# Follow these steps in the Godot editor to build the
# Jormungandr boss scene and connect everything.
# ============================================================


## ── 1. JORMUNGANDR.tscn ────────────────────────────────────

Create at: res://scenes/boss/Jormungandr.tscn

NODE TREE:
  Jormungandr          [CharacterBody2D]   ← attach Jormungandr.gd
  ├── Head             [Node2D]            ← drawn in _draw() or Sprite2D
  ├── Hitbox           [Area2D]            ← bullets hit the HEAD only
  │   └── CollisionShape2D                   CircleShape2D radius 18
  ├── DetectionZone    [Area2D]            ← finds player in boss room
  │   └── CollisionShape2D                   RectangleShape2D 600×480 (full room)
  └── BodySegments     [Node2D]            ← container for 12 segments
      ├── Segment0     [Node2D]            ← attach BossSegment.gd, set segment_index=0
      ├── Segment1     [Node2D]            ← segment_index=1
      ├── ...
      └── Segment11    [Node2D]            ← segment_index=11

COLLISION LAYERS:
  Jormungandr root:  Layer 2  (enemies)
  Hitbox:            Layer 3  (enemy_hurtboxes)   Mask: 5 (player_bullets)
  DetectionZone:     Layer 4  (detection_zones)   Mask: 1 (player)

HOW TO ADD 12 SEGMENTS FAST:
  1. Select BodySegments node
  2. Ctrl+D on Segment0 eleven times to duplicate
  3. Rename each Segment1–Segment11
  4. Attach BossSegment.gd to each
  5. In the Inspector for each, set segment_index to 0–11

HEAD NODE — if no sprite art yet:
  Add a ColorRect child to Head:
    size: (36, 28), position: (-18, -14)
    color: Color(0.25, 0.6, 0.2)
  The head naturally rotates via head_sprite.rotation = velocity.angle()
  so the ColorRect will spin with it — acceptable for prototyping.


## ── 2. BOSSROOM.tscn ───────────────────────────────────────

Create at: res://scenes/boss/BossRoom.tscn

NODE TREE:
  BossRoom   [Node2D]   ← attach BossRoom.gd
  (No children needed — everything spawned at runtime)

HOW ROOM.GD USES IT:
  In Room.gd _setup_room_type_content(), under RoomType.BOSS:

    if ResourceLoader.exists("res://scenes/boss/BossRoom.tscn"):
        var boss_room = load("res://scenes/boss/BossRoom.tscn").instantiate()
        add_child(boss_room)
        boss_room.setup(floor_number)
    else:
        print("BossRoom.tscn not yet created")

  Also connect its signal in Room.gd:
    boss_room.boss_arena_cleared.connect(_on_room_cleared.bind(room_data))


## ── 3. BOSSHPBAR.tscn ──────────────────────────────────────

Create at: res://scenes/boss/BossHPBar.tscn

NODE TREE:
  BossHPBar  [CanvasLayer]   ← attach BossHPBar.gd
  (All rendering done in _draw() — no child nodes needed)

  Set CanvasLayer.layer = 10 so it draws ABOVE game world
  but BELOW any pause menus (which should be layer 20+)

WIRING:
  BossRoom.gd calls: hp_bar.connect_to_boss(boss_node)
  after spawning Jormungandr. That's all it needs.


## ── 4. EXIT.tscn (the staircase down) ──────────────────────

Create at: res://scenes/Exit.tscn

NODE TREE:
  Exit     [Area2D]
  ├── CollisionShape2D   CircleShape2D radius 20
  └── Sprite2D           your staircase/portal art (or ColorRect)

Script (inline, very short):

  extends Area2D

  func _ready():
      body_entered.connect(_on_body_entered)

  func _on_body_entered(body):
      if body.is_in_group("player"):
          # Tell RoomManager to descend to next floor
          var rm = get_tree().get_first_node_in_group("room_manager")
          if rm and rm.has_method("descend_floor"):
              rm.descend_floor()

  Collision: Layer 8 (pickups/interactables), Mask: 1 (player)


## ── 5. CAMERA2D SETUP ───────────────────────────────────────

For the boss camera zoom and shake to work, your Camera2D
must be in the "camera" group.

  1. Select your Camera2D node in the scene tree
  2. Node tab → Groups → Add "camera"

Also add this method to RoomManager.gd if not present:

  func descend_floor():
      emit_signal("floor_completed")


## ── 6. WIRING ROOM.GD FOR THE BOSS ROOM ────────────────────

In Room.gd, update _setup_room_type_content() for BOSS type:

  RoomType.BOSS:
      if ResourceLoader.exists("res://scenes/boss/BossRoom.tscn"):
          var boss_ctrl = load("res://scenes/boss/BossRoom.tscn").instantiate()
          add_child(boss_ctrl)
          boss_ctrl.setup(floor_number)
          # BossRoom will call lock_doors/unlock_doors on get_parent() (this Room)
      else:
          print("BossRoom scene not found — create it first")


## ── 7. JORMUNGANDR ATTACK SUMMARY ──────────────────────────

PHASE 1 (100%–66% HP):
  - Coil Chase    → head pursues player at 70 px/s
  - Spit          → 3-shot poison spread toward player (CD: 3.5s)
  - Tail Sweep    → body naturally arcs, tail tip flashes red (CD: 5s)

PHASE 2 (66%–33% HP):
  Everything above, plus:
  - Ring Burst    → 12 radial bullets (CD: 4s)
  - Burrow        → sinks underground, reappears under player with 8-shot burst (CD: 7s)
  - Body Slam     → diagonal lunge at 340 px/s (CD: 6s)
  Speed increases to 90 px/s

PHASE 3 (33%–0% HP):
  Everything above, plus:
  - Venom Ring    → 3 rotating bullet clusters orbit head for 4s (CD: 5.5s)
  - Coil Crush    → body contracts inward, shrinking safe zone (CD: 8s)
  Speed increases to 130 px/s

DEATH:
  → Segment explosion cascade (0.12s per segment)
  → Guaranteed rare/legendary item drop
  → Odin unlocked via GameData.unlock_hero("Odin")
  → Exit portal spawns
  → Boss HP bar fades out


## ── 8. COLLISION LAYER REMINDER ────────────────────────────

Project Settings → Physics → 2D, rename:
  Layer 1  = player
  Layer 2  = enemies
  Layer 3  = enemy_hurtboxes
  Layer 4  = detection_zones
  Layer 5  = player_bullets
  Layer 6  = enemy_bullets
  Layer 7  = walls
  Layer 8  = pickups

Jormungandr's BODY SEGMENTS have NO collision or hurtbox.
Only the HEAD (Hitbox Area2D) can be hit by player bullets.
This means the player must aim for the head while dodging the body.
