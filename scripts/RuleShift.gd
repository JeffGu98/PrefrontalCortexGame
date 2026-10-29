extends "res://scripts/GameBase.gd"
## 规则变了：按隐藏维度（颜色/形状/数量）把卡片归到匹配的那一堆；规则会不宣告地切换。


const ROUND_SECS := 60.0
const SWITCH_AFTER_MIN := 4
const SWITCH_AFTER_MAX := 7
const TRIAL_TIME_START := 3.2
const TRIAL_TIME_MIN := 1.6
const TIME_STEP := 0.12
const INTER_TRIAL := 0.35
const BEST_PATH := "user://ruleshift_best.cfg"

const DIM_COLOR := 0
const DIM_SHAPE := 1
const DIM_COUNT := 2

const COLORS := [
	{"id": 0, "name": "红", "color": Color("#ff5d73")},
	{"id": 1, "name": "蓝", "color": Color("#5d9bff")},
	{"id": 2, "name": "绿", "color": Color("#4ade80")},
]
const SHAPES := ["●", "■", "▲"]
const COUNTS := [1, 2, 3]

enum Phase { PLAY, GAP, OVER }

var phase := Phase.PLAY
var score := 0
var streak := 0
var best_score := 0
var rule := DIM_COLOR
var until_switch := 5
var since_switch := 0
var round_left := ROUND_SECS
var trial_limit := TRIAL_TIME_START
var trial_left := TRIAL_TIME_START
var waiting := false
var trial_id := 0
var stim: Dictionary = {}
var choices: Array = []  # three cards; index = which pile
var correct_pile := 0

var score_label: Label
var round_label: Label
var speed_label: Label
var hint_label: Label
var stim_panel: Panel
var stim_draw: Control
var pile_btns: Array[Button] = []
var pile_draws: Array = []
var timer_track: ColorRect
var timer_bar: ColorRect
var restart_button: Button


func _init() -> void:
	title_text = "规则变了"
	help_text = "上方是一张卡片，有颜色、形状、数量三个特征。下方三堆各只在一个特征上和它对得上。\n当前有一条隐藏规则（按颜色 / 按形状 / 按数量），点对上规则的那一堆。\n对了几轮后规则会换，只提示「规则变了」，不告诉你换成哪条。\n和「任务切换」不同：那里规则用蓝/橙直接标出，这里要自己从对错里推断。\n一局约 60 秒。不承诺变聪明。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_stim()
	_build_piles()
	_layout_board()
	_pick_new_rule(true)
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

	hint_label = _make_label("点与隐藏规则相符的那一堆", 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 152
	hint_label.offset_bottom = 184
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint_label)

	timer_track = ColorRect.new()
	timer_track.color = Color("#1a2740")
	timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_track)
	timer_bar = ColorRect.new()
	timer_bar.color = Color("#8ab4ff")
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_track.add_child(timer_bar)


func _build_stim() -> void:
	stim_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#152034")
	style.set_corner_radius_all(16)
	stim_panel.add_theme_stylebox_override("panel", style)
	add_child(stim_panel)
	stim_draw = CardView.new()
	stim_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stim_panel.add_child(stim_draw)


