extends "res://scripts/GameBase.gd"
## N-Back：判断当前亮起的位置是否与 N 步前相同。


const GRID := 3
const CELL_COUNT := GRID * GRID
const START_N := 2
const MIN_N := 2
const MAX_N := 4
const SOA := 2.5
const STIM_TIME := 0.9
const MATCH_RATIO := 0.3
const UP_STREAK := 10
const DOWN_STREAK := 3
const SCORE_HIT := 10
const LIVES := 3
const READY_TIME := 1.0
const BEST_PATH := "user://nback_best.cfg"
const LIT := Color("#8ab4ff")
const DIM := Color("#1a2740")

enum Phase { READY, PLAY, OVER }

var phase := Phase.READY
var phase_left := 0.0
var score := 0
var lives := LIVES
var streak := 0
var wrong_streak := 0
var best_score := 0
var n_level := START_N
var history: Array[int] = []
var current_pos := 0
var stim_elapsed := 0.0
var showing := false
var answered := false
var is_match := false

var score_label: Label
var lives_label: Label
var n_label: Label
var progress_label: Label
var hint_label: Label
var grid: GridContainer
var cells: Array[Panel] = []
var same_btn: Button
var diff_btn: Button
var start_btn: Button
var brief_panel: Panel
var brief_label: Label
var timer_track: ColorRect
var timer_bar: ColorRect
var restart_button: Button


func _init() -> void:
	title_text = "N-Back"
	help_text = "3×3 格子会依次亮起一个位置。开局会告诉你当前是几-Back。\n2-Back 就是：现在亮的格子，要不要和往前第 2 个相同。前 2 个只看不点。\n之后点「相同」或「不同」。答对 +10，答错或超时扣命。连对 10 次升 N，连错 3 次降 N。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_grid()
	_build_brief()
	_build_buttons()
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
	lives_label.offset_top = 100
	lives_label.offset_bottom = 126
	add_child(lives_label)

	n_label = _make_label("", 36, Color("#ffd75d"))
	n_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	n_label.offset_top = 128
	n_label.offset_bottom = 176
	add_child(n_label)

	progress_label = _make_label("", 18, Color("#8ab4ff"))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	progress_label.offset_top = 176
	progress_label.offset_bottom = 204
	add_child(progress_label)

	hint_label = _make_label("", 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(hint_label)

	timer_track = ColorRect.new()
	timer_track.color = Color("#1a2740")
	timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_track)
	timer_bar = ColorRect.new()
	timer_bar.color = Color("#8ab4ff")
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_bar.position = Vector2.ZERO
	timer_track.add_child(timer_bar)


func _build_grid() -> void:
	grid = GridContainer.new()
	grid.columns = GRID
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	for i in range(CELL_COUNT):
		var cell := Panel.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paint_cell(cell, DIM)
		grid.add_child(cell)
		cells.append(cell)


func _build_brief() -> void:
	brief_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a2740")
	style.set_corner_radius_all(14)
	brief_panel.add_theme_stylebox_override("panel", style)
	add_child(brief_panel)
	brief_label = _make_label("", 22, Color("#e8edff"))
	brief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief_label.offset_left = 24
	brief_label.offset_right = -24
	brief_label.offset_top = 16
	brief_label.offset_bottom = -16
	brief_panel.add_child(brief_label)


