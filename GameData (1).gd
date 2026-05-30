extends Node

# ============================================================
# GameData.gd  —  The Global "Brain" of the Game
# ============================================================
# Autoload: registered as "GameData" in Project Settings.
# Accessible from any script via GameData.whatever
# ============================================================

# The hero the player chose on the character select screen
var chosen_hero: Dictionary = {}

# Everything that happens during a single run lives here.
# reset_run() wipes this at the start of each new attempt.
var current_run: Dictionary = {
	"floor":           1,
	"gold":            0,
	"gold_spent":      0,       # Tracks shop purchases
	"items_collected": [],      # Array of rune IDs picked up
	"bosses_killed":   [],      # Array of boss name strings
	"enemies_killed":  0,
	"rooms_cleared":   0,
	"deaths":          0,       # Lifetime death counter (persists)
	"curses":          [],      # Curse IDs accepted this run
	"shop_cursed":     false,
	"gold_curse":      false,
	"damage_taken":    0,       # Total damage received this run
	"damage_dealt":    0,       # Total damage dealt this run
	"run_start_time":  0,       # OS.get_unix_time_from_system() at run start
	"run_end_time":    0,
	"cause_of_death":  "",      # e.g. "Draugr", "Jormungandr", "Pit"
	"reached_victory": false,
}

# Unlocked heroes — persists between sessions via save file
var unlocked_heroes: Array = ["Thor", "Freyja"]

# Best run stats — persisted to save file for the high-score display
var best_runs: Array = []   # Array of run_summary Dicts, sorted by score
const MAX_BEST_RUNS: int = 5

# Current run score (calculated at end)
var last_run_score: int    = 0
var last_run_summary: Dictionary = {}


# ════════════════════════════════════════════════════════════
# RUN LIFECYCLE
# ════════════════════════════════════════════════════════════

func start_run():
	reset_run()
	current_run["run_start_time"] = int(Time.get_unix_time_from_system())
	print("[GameData] New run started.")

func end_run(victory: bool, cause: String = ""):
	current_run["run_end_time"]    = int(Time.get_unix_time_from_system())
	current_run["reached_victory"] = victory
	current_run["cause_of_death"]  = cause
	
	# Calculate score and build summary
	last_run_score   = calculate_score()
	last_run_summary = build_run_summary()
	
	# Add to best runs
	best_runs.append(last_run_summary)
	best_runs.sort_custom(func(a, b): return a["score"] > b["score"])
	if best_runs.size() > MAX_BEST_RUNS:
		best_runs.resize(MAX_BEST_RUNS)
	
	save_progress()
	print("[GameData] Run ended. Score: ", last_run_score,
		"  Victory: ", victory)

func reset_run():
	var deaths = current_run.get("deaths", 0)
	current_run = {
		"floor":           1,
		"gold":            0,
		"gold_spent":      0,
		"items_collected": [],
		"bosses_killed":   [],
		"enemies_killed":  0,
		"rooms_cleared":   0,
		"deaths":          deaths,   # Lifetime deaths carry over
		"curses":          [],
		"shop_cursed":     false,
		"gold_curse":      false,
		"damage_taken":    0,
		"damage_dealt":    0,
		"run_start_time":  int(Time.get_unix_time_from_system()),
		"run_end_time":    0,
		"cause_of_death":  "",
		"reached_victory": false,
	}


# ════════════════════════════════════════════════════════════
# SCORE CALCULATION
# Higher floor, more kills, fewer curses = better score
# ════════════════════════════════════════════════════════════

