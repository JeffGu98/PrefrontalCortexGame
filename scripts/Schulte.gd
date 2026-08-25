extends "res://scripts/GameBase.gd"
## 舒尔特方格：5×5 网格随机 1–25，按顺序点，越快越好。


const GRID_SIZE := 5
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const BEST_PATH := "user://schulte_best.cfg"
const GAP := 10.0
const CELL_MAX := 120.0
const CELL_MIN := 56.0
const HUD_TOP := 156.0
const SIDE_MARGIN := 36.0
const BOTTOM_RESERVE := 108.0
const RESTART_W := 220.0
const RESTART_H := 60.0

var next_number := 1
var started := false
var elapsed := 0.0
var finished := false
var mistakes := 0
var best_time := -1.0

var grid: GridContainer
var time_label: Label
var status_label: Label
var restart_button: Button
var cells: Array = []


func _init() -> void:
	title_text = "舒尔特方格"
	help_text = "5×5 格子里随机排着 1 到 25。从 1 开始按顺序点，越快越好。\n点错会闪红并计入失误，但不用从头来。\n第一次点击开始计时，点完 25 看用时。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_grid()
	_build_restart_button()
	_layout_board()
	_start_new()


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
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	add_child(grid)

	for i in range(CELL_COUNT):
		var btn := Button.new()
		btn.add_theme_color_override("font_color", Color("#e8edff"))
		btn.add_theme_color_override("font_disabled_color", Color("#4a6a8f"))
		_style_cell(btn)
		btn.pressed.connect(_on_cell_pressed.bind(btn))
		grid.add_child(btn)
		cells.append(btn)


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
	var total := GRID_SIZE * cell + (GRID_SIZE - 1) * GAP
	var vp := get_viewport_rect().size
	grid.position = Vector2((vp.x - total) / 2.0, HUD_TOP)
	grid.size = Vector2(total, total)
	var font_size := clampi(int(cell * 0.28), 18, 32)
	for btn in cells:
		var cell_btn: Button = btn
		cell_btn.custom_minimum_size = Vector2(cell, cell)
		cell_btn.add_theme_font_size_override("font_size", font_size)
	restart_button.position = Vector2((vp.x - RESTART_W) / 2.0, grid.position.y + total + 24.0)


func _cell_size() -> float:
	var vp := get_viewport_rect().size
	var avail_w := vp.x - SIDE_MARGIN * 2.0
	var avail_h := vp.y - HUD_TOP - BOTTOM_RESERVE
	var inner_w := avail_w - GAP * (GRID_SIZE - 1)
	var inner_h := avail_h - GAP * (GRID_SIZE - 1)
	var cell := minf(inner_w / GRID_SIZE, inner_h / GRID_SIZE)
	return clampf(cell, CELL_MIN, CELL_MAX)


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


func _start_new() -> void:
	next_number = 1
	started = false
	elapsed = 0.0
	finished = false
	mistakes = 0
	time_label.text = "时间  0.00 秒"
	_reset_grid()
	_refresh_status()


func _reset_grid() -> void:
	var numbers := []
	for i in range(1, CELL_COUNT + 1):
		numbers.append(i)
	numbers.shuffle()

	for i in range(CELL_COUNT):
		var btn: Button = cells[i]
		btn.text = str(numbers[i])
		btn.set_meta("num", numbers[i])
		btn.disabled = false
		btn.modulate = Color.WHITE
		btn.scale = Vector2.ONE


func _on_cell_pressed(btn: Button) -> void:
	if finished:
		return
	if not started:
		started = true

	var number: int = btn.get_meta("num")
	if number == next_number:
		next_number += 1
		_mark_correct(btn)
		if next_number > CELL_COUNT:
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
	if started and not finished:
		elapsed += delta
		time_label.text = "时间  %.2f 秒" % elapsed


func _finish() -> void:
	finished = true
	var is_best := best_time < 0.0 or elapsed < best_time
	if is_best:
		best_time = elapsed
		_save_best()
	var suffix := " · 新纪录！" if is_best else ""
	status_label.text = "完成！%.2f 秒（点错 %d 次）%s" % [elapsed, mistakes, suffix]
	status_label.add_theme_color_override("font_color", Color("#ffd75d") if is_best else Color("#4ade80"))
	_burst_feedback("完成！", Color("#ffd75d") if is_best else Color("#4ade80"))


func _refresh_status() -> void:
	if finished:
		return
	if not started:
		status_label.add_theme_color_override("font_color", Color("#7f8ba6"))
		status_label.text = _idle_text()
		return
	status_label.add_theme_color_override("font_color", Color("#8ab4ff"))
	if mistakes > 0:
		status_label.text = "下一个 %d／%d · 点错 %d" % [next_number, CELL_COUNT, mistakes]
	else:
		status_label.text = "下一个 %d／%d" % [next_number, CELL_COUNT]


func _idle_text() -> String:
	if best_time > 0.0:
		return "下一个 1／25 · 最佳 %.2f 秒" % best_time
	return "下一个 1／25 · 按顺序点击"


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_time = float(config.get_value("best", "time", -1.0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "time", best_time)
	config.save(BEST_PATH)
