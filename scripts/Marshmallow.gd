extends "res://scripts/GameBase.gd"
## 延迟满足：现在拿小分，或等待拿三倍；等待越久风险越高。


const ROUNDS := 10
const NOW_SCORE := 10
const WAIT_MULT := 3
const WAIT_MIN := 5.0
const WAIT_MAX := 15.0
const SAFE_TIME := 3.0
const FAIL_STEP := 0.04
const READY_TIME := 1.0
const FEEDBACK_TIME := 1.1
const BEST_PATH := "user://marshmallow_best.cfg"

enum Phase { READY, CHOICE, WAIT, FEEDBACK, OVER }

var phase := Phase.READY
var phase_left := 0.0
var score := 0
var best_score := 0
var round_index := 0
var wait_time := 8.0
var wait_elapsed := 0.0
var fail_check_at := 3.0
var last_gain := 0
var shattered := false

var score_label: Label
var round_label: Label
var hint_label: Label
var now_btn: Button
var wait_btn: Button
var abort_btn: Button
var bar_track: ColorRect
var bar_fill: ColorRect
var restart_button: Button


func _init() -> void:
	title_text = "延迟满足"
	help_text = "每轮二选一：现在拿 10 分，或等待若干秒拿 30 分。\n等待前 3 秒安全，之后每过一秒失败风险升高，失败这轮归零。\n可以中途放弃，拿到按进度折算的部分分。一局 10 轮，练的是策略不是手速。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_buttons()
	_layout_board()
	_start_round()


