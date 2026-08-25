extends "res://scripts/GameBase.gd"
## 看点数：短时闪现随机圆点，消失后输入看到的数量。


const ROUND_TIME := 60.0
const READY_TIME := 1.0
const FLASH_TIME_START := 0.6
const FLASH_TIME_MIN := 0.35
const FLASH_STEP := 0.02
const COUNT_MIN := 4
const COUNT_MAX_START := 12
const SCORE_EXACT := 10
const SCORE_CLOSE := 5
const FEEDBACK_TIME := 1.8
const CLEAR_TIME := 0.5
const BEST_PATH := "user://dots_best.cfg"
const MAX_DIGITS := 3
const KEYPAD_COLS := 3
const KEYPAD_ROWS := 4
const KEY_GAP := 12.0
const PANEL_CORNER := 14.0
const DOT_STROKE := 2.0

enum Phase { READY, FLASH, INPUT, FEEDBACK, CLEAR, OVER }

var phase := Phase.READY
var score := 0
var streak := 0
var best_score := 0
var time_left := ROUND_TIME
var ready_left := 0.0
var flash_time := FLASH_TIME_START
var flash_left := 0.0
var feedback_left := 0.0
var clear_left := 0.0
var count_max := COUNT_MAX_START
var true_count := 0
var typed := ""

var score_label: Label
var time_label: Label
var status_label: Label
var input_label: Label
var panel: Panel
var flash_bar: ColorRect
var canvas: DotCanvas
var keypad: Control
var key_buttons: Array[Button] = []
var restart_button: Button


func _init() -> void:
	title_text = "看点数"
	help_text = "圆点会短暂闪过，消失后用底部键盘输入你看到的数量。\n完全正确得分最高；只差 1 个也有一半分。一局 60 秒。\n进场先有一秒准备。闪现时键盘会变淡，消失后再输入。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_panel()
	_build_input_row()
	_build_keypad()
	_layout_board()
	_start_round()


