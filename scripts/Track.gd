extends "res://scripts/GameBase.gd"
## 追踪异色球：记住异色球，同色乱动后再把它们点出来。


const LIVES := 3
const START_BALLS := 6
const MAX_BALLS := 12
const HIGHLIGHT_TIME := 1.5
const MOVE_MIN := 4.0
const MOVE_MAX := 8.0
const SCORE_ALL := 20
const BEST_PATH := "user://track_best.cfg"
const SAME := Color("#8ab4ff")
const ODD := Color("#ffd75d")
const PICK := Color("#4ade80")
const WRONG := Color("#ff5d73")

enum Phase { READY, HIGHLIGHT, MOVE, PICK, FEEDBACK, OVER }

var phase := Phase.READY
var phase_left := 0.0
var score := 0
var lives := LIVES
var streak := 0
var best_score := 0
var ball_count := START_BALLS
var odd_count := 1
var positions: Array[Vector2] = []
var velocities: Array[Vector2] = []
var targets: Array[int] = []
var picked: Array[int] = []
var radii: Array[float] = []
var pulse := 0.0

var score_label: Label
var lives_label: Label
var hint_label: Label
var canvas: TrackCanvas
var confirm_btn: Button
var restart_button: Button


func _init() -> void:
	title_text = "追踪异色球"
	help_text = "开始时若干球里会有 1–3 个黄色异色球，先记住。\n随后全部变成蓝色并乱动，停下后把刚才那些异色球点出来，再按确定。\n全对 +20 并加一个球；点错或漏选扣一命。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_canvas()
	_build_confirm()
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


func _build_canvas() -> void:
	canvas = TrackCanvas.new()
	canvas.game = self
	add_child(canvas)


