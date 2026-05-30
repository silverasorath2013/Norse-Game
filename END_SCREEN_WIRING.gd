extends Node

# ============================================================
# END_SCREEN_WIRING.gd  —  READ THIS, DON'T ATTACH IT
# ============================================================
# This file shows every line you need to add to existing
# scripts to connect the death/victory screens properly.
# Copy only the sections relevant to each file.
# ============================================================


# ════════════════════════════════════════════════════════════
# 1.  Hero.gd  —  4 additions
# ════════════════════════════════════════════════════════════

# In _ready(), after add_to_group("player"):
#   GameData.start_run()   # ← starts the run timer

# In take_damage(), after subtracting current_health:
#   GameData.track_damage_taken(amount)

# In _fire_projectile(), after bullet.damage is set — OR better,
# add to Bullet.gd _on_body_entered when an enemy is hit:
#   GameData.track_damage_dealt(bullet.damage)

# In _die(), BEFORE change_scene_to_file:
#
#   # Find out what killed us (the last thing that damaged us)
#   # Store the killer name in a var whenever take_damage fires:
#   var last_attacker: String = "Unknown"   # add at top of Hero.gd
#
#   # In take_damage(amount), add:
#   #   last_attacker = "Unknown"   # set from enemy if possible
#
#   # In _die():
#   GameData.end_run(false, last_attacker)
#   get_tree().change_scene_to_file("res://scenes/DeathScreen.tscn")


# ════════════════════════════════════════════════════════════
# 2.  EnemyBase.gd  —  1 addition
# ════════════════════════════════════════════════════════════

# In _die(), BEFORE queue_free():
#   if has_node("/root/GameData"):
#       GameData.track_kill()


# ════════════════════════════════════════════════════════════
# 3.  Room.gd  —  2 additions
# ════════════════════════════════════════════════════════════

# In _on_room_cleared():
#   if has_node("/root/GameData"):
#       GameData.track_room_clear()

# In _setup_room_type_content() SHOP case, when gold is spent
# (inside ShopKeeper.try_purchase, add):
#   GameData.track_gold_spent(price)
#
# OR add to ShopKeeper.try_purchase() after deducting gold:
#   if has_node("/root/GameData"):
#       GameData.track_gold_spent(price)


# ════════════════════════════════════════════════════════════
# 4.  RoomManager.gd  —  1 addition (victory trigger)
# ════════════════════════════════════════════════════════════

# The RoomManager already has floor_completed signal.
# In _on_floor_completed(), after the final floor is beaten,
# instead of _start_floor(current_floor + 1), trigger victory:
#
#   func _on_floor_completed():
#       if current_floor >= MAX_FLOORS:   # define const MAX_FLOORS = 5
#           _trigger_victory()
#       else:
#           await get_tree().create_timer(2.0).timeout
#           _start_floor(current_floor + 1)
#
#   func _trigger_victory():
#       if has_node("/root/GameData"):
#           GameData.end_run(true, "")
#       get_tree().change_scene_to_file("res://scenes/VictoryScreen.tscn")


# ════════════════════════════════════════════════════════════
# 5.  Bullet.gd  —  1 addition (damage dealt tracking)
# ════════════════════════════════════════════════════════════

# In _on_body_entered() and _on_area_entered(), after take_damage():
#   if has_node("/root/GameData"):
#       GameData.track_damage_dealt(damage)


# ════════════════════════════════════════════════════════════
# 6.  ShopKeeper.gd  —  1 addition (gold spent tracking)
# ════════════════════════════════════════════════════════════

# In try_purchase(), after GameData.current_run["gold"] -= price:
#   GameData.track_gold_spent(price)


# ════════════════════════════════════════════════════════════
# 7.  SCENE FILES TO CREATE
# ════════════════════════════════════════════════════════════

# res://scenes/DeathScreen.tscn
#   Root: Node2D  → attach DeathScreen.gd
#   No children needed (all drawn in _draw())
#
# res://scenes/VictoryScreen.tscn
#   Root: Node2D  → attach VictoryScreen.gd
#   No children needed

# Both scenes should NOT have a Camera2D child —
# they render in screen space via _draw() which is always
# relative to the viewport, not the game world.


# ════════════════════════════════════════════════════════════
# 8.  "CAUSE OF DEATH" TRACKING  (optional polish)
# ════════════════════════════════════════════════════════════

# For the best cause-of-death display, track who last hit the player.
# Add to Hero.gd:
#
#   var last_hit_source: String = "the darkness"
#
# In EnemyBase._deal_contact():
#   # Before calling player.take_damage():
#   player.last_hit_source = enemy_name
#
# In EnemyBullet._on_body_entered():
#   # When hitting the player:
#   if body.has_method("set"):
#       body.set("last_hit_source", "enemy projectile")
#
# In Hero._die():
#   GameData.end_run(false, last_hit_source)


# ════════════════════════════════════════════════════════════
# 9.  GRADING REFERENCE
# ════════════════════════════════════════════════════════════

# Score formula (from GameData.calculate_score()):
#   +500  per floor reached
#   +10   per enemy killed
#   +25   per room cleared
#   +800  per boss defeated
#   +75   per item collected
#   +2    per gold remaining
#   -100  per curse accepted
#   -1.5x damage taken
#   +2000 for victory
#
# Grade thresholds:
#   Victory:  S=6000+  A=4500+  B=anything
#   Defeat:   B=3000+  C=1500+  D=500+  F=below 500
