extends "res://scripts/GameBase.gd"
## 反向色字 Stroop：点选项上的字，对上题目字的颜色；选项底色是干扰。


const COLORS := [
	{"name": "红", "color": Color("#ff5d73")},
	{"name": "蓝", "color": Color("#5d9bff")},
	{"name": "绿", "color": Color("#4ade80")},
	{"name": "黄", "color": Color("#ffd75d")},
]

const LIVES := 3
const TRIAL_TIME := 2.0
const INTER_TRIAL := 0.35
const HINT_IDLE := "点选项上的字，对上题目字的颜色"
const BEST_PATH := "user://stroop_best.cfg"
const TIMER_WIDTH := 400.0

var score := 0
var lives := LIVES
var streak := 0
var best_streak := 0
var best_score := 0
var trial_time_left := TRIAL_TIME
var correct_color := ""
var game_over := false
var waiting := false
var trial_id := 0

var stim_panel: Panel
var word_label: Label
var score_label: Label
var lives_label: Label
var hint_label: Label
var timer_track: ColorRect
var timer_bar: ColorRect
var color_buttons: Array[Button] = []
var restart_button: Button


func _init() -> void:
	title_text = "反向色字"
	help_text = "中央是有颜色的字，字义和字体颜色一定不同。\n点下面写着「字体颜色」的按钮。按钮底色是干扰，不要对色块。\n每答完一题四个选项会重排。每题 2 秒。点错或超时扣一命。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_color_buttons()
	_new_trial()


