extends "res://scripts/GameBase.gd"
## 反向反应 Go/No-Go：绿圆点它，红圆别点；抑制已经准备好的动作。


const LIVES := 3
const DISPLAY_TIME := 1.0
const GAP_MIN := 0.9
const GAP_MAX := 1.4
const READY_TIME := 1.0
const RULE_TIME := 1.2
const GO_RATIO := 0.75
const MAX_GO_STREAK := 4
const FLIP_AFTER := 10
const SCORE_GO := 10
const SCORE_NOGO := 15
const BEST_PATH := "user://gonogo_best.cfg"
const GREEN := Color("#4ade80")
const RED := Color("#ff5d73")

enum Phase { READY, GAP, STIM, RULE, OVER }

var phase := Phase.READY
var phase_left := 0.0
var score := 0
var lives := LIVES
var streak := 0
var best_score := 0
var is_go := true
var reversed := false
var consecutive_go := 0
var corrects_since_flip := 0

var score_label: Label
var lives_label: Label
var hint_label: Label
var rule_panel: Panel
var green_chip: Label
var red_chip: Label
var stim_btn: Button
var tap_btn: Button
var timer_track: ColorRect
var timer_bar: ColorRect
var restart_button: Button


func _init() -> void:
	title_text = "反向反应"
	help_text = "圆出现之后再决定点不点。点圆或底部「点」都可以。\n默认：绿圆要点，红圆不要点。点中绿圆得 10 分，红圆忍住得 15 分。\n点了不该点的、或该点却没点，都扣一命。连对多次后规则会反转，看顶部色块上的「点 / 停」。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_rule()
	_build_stim()
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
	rule_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a2740")
	style.set_corner_radius_all(12)
	rule_panel.add_theme_stylebox_override("panel", style)
	add_child(rule_panel)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	rule_panel.add_child(row)

	green_chip = _make_chip()
	red_chip = _make_chip()
	row.add_child(green_chip)
	row.add_child(red_chip)


