extends "res://scripts/GameBase.gd"
## 舒尔特方格：数字格 5×5 起，点完升到 6×6、7×7；档间插入 4×4 呼吸关。


const MIN_SIZE := 5
const MAX_SIZE := 7
const BREATH_SIZE := 4
const BEST_PATH := "user://schulte_best.cfg"
const GAP := 10.0
const CELL_MAX := 120.0
const CELL_MIN := 36.0
const HUD_TOP := 156.0
const SIDE_MARGIN := 36.0
const BOTTOM_RESERVE := 108.0
const RESTART_W := 220.0
const RESTART_H := 60.0
const NEXT_BOARD_GAP := 0.7

enum Phase { GATE, PLAY }

var phase := Phase.PLAY
var grid_size := MIN_SIZE
var latest_size := MIN_SIZE
var next_number := 1
var started := false
var elapsed := 0.0
var finished := false
var mistakes := 0
var board_id := 0
var breath_mode := false
var after_breath_size := -1
var best_times := {4: -1.0, 5: -1.0, 6: -1.0, 7: -1.0}

var grid: GridContainer
var time_label: Label
var status_label: Label
var restart_button: Button
var cells: Array = []


func _init() -> void:
	title_text = "舒尔特方格"
	help_text = "格子里随机排着数字。从 1 开始按顺序点，越快越好。点错会闪红并计入失误，但不用从头来。第一次点击开始计时。\n点完 5×5 会上 6×6，再上 7×7。每升一档前会插一局轻松的 4×4「呼吸关」，点完再继续变难。格子不会在中途换位。\n做到哪一档会记住。再进时选继续最新一档，或从 5×5 重来。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_grid()
	_build_restart_button()
	_layout_board()
	if latest_size > MIN_SIZE:
		_show_gate()
	else:
		_start_board(MIN_SIZE)


