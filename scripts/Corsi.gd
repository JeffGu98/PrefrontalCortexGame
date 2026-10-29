extends "res://scripts/GameBase.gd"
## 积木跨度 Corsi：记住方块点亮顺序，按相同顺序点回去（空间序列工作记忆）。


const GRID := 3
const CELL_COUNT := GRID * GRID
const START_SPAN := 3
const MIN_SPAN := 2
const MAX_SPAN := 9
const ROUND_SECS := 60.0
const LIT_TIME := 0.55
const GAP_BETWEEN := 0.18
const READY_GAP := 0.45
const INPUT_GAP := 0.35
const BEST_PATH := "user://corsi_best.cfg"
const DIM := Color("#1a2740")
const LIT := Color("#8ab4ff")
const OK := Color("#4ade80")
const BAD := Color("#ff5d73")
const IDLE_HINT := "看方块点亮的顺序，再按同样顺序点回去"

enum Phase { PICK, SHOW, INPUT, GAP, OVER }

var phase := Phase.SHOW
var score := 0
var streak := 0
var span := START_SPAN
var best_score := 0
var best_span := START_SPAN
var session_best_span := START_SPAN
var round_left := ROUND_SECS
var sequence: Array[int] = []
var input_i := 0
var round_id := 0
var accepting := false

var score_label: Label
var round_label: Label
var span_label: Label
var hint_label: Label
var grid: GridContainer
var cells: Array[Panel] = []
var cell_styles: Array[StyleBoxFlat] = []
var restart_button: Button


func _init() -> void:
	title_text = "积木跨度"
	help_text = "九个方块会按顺序亮一下。看清顺序后，按同样的顺序点回去。\n点对继续；点错这一轮结束，跨度减一（最少 2）。整段都对则跨度加一（最多 9）。\n一局约 60 秒。练的是记住空间位置的先后顺序，不是反应速度。不承诺变聪明。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_grid()
	_layout_board()
	if best_span > START_SPAN:
		_show_gate()
	else:
		span = START_SPAN
		_begin_round()