func _build_hud() -> void:
	score_label = _make_label("", 24, Color("#e8edff"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 72
	score_label.offset_bottom = 100
	add_child(score_label)

	lives_label = _make_label("", 20, Color("#ff8f9d"))
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lives_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lives_label.offset_top = 102
	lives_label.offset_bottom = 128
	add_child(lives_label)

	stim_panel = Panel.new()
	stim_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stim_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stim_panel.offset_left = 48
	stim_panel.offset_right = -48
	stim_panel.offset_top = 148
	stim_panel.offset_bottom = 392
	add_child(stim_panel)

	_paint_panel(Color("#1a2740"))

	word_label = Label.new()
	word_label.add_theme_font_size_override("font_size", 150)
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stim_panel.add_child(word_label)

	hint_label = _make_label(HINT_IDLE, 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 400
	hint_label.offset_bottom = 432
	add_child(hint_label)

	timer_track = ColorRect.new()
	timer_track.color = Color("#1a2740")
	timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := get_viewport_rect().size
	timer_track.position = Vector2((vp.x - TIMER_WIDTH) / 2.0, 440)
	timer_track.size = Vector2(TIMER_WIDTH, 12)
	add_child(timer_track)

	timer_bar = ColorRect.new()
	timer_bar.color = Color("#8ab4ff")
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_bar.position = Vector2.ZERO
	timer_bar.size = Vector2(TIMER_WIDTH, 12)
	timer_track.add_child(timer_bar)


func _build_color_buttons() -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 20)
	var btn_w := 260.0
	var btn_h := 160.0
	var total_w := btn_w * 2.0 + 20.0
	var total_h := btn_h * 2.0 + 20.0
	var vp := get_viewport_rect().size
	g.position = Vector2((vp.x - total_w) / 2.0, 468.0)
	g.size = Vector2(total_w, total_h)
	add_child(g)

	for _i in range(COLORS.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 44)
		btn.add_theme_color_override("font_color", Color("#0d1220"))
		btn.pressed.connect(_on_button_pressed.bind(btn))
		g.add_child(btn)
		color_buttons.append(btn)


func _paint_panel(bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	stim_panel.add_theme_stylebox_override("panel", style)


func _derange(n: int) -> Array[int]:
	var idx: Array[int] = []
	for i in range(n):
		idx.append(i)
	for _try in range(32):
		idx.shuffle()
		var ok := true
		for i in range(n):
			if idx[i] == i:
				ok = false
				break
		if ok:
			return idx
	if n >= 2:
		var tmp := idx[0]
		idx[0] = idx[1]
		idx[1] = tmp
	return idx


func _refresh_choices() -> void:
	var names: Array[int] = []
	for i in range(COLORS.size()):
		names.append(i)
	names.shuffle()
	var bgs := _derange(COLORS.size())
	for i in range(color_buttons.size()):
		var btn := color_buttons[i]
		var name_idx: int = names[i]
		var bg_idx: int = bgs[name_idx]
		btn.modulate = Color.WHITE
		btn.text = COLORS[name_idx]["name"]
		btn.add_theme_color_override("font_color", Color("#0d1220"))
		_style_button(btn, COLORS[bg_idx]["color"])


func _new_trial() -> void:
	if game_over:
		return
	waiting = false
	word_label.modulate = Color.WHITE
	trial_time_left = TRIAL_TIME
	timer_bar.size.x = TIMER_WIDTH
	timer_bar.color = Color("#8ab4ff")
	_set_hint(HINT_IDLE, Color("#7f8ba6"))

	var ink_idx := randi() % COLORS.size()
	var offset := randi() % (COLORS.size() - 1) + 1
	var word_idx := (ink_idx + offset) % COLORS.size()
	word_label.text = COLORS[word_idx]["name"]
	word_label.add_theme_color_override("font_color", COLORS[ink_idx]["color"])
	_paint_panel(Color("#1a2740"))
	correct_color = COLORS[ink_idx]["name"]
	_refresh_choices()
	_update_hud()


func _on_button_pressed(btn: Button) -> void:
	_on_color_pressed(btn.text, btn)


func _on_color_pressed(color_name: String, btn: Button) -> void:
	if game_over or waiting:
		return
	waiting = true
	if color_name == correct_color:
		streak += 1
		best_streak = maxi(best_streak, streak)
		var time_bonus := int(trial_time_left * 5.0)
		var pts := 10 + time_bonus + mini(streak, 10) * 2
		score += pts
		_set_hint("+%d" % pts, Color("#4ade80"))
		_burst_feedback("+%d" % pts, Color("#4ade80"))
		word_label.modulate = Color("#4ade80")
		_update_hud()
		_begin_gap()
	else:
		_flash_wrong(btn)
		_apply_miss("点错了")


func _apply_miss(reason: String) -> void:
	streak = 0
	lives -= 1
	_set_hint(reason, Color("#ff5d73"))
	_burst_feedback(reason, Color("#ff5d73"))
	_update_hud()
	if lives <= 0:
		_end_game()
	else:
		_begin_gap()


func _begin_gap() -> void:
	waiting = true
	trial_id += 1
	var id := trial_id
	await get_tree().create_timer(INTER_TRIAL).timeout
	if not is_inside_tree() or game_over or id != trial_id:
		return
	_new_trial()


func _flash_wrong(btn: Button) -> void:
	btn.modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(btn, "modulate", Color.WHITE, INTER_TRIAL)


func _process(delta: float) -> void:
	if game_over or waiting:
		return
	trial_time_left -= delta
	if trial_time_left <= 0.0:
		trial_time_left = 0.0
		waiting = true
		timer_bar.size.x = 0.0
		_apply_miss("超时")
		return
	var ratio := clampf(trial_time_left / TRIAL_TIME, 0.0, 1.0)
	timer_bar.size.x = TIMER_WIDTH * ratio
	timer_bar.color = Color("#ff5d73") if ratio < 0.25 else Color("#8ab4ff")


func _update_hud() -> void:
	score_label.text = "得分 %d　连击 %d" % [score, streak]
	lives_label.text = "生命 %d/%d" % [lives, LIVES]


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	game_over = true
	waiting = true
	trial_id += 1
	word_label.text = "结束"
	word_label.modulate = Color.WHITE
	word_label.add_theme_color_override("font_color", Color("#e8edff"))
	_paint_panel(Color("#1a2740"))
	timer_bar.size.x = 0.0
	_update_hud()

	var is_best := score > best_score
	if is_best:
		best_score = score
		_save_best()
	var parts: PackedStringArray = ["最佳连击 %d" % best_streak]
	if best_score > 0:
		parts.append("历史最佳 %d" % best_score)
	if is_best and score > 0:
		parts.append("新纪录")
	_set_hint(" · ".join(parts), Color("#ffd75d"))

	if restart_button == null:
		restart_button = _make_restart_button(_restart, 980.0)


func _restart() -> void:
	trial_id += 1
	score = 0
	lives = LIVES
	streak = 0
	best_streak = 0
	game_over = false
	waiting = false
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	_new_trial()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.save(BEST_PATH)
