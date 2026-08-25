extends "res://scripts/GameBase.gd"
## 任务切换：按当前规则判断数字的奇偶或大小。


const LIVES := 3
const TRIAL_TIME := 3.0
const INTER_TRIAL := 0.35
const READY_TIME := 1.0
const SCORE_REPEAT := 10
const SCORE_SWITCH := 20
const BEST_PATH := "user://switch_best.cfg"
const ODD_EVEN := 0
const HIGH_LOW := 1
const BLUE := Color("#5d9bff")
const ORANGE := Color("#ffb35d")

enum Phase { READY, PLAY, GAP, OVER }

var phase := Phase.READY
var phase_left := 0.0
var score := 0
var lives := LIVES
var streak := 0
var best_score := 0
var rule := ODD_EVEN
var stay_left := 3
var is_switch := false
var number := 1
var trial_time_left := TRIAL_TIME
var waiting := false
var trial_id := 0

var score_label: Label
var lives_label: Label
var hint_label: Label
var rule_chip: Label
var number_label: Label
var left_btn: Button
var right_btn: Button
var start_btn: Button
var brief_panel: Panel
var brief_label: Label
var timer_track: ColorRect
var timer_bar: ColorRect
var restart_button: Button


func _init() -> void:
	title_text = "任务切换"
	help_text = "中央出现 1–9 的数字（没有 5）。上方色块是当前规则：蓝=奇偶，橙=大于/小于 5。\n按规则点对应按钮。规则会不时切换；切对了分更高。\n每题 3 秒，点错或超时扣命。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_rule()
	_build_number()
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

	hint_label = _make_label("", 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(hint_label)


func _build_rule() -> void:
	rule_chip = _make_label("", 28, Color("#0d1220"))
	rule_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(rule_chip)


func _build_number() -> void:
	number_label = _make_label("", 140, Color("#e8edff"))
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(number_label)

	timer_track = ColorRect.new()
	timer_track.color = Color("#1a2740")
	timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_track)
	timer_bar = ColorRect.new()
	timer_bar.color = Color("#8ab4ff")
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_track.add_child(timer_bar)


func _build_brief() -> void:
	brief_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#152034")
	style.set_corner_radius_all(14)
	brief_panel.add_theme_stylebox_override("panel", style)
	add_child(brief_panel)
	brief_label = _make_label(
		"上方色块就是当前规则。\n蓝底：判断奇数还是偶数\n橙底：判断大于 5 还是小于 5\n\n规则会换。切对了分更高。\n每题 3 秒，看清再点开始。",
		22,
		Color("#e8edff")
	)
	brief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief_label.offset_left = 24
	brief_label.offset_right = -24
	brief_panel.add_child(brief_label)


