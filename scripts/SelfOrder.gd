extends "res://scripts/GameBase.gd"
## 各点一次 Self-Ordered Pointing：自己点遍一组图案且不重复；点完后换位置（工作记忆自我监控）。


const START_SET := 4
const MIN_SET := 4
const MAX_SET := 12
const ROUND_SECS := 60.0
const FLASH_OK := 0.14
const MOVE_TIME := 0.22
const INPUT_GAP := 0.40
const REVEAL_TIME := 0.85
const BEST_PATH := "user://selforder_best.cfg"
const IDLE_HINT := "每次点一个还没点过的图案；点完后它们会换位置"
const TOKEN_BG := Color("#1a2740")
const COLOR_OK := Color("#4ade80")
const COLOR_BAD := Color("#ff5d73")

## Shape + color are double-coded so tokens stay easy to tell apart.
const TOKENS := [
	{"shape": 0, "color": Color("#ff5d73")},
	{"shape": 1, "color": Color("#5d9bff")},
	{"shape": 2, "color": Color("#4ade80")},
	{"shape": 3, "color": Color("#ffd75d")},
	{"shape": 4, "color": Color("#ff8a3d")},
	{"shape": 5, "color": Color("#c084fc")},
	{"shape": 6, "color": Color("#2ee8d0")},
	{"shape": 7, "color": Color("#ff7ab6")},
	{"shape": 8, "color": Color("#b8f25a")},
	{"shape": 9, "color": Color("#e8edff")},
	{"shape": 10, "color": Color("#fb7185")},
	{"shape": 11, "color": Color("#38bdf8")},
]

enum Phase { PICK, PLAY, WAIT, OVER }

var phase := Phase.PLAY
var score := 0
var streak := 0
var set_size := START_SET
var best_score := 0
var best_set := START_SET
var session_best_set := START_SET
var round_left := ROUND_SECS
var picked: Array[int] = []
var slot_of: Array[int] = []
var round_id := 0
var accepting := false

var score_label: Label
var round_label: Label
var set_label: Label
var hint_label: Label
var board: Control
var tokens: Array = []
var token_styles: Array = []
var restart_button: Button


func _init() -> void:
	title_text = "各点一次"
	help_text = "画面上有一组不同的图案。每次点一个还没点过的；点完后同样的图案会换位置，再点下一个没点过的。\n不要靠位置记——每次都会换位。点到已经点过的，这一轮结束，图案数减一。全部点完则加一。\n和积木跨度不同：那里是按给定顺序复述，这里要自己记住点过哪些。一局约 60 秒。不承诺变聪明。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_board()
	_layout_board()
	if best_set > START_SET:
		_show_gate()
	else:
		set_size = START_SET
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

	set_label = _make_label("", 28, Color("#8ab4ff"))
	set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	set_label.offset_top = 126
	set_label.offset_bottom = 164
	add_child(set_label)

	hint_label = _make_label(IDLE_HINT, 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 164
	hint_label.offset_bottom = 214
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint_label)


func _build_board() -> void:
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	for i in range(MAX_SET):
		var cell := Panel.new()
		cell.visible = false
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = TOKEN_BG
		style.set_corner_radius_all(14)
		cell.add_theme_stylebox_override("panel", style)
		cell.gui_input.connect(_on_token_input.bind(i))
		var art := TokenView.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.token = TOKENS[i]
		cell.add_child(art)
		board.add_child(cell)
		tokens.append(cell)
		token_styles.append(style)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and board != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var top := 228.0
	var bottom := vp.y - 180.0
	var side := minf(vp.x - 48.0, maxf(bottom - top, 280.0))
	board.position = Vector2((vp.x - side) / 2.0, top)
	board.size = Vector2(side, side)
	_place_tokens(false)
	_layout_progress_gate()
	if restart_button != null:
		restart_button.position = Vector2((vp.x - 220.0) / 2.0, vp.y - 160.0)


## Columns for an n-item grid (last row may be short and is centered).
static func grid_columns(n: int) -> int:
	if n <= 4:
		return 2
	if n == 8:
		return 4
	if n <= 9:
		return 3
	return 4


