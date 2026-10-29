extends "res://scripts/GameBase.gd"
## 线索靶 AX-CPT：先看前字再看后字；只有「甲→靶」点「是」，其它点「否」（语境维持 / 主动控制）。


const ROUND_SECS := 60.0
const CUE_TIME := 0.55
const DELAY_START := 0.85
const DELAY_MIN := 0.45
const PROBE_START := 1.25
const PROBE_MIN := 0.75
const INTER_TRIAL := 0.35
const AX_RATIO_START := 0.70
const AX_RATIO_MIN := 0.55
const BEST_PATH := "user://axcpt_best.cfg"

const CUE_A := "甲"
const CUE_B := "乙"
const PROBE_X := "靶"
const PROBE_Y := "他"

const COLOR_A := Color("#5d9bff")
const COLOR_B := Color("#ffb35d")
const COLOR_X := Color("#4ade80")
const COLOR_Y := Color("#ff5d73")
const PANEL_BG := Color("#1a2740")

enum Phase { READY, CUE, DELAY, PROBE, GAP, OVER }
enum TrialKind { AX, AY, BX, BY }

var phase := Phase.READY
var score := 0
var streak := 0
var best_score := 0
var round_left := ROUND_SECS
var delay_limit := DELAY_START
var probe_limit := PROBE_START
var phase_left := 0.0
var waiting := false
var trial_id := 0
var kind := TrialKind.AX
var cue_text := CUE_A
var probe_text := PROBE_X
var is_target := true
var answered := false

var score_label: Label
var round_label: Label
var speed_label: Label
var hint_label: Label
var rule_chip: Label
var stim_panel: Panel
var stim_label: Label
var yes_btn: Button
var no_btn: Button
var start_btn: Button
var brief_panel: Panel
var brief_label: Label
var timer_track: ColorRect
var timer_bar: ColorRect
var restart_button: Button


func _init() -> void:
	title_text = "线索靶"
	help_text = "每题先出现一个「前字」（甲或乙），稍后再出现「后字」（靶或他）。\n只有「甲」后面跟「靶」才点「是」；其它组合都点「否」。\n多数时候是甲→靶，所以容易抢点「是」——乙→靶 和 甲→他 才是真正要忍住的。\n练的是把前字记在脑子里再决定，不是单纯反应快。一局约 60 秒。不承诺变聪明。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_stim()
	_build_brief()
	_build_buttons()
	_layout_board()
	_start_ready()


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

	speed_label = _make_label("", 18, Color("#8ab4ff"))
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	speed_label.offset_top = 126
	speed_label.offset_bottom = 152
	add_child(speed_label)

	hint_label = _make_label("", 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint_label)

	rule_chip = _make_label("只有 甲 → 靶 点「是」", 22, Color("#0d1220"))
	rule_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(rule_chip)