func _build_buttons() -> void:
	same_btn = Button.new()
	same_btn.text = "相同"
	same_btn.focus_mode = Control.FOCUS_NONE
	same_btn.add_theme_font_size_override("font_size", 30)
	same_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(same_btn, Color("#4ade80"))
	same_btn.pressed.connect(_on_answer.bind(true))
	add_child(same_btn)

	diff_btn = Button.new()
	diff_btn.text = "不同"
	diff_btn.focus_mode = Control.FOCUS_NONE
	diff_btn.add_theme_font_size_override("font_size", 30)
	diff_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(diff_btn, Color("#1a2740"))
	diff_btn.pressed.connect(_on_answer.bind(false))
	add_child(diff_btn)

	start_btn = Button.new()
	start_btn.text = "开始"
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.add_theme_font_size_override("font_size", 28)
	start_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(start_btn, Color("#4ade80"))
	start_btn.pressed.connect(_start_play)
	add_child(start_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and grid != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var btn_w := minf(260.0, (vp.x - 80.0 - 20.0) / 2.0)
	var btn_h := 120.0
	var btn_y := vp.y - 40.0 - btn_h
	var pair_w := btn_w * 2.0 + 20.0
	var btn_x := (vp.x - pair_w) / 2.0
	same_btn.position = Vector2(btn_x, btn_y)
	same_btn.size = Vector2(btn_w, btn_h)
	same_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	diff_btn.position = Vector2(btn_x + btn_w + 20.0, btn_y)
	diff_btn.size = Vector2(btn_w, btn_h)
	diff_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	start_btn.position = Vector2((vp.x - 280.0) / 2.0, btn_y)
	start_btn.size = Vector2(280, btn_h)
	start_btn.custom_minimum_size = Vector2(280, btn_h)

	var hint_y := btn_y - 48.0
	hint_label.offset_top = hint_y
	hint_label.offset_bottom = hint_y + 36.0

	var bar_w := 400.0
	timer_track.size = Vector2(bar_w, 10)
	timer_track.position = Vector2((vp.x - bar_w) / 2.0, hint_y - 22.0)
	timer_bar.size.y = 10

	var grid_top := 216.0
	var grid_bottom := timer_track.position.y - 20.0
	var avail := maxf(grid_bottom - grid_top, 220.0)
	var cell := clampf((avail - 24.0) / GRID, 72.0, 150.0)
	var total := GRID * cell + (GRID - 1) * 12.0
	grid.position = Vector2((vp.x - total) / 2.0, grid_top + (avail - total) / 2.0)
	grid.size = Vector2(total, total)
	for cell_panel in cells:
		cell_panel.custom_minimum_size = Vector2(cell, cell)
	if brief_panel != null:
		brief_panel.position = grid.position
		brief_panel.size = grid.size


func _start_round() -> void:
	score = 0
	lives = LIVES
	streak = 0
	wrong_streak = 0
	n_level = START_N
	history.clear()
	phase = Phase.READY
	phase_left = 0.0
	showing = false
	answered = false
	_dim_all()
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	brief_label.text = _brief_text(n_level)
	var ready := "先看说明，再开始"
	if best_score > 0:
		ready += " · 最佳 %d" % best_score
	_set_hint(ready, Color("#7f8ba6"))
	_update_hud()


func _brief_text(n: int) -> String:
	return "当前是 %d-Back\n\n请记住往前第 %d 个亮过的格子。\n现在亮的位置，要和倒着数第 %d 个比是不是同一格。\n\n先看 %d 个，不用点。\n从第 %d 个开始按「相同」或「不同」。" % [n, n, n, n, n + 1]


func _start_play() -> void:
	if phase != Phase.READY:
		return
	phase = Phase.PLAY
	_update_hud()
	_begin_trial()


func _begin_trial() -> void:
	if phase == Phase.OVER:
		return
	current_pos = _pick_position()
	is_match = history.size() >= n_level and current_pos == history[history.size() - n_level]
	history.append(current_pos)
	stim_elapsed = 0.0
	showing = true
	answered = false
	_dim_all()
	_paint_cell(cells[current_pos], LIT)
	cells[current_pos].modulate = Color(1.2, 1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(cells[current_pos], "modulate", Color.WHITE, 0.18)
	if _is_scoring():
		_set_hint("和 %d 步前相同吗？" % n_level, Color("#7f8ba6"))
	else:
		var remain := n_level - history.size()
		if remain > 0:
			_set_hint("记住位置 · 还剩 %d 个不判分" % remain, Color("#7f8ba6"))
		else:
			_set_hint("记住这一个，下一个开始作答", Color("#7f8ba6"))
	_update_hud()


func _pick_position() -> int:
	if history.size() < n_level:
		return randi() % CELL_COUNT
	var target: int = history[history.size() - n_level]
	if randf() < MATCH_RATIO:
		return target
	var pick := randi() % (CELL_COUNT - 1)
	if pick >= target:
		pick += 1
	return pick


func _is_scoring() -> bool:
	return history.size() > n_level


func _on_answer(said_match: bool) -> void:
	if phase != Phase.PLAY or answered or not _is_scoring():
		return
	answered = true
	if said_match == is_match:
		_hit()
	else:
		_miss("答错了")


func _hit() -> void:
	streak += 1
	wrong_streak = 0
	score += SCORE_HIT
	_set_hint("对  +%d" % SCORE_HIT, Color("#4ade80"))
	if streak >= UP_STREAK and n_level < MAX_N:
		n_level += 1
		streak = 0
		wrong_streak = 0
		_set_hint("现在要比往前第 %d 个" % n_level, Color("#ffd75d"))
		_burst_feedback("升到 %d-Back\n记住往前第 %d 个" % [n_level, n_level], Color("#ffd75d"))
	else:
		_burst_feedback("+%d" % SCORE_HIT, Color("#4ade80"))
	_update_hud()


func _miss(reason: String) -> void:
	streak = 0
	wrong_streak += 1
	lives -= 1
	_set_hint(reason, Color("#ff5d73"))
	_burst_feedback(reason, Color("#ff5d73"))
	if n_level > MIN_N and wrong_streak >= DOWN_STREAK:
		n_level -= 1
		wrong_streak = 0
		_set_hint("%s · 现在要比往前第 %d 个" % [reason, n_level], Color("#ffd75d"))
	_update_hud()
	if lives <= 0:
		_end_game()


func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	if phase == Phase.READY:
		_update_hud()
		return
	stim_elapsed += delta
	var ratio := clampf(1.0 - stim_elapsed / SOA, 0.0, 1.0)
	timer_bar.size.x = timer_track.size.x * ratio
	timer_bar.color = Color("#ff5d73") if ratio < 0.2 and _is_scoring() else Color("#8ab4ff")
	if showing and stim_elapsed >= STIM_TIME:
		showing = false
		_paint_cell(cells[current_pos], DIM)
	if stim_elapsed >= SOA:
		if _is_scoring() and not answered:
			_miss("没答")
		if phase != Phase.OVER:
			_begin_trial()
		return
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if phase == Phase.READY:
		if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE or key.keycode == KEY_KP_ENTER:
			_start_play()
		return
	if phase != Phase.PLAY:
		return
	if key.keycode == KEY_F or key.keycode == KEY_LEFT:
		_on_answer(true)
	elif key.keycode == KEY_J or key.keycode == KEY_RIGHT:
		_on_answer(false)


func _dim_all() -> void:
	for cell in cells:
		_paint_cell(cell, DIM)
		cell.modulate = Color.WHITE


func _paint_cell(cell: Panel, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	cell.add_theme_stylebox_override("panel", style)


func _update_hud() -> void:
	score_label.text = "得分 %d　连击 %d" % [score, streak]
	lives_label.text = "生命 %d/%d" % [lives, LIVES]
	n_label.text = "%d-Back　·　往前第 %d 个" % [n_level, n_level]
	if phase == Phase.READY:
		progress_label.text = "先记住往前第 %d 个格子" % n_level
	else:
		progress_label.text = "升阶 %d／%d　连错降阶 %d／%d" % [streak, UP_STREAK, wrong_streak, DOWN_STREAK]
	var scoring := phase == Phase.PLAY and _is_scoring() and not answered
	var ready := phase == Phase.READY
	if same_btn != null:
		same_btn.visible = not ready
		diff_btn.visible = not ready
		start_btn.visible = ready
		same_btn.modulate = Color.WHITE if scoring else Color(1, 1, 1, 0.4)
		diff_btn.modulate = Color.WHITE if scoring else Color(1, 1, 1, 0.4)
	if brief_panel != null:
		brief_panel.visible = ready
	if timer_track != null:
		timer_track.visible = phase == Phase.PLAY


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	phase = Phase.OVER
	showing = false
	_dim_all()
	timer_track.visible = false
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
		restart_button = _make_restart_button(_restart, same_btn.position.y - 84.0)


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
