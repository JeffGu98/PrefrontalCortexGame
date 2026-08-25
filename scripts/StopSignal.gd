extends "res://scripts/GameBase.gd"
## 红灯停 Stop-signal：车在开，到线前要冲；中途亮红灯就必须急刹。


const LIVES := 3
const READY_TIME := 1.0
const GAP_MIN := 0.55
const GAP_MAX := 0.9
const FEEDBACK_TIME := 0.45
const TRAVEL_MIN := 1.2
const TRAVEL_MAX := 2.0
const STOP_RATIO := 0.5
const STOP_AT_MIN := 0.4
const STOP_AT_MAX := 0.7
const STOP_HOLD := 0.5
const GO_WINDOW := 0.72
const MAX_GO_STREAK := 2
const SCORE_GO := 10
const SCORE_STOP := 20
const BEST_PATH := "user://stopsignal_best.cfg"
const CAR_SIZE := Vector2(110, 52)

enum Phase { READY, GAP, DRIVE, FEEDBACK, OVER }

var phase := Phase.READY
var phase_left := 0.0
var score := 0
var lives := LIVES
var streak := 0
var best_score := 0
var consecutive_go := 0
var last_was_stop := false

var is_stop := false
var stop_at := 0.55
var travel_time := 1.5
var drive_elapsed := 0.0
var red_on := false
var red_elapsed := 0.0
var progress := 0.0

var score_label: Label
var lives_label: Label
var hint_label: Label
var rule_label: Label
var track: TrackView
var car: CarView
var light: ColorRect
var tap_btn: Button
var restart_button: Button


func _init() -> void:
	title_text = "红灯停"
	help_text = "小车从左开向右边的终点线。等到车靠近终点的绿线再冲，一开始点没有用。\n大多数时候要冲过去。若中途突然亮红灯，必须立刻停手。\n冲过终点得 10 分；红灯亮后忍住得 20 分。红灯时还冲、或绿灯没冲，都扣命。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_rule()
	_build_track()
	_build_tap()
	_layout_board()
	_start_round()