func calculate_score() -> int:
	var score = 0
	
	# Floor progress (big bonus)
	score += current_run["floor"] * 500
	
	# Enemies killed (small per-kill bonus)
	score += current_run["enemies_killed"] * 10
	
	# Rooms cleared
	score += current_run["rooms_cleared"] * 25
	
	# Bosses (large bonus)
	score += current_run.get("bosses_killed", []).size() * 800
	
	# Items collected (moderate bonus)
	score += current_run.get("items_collected", []).size() * 75
	
	# Gold remaining at end (small bonus for thrift)
	score += current_run.get("gold", 0) * 2
	
	# Curses accepted = penalty (brave but costly)
	score -= current_run.get("curses", []).size() * 100
	
	# Damage taken penalty (skill bonus)
	score -= int(current_run.get("damage_taken", 0) * 1.5)
	
	# Victory bonus
	if current_run.get("reached_victory", false):
		score += 2000
	
	return max(0, score)


func calculate_grade() -> String:
	var s = calculate_score()
	if current_run.get("reached_victory", false):
		if s >= 6000:  return "S"
		if s >= 4500:  return "A"
		return "B"
	else:
		if s >= 3000:  return "B"
		if s >= 1500:  return "C"
		if s >= 500:   return "D"
		return "F"


func get_run_duration_seconds() -> int:
	var start = current_run.get("run_start_time", 0)
	var end   = current_run.get("run_end_time", int(Time.get_unix_time_from_system()))
	return max(0, end - start)


func format_duration(seconds: int) -> String:
	var m = seconds / 60
	var s = seconds % 60
	return "%d:%02d" % [m, s]


func build_run_summary() -> Dictionary:
	return {
		"score":          calculate_score(),
		"grade":          calculate_grade(),
		"hero_name":      chosen_hero.get("name", "Unknown"),
		"floor":          current_run["floor"],
		"enemies_killed": current_run["enemies_killed"],
		"rooms_cleared":  current_run["rooms_cleared"],
		"bosses_killed":  current_run["bosses_killed"].size(),
		"items":          current_run["items_collected"].size(),
		"curses":         current_run["curses"].size(),
		"damage_taken":   current_run["damage_taken"],
		"gold_spent":     current_run["gold_spent"],
		"duration":       format_duration(get_run_duration_seconds()),
		"victory":        current_run["reached_victory"],
		"cause_of_death": current_run["cause_of_death"],
	}


# ════════════════════════════════════════════════════════════
# HERO UNLOCKS
# ════════════════════════════════════════════════════════════

func unlock_hero(hero_name: String):
	if hero_name not in unlocked_heroes:
		unlocked_heroes.append(hero_name)
		save_progress()
		print("[GameData] Unlocked: ", hero_name)


# ════════════════════════════════════════════════════════════
# SAVE / LOAD
# ════════════════════════════════════════════════════════════

func save_progress():
	var config = ConfigFile.new()
	config.set_value("unlocks",  "heroes",    unlocked_heroes)
	config.set_value("records",  "best_runs", best_runs)
	config.set_value("lifetime", "deaths",    current_run.get("deaths", 0))
	var err = config.save("user://save.cfg")
	if err != OK:
		push_warning("[GameData] Could not save progress!")

func load_progress():
	var config = ConfigFile.new()
	var err    = config.load("user://save.cfg")
	if err == OK:
		unlocked_heroes = config.get_value("unlocks", "heroes", ["Thor", "Freyja"])
		best_runs       = config.get_value("records", "best_runs", [])
		current_run["deaths"] = config.get_value("lifetime", "deaths", 0)
		print("[GameData] Loaded. Heroes: ", unlocked_heroes.size(),
			"  Best runs: ", best_runs.size())
	else:
		print("[GameData] No save file — using defaults.")


# ════════════════════════════════════════════════════════════
# STAT TRACKERS  (called from other scripts during play)
# ════════════════════════════════════════════════════════════

func track_kill():
	current_run["enemies_killed"] += 1

func track_room_clear():
	current_run["rooms_cleared"] += 1

func track_damage_taken(amount: int):
	current_run["damage_taken"] += amount

func track_damage_dealt(amount: int):
	current_run["damage_dealt"] += amount

func track_gold_spent(amount: int):
	current_run["gold_spent"] += amount