func _build_hud() -> void:
	time_label = _make_label("时间  0.00 秒", 26, Color("#e8edff"))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	time_label.offset_top = 72
	time_label.offset_bottom = 108
	add_child(time_label)

	status_label = _make_label("", 20, Color("#7f8ba6"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_top = 110
	status_label.offset_bottom = 144
	add_child(status_label)


func _build_grid() -> void:
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	add_child(grid)


func _build_restart_button() -> void:
	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.add_theme_font_size_override("font_size", 22)
	restart_button.add_theme_color_override("font_color", Color("#e8edff"))
	restart_button.custom_minimum_size = Vector2(RESTART_W, RESTART_H)
	_style_button(restart_button, Color("#1a2740"))
	restart_button.pressed.connect(_start_new)
	add_child(restart_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and grid != null:
		_layout_board()


func _layout_board() -> void:
	var cell := _cell_size()
	var total := grid_size * cell + (grid_size - 1) * GAP
	var vp := get_viewport_rect().size
	grid.position = Vector2((vp.x - total) / 2.0, HUD_TOP)
	grid.size = Vector2(total, total)
	var font_size := clampi(int(cell * 0.32), 14, 32)
	for btn in cells:
		var cell_btn: Button = btn
		cell_btn.custom_minimum_size = Vector2(cell, cell)
		cell_btn.add_theme_font_size_override("font_size", font_size)
	restart_button.position = Vector2((vp.x - RESTART_W) / 2.0, grid.position.y + total + 24.0)
	_layout_progress_gate()


func _cell_size() -> float:
	var vp := get_viewport_rect().size
	var avail_w := vp.x - SIDE_MARGIN * 2.0
	var avail_h := vp.y - HUD_TOP - BOTTOM_RESERVE
	var inner_w := avail_w - GAP * (grid_size - 1)
	var inner_h := avail_h - GAP * (grid_size - 1)
	var cell := minf(inner_w / grid_size, inner_h / grid_size)
	return clampf(cell, CELL_MIN, CELL_MAX)


func _cell_count() -> int:
	return grid_size * grid_size


func _size_label(n: int = -1) -> String:
	if n < 0:
		n = grid_size
	return "%d×%d" % [n, n]


func _style_cell(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#1a2740")
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#233455")
	hover.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("#152038")
	pressed.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color("#132034")
	disabled.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("disabled", disabled)


func _show_gate() -> void:
	phase = Phase.GATE
	finished = true
	started = false
	breath_mode = false
	after_breath_size = -1
	grid.visible = false
	restart_button.visible = false
	_show_progress_gate(
		"上次做到 %s。\n这一局进最新一档，还是从 5×5 重来？" % _size_label(latest_size),
		"进入最新一关（%s）" % _size_label(latest_size),
		"从头开始（5×5）"
	)
	status_label.add_theme_color_override("font_color", Color("#7f8ba6"))
	status_label.text = "选这一局从哪档开始"
	time_label.text = "时间  —"


func _hide_gate() -> void:
	_hide_progress_gate()
	grid.visible = true
	restart_button.visible = true


func _on_progress_continue() -> void:
	if phase != Phase.GATE:
		return
	_hide_gate()
	_start_board(latest_size)


func _on_progress_fresh() -> void:
	if phase != Phase.GATE:
		return
	latest_size = MIN_SIZE
	_save_progress()
	_hide_gate()
	_start_board(MIN_SIZE)


func _start_new() -> void:
	if phase == Phase.GATE:
		return
	if breath_mode:
		_start_breath(after_breath_size)
	elif finished and grid_size < MAX_SIZE:
		_start_board(grid_size + 1)
	else:
		_start_board(grid_size)


func _start_board(size: int) -> void:
	breath_mode = false
	after_breath_size = -1
	_start_board_raw(clampi(size, MIN_SIZE, MAX_SIZE))


func _start_breath(next_size: int) -> void:
	breath_mode = true
	after_breath_size = next_size
	_start_board_raw(BREATH_SIZE)


func _start_board_raw(size: int) -> void:
	phase = Phase.PLAY
	board_id += 1
	grid_size = size
	next_number = 1
	started = false
	elapsed = 0.0
	finished = false
	mistakes = 0
	time_label.text = "时间  0.00 秒"
	_hide_gate()
	_rebuild_cells()
	_reset_grid()
	_layout_board()
	if not breath_mode:
		_remember_level()
	_refresh_status()


func _rebuild_cells() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.free()
	cells.clear()
	grid.columns = grid_size
	for i in range(_cell_count()):
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_color_override("font_color", Color("#e8edff"))
		btn.add_theme_color_override("font_disabled_color", Color("#4a6a8f"))
		_style_cell(btn)
		btn.pressed.connect(_on_cell_pressed.bind(btn))
		grid.add_child(btn)
		cells.append(btn)


func _reset_grid() -> void:
	var numbers: Array = []
	for i in range(1, _cell_count() + 1):
		numbers.append(i)
	numbers.shuffle()
	for i in range(_cell_count()):
		var btn: Button = cells[i]
		btn.text = str(numbers[i])
		btn.set_meta("num", numbers[i])
		btn.disabled = false
		btn.modulate = Color.WHITE
		btn.scale = Vector2.ONE


func _on_cell_pressed(btn: Button) -> void:
	if phase != Phase.PLAY or finished or btn.disabled:
		return
	if not started:
		started = true
	var number: int = btn.get_meta("num")
	if number == next_number:
		next_number += 1
		_mark_correct(btn)
		if next_number > _cell_count():
			_finish()
		else:
			_refresh_status()
	else:
		mistakes += 1
		_flash_wrong(btn)
		_refresh_status()


func _mark_correct(btn: Button) -> void:
	btn.disabled = true
	btn.modulate = Color("#4ade80")
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(1.12, 1.12)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(btn, "modulate", Color(0.55, 0.85, 0.7), 0.45)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _flash_wrong(btn: Button) -> void:
	btn.modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(btn, "modulate", Color.WHITE, 0.3)


func _process(delta: float) -> void:
	if phase != Phase.PLAY or not started or finished:
		return
	elapsed += delta
	time_label.text = "时间  %.2f 秒" % elapsed


func _finish() -> void:
	finished = true
	started = false
	var is_best := _record_best()
	var suffix := " · 新纪录" if is_best else ""
	if breath_mode:
		status_label.text = "呼吸关 %s 完成 %.2f 秒（点错 %d）%s" % [_size_label(), elapsed, mistakes, suffix]
		status_label.add_theme_color_override("font_color", Color("#8ab4ff"))
		_burst_feedback("轻松一下", Color("#8ab4ff"))
		var id := board_id
		await get_tree().create_timer(NEXT_BOARD_GAP).timeout
		if not is_inside_tree() or id != board_id or phase != Phase.PLAY:
			return
		var nxt := after_breath_size
		breath_mode = false
		after_breath_size = -1
		if nxt >= MIN_SIZE:
			_start_board(nxt)
		else:
			_start_board(MAX_SIZE)
		return

	status_label.text = "%s 完成 %.2f 秒（点错 %d）%s" % [_size_label(), elapsed, mistakes, suffix]
	status_label.add_theme_color_override("font_color", Color("#ffd75d") if is_best else Color("#4ade80"))
	if grid_size < MAX_SIZE:
		var nxt := grid_size + 1
		latest_size = nxt
		_save_progress()
		_burst_feedback(_size_label(), Color("#ffd75d") if is_best else Color("#4ade80"))
		var id2 := board_id
		await get_tree().create_timer(NEXT_BOARD_GAP).timeout
		if not is_inside_tree() or id2 != board_id or phase != Phase.PLAY:
			return
		_start_breath(nxt)
	else:
		_save_progress()
		_burst_feedback(_size_label(), Color("#ffd75d") if is_best else Color("#4ade80"))
		var id3 := board_id
		await get_tree().create_timer(NEXT_BOARD_GAP).timeout
		if not is_inside_tree() or id3 != board_id or phase != Phase.PLAY:
			return
		# Cap clear → one breath, then reshuffle 7×7.
		_start_breath(MAX_SIZE)


func _refresh_status() -> void:
	if finished or phase != Phase.PLAY:
		return
	if not started:
		status_label.add_theme_color_override("font_color", Color("#7f8ba6"))
		status_label.text = _idle_text()
		return
	status_label.add_theme_color_override("font_color", Color("#8ab4ff") if breath_mode else Color("#8ab4ff"))
	var tag := "呼吸关 " if breath_mode else ""
	var body := "%s%s  下一个 %d／%d" % [tag, _size_label(), next_number, _cell_count()]
	if mistakes > 0:
		body += " · 点错 %d" % mistakes
	status_label.text = body


func _idle_text() -> String:
	var best: float = best_times.get(grid_size, -1.0)
	var tag := "呼吸关 " if breath_mode else ""
	var head := "%s%s  下一个 1／%d" % [tag, _size_label(), _cell_count()]
	if breath_mode:
		return "%s · 轻松一局后再变难" % head
	if best > 0.0:
		return "%s · 最佳 %.2f 秒" % [head, best]
	return "%s · 按顺序点击" % head


func _record_best() -> bool:
	var prev: float = best_times.get(grid_size, -1.0)
	var is_best := prev < 0.0 or elapsed < prev
	if is_best:
		best_times[grid_size] = elapsed
		_save_progress()
	return is_best


func _remember_level() -> void:
	latest_size = clampi(maxi(latest_size, grid_size), MIN_SIZE, MAX_SIZE)
	_save_progress()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		var legacy := float(config.get_value("best", "time", -1.0))
		best_times[4] = float(config.get_value("best", "time_4", -1.0))
		best_times[5] = float(config.get_value("best", "time_5", legacy))
		best_times[6] = float(config.get_value("best", "time_6", -1.0))
		best_times[7] = float(config.get_value("best", "time_7", -1.0))
		latest_size = clampi(int(config.get_value("best", "size", MIN_SIZE)), MIN_SIZE, MAX_SIZE)


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "time", best_times.get(5, -1.0))
	config.set_value("best", "time_4", best_times.get(4, -1.0))
	config.set_value("best", "time_5", best_times.get(5, -1.0))
	config.set_value("best", "time_6", best_times.get(6, -1.0))
	config.set_value("best", "time_7", best_times.get(7, -1.0))
	config.set_value("best", "size", clampi(latest_size, MIN_SIZE, MAX_SIZE))
	config.save(BEST_PATH)