func _build_hud() -> void:
	score_label = _make_label("", 28, Color("#e8edff"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 72
	score_label.offset_bottom = 112
	add_child(score_label)

	round_label = _make_label("", 20, Color("#8ab4ff"))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	round_label.offset_top = 112
	round_label.offset_bottom = 140
	add_child(round_label)

	hint_label = _make_label("", 20, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 220
	hint_label.offset_bottom = 320
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint_label)

	bar_track = ColorRect.new()
	bar_track.color = Color("#1a2740")
	bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_track)
	bar_fill = ColorRect.new()
	bar_fill.color = Color("#ffd75d")
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_track.add_child(bar_fill)


func _build_buttons() -> void:
	now_btn = Button.new()
	now_btn.focus_mode = Control.FOCUS_NONE
	now_btn.add_theme_font_size_override("font_size", 24)
	now_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(now_btn, Color("#1a2740"))
	now_btn.pressed.connect(_take_now)
	add_child(now_btn)

	wait_btn = Button.new()
	wait_btn.focus_mode = Control.FOCUS_NONE
	wait_btn.add_theme_font_size_override("font_size", 24)
	wait_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(wait_btn, Color("#ffd75d"))
	wait_btn.pressed.connect(_start_wait)
	add_child(wait_btn)

	abort_btn = Button.new()
	abort_btn.text = "放弃，拿部分分"
	abort_btn.focus_mode = Control.FOCUS_NONE
	abort_btn.add_theme_font_size_override("font_size", 22)
	abort_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(abort_btn, Color("#1a2740"))
	abort_btn.pressed.connect(_abort_wait)
	add_child(abort_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and now_btn != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var btn_w := minf(560.0, vp.x - 80.0)
	var btn_h := 88.0
	var x := (vp.x - btn_w) / 2.0
	wait_btn.position = Vector2(x, vp.y - 48.0 - btn_h)
	wait_btn.size = Vector2(btn_w, btn_h)
	now_btn.position = Vector2(x, wait_btn.position.y - 16.0 - btn_h)
	now_btn.size = Vector2(btn_w, btn_h)
	abort_btn.position = Vector2(x, vp.y - 48.0 - btn_h)
	abort_btn.size = Vector2(btn_w, btn_h)
	bar_track.position = Vector2(x, 360)
	bar_track.size = Vector2(btn_w, 18)
	bar_fill.size.y = 18


func _start_round() -> void:
	score = 0
	round_index = 0
	phase = Phase.READY
	phase_left = READY_TIME
	shattered = false
	score_label.modulate = Color.WHITE
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	var ready := "10 轮 · 策略选择"
	if best_score > 0:
		ready += " · 最佳 %d" % best_score
	_set_hint(ready, Color("#7f8ba6"))
	_update_hud()


func _begin_choice() -> void:
	if round_index >= ROUNDS:
		_end_game()
		return
	wait_time = randf_range(WAIT_MIN, WAIT_MAX)
	wait_elapsed = 0.0
	fail_check_at = SAFE_TIME
	shattered = false
	score_label.modulate = Color.WHITE
	phase = Phase.CHOICE
	now_btn.text = "现在拿 %d 分" % NOW_SCORE
	wait_btn.text = "等待 %.0f 秒拿 %d 分" % [wait_time, NOW_SCORE * WAIT_MULT]
	_set_hint("这一轮怎么拿分？等待越久，风险越高。", Color("#7f8ba6"))
	_update_hud()


func _take_now() -> void:
	if phase != Phase.CHOICE:
		return
	_award(NOW_SCORE, "收下 %d 分" % NOW_SCORE, Color("#8ab4ff"))


func _start_wait() -> void:
	if phase != Phase.CHOICE:
		return
	phase = Phase.WAIT
	wait_elapsed = 0.0
	fail_check_at = SAFE_TIME
	_set_hint("等待中 · 随时可以放弃拿部分分", Color("#ffd75d"))
	_update_hud()


func _abort_wait() -> void:
	if phase != Phase.WAIT:
		return
	var ratio := clampf(wait_elapsed / wait_time, 0.0, 1.0)
	var gain := int(round(NOW_SCORE + float(NOW_SCORE * (WAIT_MULT - 1)) * ratio))
	_award(gain, "中途收下 %d 分" % gain, Color("#8ab4ff"))


func _award(gain: int, text: String, color: Color) -> void:
	last_gain = gain
	score += gain
	round_index += 1
	phase = Phase.FEEDBACK
	phase_left = FEEDBACK_TIME
	_set_hint(text, color)
	_update_hud()


func _fail_wait() -> void:
	last_gain = 0
	round_index += 1
	shattered = true
	phase = Phase.FEEDBACK
	phase_left = FEEDBACK_TIME
	score_label.modulate = Color("#ff5d73")
	var tw := create_tween()
	tw.tween_property(score_label, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.2)
	_set_hint("等待落空 · 这轮 0 分", Color("#ff5d73"))
	_update_hud()


func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	if phase == Phase.WAIT:
		wait_elapsed += delta
		var ratio := clampf(wait_elapsed / wait_time, 0.0, 1.0)
		bar_fill.size.x = bar_track.size.x * ratio
		while wait_elapsed >= fail_check_at and fail_check_at < wait_time:
			var seconds_past := fail_check_at - SAFE_TIME
			if seconds_past > 0.0:
				var p := minf(0.45, FAIL_STEP * seconds_past)
				if randf() < p:
					_fail_wait()
					return
			fail_check_at += 1.0
		if wait_elapsed >= wait_time:
			_award(NOW_SCORE * WAIT_MULT, "等到了  +%d" % (NOW_SCORE * WAIT_MULT), Color("#4ade80"))
		_update_hud()
		return
	phase_left -= delta
	if phase_left > 0.0:
		_update_hud()
		return
	if phase == Phase.READY or phase == Phase.FEEDBACK:
		_begin_choice()


func _update_hud() -> void:
	score_label.text = "总分 %d" % score
	score_label.pivot_offset = score_label.size / 2.0
	round_label.text = "第 %d／%d 轮" % [mini(round_index + 1, ROUNDS), ROUNDS]
	var choice := phase == Phase.CHOICE
	var waiting := phase == Phase.WAIT
	now_btn.visible = choice
	wait_btn.visible = choice
	abort_btn.visible = waiting
	bar_track.visible = waiting or (phase == Phase.FEEDBACK and last_gain != NOW_SCORE)
	if phase == Phase.CHOICE:
		bar_fill.size.x = 0.0


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	phase = Phase.OVER
	now_btn.visible = false
	wait_btn.visible = false
	abort_btn.visible = false
	var is_best := score > best_score
	if is_best:
		best_score = score
		_save_best()
	var suffix := " · 新纪录！" if is_best else ""
	if best_score > 0 and not is_best:
		suffix = " · 最佳 %d" % best_score
	_set_hint("10 轮结束 · 总分 %d%s" % [score, suffix], Color("#ffd75d"))
	_update_hud()
	if restart_button == null:
		restart_button = _make_restart_button(_restart, abort_btn.position.y - 20.0)


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