func _build_hud() -> void:
	score_label = _make_label("", 24, Color("#e8edff"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 72
	score_label.offset_bottom = 100
	add_child(score_label)

	lives_label = _make_label("", 20, Color("#ff8f9d"))
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lives_label.offset_top = 102
	lives_label.offset_bottom = 128
	add_child(lives_label)

	hint_label = _make_label("", 20, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(hint_label)


func _build_rule() -> void:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a2740")
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 148
	panel.offset_bottom = 216
	add_child(panel)
	rule_label = _make_label("到线前冲　·　红灯停", 22, Color("#e8edff"))
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rule_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(rule_label)


func _build_track() -> void:
	track = TrackView.new()
	track.gui_input.connect(_on_track_gui_input)
	add_child(track)

	light = ColorRect.new()
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.color = Color("#2a3348")
	track.add_child(light)

	car = CarView.new()
	car.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car.custom_minimum_size = CAR_SIZE
	car.size = CAR_SIZE
	track.add_child(car)


func _build_tap() -> void:
	tap_btn = Button.new()
	tap_btn.text = "冲"
	tap_btn.focus_mode = Control.FOCUS_NONE
	tap_btn.add_theme_font_size_override("font_size", 40)
	tap_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(tap_btn, Color("#1a2740"))
	tap_btn.pressed.connect(_on_tap)
	add_child(tap_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and tap_btn != null:
		_layout_board()
		_place_car()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var tap_w := minf(520.0, vp.x - 80.0)
	var tap_h := 150.0
	tap_btn.position = Vector2((vp.x - tap_w) / 2.0, vp.y - 48.0 - tap_h)
	tap_btn.size = Vector2(tap_w, tap_h)
	tap_btn.custom_minimum_size = Vector2(tap_w, tap_h)
	tap_btn.pivot_offset = Vector2(tap_w, tap_h) * 0.5

	var track_y := 236.0
	var track_h := clampf(tap_btn.position.y - track_y - 88.0, 160.0, 280.0)
	track.position = Vector2(40, track_y)
	track.size = Vector2(vp.x - 80.0, track_h)
	track.queue_redraw()

	var lamp := 28.0
	light.size = Vector2(lamp, lamp)
	light.position = Vector2(track.size.x - 22.0 - lamp, 16.0)

	var hint_y := track.position.y + track_h + 16.0
	hint_label.offset_top = hint_y
	hint_label.offset_bottom = hint_y + 40.0
	_place_car()


func _start_round() -> void:
	score = 0
	lives = LIVES
	streak = 0
	consecutive_go = 0
	last_was_stop = false
	phase = Phase.READY
	phase_left = READY_TIME
	red_on = false
	progress = 0.0
	car.fill = Color("#8ab4ff")
	car.queue_redraw()
	_set_light(false)
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	var ready := "到线前冲 · 红灯停"
	if best_score > 0:
		ready += " · 最佳 %d" % best_score
	_set_hint(ready, Color("#7f8ba6"))
	_place_car()
	_update_hud()


func _begin_gap() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.GAP
	phase_left = randf_range(GAP_MIN, GAP_MAX)
	red_on = false
	progress = 0.0
	car.fill = Color("#8ab4ff")
	car.queue_redraw()
	car.position.x = 16.0
	_set_light(false)
	tap_btn.scale = Vector2.ONE
	_update_hud()


func _begin_drive() -> void:
	if phase == Phase.OVER:
		return
	_pick_trial()
	travel_time = randf_range(TRAVEL_MIN, TRAVEL_MAX)
	stop_at = randf_range(STOP_AT_MIN, STOP_AT_MAX)
	drive_elapsed = 0.0
	red_elapsed = 0.0
	red_on = false
	progress = 0.0
	car.fill = Color("#8ab4ff")
	car.queue_redraw()
	_set_light(false)
	phase = Phase.DRIVE
	_set_hint("等到绿线再冲", Color("#7f8ba6"))
	_place_car()
	_update_hud()


func _pick_trial() -> void:
	if consecutive_go >= MAX_GO_STREAK:
		is_stop = true
		consecutive_go = 0
	elif last_was_stop:
		is_stop = false
		consecutive_go += 1
	else:
		is_stop = randf() < STOP_RATIO
		consecutive_go = 0 if is_stop else consecutive_go + 1
	last_was_stop = is_stop


func _place_car() -> void:
	if track == null or car == null:
		return
	var y := (track.size.y - CAR_SIZE.y) / 2.0 + 6.0
	var x_max := track.size.x - 16.0 - CAR_SIZE.x
	car.position = Vector2(lerpf(16.0, maxf(x_max, 16.0), clampf(progress, 0.0, 1.0)), y)
	car.size = CAR_SIZE


func _set_light(on: bool) -> void:
	if light == null:
		return
	light.color = Color("#ff5d73") if on else Color("#2a3348")


func _trigger_red() -> void:
	red_on = true
	red_elapsed = 0.0
	_set_light(true)
	_set_hint("红灯！", Color("#ff5d73"))
	light.modulate = Color(1.4, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(light, "modulate", Color.WHITE, 0.2)


func _on_track_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_on_tap()


func _on_tap() -> void:
	if phase != Phase.DRIVE:
		return
	if red_on:
		_miss("没刹住")
		return
	if progress < GO_WINDOW:
		_set_hint("还没到，再等等", Color("#ffd75d"))
		return
	_succeed(SCORE_GO, "冲过")


func _succeed(points: int, reason: String) -> void:
	if phase != Phase.DRIVE:
		return
	streak += 1
	score += points
	phase = Phase.FEEDBACK
	phase_left = FEEDBACK_TIME
	if red_on:
		progress = clampf(progress, 0.0, 0.92)
		car.fill = Color("#ffd75d")
	else:
		progress = 1.0
		car.fill = Color("#4ade80")
	car.queue_redraw()
	_place_car()
	_set_hint("%s  +%d" % [reason, points], Color("#4ade80"))
	_burst_feedback("%s  +%d" % [reason, points], Color("#4ade80"))
	_update_hud()


func _miss(reason: String) -> void:
	if phase != Phase.DRIVE:
		return
	streak = 0
	lives -= 1
	phase = Phase.FEEDBACK
	phase_left = FEEDBACK_TIME
	car.fill = Color("#ff5d73")
	car.queue_redraw()
	var origin_x := car.position.x
	var tw := create_tween()
	tw.tween_property(car, "position:x", origin_x + 10.0, 0.05)
	tw.tween_property(car, "position:x", origin_x - 10.0, 0.05)
	tw.tween_property(car, "position:x", origin_x, 0.05)
	_set_hint(reason, Color("#ff5d73"))
	_burst_feedback(reason, Color("#ff5d73"))
	_update_hud()
	if lives <= 0:
		_end_game()


func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	if phase == Phase.DRIVE:
		drive_elapsed += delta
		progress = clampf(drive_elapsed / travel_time, 0.0, 1.0)
		if is_stop and not red_on and progress >= stop_at:
			_trigger_red()
		if red_on:
			red_elapsed += delta
			if red_elapsed >= STOP_HOLD:
				_succeed(SCORE_STOP, "刹住了")
				return
		_place_car()
		var in_window := progress >= GO_WINDOW and not red_on
		if in_window and hint_label.text != "冲！":
			_set_hint("冲！", Color("#4ade80"))
		var itch := 1.0 + 0.04 * progress + 0.04 * sin(drive_elapsed * 10.0)
		if in_window:
			itch += 0.08
		tap_btn.scale = Vector2(itch, itch)
		if progress >= 1.0:
			if red_on:
				_succeed(SCORE_STOP, "刹住了")
			else:
				_miss("没冲出去")
		_update_hud()
		return
	phase_left -= delta
	tap_btn.scale = Vector2.ONE
	if phase_left > 0.0:
		_update_hud()
		return
	if phase == Phase.READY or phase == Phase.GAP:
		_begin_drive()
	elif phase == Phase.FEEDBACK:
		_begin_gap()


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.DRIVE:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_on_tap()


func _update_hud() -> void:
	score_label.text = "得分 %d　连击 %d" % [score, streak]
	lives_label.text = "生命 %d/%d" % [lives, LIVES]
	if tap_btn != null:
		tap_btn.modulate = Color.WHITE if phase == Phase.DRIVE else Color(1, 1, 1, 0.45)


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	phase = Phase.OVER
	tap_btn.scale = Vector2.ONE
	tap_btn.modulate = Color(1, 1, 1, 0.45)
	var is_best := score > best_score
	if is_best:
		best_score = score
		_save_best()
	var suffix := " · 新纪录！" if is_best else ""
	if best_score > 0 and not is_best:
		suffix = " · 最佳 %d" % best_score
	_set_hint("结束 · 得分 %d%s" % [score, suffix], Color("#ffd75d"))
	_update_hud()
	if restart_button == null:
		restart_button = _make_restart_button(_restart, tap_btn.position.y - 84.0)


func _restart() -> void:
	_start_round()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.save(BEST_PATH)


class TrackView extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#12192a"), true)
		var y := size.y * 0.5
		var x := 20.0
		while x < size.x - 36.0:
			draw_rect(Rect2(x, y - 2.0, 22.0, 4.0), Color("#2a3a58"), true)
			x += 38.0
		var go_x := size.x * 0.72
		draw_rect(Rect2(go_x - 3.0, 10.0, 5.0, size.y - 20.0), Color("#4ade80"), true)
		draw_rect(Rect2(size.x - 16.0, 10.0, 6.0, size.y - 20.0), Color("#ffd75d"), true)


class CarView extends Control:
	var fill := Color("#8ab4ff")

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body := PackedVector2Array([
			Vector2(w * 0.06, h * 0.46),
			Vector2(w * 0.22, h * 0.16),
			Vector2(w * 0.58, h * 0.16),
			Vector2(w * 0.76, h * 0.46),
			Vector2(w * 0.94, h * 0.46),
			Vector2(w * 0.94, h * 0.70),
			Vector2(w * 0.06, h * 0.70),
		])
		draw_colored_polygon(body, fill)
		var cabin := PackedVector2Array([
			Vector2(w * 0.28, h * 0.22),
			Vector2(w * 0.54, h * 0.22),
			Vector2(w * 0.66, h * 0.46),
			Vector2(w * 0.30, h * 0.46),
		])
		draw_colored_polygon(cabin, Color("#0d1220").lightened(0.12))
		draw_circle(Vector2(w * 0.28, h * 0.74), h * 0.16, Color("#0d1220"))
		draw_circle(Vector2(w * 0.72, h * 0.74), h * 0.16, Color("#0d1220"))
		draw_circle(Vector2(w * 0.28, h * 0.74), h * 0.07, Color("#7f8ba6"))
		draw_circle(Vector2(w * 0.72, h * 0.74), h * 0.07, Color("#7f8ba6"))
