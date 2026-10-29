extends "res://scripts/GameBase.gd"
## 中间箭头 Flanker：只看最中间的箭头方向，抑制两侧箭头的干扰。


const ROUND_SECS := 60.0
const ARROW_BASE := 5
const ARROW_HARD := 7
const TIME_START := 1.15
const TIME_MIN := 0.52
const TIME_STEP := 0.05
const TIME_RECOVER := 0.04
const SPEED_EVERY := 3
const INCON_START := 0.55
const INCON_MAX := 0.82
const INTER_TRIAL := 0.22
## 加速到此以下时关掉全屏大字 burst，只留中间变色 + 短提示。
const BURST_CUTOFF := 0.72
## 加速到此以下时改用 7 箭 + 更挤侧翼。
const HARD_CUTOFF := 0.70
const CENTER_SIZE := 88
const FLANK_SIZE := 64
const CENTER_COLOR := Color("#ffffff")
const FLANK_COLOR := Color("#9aa8c4")
const HINT_IDLE := "点最中间那个箭头的方向"
const BEST_PATH := "user://flanker_best.cfg"
const LEFT_MARK := "←"
const RIGHT_MARK := "→"

enum Phase { PLAY, OVER }

var phase := Phase.PLAY
var score := 0
var streak := 0
var best_streak := 0
var best_score := 0
var trial_limit := TIME_START
var trial_left := TIME_START
var round_left := ROUND_SECS
var waiting := false
var trial_id := 0
var center_is_left := true
var incongruent := false
var arrow_count := ARROW_BASE

var score_label: Label
var round_label: Label
var speed_label: Label
var hint_label: Label
var arrow_row: HBoxContainer
var arrows: Array[Label] = []
var timer_track: ColorRect
var timer_bar: ColorRect
var left_btn: Button
var right_btn: Button
var restart_button: Button


func _init() -> void:
	title_text = "中间箭头"
	help_text = "一排箭头。只看最中间那个，点它朝的方向。\n两边的箭头常常故意指反方向，别跟着两边走。\n连对会缩短作答时间；加速后中间会略亮略大，侧翼更挤，并关掉大字闪屏。\n一局约 60 秒。超时或点错不扣命，只断连击；时间到结算。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_arrows()
	_build_buttons()
	_layout_board()
	_new_trial()


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

	hint_label = _make_label(HINT_IDLE, 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 152
	hint_label.offset_bottom = 184
	add_child(hint_label)

	timer_track = ColorRect.new()
	timer_track.color = Color("#1a2740")
	timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_track)
	timer_bar = ColorRect.new()
	timer_bar.color = Color("#8ab4ff")
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_track.add_child(timer_bar)


func _build_arrows() -> void:
	arrow_row = HBoxContainer.new()
	arrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	arrow_row.add_theme_constant_override("separation", 8)
	arrow_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow_row)
	# Pre-create max arrows; unused stay hidden.
	for _i in range(ARROW_HARD):
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_font_size_override("font_size", FLANK_SIZE)
		lab.add_theme_color_override("font_color", FLANK_COLOR)
		arrow_row.add_child(lab)
		arrows.append(lab)