func _build_hud() -> void:
	score_label = _make_label("", 24, Color("#e8edff"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 72
	score_label.offset_bottom = 102
	add_child(score_label)

	time_label = _make_label("", 20, Color("#8ab4ff"))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	time_label.offset_top = 102
	time_label.offset_bottom = 130
	add_child(time_label)

	status_label = _make_label("", 18, Color("#7f8ba6"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_top = 128
	status_label.offset_bottom = 156
	add_child(status_label)


func _build_panel() -> void:
	panel = Panel.new()
	panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a2740")
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	flash_bar = ColorRect.new()
	flash_bar.color = Color("#8ab4ff")
	flash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_bar.size = Vector2(0, 4)
	flash_bar.visible = false
	panel.add_child(flash_bar)

	canvas = DotCanvas.new()
	panel.add_child(canvas)


func _build_input_row() -> void:
	input_label = _make_label("—", 48, Color("#e8edff"))
	input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	input_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(input_label)


func _build_keypad() -> void:
	keypad = Control.new()
	add_child(keypad)
	var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "删除", "0", "确定"]
	for key in keys:
		var btn := Button.new()
		btn.text = key
		btn.add_theme_font_size_override("font_size", 26)
		if key == "确定":
			btn.add_theme_color_override("font_color", Color("#0d1220"))
			_style_button(btn, Color("#4ade80"))
		else:
			btn.add_theme_color_override("font_color", Color("#e8edff"))
			_style_button(btn, Color("#1a2740"))
		btn.pressed.connect(_on_key_pressed.bind(key))
		keypad.add_child(btn)
		key_buttons.append(btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and panel != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var side := 40.0
	var key_w := minf(180.0, (vp.x - side * 2.0 - KEY_GAP * (KEYPAD_COLS - 1)) / KEYPAD_COLS)
	var key_h := clampf(minf(88.0, (vp.y * 0.28 - KEY_GAP * (KEYPAD_ROWS - 1)) / KEYPAD_ROWS), 56.0, 88.0)
	var keypad_h := key_h * KEYPAD_ROWS + KEY_GAP * (KEYPAD_ROWS - 1)
	var keypad_w := key_w * KEYPAD_COLS + KEY_GAP * (KEYPAD_COLS - 1)
	var keypad_y := vp.y - 24.0 - keypad_h
	keypad.position = Vector2((vp.x - keypad_w) / 2.0, keypad_y)
	keypad.size = Vector2(keypad_w, keypad_h)
	for i in range(key_buttons.size()):
		var btn := key_buttons[i]
		btn.custom_minimum_size = Vector2(key_w, key_h)
		btn.position = Vector2((i % KEYPAD_COLS) * (key_w + KEY_GAP), int(i / KEYPAD_COLS) * (key_h + KEY_GAP))
		btn.size = Vector2(key_w, key_h)

	var input_h := 56.0
	var input_y := keypad_y - input_h - 8.0
	input_label.offset_top = input_y
	input_label.offset_bottom = input_y + input_h

	var panel_y := 164.0
	var panel_h := maxf(input_y - panel_y - 8.0, 200.0)
	panel.position = Vector2(side, panel_y)
	panel.size = Vector2(vp.x - side * 2.0, panel_h)
	flash_bar.position = Vector2.ZERO


func _start_round() -> void:
	score = 0
	streak = 0
	time_left = ROUND_TIME
	flash_time = FLASH_TIME_START
	count_max = COUNT_MAX_START
	typed = ""
	phase = Phase.READY
	ready_left = READY_TIME
	canvas.showing = false
	canvas.fill = Color("#8ab4ff")
	canvas.queue_redraw()
	flash_bar.visible = false
	_tint_panel(Color("#1a2740"))
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	var ready_text := "看准闪过的点数"
	if best_score > 0:
		ready_text += " · 最佳 %d" % best_score
	_set_status(ready_text, Color("#7f8ba6"))
	_update_hud()


func _new_trial() -> void:
	if phase == Phase.OVER:
		return
	typed = ""
	_tint_panel(Color("#1a2740"))
	true_count = randi_range(COUNT_MIN, count_max)
	canvas.radius = _radius_for(true_count, panel.size)
	canvas.fill = Color("#8ab4ff")
	canvas.points = _keep_inside(_scatter_points(true_count, panel.size, canvas.radius), panel.size, canvas.radius)
	true_count = canvas.points.size()
	canvas.showing = true
	canvas.queue_redraw()
	phase = Phase.FLASH
	flash_left = flash_time
	flash_bar.visible = true
	flash_bar.size = Vector2(panel.size.x, 4)
	_set_status("看清楚点数", Color("#7f8ba6"))
	_update_hud()


func _radius_for(count: int, area: Vector2) -> float:
	var usable := maxf((area.x - 48.0) * (area.y - 48.0), 1.0)
	var radius := sqrt(usable / float(maxi(count, 1))) / 6.5
	return clampf(radius, 9.0, 14.0)


func _inner_rect(area: Vector2, radius: float) -> Rect2:
	var inset := radius + PANEL_CORNER + DOT_STROKE + 4.0
	var size := area - Vector2(inset, inset) * 2.0
	if size.x < radius * 2.0 or size.y < radius * 2.0:
		inset = radius + DOT_STROKE + 4.0
		size = area - Vector2(inset, inset) * 2.0
	size.x = maxf(size.x, 2.0)
	size.y = maxf(size.y, 2.0)
	return Rect2(Vector2(inset, inset), size)


func _keep_inside(points: Array[Vector2], area: Vector2, radius: float) -> Array[Vector2]:
	var inner := _inner_rect(area, radius)
	var min_p := inner.position
	var max_p := inner.position + inner.size
	var out: Array[Vector2] = []
	for p in points:
		out.append(Vector2(clampf(p.x, min_p.x, max_p.x), clampf(p.y, min_p.y, max_p.y)))
	return out


func _scatter_points(count: int, area: Vector2, radius: float) -> Array[Vector2]:
	var usable := _inner_rect(area, radius)
	if usable.size.x <= radius or usable.size.y <= radius:
		return [area * 0.5]
	var ideal := sqrt((usable.size.x * usable.size.y) / float(maxi(count, 1)))
	var min_dist := maxf(radius * 3.8, ideal * 0.78)
	var floor_dist := radius * 3.2
	for _pass in range(10):
		var points := _bridson(count, usable, min_dist)
		if points.size() >= count:
			return points.slice(0, count)
		if min_dist <= floor_dist + 0.5:
			break
		min_dist = maxf(floor_dist, min_dist * 0.9)
	return _dart_fill(count, usable, floor_dist)


func _bridson(count: int, usable: Rect2, min_dist: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if min_dist <= 1.0:
		return points
	var cell := min_dist / sqrt(2.0)
	var gw := maxi(int(ceilf(usable.size.x / cell)), 1)
	var gh := maxi(int(ceilf(usable.size.y / cell)), 1)
	var grid := PackedInt32Array()
	grid.resize(gw * gh)
	for i in range(grid.size()):
		grid[i] = -1
	var first := Vector2(
		usable.position.x + randf() * usable.size.x,
		usable.position.y + randf() * usable.size.y
	)
	points.append(first)
	_grid_put(grid, gw, cell, usable, first, 0)
	var active: Array[int] = [0]
	while points.size() < count and not active.is_empty():
		var ai := randi() % active.size()
		var origin: Vector2 = points[active[ai]]
		var placed := false
		for _try in range(30):
			var ang := randf() * TAU
			var rad := min_dist * (1.0 + randf())
			var cand := origin + Vector2(cos(ang), sin(ang)) * rad
			if not _inside_usable(cand, usable):
				continue
			if not _is_open(points, grid, gw, gh, cell, usable, cand, min_dist):
				continue
			_grid_put(grid, gw, cell, usable, cand, points.size())
			active.append(points.size())
			points.append(cand)
			placed = true
			break
		if not placed:
			active.remove_at(ai)
	return points


func _grid_put(grid: PackedInt32Array, gw: int, cell: float, usable: Rect2, p: Vector2, idx: int) -> void:
	var gx := clampi(int((p.x - usable.position.x) / cell), 0, gw - 1)
	var gy := clampi(int((p.y - usable.position.y) / cell), 0, int(grid.size() / gw) - 1)
	grid[gy * gw + gx] = idx


func _is_open(
	points: Array[Vector2],
	grid: PackedInt32Array,
	gw: int,
	gh: int,
	cell: float,
	usable: Rect2,
	cand: Vector2,
	min_dist: float
) -> bool:
	var gx := clampi(int((cand.x - usable.position.x) / cell), 0, gw - 1)
	var gy := clampi(int((cand.y - usable.position.y) / cell), 0, gh - 1)
	for iy in range(maxi(gy - 2, 0), mini(gy + 3, gh)):
		for ix in range(maxi(gx - 2, 0), mini(gx + 3, gw)):
			var id := grid[iy * gw + ix]
			if id >= 0 and cand.distance_to(points[id]) < min_dist:
				return false
	return true


func _dart_fill(count: int, usable: Rect2, min_dist: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var attempts := 0
	while points.size() < count and attempts < count * 400:
		attempts += 1
		var p := Vector2(
			usable.position.x + randf() * usable.size.x,
			usable.position.y + randf() * usable.size.y
		)
		var ok := true
		for q in points:
			if p.distance_to(q) < min_dist:
				ok = false
				break
		if ok:
			points.append(p)
	var guard := 0
	while points.size() < count and guard < count * 80:
		guard += 1
		points.append(Vector2(
			usable.position.x + randf() * usable.size.x,
			usable.position.y + randf() * usable.size.y
		))
	return points


func _inside_usable(p: Vector2, usable: Rect2) -> bool:
	return p.x >= usable.position.x and p.y >= usable.position.y \
		and p.x <= usable.position.x + usable.size.x \
		and p.y <= usable.position.y + usable.size.y


func _on_key_pressed(key: String) -> void:
	if phase != Phase.INPUT:
		return
	if key == "删除":
		_delete_digit()
	elif key == "确定":
		_confirm()
	else:
		_append_digit(key)


func _append_digit(digit: String) -> void:
	if typed.length() >= MAX_DIGITS:
		return
	typed += digit
	_update_hud()


func _delete_digit() -> void:
	if typed.is_empty():
		return
	typed = typed.substr(0, typed.length() - 1)
	_update_hud()


func _confirm() -> void:
	if phase != Phase.INPUT or typed.is_empty():
		return
	var guess := int(typed)
	var error := absi(guess - true_count)
	var result := Color("#ff5d73")
	if error == 0:
		streak += 1
		score += SCORE_EXACT + mini(streak, 10) * 2
		_raise_difficulty()
		result = Color("#4ade80")
		_set_status("正好！　实际 %d" % true_count, result)
		_burst_feedback("正好！", result)
	elif error == 1:
		score += SCORE_CLOSE
		result = Color("#ffd75d")
		_set_status("接近　·　实际 %d" % true_count, result)
		_burst_feedback("接近", result)
	else:
		streak = 0
		_lower_difficulty()
		_set_status("看岔了　·　实际 %d" % true_count, result)
		_burst_feedback("看岔了", result)
	canvas.fill = result
	canvas.showing = true
	canvas.queue_redraw()
	flash_bar.visible = false
	_tint_panel(Color("#152034"))
	phase = Phase.FEEDBACK
	feedback_left = FEEDBACK_TIME
	_update_hud()


func _raise_difficulty() -> void:
	if flash_time > FLASH_TIME_MIN + 0.0001:
		flash_time = maxf(FLASH_TIME_MIN, flash_time - FLASH_STEP)
	else:
		count_max += 1


func _lower_difficulty() -> void:
	if count_max > COUNT_MAX_START:
		count_max -= 1
	else:
		flash_time = minf(FLASH_TIME_START, flash_time + FLASH_STEP)


func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	if phase == Phase.READY:
		ready_left -= delta
		if ready_left <= 0.0:
			_new_trial()
		_update_hud()
		return
	if phase == Phase.FEEDBACK:
		feedback_left -= delta
		if feedback_left <= 0.0:
			_begin_clear()
		_update_hud()
		return
	if phase == Phase.CLEAR:
		clear_left -= delta
		if clear_left <= 0.0:
			_new_trial()
		_update_hud()
		return
	time_left -= delta
	if time_left <= 0.0:
		_end_round()
		return
	if phase == Phase.FLASH:
		flash_left -= delta
		flash_bar.size.x = panel.size.x * clampf(flash_left / flash_time, 0.0, 1.0)
		if flash_left <= 0.0:
			canvas.showing = false
			canvas.queue_redraw()
			flash_bar.visible = false
			phase = Phase.INPUT
			_set_status("输入你看到的数量", Color("#7f8ba6"))
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.INPUT:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var k: int = key_event.keycode
	if k >= KEY_0 and k <= KEY_9:
		_append_digit(str(k - KEY_0))
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		_append_digit(str(k - KEY_KP_0))
	elif k == KEY_BACKSPACE:
		_delete_digit()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		_confirm()


func _begin_clear() -> void:
	phase = Phase.CLEAR
	clear_left = CLEAR_TIME
	canvas.showing = false
	canvas.queue_redraw()
	_tint_panel(Color("#1a2740"))
	_set_status("下一题", Color("#7f8ba6"))
	_update_hud()


func _tint_panel(color: Color) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)


func _update_hud() -> void:
	score_label.text = "得分 %d　连击 %d" % [score, streak]
	if phase == Phase.READY:
		time_label.text = "准备"
	else:
		time_label.text = "剩余 %d 秒" % ceili(maxf(time_left, 0.0))
	if phase == Phase.FLASH or phase == Phase.READY or phase == Phase.CLEAR:
		input_label.text = "·"
	elif phase == Phase.FEEDBACK:
		input_label.text = str(true_count)
	elif typed.is_empty():
		input_label.text = "—"
	else:
		input_label.text = typed
	if keypad != null:
		keypad.modulate = Color.WHITE if phase == Phase.INPUT else Color(1, 1, 1, 0.42)


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _end_round() -> void:
	phase = Phase.OVER
	time_left = 0.0
	canvas.showing = false
	canvas.queue_redraw()
	flash_bar.visible = false
	var is_best := score > best_score
	if is_best:
		best_score = score
		_save_best()
	var suffix := " · 新纪录！" if is_best else ""
	if best_score > 0 and not is_best:
		suffix = " · 最佳 %d" % best_score
	_set_status("时间到 · 得分 %d%s" % [score, suffix], Color("#ffd75d"))
	_update_hud()
	if restart_button == null:
		var y := panel.position.y + (panel.size.y - 60.0) / 2.0
		restart_button = _make_restart_button(_start_round, y)
		restart_button.text = "再来一局"


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.save(BEST_PATH)


class DotCanvas extends Node2D:
	var points: Array[Vector2] = []
	var showing := false
	var radius := 18.0
	var fill := Color("#8ab4ff")

	func _draw() -> void:
		if not showing:
			return
		for p in points:
			draw_circle(p, radius, fill)
			draw_circle(p, radius, Color("#e8edff"), false, 2.0)