func _build_hud() -> void:
	score_label = _make_label("", 24, Color("#e8edff"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 72
	score_label.offset_bottom = 100
	add_child(score_label)

	round_label = _make_label("", 20, Color("#ffd75d"))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	round_label.offset_top = 100
	round_label.offset_bottom = 126
	add_child(round_label)

	span_label = _make_label("", 28, Color("#8ab4ff"))
	span_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	span_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	span_label.offset_top = 126
	span_label.offset_bottom = 164
	add_child(span_label)

	hint_label = _make_label(IDLE_HINT, 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 164
	hint_label.offset_bottom = 200
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint_label)


func _build_grid() -> void:
	grid = GridContainer.new()
	grid.columns = GRID
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	add_child(grid)
	for i in range(CELL_COUNT):
		var cell := Panel.new()
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = DIM
		style.set_corner_radius_all(14)
		cell.add_theme_stylebox_override("panel", style)
		cell.gui_input.connect(_on_cell_input.bind(i))
		grid.add_child(cell)
		cells.append(cell)
		cell_styles.append(style)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and grid != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var side := minf(vp.x - 64.0, 520.0)
	grid.position = Vector2((vp.x - side) / 2.0, 220.0)
	grid.size = Vector2(side, side)
	var cell_side := (side - 14.0 * (GRID - 1)) / float(GRID)
	for cell in cells:
		cell.custom_minimum_size = Vector2(cell_side, cell_side)
		cell.size = Vector2(cell_side, cell_side)
	_layout_progress_gate()
	if restart_button != null:
		restart_button.position = Vector2((vp.x - 220.0) / 2.0, vp.y - 160.0)


func _show_gate() -> void:
	phase = Phase.PICK
	grid.visible = false
	_show_progress_gate(
		"历史最长跨度 %d。\n这一局从跨度 %d 继续，还是从 %d 重来？" % [best_span, best_span, START_SPAN],
		"从跨度 %d 继续" % best_span,
		"从头开始（跨度 %d）" % START_SPAN
	)
	_set_hint("选这一局从哪档开始", Color("#7f8ba6"))
	_update_hud()


func _on_progress_continue() -> void:
	if phase != Phase.PICK:
		return
	span = clampi(best_span, MIN_SPAN, MAX_SPAN)
	_hide_progress_gate()
	grid.visible = true
	_begin_round()


func _on_progress_fresh() -> void:
	if phase != Phase.PICK:
		return
	span = START_SPAN
	_hide_progress_gate()
	grid.visible = true
	_begin_round()


func _begin_round() -> void:
	phase = Phase.SHOW
	score = 0
	streak = 0
	session_best_span = span
	round_left = ROUND_SECS
	round_id += 1
	accepting = false
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	_update_hud()
	_start_trial()


func _start_trial() -> void:
	if phase == Phase.OVER:
		return
	round_id += 1
	var id := round_id
	accepting = false
	input_i = 0
	sequence = _make_sequence(span)
	_paint_all(DIM)
	phase = Phase.SHOW
	_set_hint("看顺序…", Color("#8ab4ff"))
	_update_hud()
	await get_tree().create_timer(READY_GAP).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	for idx in sequence:
		if not is_inside_tree() or id != round_id or phase == Phase.OVER:
			return
		_paint_cell(idx, LIT)
		await get_tree().create_timer(LIT_TIME).timeout
		if not is_inside_tree() or id != round_id or phase == Phase.OVER:
			return
		_paint_cell(idx, DIM)
		await get_tree().create_timer(GAP_BETWEEN).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	phase = Phase.INPUT
	accepting = true
	_set_hint("按同样顺序点", Color("#e8edff"))
	_update_hud()


func _make_sequence(n: int) -> Array[int]:
	var seq: Array[int] = []
	var last := -1
	for _i in range(n):
		var pick := randi() % CELL_COUNT
		# Avoid immediate repeat so the light is readable.
		var guard := 0
		while pick == last and guard < 8:
			pick = randi() % CELL_COUNT
			guard += 1
		seq.append(pick)
		last = pick
	return seq


func _on_cell_input(event: InputEvent, index: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_on_tap(index)


func _on_tap(index: int) -> void:
	if phase != Phase.INPUT or not accepting:
		return
	accepting = false
	var expect: int = sequence[input_i]
	if index == expect:
		_paint_cell(index, OK)
		input_i += 1
		if input_i >= sequence.size():
			_on_trial_correct()
		else:
			_set_hint("%d / %d" % [input_i, sequence.size()], Color("#4ade80"))
			await get_tree().create_timer(0.12).timeout
			if phase == Phase.INPUT:
				_paint_cell(index, DIM)
				accepting = true
	else:
		_paint_cell(index, BAD)
		_on_trial_wrong()


func _on_trial_correct() -> void:
	streak += 1
	session_best_span = maxi(session_best_span, span)
	if span > best_span:
		best_span = span
		_save_best()
	var pts := 10 + span * 4 + mini(streak, 8) * 2
	score += pts
	_set_hint("全对 +%d · 跨度 %d" % [pts, span], Color("#4ade80"))
	_burst_feedback("+%d" % pts, Color("#4ade80"))
	span = mini(span + 1, MAX_SPAN)
	_update_hud()
	_after_trial()


func _on_trial_wrong() -> void:
	streak = 0
	_set_hint("顺序错了", Color("#ff5d73"))
	_burst_feedback("错", Color("#ff5d73"))
	span = maxi(span - 1, MIN_SPAN)
	_update_hud()
	_after_trial()


func _after_trial() -> void:
	phase = Phase.GAP
	accepting = false
	round_id += 1
	var id := round_id
	await get_tree().create_timer(INPUT_GAP).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	_paint_all(DIM)
	if round_left <= 0.0:
		_end_game()
		return
	_start_trial()


func _process(delta: float) -> void:
	if phase == Phase.PICK or phase == Phase.OVER:
		return
	round_left -= delta
	if round_left <= 0.0:
		round_left = 0.0
		if phase == Phase.INPUT or phase == Phase.GAP or phase == Phase.SHOW:
			_end_game()
			return
	_update_hud()


func _paint_all(color: Color) -> void:
	for i in range(CELL_COUNT):
		_paint_cell(i, color)


func _paint_cell(i: int, color: Color) -> void:
	cell_styles[i].bg_color = color
	cells[i].queue_redraw()


func _update_hud() -> void:
	score_label.text = "得分 %d　连对 %d" % [score, streak]
	round_label.text = "剩余 %.0f 秒" % ceilf(maxi(round_left, 0.0))
	span_label.text = "跨度 %d　历史最长 %d" % [span, best_span]


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	accepting = false
	round_id += 1
	_paint_all(DIM)
	var is_best := score > best_score
	if is_best:
		best_score = score
	best_span = maxi(best_span, session_best_span)
	_save_best()
	_update_hud()
	var parts: PackedStringArray = ["时间到", "本局最长跨度 %d" % session_best_span]
	if best_score > 0:
		parts.append("历史最佳 %d" % best_score)
	if is_best and score > 0:
		parts.append("新纪录")
	_set_hint(" · ".join(parts), Color("#ffd75d"))
	if restart_button == null:
		var vp := get_viewport_rect().size
		restart_button = _make_restart_button(_restart, vp.y - 160.0)


func _restart() -> void:
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	span = clampi(span, MIN_SPAN, MAX_SPAN)
	_begin_round()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))
		best_span = clampi(int(config.get_value("best", "span", START_SPAN)), MIN_SPAN, MAX_SPAN)


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.set_value("best", "span", clampi(best_span, MIN_SPAN, MAX_SPAN))
	config.save(BEST_PATH)