func _build_buttons() -> void:
	left_btn = Button.new()
	left_btn.text = "←  左"
	left_btn.focus_mode = Control.FOCUS_NONE
	left_btn.add_theme_font_size_override("font_size", 36)
	left_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(left_btn, Color("#1a2740"))
	left_btn.pressed.connect(_on_answer.bind(true))
	add_child(left_btn)

	right_btn = Button.new()
	right_btn.text = "右  →"
	right_btn.focus_mode = Control.FOCUS_NONE
	right_btn.add_theme_font_size_override("font_size", 36)
	right_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(right_btn, Color("#1a2740"))
	right_btn.pressed.connect(_on_answer.bind(false))
	add_child(right_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and left_btn != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	arrow_row.position = Vector2(24, 220)
	arrow_row.size = Vector2(vp.x - 48.0, 160)
	var bar_w := minf(480.0, vp.x - 80.0)
	timer_track.position = Vector2((vp.x - bar_w) / 2.0, 400)
	timer_track.size = Vector2(bar_w, 14)
	timer_bar.size.y = 14
	var btn_w := minf(280.0, (vp.x - 80.0 - 20.0) / 2.0)
	var btn_h := 150.0
	var y := vp.y - 48.0 - btn_h
	var x := (vp.x - btn_w * 2.0 - 20.0) / 2.0
	left_btn.position = Vector2(x, y)
	left_btn.size = Vector2(btn_w, btn_h)
	left_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	right_btn.position = Vector2(x + btn_w + 20.0, y)
	right_btn.size = Vector2(btn_w, btn_h)
	right_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	if restart_button != null:
		restart_button.position = Vector2((vp.x - 220.0) / 2.0, y - 80.0)


func _center_index() -> int:
	return arrow_count / 2


func _apply_arrow_layout() -> void:
	var hard := trial_limit <= HARD_CUTOFF
	arrow_count = ARROW_HARD if hard else ARROW_BASE
	arrow_row.add_theme_constant_override("separation", 4 if hard else 8)
	for i in range(arrows.size()):
		arrows[i].visible = i < arrow_count


func _new_trial() -> void:
	if phase == Phase.OVER:
		return
	waiting = false
	_apply_arrow_layout()
	incongruent = randf() < _incon_ratio()
	center_is_left = randf() < 0.5
	var flank_left := center_is_left if not incongruent else not center_is_left
	var mid := _center_index()
	for i in range(arrow_count):
		var is_center := i == mid
		var is_left := center_is_left if is_center else flank_left
		arrows[i].text = LEFT_MARK if is_left else RIGHT_MARK
		arrows[i].modulate = Color.WHITE
		if is_center:
			arrows[i].add_theme_font_size_override("font_size", CENTER_SIZE)
			arrows[i].add_theme_color_override("font_color", CENTER_COLOR)
		else:
			arrows[i].add_theme_font_size_override("font_size", FLANK_SIZE)
			arrows[i].add_theme_color_override("font_color", FLANK_COLOR)
	trial_left = trial_limit
	timer_bar.color = Color("#8ab4ff")
	_set_hint(HINT_IDLE, Color("#7f8ba6"))
	_update_hud()
	_paint_timer()


func _incon_ratio() -> float:
	var extra := 0.04 * float(maxi((TIME_START - trial_limit) / TIME_STEP, 0.0))
	return clampf(INCON_START + extra, INCON_START, INCON_MAX)


func _maybe_burst(text: String, color: Color) -> void:
	# Fast trials: big burst covers the next arrows — skip it.
	if trial_limit > BURST_CUTOFF:
		_burst_feedback(text, color)


func _on_answer(pick_left: bool) -> void:
	if phase != Phase.PLAY or waiting:
		return
	waiting = true
	var mid := _center_index()
	if pick_left == center_is_left:
		streak += 1
		best_streak = maxi(best_streak, streak)
		if streak > 0 and streak % SPEED_EVERY == 0:
			trial_limit = maxf(TIME_MIN, trial_limit - TIME_STEP)
		var time_bonus := int(trial_left / trial_limit * 8.0)
		var pts := 10 + time_bonus + mini(streak, 10) * 2
		score += pts
		arrows[mid].add_theme_color_override("font_color", Color("#4ade80"))
		_set_hint("+%d" % pts, Color("#4ade80"))
		_maybe_burst("+%d" % pts, Color("#4ade80"))
		_update_hud()
		_begin_gap()
	else:
		_apply_miss("点错了")


func _apply_miss(reason: String) -> void:
	streak = 0
	trial_limit = minf(TIME_START, trial_limit + TIME_RECOVER)
	var mid := _center_index()
	arrows[mid].add_theme_color_override("font_color", Color("#ff5d73"))
	_set_hint(reason, Color("#ff5d73"))
	_maybe_burst(reason, Color("#ff5d73"))
	_update_hud()
	_begin_gap()


func _begin_gap() -> void:
	waiting = true
	trial_id += 1
	var id := trial_id
	left_btn.modulate = Color(1, 1, 1, 0.45)
	right_btn.modulate = Color(1, 1, 1, 0.45)
	await get_tree().create_timer(INTER_TRIAL).timeout
	if not is_inside_tree() or phase != Phase.PLAY or id != trial_id:
		return
	left_btn.modulate = Color.WHITE
	right_btn.modulate = Color.WHITE
	_new_trial()


func _process(delta: float) -> void:
	if phase != Phase.PLAY:
		return
	round_left -= delta
	if round_left <= 0.0:
		round_left = 0.0
		_end_game()
		return
	_update_hud()
	if waiting:
		return
	trial_left -= delta
	if trial_left <= 0.0:
		trial_left = 0.0
		waiting = true
		_paint_timer()
		_apply_miss("超时")
		return
	_paint_timer()


func _paint_timer() -> void:
	var ratio := clampf(trial_left / maxf(trial_limit, 0.01), 0.0, 1.0)
	timer_bar.size.x = timer_track.size.x * ratio
	timer_bar.color = Color("#ff5d73") if ratio < 0.25 else Color("#8ab4ff")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if phase != Phase.PLAY or waiting:
		return
	if key.keycode == KEY_LEFT or key.keycode == KEY_F:
		_on_answer(true)
	elif key.keycode == KEY_RIGHT or key.keycode == KEY_J:
		_on_answer(false)


func _update_hud() -> void:
	score_label.text = "得分 %d　连击 %d" % [score, streak]
	round_label.text = "剩余 %.0f 秒" % ceilf(round_left)
	var hard_tag := " · 7 箭" if arrow_count >= ARROW_HARD else ""
	speed_label.text = "每题 %.2f 秒%s" % [trial_limit, hard_tag]
	var play := phase == Phase.PLAY and not waiting
	if left_btn != null:
		left_btn.modulate = Color.WHITE if play else Color(1, 1, 1, 0.45)
		right_btn.modulate = Color.WHITE if play else Color(1, 1, 1, 0.45)


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	waiting = true
	trial_id += 1
	left_btn.visible = false
	right_btn.visible = false
	timer_bar.size.x = 0.0
	_update_hud()
	var is_best := score > best_score
	if is_best:
		best_score = score
		_save_best()
	var parts: PackedStringArray = ["时间到", "最佳连击 %d" % best_streak]
	if best_score > 0:
		parts.append("历史最佳 %d" % best_score)
	if is_best and score > 0:
		parts.append("新纪录")
	_set_hint(" · ".join(parts), Color("#ffd75d"))
	if restart_button == null:
		var vp := get_viewport_rect().size
		restart_button = _make_restart_button(_restart, vp.y - 220.0)


func _restart() -> void:
	trial_id += 1
	score = 0
	streak = 0
	best_streak = 0
	trial_limit = TIME_START
	round_left = ROUND_SECS
	arrow_count = ARROW_BASE
	phase = Phase.PLAY
	waiting = false
	left_btn.visible = true
	right_btn.visible = true
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