func _make_chip() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("#0d1220"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_stim() -> void:
	stim_btn = Button.new()
	stim_btn.text = ""
	stim_btn.focus_mode = Control.FOCUS_NONE
	stim_btn.visible = false
	stim_btn.pressed.connect(_on_tap)
	add_child(stim_btn)

	timer_track = ColorRect.new()
	timer_track.color = Color("#1a2740")
	timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_track.visible = false
	add_child(timer_track)

	timer_bar = ColorRect.new()
	timer_bar.color = Color("#8ab4ff")
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_bar.position = Vector2.ZERO
	timer_track.add_child(timer_bar)


func _build_tap() -> void:
	tap_btn = Button.new()
	tap_btn.text = "点"
	tap_btn.focus_mode = Control.FOCUS_NONE
	tap_btn.add_theme_font_size_override("font_size", 40)
	tap_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(tap_btn, Color("#1a2740"))
	tap_btn.pressed.connect(_on_tap)
	add_child(tap_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and tap_btn != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	rule_panel.position = Vector2(40, 148)
	rule_panel.size = Vector2(vp.x - 80.0, 72)

	var tap_w := minf(520.0, vp.x - 80.0)
	var tap_h := 150.0
	tap_btn.position = Vector2((vp.x - tap_w) / 2.0, vp.y - 48.0 - tap_h)
	tap_btn.size = Vector2(tap_w, tap_h)
	tap_btn.custom_minimum_size = Vector2(tap_w, tap_h)
	tap_btn.pivot_offset = Vector2(tap_w, tap_h) * 0.5

	var stim_size := clampf(tap_btn.position.y - 280.0, 160.0, 260.0)
	stim_btn.position = Vector2((vp.x - stim_size) / 2.0, 248.0)
	stim_btn.size = Vector2(stim_size, stim_size)
	stim_btn.custom_minimum_size = Vector2(stim_size, stim_size)
	stim_btn.pivot_offset = Vector2(stim_size, stim_size) * 0.5

	var bar_w := 220.0
	timer_track.position = Vector2((vp.x - bar_w) / 2.0, stim_btn.position.y + stim_size + 18.0)
	timer_track.size = Vector2(bar_w, 8)
	timer_bar.size.y = 8

	var hint_y := timer_track.position.y + 22.0
	hint_label.offset_top = hint_y
	hint_label.offset_bottom = hint_y + 40.0


func _start_round() -> void:
	score = 0
	lives = LIVES
	streak = 0
	reversed = false
	consecutive_go = 0
	corrects_since_flip = 0
	phase = Phase.READY
	phase_left = READY_TIME
	stim_btn.visible = false
	stim_btn.scale = Vector2.ONE
	tap_btn.scale = Vector2.ONE
	timer_track.visible = false
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	_refresh_rule_chips()
	var ready := "绿点红停"
	if best_score > 0:
		ready += " · 最佳 %d" % best_score
	_set_hint(ready, Color("#7f8ba6"))
	_update_hud()


func _pick_trial() -> void:
	if consecutive_go >= MAX_GO_STREAK:
		is_go = false
		consecutive_go = 0
	else:
		is_go = randf() < GO_RATIO
		consecutive_go = consecutive_go + 1 if is_go else 0


func _stim_color() -> Color:
	if is_go:
		return GREEN if not reversed else RED
	return RED if not reversed else GREEN


func _show_stim() -> void:
	if phase == Phase.OVER:
		return
	_pick_trial()
	var color := _stim_color()
	_style_circle(stim_btn, color)
	stim_btn.visible = true
	stim_btn.scale = Vector2(0.82, 0.82)
	var tw := create_tween()
	tw.tween_property(stim_btn, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tap_btn.scale = Vector2(1.12, 1.12)
	var tw2 := create_tween()
	tw2.tween_property(tap_btn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	timer_track.visible = true
	timer_bar.size.x = timer_track.size.x
	timer_bar.color = Color("#8ab4ff")
	phase = Phase.STIM
	phase_left = DISPLAY_TIME
	_set_hint("出现了", Color("#7f8ba6"))
	_update_hud()


func _style_circle(btn: Button, color: Color) -> void:
	var radius := int(maxi(int(btn.size.x), 80) / 2)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(radius)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)


func _refresh_rule_chips() -> void:
	green_chip.text = "绿  ·  点" if not reversed else "绿  ·  停"
	red_chip.text = "红  ·  停" if not reversed else "红  ·  点"
	_chip_bg(green_chip, GREEN)
	_chip_bg(red_chip, RED)


func _chip_bg(label: Label, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal", style)


func _begin_gap() -> void:
	if phase == Phase.OVER:
		return
	stim_btn.visible = false
	stim_btn.scale = Vector2.ONE
	timer_track.visible = false
	phase = Phase.GAP
	phase_left = randf_range(GAP_MIN, GAP_MAX)
	_update_hud()


func _begin_rule_change() -> void:
	reversed = not reversed
	corrects_since_flip = 0
	consecutive_go = 0
	stim_btn.visible = false
	timer_track.visible = false
	_refresh_rule_chips()
	phase = Phase.RULE
	phase_left = RULE_TIME
	_set_hint("规则反转！", Color("#ffd75d"))
	_update_hud()


func _on_tap() -> void:
	if phase != Phase.STIM:
		return
	if is_go:
		_succeed(SCORE_GO, "点中")
	else:
		_miss("不该点")


func _succeed(points: int, reason: String) -> void:
	streak += 1
	score += points
	corrects_since_flip += 1
	_set_hint("%s  +%d" % [reason, points], Color("#4ade80"))
	_update_hud()
	if corrects_since_flip >= FLIP_AFTER:
		_begin_rule_change()
	else:
		_begin_gap()


func _miss(reason: String) -> void:
	streak = 0
	lives -= 1
	_set_hint(reason, Color("#ff5d73"))
	_update_hud()
	if lives <= 0:
		_end_game()
	else:
		_begin_gap()


func _timeout() -> void:
	if is_go:
		_miss("没点到")
	else:
		_succeed(SCORE_NOGO, "忍住了")


func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	phase_left -= delta
	if phase == Phase.STIM:
		var ratio := clampf(phase_left / DISPLAY_TIME, 0.0, 1.0)
		timer_bar.size.x = timer_track.size.x * ratio
		timer_bar.color = Color("#ff5d73") if ratio < 0.25 else Color("#8ab4ff")
		if phase_left <= 0.0:
			_timeout()
		_update_hud()
		return
	if phase_left > 0.0:
		_update_hud()
		return
	if phase == Phase.READY or phase == Phase.GAP or phase == Phase.RULE:
		_show_stim()


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.STIM:
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
		tap_btn.modulate = Color.WHITE if phase == Phase.STIM else Color(1, 1, 1, 0.45)


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	phase = Phase.OVER
	stim_btn.visible = false
	timer_track.visible = false
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
