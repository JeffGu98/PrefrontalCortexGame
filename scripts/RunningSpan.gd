extends "res://scripts/GameBase.gd"
## 末项记 Running Span：数字一条条闪过，只按顺序点出最后 N 个（工作记忆更新：丢掉前面的）。


const START_SPAN := 2
const MIN_SPAN := 2
const MAX_SPAN := 7
const ROUND_SECS := 60.0
const LIT_START := 0.75
const LIT_MIN := 0.50
const GAP_BETWEEN := 0.18
const READY_GAP := 0.40
const INPUT_GAP := 0.40
const EXTRA_MIN := 1
const EXTRA_MAX := 3
const BEST_PATH := "user://running_span_best.cfg"
const IDLE_HINT := "数字会一条条闪过。只要记住最后 N 个，按从早到晚的顺序点出来"
const PAD_DIM := Color("#1a2740")
const PAD_OK := Color("#4ade80")
const PAD_BAD := Color("#ff5d73")

enum Phase { PICK, SHOW, INPUT, GAP, OVER }

var phase := Phase.SHOW
var score := 0
var streak := 0
var span := START_SPAN
var best_score := 0
var best_span := START_SPAN
var session_best_span := START_SPAN
var round_left := ROUND_SECS
var stream: Array[int] = []
var target: Array[int] = []
var input_i := 0
var round_id := 0
var accepting := false
var lit_time := LIT_START

var score_label: Label
var round_label: Label
var span_label: Label
var hint_label: Label
var stim_panel: Panel
var stim_label: Label
var pad_grid: GridContainer
var pad_btns: Array[Button] = []
var restart_button: Button


func _init() -> void:
	title_text = "末项记"
	help_text = "屏幕中间会一条条闪过数字（1–9）。整串看完后，只按顺序点出最后 N 个（从较早到较晚）。\n前面的要主动丢掉——这和积木跨度（整段复述）、N-Back（是否与 N 步前相同）都不一样。\n全对末项数 +1，点错 −1。一局约 60 秒。不承诺变聪明。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_stim()
	_build_pad()
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
	hint_label.offset_bottom = 210
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint_label)


func _build_stim() -> void:
	stim_panel = Panel.new()
	stim_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stim_panel)
	_paint_stim(Color("#1a2740"))

	stim_label = Label.new()
	stim_label.add_theme_font_size_override("font_size", 120)
	stim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stim_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stim_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stim_label.add_theme_color_override("font_color", Color("#e8edff"))
	stim_panel.add_child(stim_label)