## Slot rectangles inside a square board.
static func slot_rects(n: int, side: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cols := grid_columns(n)
	var rows := int(ceili(float(n) / float(cols)))
	var gap := 12.0
	var cell := minf((side - gap * float(cols - 1)) / float(cols), (side - gap * float(rows - 1)) / float(rows))
	var grid_w := float(cols) * cell + gap * float(cols - 1)
	var grid_h := float(rows) * cell + gap * float(rows - 1)
	var origin := Vector2((side - grid_w) / 2.0, (side - grid_h) / 2.0)
	for i in range(n):
		var r := i / cols
		var c := i % cols
		var row_count := cols if r < rows - 1 else n - r * cols
		var row_w := float(row_count) * cell + gap * float(row_count - 1)
		var x_off := (grid_w - row_w) / 2.0
		var pos := origin + Vector2(x_off + float(c) * (cell + gap), float(r) * (cell + gap))
		out.append(Rect2(pos, Vector2(cell, cell)))
	return out


## A new slot permutation; at least half the tokens change place when n > 1.
static func shuffled_slots(n: int, previous: Array[int]) -> Array[int]:
	var ids: Array[int] = []
	for i in range(n):
		ids.append(i)
	if n <= 1:
		return ids
	for _try in range(16):
		ids.shuffle()
		var moved := 0
		if previous.size() == n:
			for i in range(n):
				if ids[i] != previous[i]:
					moved += 1
		else:
			moved = n
		if moved >= maxi(n / 2, 1):
			return ids
	if previous.size() == n and n >= 2:
		ids = previous.duplicate()
		var a := ids[0]
		ids[0] = ids[1]
		ids[1] = a
	return ids


func _show_gate() -> void:
	phase = Phase.PICK
	board.visible = false
	_show_progress_gate(
		"历史最多一次点完 %d 个。\n这一局从 %d 个继续，还是从 %d 个重来？" % [best_set, best_set, START_SET],
		"从 %d 个继续" % best_set,
		"从头开始（%d 个）" % START_SET
	)
	_set_hint("选这一局从几格开始", Color("#7f8ba6"))
	_update_hud()


func _on_progress_continue() -> void:
	if phase != Phase.PICK:
		return
	set_size = clampi(best_set, MIN_SET, MAX_SET)
	_hide_progress_gate()
	board.visible = true
	_begin_round()


func _on_progress_fresh() -> void:
	if phase != Phase.PICK:
		return
	set_size = START_SET
	_hide_progress_gate()
	board.visible = true
	_begin_round()


func _begin_round() -> void:
	phase = Phase.PLAY
	score = 0
	streak = 0
	session_best_set = set_size
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
	picked.clear()
	slot_of = shuffled_slots(set_size, [])
	_reset_token_looks()
	_sync_token_visibility()
	_place_tokens(false)
	phase = Phase.PLAY
	accepting = true
	_set_hint("先点任意一个，之后不要再点它", Color("#8ab4ff"))
	_update_hud()


func _sync_token_visibility() -> void:
	for i in range(MAX_SET):
		tokens[i].visible = i < set_size
		tokens[i].modulate = Color.WHITE


func _reset_token_looks() -> void:
	for i in range(MAX_SET):
		var art: TokenView = tokens[i].get_child(0)
		art.mark = TokenView.MARK_NONE
		art.queue_redraw()
		token_styles[i].bg_color = TOKEN_BG
		tokens[i].queue_redraw()


func _place_tokens(animate: bool) -> void:
	if board == null or slot_of.size() < set_size:
		return
	var rects := slot_rects(set_size, board.size.x)
	for token_id in range(set_size):
		var slot: int = slot_of[token_id]
		var rect: Rect2 = rects[slot]
		var cell: Panel = tokens[token_id]
		if animate:
			var tw := cell.create_tween()
			tw.tween_property(cell, "position", rect.position, MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(cell, "size", rect.size, MOVE_TIME)
		else:
			cell.position = rect.position
			cell.size = rect.size


func _on_token_input(event: InputEvent, token_id: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_on_tap(token_id)


func _on_tap(token_id: int) -> void:
	if phase != Phase.PLAY or not accepting:
		return
	if token_id < 0 or token_id >= set_size:
		return
	accepting = false
	if picked.has(token_id):
		_on_trial_wrong(token_id)
		return
	picked.append(token_id)
	_paint_cell(token_id, COLOR_OK)
	var remaining := set_size - picked.size()
	if remaining <= 0:
		_on_trial_complete()
		return
	var pts := 4
	score += pts
	_play_sfx("tap")
	_set_hint("已点 %d / %d  ·  +%d" % [picked.size(), set_size, pts], Color("#4ade80"))
	_update_hud()
	_after_correct_pick()


func _after_correct_pick() -> void:
	round_id += 1
	var id := round_id
	await get_tree().create_timer(FLASH_OK).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	_paint_cell(picked[picked.size() - 1], TOKEN_BG)
	var previous := slot_of.duplicate()
	slot_of = shuffled_slots(set_size, previous)
	_place_tokens(true)
	await get_tree().create_timer(MOVE_TIME).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	if remaining_after_picked() <= 0:
		return
	accepting = true
	_set_hint("再点一个还没点过的（已点 %d / %d）" % [picked.size(), set_size], Color("#e8edff"))


func remaining_after_picked() -> int:
	return set_size - picked.size()


func _on_trial_complete() -> void:
	streak += 1
	session_best_set = maxi(session_best_set, set_size)
	if set_size > best_set:
		best_set = set_size
		_save_best()
	var bonus := 10 + set_size * 4 + mini(streak, 8) * 2
	score += bonus
	_set_hint("全部点完 +%d · %d 个" % [bonus, set_size], Color("#4ade80"))
	_burst_feedback("+%d" % bonus, Color("#4ade80"))
	set_size = mini(set_size + 1, MAX_SET)
	_update_hud()
	_after_trial()


func _on_trial_wrong(token_id: int) -> void:
	streak = 0
	_paint_cell(token_id, COLOR_BAD)
	_reveal_picked(token_id)
	_set_hint("这个点过了", Color("#ff5d73"))
	_burst_feedback("点过了", Color("#ff5d73"))
	set_size = maxi(set_size - 1, MIN_SET)
	_update_hud()
	_after_trial(REVEAL_TIME)


func _reveal_picked(wrong_id: int) -> void:
	for i in range(set_size):
		var art: TokenView = tokens[i].get_child(0)
		if i == wrong_id:
			art.mark = TokenView.MARK_BAD
		elif picked.has(i):
			art.mark = TokenView.MARK_PICKED
			if token_styles[i].bg_color != COLOR_BAD:
				token_styles[i].bg_color = Color("#1c3a2c")
		else:
			art.mark = TokenView.MARK_NONE
		art.queue_redraw()
		tokens[i].queue_redraw()


func _after_trial(delay: float = INPUT_GAP) -> void:
	phase = Phase.WAIT
	accepting = false
	round_id += 1
	var id := round_id
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or id != round_id or phase == Phase.OVER:
		return
	_reset_token_looks()
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
		if phase == Phase.PLAY or phase == Phase.WAIT:
			_end_game()
			return
	_update_hud()


func _paint_cell(token_id: int, color: Color) -> void:
	token_styles[token_id].bg_color = color
	tokens[token_id].queue_redraw()


func _update_hud() -> void:
	score_label.text = "得分 %d　连对 %d" % [score, streak]
	round_label.text = "剩余 %.0f 秒" % ceilf(maxi(round_left, 0.0))
	set_label.text = "本组 %d 个　历史最多 %d" % [set_size, best_set]


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _end_game() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	accepting = false
	round_id += 1
	_reset_token_looks()
	var is_best := score > best_score
	if is_best:
		best_score = score
	best_set = maxi(best_set, session_best_set)
	_save_best()
	_mark_session_completed()
	_update_hud()
	var parts: PackedStringArray = ["时间到", "本局最多一次点完 %d 个" % session_best_set]
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
	set_size = clampi(set_size, MIN_SET, MAX_SET)
	_begin_round()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))
		best_set = clampi(int(config.get_value("best", "set", START_SET)), MIN_SET, MAX_SET)


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.set_value("best", "set", clampi(best_set, MIN_SET, MAX_SET))
	config.save(BEST_PATH)


class TokenView extends Control:
	const MARK_NONE := 0
	const MARK_PICKED := 1
	const MARK_BAD := 2
	var token: Dictionary = {}
	var mark := MARK_NONE

	func _draw() -> void:
		if token.is_empty():
			return
		var shape: int = int(token.get("shape", 0))
		var color: Color = token.get("color", Color.WHITE)
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.32
		_draw_shape(shape, c, r, color)
		if mark == MARK_PICKED:
			_draw_check(c + Vector2(r * 0.55, r * 0.55), r * 0.38, Color("#4ade80"))
		elif mark == MARK_BAD:
			_draw_x(c + Vector2(r * 0.55, r * 0.55), r * 0.32, Color("#ffd75d"))

	func _draw_shape(shape: int, c: Vector2, r: float, color: Color) -> void:
		match shape:
			0:
				draw_circle(c, r, color)
			1:
				draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), color)
			2:
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r),
					c + Vector2(r * 0.95, r * 0.85),
					c + Vector2(-r * 0.95, r * 0.85),
				]), color)
			3:
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r),
					c + Vector2(r, 0),
					c + Vector2(0, r),
					c + Vector2(-r, 0),
				]), color)
			4:
				var t := r * 0.38
				draw_rect(Rect2(c.x - t, c.y - r, t * 2.0, r * 2.0), color)
				draw_rect(Rect2(c.x - r, c.y - t, r * 2.0, t * 2.0), color)
			5:
				draw_colored_polygon(_star_points(c, r, r * 0.42), color)
			6:
				draw_circle(c, r, color)
				draw_circle(c, r * 0.48, TOKEN_BG)
			7:
				draw_colored_polygon(_regular_poly(c, r, 6, deg_to_rad(30.0)), color)
			8:
				var tip := c + Vector2(0, -r)
				var left := c + Vector2(-r * 0.85, r * 0.15)
				var right := c + Vector2(r * 0.85, r * 0.15)
				var mid := c + Vector2(0, r * 0.05)
				var shaft := r * 0.28
				draw_colored_polygon(PackedVector2Array([tip, right, mid, left]), color)
				draw_rect(Rect2(c.x - shaft * 0.45, c.y, shaft * 0.9, r * 0.85), color)
			9:
				draw_circle(c, r, color)
				draw_circle(c + Vector2(r * 0.38, -r * 0.12), r * 0.72, TOKEN_BG)
			10:
				_draw_thick_line(c + Vector2(-r * 0.75, -r * 0.75), c + Vector2(r * 0.75, r * 0.75), r * 0.32, color)
				_draw_thick_line(c + Vector2(r * 0.75, -r * 0.75), c + Vector2(-r * 0.75, r * 0.75), r * 0.32, color)
			_:
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r),
					c + Vector2(r * 0.55, 0),
					c + Vector2(0, r),
					c + Vector2(-r * 0.55, 0),
				]), color)

	func _regular_poly(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in range(n):
			var a := rot + TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts

	func _star_points(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in range(10):
			var a := -PI / 2.0 + TAU * float(i) / 10.0
			var rad := outer if i % 2 == 0 else inner
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		return pts

	func _draw_thick_line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x) * (width * 0.5)
		draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), color)

	func _draw_check(c: Vector2, s: float, color: Color) -> void:
		_draw_thick_line(c + Vector2(-s, 0.05 * s), c + Vector2(-0.15 * s, s * 0.7), s * 0.38, color)
		_draw_thick_line(c + Vector2(-0.15 * s, s * 0.7), c + Vector2(s, -s * 0.7), s * 0.38, color)

	func _draw_x(c: Vector2, s: float, color: Color) -> void:
		_draw_thick_line(c + Vector2(-s, -s), c + Vector2(s, s), s * 0.42, color)
		_draw_thick_line(c + Vector2(s, -s), c + Vector2(-s, s), s * 0.42, color)