func _build_piles() -> void:
	for i in range(3):
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = ""
		_style_button(btn, Color("#1a2740"))
		btn.pressed.connect(_on_pick.bind(i))
		add_child(btn)
		pile_btns.append(btn)
		var draw := CardView.new()
		draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(draw)
		pile_draws.append(draw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and stim_panel != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var stim_w := minf(280.0, vp.x - 96.0)
	var stim_h := 168.0
	stim_panel.position = Vector2((vp.x - stim_w) / 2.0, 200.0)
	stim_panel.size = Vector2(stim_w, stim_h)
	stim_draw.position = Vector2(12, 12)
	stim_draw.size = Vector2(stim_w - 24.0, stim_h - 24.0)

	var bar_w := minf(480.0, vp.x - 80.0)
	timer_track.position = Vector2((vp.x - bar_w) / 2.0, 384.0)
	timer_track.size = Vector2(bar_w, 12)
	timer_bar.size.y = 12

	var pile_w := minf(200.0, (vp.x - 64.0 - 24.0) / 3.0)
	var pile_h := 150.0
	var total_w := pile_w * 3.0 + 24.0
	var x0 := (vp.x - total_w) / 2.0
	var y := vp.y - 48.0 - pile_h
	for i in range(3):
		pile_btns[i].position = Vector2(x0 + i * (pile_w + 12.0), y)
		pile_btns[i].size = Vector2(pile_w, pile_h)
		pile_btns[i].custom_minimum_size = Vector2(pile_w, pile_h)
		pile_draws[i].position = Vector2(10, 10)
		pile_draws[i].size = Vector2(pile_w - 20.0, pile_h - 20.0)
	if restart_button != null:
		restart_button.position = Vector2((vp.x - 220.0) / 2.0, y - 80.0)


func _pick_new_rule(silent: bool) -> void:
	var options: Array[int] = [DIM_COLOR, DIM_SHAPE, DIM_COUNT]
	if not silent:
		options.erase(rule)
	rule = options[randi() % options.size()]
	until_switch = randi_range(SWITCH_AFTER_MIN, SWITCH_AFTER_MAX)
	since_switch = 0


func _card(color_id: int, shape_id: int, count_id: int) -> Dictionary:
	return {"color": color_id, "shape": shape_id, "count": count_id}


func _new_trial() -> void:
	if phase == Phase.OVER:
		return
	waiting = false
	stim = _random_card()
	choices = _build_choices(stim)
	correct_pile = rule  # pile i matches stim only on dimension i
	stim_draw.card = stim
	stim_draw.queue_redraw()
	for i in range(3):
		pile_draws[i].card = choices[i]
		pile_draws[i].queue_redraw()
		pile_btns[i].modulate = Color.WHITE
	trial_left = trial_limit
	_set_hint("点与隐藏规则相符的那一堆", Color("#7f8ba6"))
	_update_hud()
	_paint_timer()


func _random_card() -> Dictionary:
	return _card(randi() % 3, randi() % 3, randi() % 3)


func _build_choices(s: Dictionary) -> Array:
	# Three piles: each matches stim on exactly one dimension.
	var out: Array = []
	var keys := ["color", "shape", "count"]
	for dim in range(3):
		var c := {"color": int(s["color"]), "shape": int(s["shape"]), "count": int(s["count"])}
		for other in range(3):
			if other == dim:
				continue
			var cur: int = int(c[keys[other]])
			var vals: Array[int] = []
			for v in range(3):
				if v != cur:
					vals.append(v)
			c[keys[other]] = vals[randi() % vals.size()]
		out.append(c)
	return out


func _on_pick(pile: int) -> void:
	if phase != Phase.PLAY or waiting:
		return
	waiting = true
	if pile == correct_pile:
		streak += 1
		since_switch += 1
		var pts := 10 + mini(streak, 8) * 2
		if since_switch == 1 and score > 0:
			pts += 10  # first hit after a switch
		score += pts
		if streak > 0 and streak % 3 == 0:
			trial_limit = maxf(TRIAL_TIME_MIN, trial_limit - TIME_STEP)
		pile_btns[pile].modulate = Color("#4ade80")
		_set_hint("+%d" % pts, Color("#4ade80"))
		_burst_feedback("+%d" % pts, Color("#4ade80"))
		_update_hud()
		var switched := false
		if since_switch >= until_switch:
			_pick_new_rule(false)
			switched = true
		_begin_gap(switched)
	else:
		_apply_miss(pile)


func _apply_miss(pile: int) -> void:
	streak = 0
	since_switch = 0
	trial_limit = minf(TRIAL_TIME_START, trial_limit + TIME_STEP * 0.5)
	pile_btns[pile].modulate = Color("#ff5d73")
	pile_btns[correct_pile].modulate = Color("#4ade80")
	_set_hint("不对 · 再推断", Color("#ff5d73"))
	_burst_feedback("错", Color("#ff5d73"))
	# Wrong answers also slowly shift — keep same rule but reset switch counter.
	until_switch = randi_range(SWITCH_AFTER_MIN, SWITCH_AFTER_MAX)
	_update_hud()
	_begin_gap(false)


func _begin_gap(announce_switch: bool) -> void:
	waiting = true
	trial_id += 1
	var id := trial_id
	await get_tree().create_timer(INTER_TRIAL).timeout
	if not is_inside_tree() or id != trial_id or phase == Phase.OVER:
		return
	if announce_switch:
		_set_hint("规则变了", Color("#ffd75d"))
		_burst_feedback("规则变了", Color("#ffd75d"))
		await get_tree().create_timer(0.55).timeout
		if not is_inside_tree() or id != trial_id or phase == Phase.OVER:
			return
	if round_left <= 0.0:
		_end_game()
		return
	phase = Phase.PLAY
	_new_trial()


func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	round_left -= delta
	if round_left <= 0.0:
		round_left = 0.0
		_end_game()
		return
	_update_hud()
	if phase != Phase.PLAY or waiting:
		return
	trial_left -= delta
	if trial_left <= 0.0:
		trial_left = 0.0
		waiting = true
		_paint_timer()
		streak = 0
		_set_hint("超时", Color("#ff5d73"))
		_burst_feedback("超时", Color("#ff5d73"))
		_begin_gap(false)
		return
	_paint_timer()


func _paint_timer() -> void:
	var ratio := clampf(trial_left / maxf(trial_limit, 0.01), 0.0, 1.0)
	timer_bar.size.x = timer_track.size.x * ratio
	timer_bar.color = Color("#ff5d73") if ratio < 0.25 else Color("#8ab4ff")


func _update_hud() -> void:
	score_label.text = "得分 %d　连对 %d" % [score, streak]
	round_label.text = "剩余 %.0f 秒" % ceilf(maxi(round_left, 0.0))
	speed_label.text = "每题 %.1f 秒" % trial_limit


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	waiting = true
	trial_id += 1
	for btn in pile_btns:
		btn.visible = false
	timer_bar.size.x = 0.0
	var is_best := score > best_score
	if is_best:
		best_score = score
		_save_best()
	_update_hud()
	var parts: PackedStringArray = ["时间到"]
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
	trial_limit = TRIAL_TIME_START
	round_left = ROUND_SECS
	phase = Phase.PLAY
	waiting = false
	for btn in pile_btns:
		btn.visible = true
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	_pick_new_rule(true)
	_new_trial()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.save(BEST_PATH)


class CardView extends Control:
	const PALETTE := [Color("#ff5d73"), Color("#5d9bff"), Color("#4ade80")]
	const GLYPHS := ["●", "■", "▲"]
	const NUMS := [1, 2, 3]
	var card: Dictionary = {"color": 0, "shape": 0, "count": 0}

	func _draw() -> void:
		var c_id: int = clampi(int(card.get("color", 0)), 0, 2)
		var s_id: int = clampi(int(card.get("shape", 0)), 0, 2)
		var n_id: int = clampi(int(card.get("count", 0)), 0, 2)
		var color: Color = PALETTE[c_id]
		var shape: String = GLYPHS[s_id]
		var count: int = NUMS[n_id]
		var font := ThemeDB.fallback_font
		var font_size := clampi(int(minf(size.x, size.y) * 0.42), 28, 64)
		var glyph_w := font.get_string_size(shape, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var gap := glyph_w * 0.15
		var total_w := glyph_w * float(count) + gap * float(count - 1)
		var x := (size.x - total_w) / 2.0
		var y := (size.y + float(font_size)) / 2.0 - 4.0
		for i in range(count):
			draw_string(font, Vector2(x + float(i) * (glyph_w + gap), y), shape, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