func _build_confirm() -> void:
	confirm_btn = Button.new()
	confirm_btn.text = "确定"
	confirm_btn.focus_mode = Control.FOCUS_NONE
	confirm_btn.add_theme_font_size_override("font_size", 28)
	confirm_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(confirm_btn, Color("#4ade80"))
	confirm_btn.pressed.connect(_confirm)
	add_child(confirm_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and canvas != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	confirm_btn.custom_minimum_size = Vector2(240, 72)
	confirm_btn.size = Vector2(240, 72)
	confirm_btn.position = Vector2((vp.x - 240.0) / 2.0, vp.y - 48.0 - 72.0)
	hint_label.offset_top = confirm_btn.position.y - 44.0
	hint_label.offset_bottom = confirm_btn.position.y - 8.0
	canvas.position = Vector2(28, 148)
	canvas.size = Vector2(vp.x - 56.0, hint_label.offset_top - 160.0)


func _start_round() -> void:
	score = 0
	lives = LIVES
	streak = 0
	ball_count = START_BALLS
	odd_count = 1
	phase = Phase.READY
	phase_left = 1.0
	picked.clear()
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	var ready := "记住黄色的球"
	if best_score > 0:
		ready += " · 最佳 %d" % best_score
	_set_hint(ready, Color("#7f8ba6"))
	_update_hud()
	canvas.queue_redraw()


func _begin_highlight() -> void:
	if phase == Phase.OVER:
		return
	odd_count = 1 if ball_count <= 7 else (2 if ball_count <= 10 else 3)
	_spawn_balls()
	phase = Phase.HIGHLIGHT
	phase_left = HIGHLIGHT_TIME
	pulse = 0.0
	picked.clear()
	_set_hint("记住黄色的 %d 个" % odd_count, Color("#ffd75d"))
	_update_hud()
	canvas.queue_redraw()


func _spawn_balls() -> void:
	positions.clear()
	velocities.clear()
	targets.clear()
	radii.clear()
	var area := canvas.size
	var r := clampf(22.0 - (ball_count - 6) * 0.8, 16.0, 22.0)
	for i in range(ball_count):
		radii.append(r)
		var p := Vector2(r + 8.0 + randf() * maxf(area.x - r * 2.0 - 16.0, r), r + 8.0 + randf() * maxf(area.y - r * 2.0 - 16.0, r))
		positions.append(p)
		var ang := randf() * TAU
		var spd := randf_range(90.0, 140.0)
		velocities.append(Vector2(cos(ang), sin(ang)) * spd)
	var idx := range(ball_count)
	idx.shuffle()
	for i in range(odd_count):
		targets.append(int(idx[i]))


func _begin_move() -> void:
	phase = Phase.MOVE
	phase_left = clampf(MOVE_MIN + (ball_count - START_BALLS) * 0.5, MOVE_MIN, MOVE_MAX)
	_set_hint("盯住它们", Color("#7f8ba6"))
	_update_hud()


func _begin_pick() -> void:
	phase = Phase.PICK
	picked.clear()
	_set_hint("点出刚才的异色球，再确定", Color("#8ab4ff"))
	_update_hud()
	canvas.queue_redraw()


func _on_canvas_click(local: Vector2) -> void:
	if phase != Phase.PICK:
		return
	var hit := -1
	var best := 1e9
	for i in range(positions.size()):
		var d := local.distance_to(positions[i])
		if d <= radii[i] + 8.0 and d < best:
			best = d
			hit = i
	if hit < 0:
		return
	var at := picked.find(hit)
	if at >= 0:
		picked.remove_at(at)
	else:
		picked.append(hit)
	canvas.queue_redraw()
	_update_hud()


func _confirm() -> void:
	if phase != Phase.PICK:
		return
	var target_set := {}
	for t in targets:
		target_set[t] = true
	var pick_set := {}
	for p in picked:
		pick_set[p] = true
	var all_good := picked.size() == targets.size()
	if all_good:
		for t in targets:
			if not pick_set.has(t):
				all_good = false
				break
	phase = Phase.FEEDBACK
	phase_left = 1.1
	if all_good:
		streak += 1
		score += SCORE_ALL
		if ball_count < MAX_BALLS:
			ball_count += 1
		_set_hint("全对  +%d" % SCORE_ALL, Color("#4ade80"))
	else:
		streak = 0
		lives -= 1
		_set_hint("有出入", Color("#ff5d73"))
	_update_hud()
	canvas.queue_redraw()
	if lives <= 0:
		_end_game()


func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	pulse += delta
	if phase == Phase.MOVE:
		_step_move(delta)
		phase_left -= delta
		if phase_left <= 0.0:
			_begin_pick()
		canvas.queue_redraw()
		return
	if phase == Phase.HIGHLIGHT:
		phase_left -= delta
		canvas.queue_redraw()
		if phase_left <= 0.0:
			_begin_move()
		return
	if phase == Phase.READY or phase == Phase.FEEDBACK:
		phase_left -= delta
		if phase_left <= 0.0:
			if lives <= 0:
				return
			_begin_highlight()
		canvas.queue_redraw()


func _draw_balls(c: Control) -> void:
	if positions.is_empty():
		return
	for i in range(positions.size()):
		var col := SAME
		var width := 2.0
		if phase == Phase.HIGHLIGHT and targets.has(i):
			col = ODD
			width = 3.0 + sin(pulse * 8.0) * 1.5
		elif phase == Phase.PICK and picked.has(i):
			col = PICK
		elif phase == Phase.FEEDBACK:
			if targets.has(i):
				col = ODD
			if picked.has(i) and not targets.has(i):
				col = WRONG
		c.draw_circle(positions[i], radii[i], col)
		c.draw_circle(positions[i], radii[i], Color("#e8edff"), false, width)


func _step_move(delta: float) -> void:
	var area := canvas.size
	for i in range(positions.size()):
		var p := positions[i] + velocities[i] * delta
		var r: float = radii[i]
		if p.x < r:
			p.x = r
			velocities[i].x = absf(velocities[i].x)
		elif p.x > area.x - r:
			p.x = area.x - r
			velocities[i].x = -absf(velocities[i].x)
		if p.y < r:
			p.y = r
			velocities[i].y = absf(velocities[i].y)
		elif p.y > area.y - r:
			p.y = area.y - r
			velocities[i].y = -absf(velocities[i].y)
		positions[i] = p


func _update_hud() -> void:
	score_label.text = "得分 %d　连击 %d　球 %d" % [score, streak, ball_count]
	lives_label.text = "生命 %d/%d" % [lives, LIVES]
	if confirm_btn != null:
		confirm_btn.modulate = Color.WHITE if phase == Phase.PICK else Color(1, 1, 1, 0.4)


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	phase = Phase.OVER
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
		restart_button = _make_restart_button(_restart, confirm_btn.position.y - 84.0)


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


class TrackCanvas extends Control:
	var game

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var mouse := event as InputEventMouseButton
		if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and game != null:
			game._on_canvas_click(mouse.position)

	func _draw() -> void:
		if game == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color("#12192a"), true)
		game._draw_balls(self)