func _build_buttons() -> void:
	left_btn = Button.new()
	left_btn.focus_mode = Control.FOCUS_NONE
	left_btn.add_theme_font_size_override("font_size", 28)
	left_btn.add_theme_color_override("font_color", Color("#e8edff"))
	left_btn.pressed.connect(_on_answer.bind(0))
	add_child(left_btn)

	right_btn = Button.new()
	right_btn.focus_mode = Control.FOCUS_NONE
	right_btn.add_theme_font_size_override("font_size", 28)
	right_btn.add_theme_color_override("font_color", Color("#e8edff"))
	right_btn.pressed.connect(_on_answer.bind(1))
	add_child(right_btn)

	start_btn = Button.new()
	start_btn.text = "开始"
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.add_theme_font_size_override("font_size", 28)
	start_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(start_btn, Color("#4ade80"))
	start_btn.pressed.connect(_start_play)
	add_child(start_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and left_btn != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	rule_chip.position = Vector2(40, 148)
	rule_chip.size = Vector2(vp.x - 80.0, 80)
	_paint_rule()

	number_label.position = Vector2(40, 250)
	number_label.size = Vector2(vp.x - 80.0, 260)

	var bar_w := 400.0
	timer_track.position = Vector2((vp.x - bar_w) / 2.0, 530)
	timer_track.size = Vector2(bar_w, 12)
	timer_bar.size.y = 12

	hint_label.offset_top = 552
	hint_label.offset_bottom = 588

	var btn_w := minf(260.0, (vp.x - 80.0 - 20.0) / 2.0)
	var btn_h := 140.0
	var y := vp.y - 48.0 - btn_h
	var x := (vp.x - btn_w * 2.0 - 20.0) / 2.0
	left_btn.position = Vector2(x, y)
	left_btn.size = Vector2(btn_w, btn_h)
	left_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	right_btn.position = Vector2(x + btn_w + 20.0, y)
	right_btn.size = Vector2(btn_w, btn_h)
	right_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	start_btn.position = Vector2((vp.x - 280.0) / 2.0, y)
	start_btn.size = Vector2(280, btn_h)
	start_btn.custom_minimum_size = Vector2(280, btn_h)
	if brief_panel != null:
		brief_panel.position = Vector2(40, 250)
		brief_panel.size = Vector2(vp.x - 80.0, 260)


func _start_round() -> void:
	score = 0
	lives = LIVES
	streak = 0
	rule = ODD_EVEN if randf() < 0.5 else HIGH_LOW
	stay_left = randi_range(2, 4)
	is_switch = false
	waiting = false
	phase = Phase.READY
	phase_left = 0.0
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	var ready := "先看清蓝/橙规则"
	if best_score > 0:
		ready += " · 最佳 %d" % best_score
	_set_hint(ready, Color("#7f8ba6"))
	number_label.text = ""
	_paint_rule()
	_update_hud()


func _start_play() -> void:
	if phase != Phase.READY:
		return
	_new_trial()


func _new_trial() -> void:
	if phase == Phase.OVER:
		return
	waiting = false
	phase = Phase.PLAY
	trial_time_left = TRIAL_TIME
	is_switch = false
	stay_left -= 1
	if stay_left <= 0:
		rule = HIGH_LOW if rule == ODD_EVEN else ODD_EVEN
		stay_left = randi_range(2, 4)
		is_switch = true
	number = randi_range(1, 4) if randf() < 0.5 else randi_range(6, 9)
	number_label.text = str(number)
	number_label.modulate = Color.WHITE
	_paint_rule()
	_set_hint("规则变了" if is_switch else "判断", Color("#ffd75d") if is_switch else Color("#7f8ba6"))
	_update_hud()


func _paint_rule() -> void:
	if rule_chip == null:
		return
	var color := BLUE if rule == ODD_EVEN else ORANGE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	rule_chip.add_theme_stylebox_override("normal", style)
	rule_chip.text = "奇偶" if rule == ODD_EVEN else "大于 / 小于 5"
	if left_btn == null:
		return
	if rule == ODD_EVEN:
		left_btn.text = "奇数"
		right_btn.text = "偶数"
		_style_button(left_btn, BLUE.darkened(0.25))
		_style_button(right_btn, BLUE.darkened(0.25))
	else:
		left_btn.text = "小于 5"
		right_btn.text = "大于 5"
		_style_button(left_btn, ORANGE.darkened(0.25))
		_style_button(right_btn, ORANGE.darkened(0.25))


func _correct_side() -> int:
	if rule == ODD_EVEN:
		return 0 if number % 2 == 1 else 1
	return 0 if number < 5 else 1


func _on_answer(side: int) -> void:
	if phase != Phase.PLAY or waiting:
		return
	if side == _correct_side():
		var pts := SCORE_SWITCH if is_switch else SCORE_REPEAT
		streak += 1
		score += pts
		_set_hint("+%d%s" % [pts, " · 切对了" if is_switch else ""], Color("#4ade80"))
		_burst_feedback("+%d" % pts, Color("#4ade80"))
		number_label.modulate = Color("#4ade80")
		_update_hud()
		_begin_gap()
	else:
		_miss("点错了")


func _miss(reason: String) -> void:
	streak = 0
	lives -= 1
	_set_hint(reason, Color("#ff5d73"))
	_burst_feedback(reason, Color("#ff5d73"))
	number_label.modulate = Color("#ff5d73")
	_update_hud()
	if lives <= 0:
		_end_game()
	else:
		_begin_gap()


func _begin_gap() -> void:
	waiting = true
	phase = Phase.GAP
	trial_id += 1
	var id := trial_id
	await get_tree().create_timer(INTER_TRIAL).timeout
	if not is_inside_tree() or phase == Phase.OVER or id != trial_id:
		return
	_new_trial()


func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	if phase == Phase.READY:
		return
	if phase != Phase.PLAY or waiting:
		return
	trial_time_left -= delta
	var ratio := clampf(trial_time_left / TRIAL_TIME, 0.0, 1.0)
	timer_bar.size.x = timer_track.size.x * ratio
	timer_bar.color = Color("#ff5d73") if ratio < 0.25 else Color("#8ab4ff")
	if trial_time_left <= 0.0:
		_miss("超时")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if phase == Phase.READY:
		if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE or key.keycode == KEY_KP_ENTER:
			_start_play()
		return
	if phase != Phase.PLAY or waiting:
		return
	if key.keycode == KEY_LEFT or key.keycode == KEY_F:
		_on_answer(0)
	elif key.keycode == KEY_RIGHT or key.keycode == KEY_J:
		_on_answer(1)


func _update_hud() -> void:
	score_label.text = "得分 %d　连击 %d" % [score, streak]
	lives_label.text = "生命 %d/%d" % [lives, LIVES]
	var play := phase == Phase.PLAY and not waiting
	var ready := phase == Phase.READY
	if left_btn != null:
		left_btn.visible = not ready
		right_btn.visible = not ready
		start_btn.visible = ready
		left_btn.modulate = Color.WHITE if play else Color(1, 1, 1, 0.45)
		right_btn.modulate = Color.WHITE if play else Color(1, 1, 1, 0.45)
	if brief_panel != null:
		brief_panel.visible = ready
	if timer_track != null:
		timer_track.visible = not ready and phase != Phase.OVER


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	phase = Phase.OVER
	waiting = true
	trial_id += 1
	number_label.text = "结束"
	number_label.modulate = Color.WHITE
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
		restart_button = _make_restart_button(_restart, left_btn.position.y - 84.0)


func _restart() -> void:
	trial_id += 1
	_start_round()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.save(BEST_PATH)