func _build_stim() -> void:
	stim_panel = Panel.new()
	stim_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stim_panel)
	_paint_stim(PANEL_BG)

	stim_label = Label.new()
	stim_label.add_theme_font_size_override("font_size", 120)
	stim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stim_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stim_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stim_panel.add_child(stim_label)

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
		"先出前字（甲/乙），再出后字（靶/他）。\n\n只有「甲 → 靶」点「是」\n其它组合一律点「否」\n\n甲→靶 很多，别养成乱点「是」。\n乙→靶、甲→他 才是要忍住的。",
		20,
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
	yes_btn = Button.new()
	yes_btn.text = "是"
	yes_btn.focus_mode = Control.FOCUS_NONE
	yes_btn.add_theme_font_size_override("font_size", 36)
	yes_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(yes_btn, Color("#4ade80"))
	yes_btn.pressed.connect(_on_answer.bind(true))
	add_child(yes_btn)

	no_btn = Button.new()
	no_btn.text = "否"
	no_btn.focus_mode = Control.FOCUS_NONE
	no_btn.add_theme_font_size_override("font_size", 36)
	no_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(no_btn, Color("#1a2740"))
	no_btn.pressed.connect(_on_answer.bind(false))
	add_child(no_btn)

	start_btn = Button.new()
	start_btn.text = "开始"
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.add_theme_font_size_override("font_size", 28)
	start_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(start_btn, Color("#4ade80"))
	start_btn.pressed.connect(_start_play)
	add_child(start_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and yes_btn != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	rule_chip.position = Vector2(40, 156)
	rule_chip.size = Vector2(vp.x - 80.0, 56)
	_paint_rule_chip()

	stim_panel.position = Vector2(48, 230)
	stim_panel.size = Vector2(vp.x - 96.0, 280)
	_paint_stim(PANEL_BG)

	var bar_w := 400.0
	timer_track.position = Vector2((vp.x - bar_w) / 2.0, 528)
	timer_track.size = Vector2(bar_w, 12)
	timer_bar.size.y = 12

	hint_label.offset_top = 548
	hint_label.offset_bottom = 592

	if brief_panel != null:
		brief_panel.position = Vector2(40, 230)
		brief_panel.size = Vector2(vp.x - 80.0, 280)

	var btn_w := minf(260.0, (vp.x - 80.0 - 20.0) / 2.0)
	var btn_h := 140.0
	var y := vp.y - 48.0 - btn_h
	var x := (vp.x - btn_w * 2.0 - 20.0) / 2.0
	yes_btn.position = Vector2(x, y)
	yes_btn.size = Vector2(btn_w, btn_h)
	yes_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	no_btn.position = Vector2(x + btn_w + 20.0, y)
	no_btn.size = Vector2(btn_w, btn_h)
	no_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	start_btn.position = Vector2((vp.x - 280.0) / 2.0, y)
	start_btn.size = Vector2(280, btn_h)
	start_btn.custom_minimum_size = Vector2(280, btn_h)


func _paint_rule_chip() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#8ab4ff")
	style.set_corner_radius_all(12)
	rule_chip.add_theme_stylebox_override("normal", style)


func _paint_stim(bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	stim_panel.add_theme_stylebox_override("panel", style)


func _start_ready() -> void:
	phase = Phase.READY
	score = 0
	streak = 0
	round_left = ROUND_SECS
	delay_limit = DELAY_START
	probe_limit = PROBE_START
	waiting = false
	answered = false
	trial_id += 1
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	stim_label.text = ""
	_paint_stim(PANEL_BG)
	var ready := "看清规则再开始"
	if best_score > 0:
		ready += " · 最佳 %d" % best_score
	_set_hint(ready, Color("#7f8ba6"))
	_update_hud()


func _start_play() -> void:
	if phase != Phase.READY:
		return
	round_left = ROUND_SECS
	_new_trial()


func _pick_kind() -> TrialKind:
	# Classic AX bias; as streak rises, slightly more AY/BX traps.
	var ax_ratio := lerpf(AX_RATIO_START, AX_RATIO_MIN, clampf(float(streak) / 12.0, 0.0, 1.0))
	var r := randf()
	if r < ax_ratio:
		return TrialKind.AX
	var trap := (r - ax_ratio) / maxf(1.0 - ax_ratio, 0.001)
	if trap < 0.34:
		return TrialKind.AY
	if trap < 0.67:
		return TrialKind.BX
	return TrialKind.BY


func _new_trial() -> void:
	if phase == Phase.OVER:
		return
	if round_left <= 0.0:
		_end_game()
		return
	kind = _pick_kind()
	match kind:
		TrialKind.AX:
			cue_text = CUE_A
			probe_text = PROBE_X
			is_target = true
		TrialKind.AY:
			cue_text = CUE_A
			probe_text = PROBE_Y
			is_target = false
		TrialKind.BX:
			cue_text = CUE_B
			probe_text = PROBE_X
			is_target = false
		TrialKind.BY:
			cue_text = CUE_B
			probe_text = PROBE_Y
			is_target = false
	delay_limit = maxf(DELAY_MIN, lerpf(DELAY_START, DELAY_MIN, clampf(float(streak) / 10.0, 0.0, 1.0)))
	probe_limit = maxf(PROBE_MIN, lerpf(PROBE_START, PROBE_MIN, clampf(float(streak) / 10.0, 0.0, 1.0)))
	answered = false
	waiting = false
	phase = Phase.CUE
	phase_left = CUE_TIME
	stim_label.text = cue_text
	stim_label.add_theme_color_override("font_color", COLOR_A if cue_text == CUE_A else COLOR_B)
	_paint_stim(PANEL_BG)
	_set_hint("记住前字…", Color("#8ab4ff"))
	timer_bar.size.x = timer_track.size.x
	timer_bar.color = Color("#8ab4ff")
	_update_hud()


func _enter_delay() -> void:
	phase = Phase.DELAY
	phase_left = delay_limit
	stim_label.text = "· · ·"
	stim_label.add_theme_color_override("font_color", Color("#7f8ba6"))
	_paint_stim(Color("#12192a"))
	_set_hint("等后字…", Color("#7f8ba6"))
	_update_hud()


func _enter_probe() -> void:
	phase = Phase.PROBE
	phase_left = probe_limit
	answered = false
	stim_label.text = probe_text
	stim_label.add_theme_color_override("font_color", COLOR_X if probe_text == PROBE_X else COLOR_Y)
	_paint_stim(PANEL_BG)
	_set_hint("甲→靶 点「是」，其它点「否」", Color("#e8edff"))
	timer_bar.size.x = timer_track.size.x
	timer_bar.color = Color("#8ab4ff")
	_update_hud()


func _on_answer(say_yes: bool) -> void:
	if phase != Phase.PROBE or answered or waiting:
		return
	answered = true
	waiting = true
	var correct := say_yes == is_target
	if correct:
		streak += 1
		var pts := 10
		if not is_target:
			# Withholding on trap (AY/BX) is the hard part.
			pts = 15 if kind == TrialKind.AY or kind == TrialKind.BX else 12
		else:
			pts = 10 + mini(streak, 8) * 2
		score += pts
		var tag := ""
		match kind:
			TrialKind.AY:
				tag = " · 忍住甲→他"
			TrialKind.BX:
				tag = " · 忍住乙→靶"
			TrialKind.BY:
				tag = " · 否"
			_:
				tag = ""
		_set_hint("+%d%s" % [pts, tag], Color("#4ade80"))
		_burst_feedback("+%d" % pts, Color("#4ade80"))
		stim_label.modulate = Color("#4ade80")
	else:
		streak = 0
		var why := "该点「是」" if is_target else "该点「否」"
		_set_hint("错了 · %s" % why, Color("#ff5d73"))
		_burst_feedback("错", Color("#ff5d73"))
		stim_label.modulate = Color("#ff5d73")
	_update_hud()
	_begin_gap()


func _miss_timeout() -> void:
	if phase != Phase.PROBE or answered:
		return
	answered = true
	waiting = true
	streak = 0
	_set_hint("超时", Color("#ff5d73"))
	_burst_feedback("超时", Color("#ff5d73"))
	stim_label.modulate = Color("#ff5d73")
	_update_hud()
	_begin_gap()


func _begin_gap() -> void:
	phase = Phase.GAP
	waiting = true
	trial_id += 1
	var id := trial_id
	await get_tree().create_timer(INTER_TRIAL).timeout
	if not is_inside_tree() or phase == Phase.OVER or id != trial_id:
		return
	stim_label.modulate = Color.WHITE
	if round_left <= 0.0:
		_end_game()
		return
	_new_trial()


func _process(delta: float) -> void:
	if phase == Phase.OVER or phase == Phase.READY:
		return
	round_left -= delta
	if round_left <= 0.0:
		round_left = 0.0
		if phase == Phase.PROBE and not answered:
			_miss_timeout()
			return
		if phase == Phase.CUE or phase == Phase.DELAY or phase == Phase.GAP:
			_end_game()
			return
	if phase == Phase.CUE:
		phase_left -= delta
		var ratio := clampf(phase_left / maxf(CUE_TIME, 0.001), 0.0, 1.0)
		timer_bar.size.x = timer_track.size.x * ratio
		if phase_left <= 0.0:
			_enter_delay()
		_update_hud()
		return
	if phase == Phase.DELAY:
		phase_left -= delta
		var ratio_d := clampf(phase_left / maxf(delay_limit, 0.001), 0.0, 1.0)
		timer_bar.size.x = timer_track.size.x * ratio_d
		timer_bar.color = Color("#7f8ba6")
		if phase_left <= 0.0:
			_enter_probe()
		_update_hud()
		return
	if phase == Phase.PROBE and not answered:
		phase_left -= delta
		var ratio_p := clampf(phase_left / maxf(probe_limit, 0.001), 0.0, 1.0)
		timer_bar.size.x = timer_track.size.x * ratio_p
		timer_bar.color = Color("#ff5d73") if ratio_p < 0.25 else Color("#8ab4ff")
		if phase_left <= 0.0:
			_miss_timeout()
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
	if phase != Phase.PROBE or answered or waiting:
		return
	if key.keycode == KEY_LEFT or key.keycode == KEY_F or key.keycode == KEY_Y:
		_on_answer(true)
	elif key.keycode == KEY_RIGHT or key.keycode == KEY_J or key.keycode == KEY_N:
		_on_answer(false)


func _update_hud() -> void:
	score_label.text = "得分 %d　连对 %d" % [score, streak]
	round_label.text = "剩余 %.0f 秒" % ceilf(maxf(round_left, 0.0))
	speed_label.text = "间隔 %.2f 秒 · 作答 %.2f 秒" % [delay_limit, probe_limit]
	var ready := phase == Phase.READY
	var playable := phase == Phase.PROBE and not answered and not waiting
	if yes_btn != null:
		yes_btn.visible = not ready
		no_btn.visible = not ready
		start_btn.visible = ready
		yes_btn.modulate = Color.WHITE if playable else Color(1, 1, 1, 0.45)
		no_btn.modulate = Color.WHITE if playable else Color(1, 1, 1, 0.45)
	if brief_panel != null:
		brief_panel.visible = ready
	if stim_panel != null:
		stim_panel.visible = not ready
	if timer_track != null:
		timer_track.visible = not ready and phase != Phase.OVER


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	waiting = true
	answered = true
	trial_id += 1
	stim_label.text = "结束"
	stim_label.modulate = Color.WHITE
	stim_label.add_theme_color_override("font_color", Color("#e8edff"))
	_paint_stim(PANEL_BG)
	var is_best := score > best_score
	if is_best:
		best_score = score
		_save_best()
	var suffix := " · 新纪录！" if is_best else ""
	if best_score > 0 and not is_best:
		suffix = " · 最佳 %d" % best_score
	_set_hint("时间到 · 得分 %d%s" % [score, suffix], Color("#ffd75d"))
	_update_hud()
	if restart_button == null:
		restart_button = _make_restart_button(_restart, yes_btn.position.y - 84.0)


func _restart() -> void:
	trial_id += 1
	_start_ready()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.save(BEST_PATH)