func _build_pad() -> void:
	pad_grid = GridContainer.new()
	pad_grid.columns = 3
	pad_grid.add_theme_constant_override("h_separation", 12)
	pad_grid.add_theme_constant_override("v_separation", 12)
	add_child(pad_grid)
	for n in range(1, 10):
		var btn := Button.new()
		btn.text = str(n)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 36)
		btn.add_theme_color_override("font_color", Color("#e8edff"))
		_style_button(btn, PAD_DIM)
		btn.pressed.connect(_on_pad.bind(n))
		pad_grid.add_child(btn)
		pad_btns.append(btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and stim_panel != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	stim_panel.position = Vector2(48, 220)
	stim_panel.size = Vector2(vp.x - 96.0, 220)
	_paint_stim(Color("#1a2740"))

	var pad_w := minf(vp.x - 64.0, 420.0)
	var pad_h := pad_w
	pad_grid.position = Vector2((vp.x - pad_w) / 2.0, 468.0)
	pad_grid.size = Vector2(pad_w, pad_h)
	var cell := (pad_w - 12.0 * 2.0) / 3.0
	for btn in pad_btns:
		btn.custom_minimum_size = Vector2(cell, cell)
		btn.size = Vector2(cell, cell)
	_layout_progress_gate()
	if restart_button != null:
		restart_button.position = Vector2((vp.x - 220.0) / 2.0, vp.y - 120.0)


func _paint_stim(bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	stim_panel.add_theme_stylebox_override("panel", style)


func _show_gate() -> void:
	phase = Phase.PICK
	stim_panel.visible = false
	pad_grid.visible = false
	_show_progress_gate(
		"历史最长末项 %d。\n这一局从 %d 继续，还是从 %d 重来？" % [best_span, best_span, START_SPAN],
		"从末项 %d 继续" % best_span,
		"从头开始（末项 %d）" % START_SPAN
	)
	_set_hint("选这一局从哪档开始", Color("#7f8ba6"))
	_update_hud()


func _on_progress_continue() -> void:
	if phase != Phase.PICK:
		return
	span = clampi(best_span, MIN_SPAN, MAX_SPAN)
	_hide_progress_gate()
	stim_panel.visible = true
	pad_grid.visible = true
	_begin_round()


func _on_progress_fresh() -> void:
	if phase != Phase.PICK:
		return
	span = START_SPAN
	_hide_progress_gate()
	stim_panel.visible = true
	pad_grid.visible = true
	_begin_round()


func _begin_round() -> void:
	phase = Phase.SHOW
	score = 0
	streak = 0
	session_best_span = span
	round_left = ROUND_SECS
	round_id += 1
	accepting = false
	lit_time = LIT_START
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	_reset_pad_styles()
	_update_hud()
	_start_trial()


func _start_trial() -> void:
	if phase == Phase.OVER:
		return
	round_id += 1
	var id := round_id
	accepting = false
	input_i = 0
	lit_time = maxf(LIT_MIN, lerpf(LIT_START, LIT_MIN, clampf(float(streak) / 8.0, 0.0, 1.0)))
	_build_stream()
	stim_label.text = ""
	_paint_stim(Color("#1a2740"))
	_reset_pad_styles()
	_set_pad_enabled(false)
	phase = Phase.SHOW
	_set_hint("看数字… 只要最后 %d 个" % span, Color("#8ab4ff"))
	_update_hud()
	await get_tree().create_timer(READY_GAP).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	for d in stream:
		if not is_inside_tree() or id != round_id or phase == Phase.OVER:
			return
		stim_label.text = str(d)
		stim_label.add_theme_color_override("font_color", Color("#e8edff"))
		_paint_stim(Color("#152034"))
		await get_tree().create_timer(lit_time).timeout
		if not is_inside_tree() or id != round_id or phase == Phase.OVER:
			return
		stim_label.text = ""
		_paint_stim(Color("#12192a"))
		await get_tree().create_timer(GAP_BETWEEN).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	phase = Phase.INPUT
	accepting = true
	stim_label.text = "？"
	stim_label.add_theme_color_override("font_color", Color("#ffd75d"))
	_paint_stim(Color("#1a2740"))
	_set_pad_enabled(true)
	_set_hint("按从早到晚点出最后 %d 个" % span, Color("#e8edff"))
	_update_hud()


func _build_stream() -> void:
	var extra := randi_range(EXTRA_MIN, EXTRA_MAX)
	var total := span + extra
	stream.clear()
	var last := -1
	for _i in range(total):
		var pick := randi_range(1, 9)
		var guard := 0
		while pick == last and guard < 8:
			pick = randi_range(1, 9)
			guard += 1
		stream.append(pick)
		last = pick
	target.clear()
	var start := stream.size() - span
	for i in range(start, stream.size()):
		target.append(stream[i])


func _on_pad(digit: int) -> void:
	if phase != Phase.INPUT or not accepting:
		return
	accepting = false
	var expect: int = target[input_i]
	var btn := pad_btns[digit - 1]
	if digit == expect:
		_style_button(btn, PAD_OK)
		btn.add_theme_color_override("font_color", Color("#0d1220"))
		input_i += 1
		if input_i >= target.size():
			_on_trial_correct()
		else:
			_set_hint("%d / %d" % [input_i, target.size()], Color("#4ade80"))
			await get_tree().create_timer(0.12).timeout
			if phase == Phase.INPUT:
				_style_button(btn, PAD_DIM)
				btn.add_theme_color_override("font_color", Color("#e8edff"))
				accepting = true
	else:
		_style_button(btn, PAD_BAD)
		btn.add_theme_color_override("font_color", Color("#e8edff"))
		_on_trial_wrong()


func _on_trial_correct() -> void:
	streak += 1
	session_best_span = maxi(session_best_span, span)
	if span > best_span:
		best_span = span
		_save_best()
	var pts := 10 + span * 5 + mini(streak, 8) * 2
	score += pts
	_set_hint("全对 +%d · 末项 %d" % [pts, span], Color("#4ade80"))
	_burst_feedback("+%d" % pts, Color("#4ade80"))
	span = mini(span + 1, MAX_SPAN)
	_set_pad_enabled(false)
	_update_hud()
	_after_trial()


func _on_trial_wrong() -> void:
	streak = 0
	_set_hint("错了 · 应是 %s" % _target_str(), Color("#ff5d73"))
	_burst_feedback("错", Color("#ff5d73"))
	span = maxi(span - 1, MIN_SPAN)
	_set_pad_enabled(false)
	_update_hud()
	_after_trial()


func _target_str() -> String:
	var parts: PackedStringArray = []
	for d in target:
		parts.append(str(d))
	return " ".join(parts)


func _after_trial() -> void:
	phase = Phase.GAP
	accepting = false
	round_id += 1
	var id := round_id
	await get_tree().create_timer(INPUT_GAP).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	stim_label.text = ""
	_reset_pad_styles()
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


func _set_pad_enabled(on: bool) -> void:
	for btn in pad_btns:
		btn.disabled = not on
		btn.modulate = Color.WHITE if on else Color(1, 1, 1, 0.45)


func _reset_pad_styles() -> void:
	for btn in pad_btns:
		_style_button(btn, PAD_DIM)
		btn.add_theme_color_override("font_color", Color("#e8edff"))


func _update_hud() -> void:
	score_label.text = "得分 %d　连对 %d" % [score, streak]
	round_label.text = "剩余 %.0f 秒" % ceilf(maxf(round_left, 0.0))
	span_label.text = "末项 %d　历史最长 %d" % [span, best_span]


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	accepting = false
	round_id += 1
	stim_label.text = "结束"
	stim_label.add_theme_color_override("font_color", Color("#e8edff"))
	_paint_stim(Color("#1a2740"))
	_set_pad_enabled(false)
	var is_best := score > best_score
	if is_best:
		best_score = score
	best_span = maxi(best_span, session_best_span)
	_save_best()
	_update_hud()
	var parts: PackedStringArray = ["时间到", "本局最长末项 %d" % session_best_span]
	if best_score > 0:
		parts.append("历史最佳 %d" % best_score)
	if is_best and score > 0:
		parts.append("新纪录")
	_set_hint(" · ".join(parts), Color("#ffd75d"))
	if restart_button == null:
		var vp := get_viewport_rect().size
		restart_button = _make_restart_button(_restart, vp.y - 120.0)


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
