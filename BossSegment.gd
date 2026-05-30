extends Node2D

# ============================================================
# BossSegment.gd
# ============================================================
# Attached to each of the 12 body segment nodes inside
# Jormungandr's BodySegments container.
#
# Each segment:
#   - Draws itself (coloured oval, scales slightly smaller
#     toward the tail so the body tapers)
#   - Has its own hurtbox so the player CAN'T damage the body
#     (only the head takes damage — classic snake boss rule)
#   - Can deal contact damage to the player
#   - Pulses colour on phase changes
#
# Jormungandr.gd positions each segment via position_history.
# This script only handles visuals and contact damage.
# ============================================================

var segment_index: int    = 0     # 0 = closest to head, 11 = tail tip
var phase:         int    = 1
var _pulse_time:   float  = 0.0

# Scale tapers from 1.0 at head-adjacent to 0.55 at tail tip
func get_scale_for_index(idx: int, total: int) -> float:
	return lerp(1.0, 0.55, float(idx) / float(total - 1))

# Phase colours — body shifts each phase
const SEGMENT_COLORS = {
	1: Color(0.25, 0.55, 0.18),   # Phase 1: deep green
	2: Color(0.50, 0.40, 0.10),   # Phase 2: sickly gold
	3: Color(0.65, 0.12, 0.08),   # Phase 3: blood red
}


func _process(delta: float):
	_pulse_time += delta
	queue_redraw()


func _draw():
	var idx_scale = get_scale_for_index(segment_index, 12)
	var base_w    = 20.0 * idx_scale
	var base_h    = 16.0 * idx_scale
	
	# Pulse: segments near the tail pulse slower
	var pulse_speed  = 1.8 - segment_index * 0.08
	var pulse_amount = sin(_pulse_time * pulse_speed) * 0.06
	
	var draw_w = base_w * (1.0 + pulse_amount)
	var draw_h = base_h * (1.0 + pulse_amount)
	
	var base_color = SEGMENT_COLORS.get(phase, Color(0.3, 0.6, 0.2))
	
	# Alternate slight tint on even/odd segments for a scale pattern
	var color = base_color if segment_index % 2 == 0 else base_color.darkened(0.15)
	
	# Draw body oval
	draw_circle(Vector2.ZERO, draw_w * 0.5, color)
	
	# Draw scale line detail across the segment
	var line_color = color.lightened(0.2)
	draw_line(Vector2(-draw_w * 0.3, 0), Vector2(draw_w * 0.3, 0), line_color, 1.0)
	
	# Tail segments get a pointed tip marker
	if segment_index >= 10:
		var tip_color = base_color.darkened(0.3)
		draw_circle(Vector2(draw_w * 0.4, 0), draw_w * 0.15, tip_color)


func set_phase(new_phase: int):
	phase = new_phase
	queue_redraw()
