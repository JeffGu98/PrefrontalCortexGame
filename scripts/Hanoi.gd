extends "res://scripts/GameBase.gd"
## 汉诺塔：三柱移盘，大不能压小，尽量用最优步数。


const MIN_DISKS := 3
const MAX_DISKS := 6
const BASE := 30
const OPTIMAL_BONUS := 50
const BEST_PATH := "user://hanoi_best.cfg"
const PEGS := 3
const DISK_COLORS := [
	Color("#ff5d73"),
	Color("#ffb35d"),
	Color("#ffd75d"),
	Color("#4ade80"),
	Color("#5d9bff"),
	Color("#c084fc"),
]

enum Phase { PLAY, WON, OVER }

var phase := Phase.PLAY
var score := 0
var best_score := 0
var disk_n := MIN_DISKS
var moves := 0
var elapsed := 0.0
var selected := -1
var animating := false
var pegs: Array = []
var disk_nodes: Dictionary = {}

var score_label: Label
var status_label: Label
var hint_label: Label
var board: Control
var peg_hits: Array[Button] = []
var restart_button: Button


func _init() -> void:
	title_text = "汉诺塔"
	help_text = "三根柱子。开始时盘子都在左边，要全部移到右边。\n点一下选出顶上的盘，再点目标柱放下。大盘不能压小盘。\n最优步数是 2^N−1。最优通关会加盘；步数太多仍可通过，但标成非最优。练的是计划，不是速度。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_board()
	_layout_board()
	_start_level()


func _build_hud() -> void:
	score_label = _make_label("", 24, Color("#e8edff"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 72
	score_label.offset_bottom = 100
	add_child(score_label)

	status_label = _make_label("", 18, Color("#8ab4ff"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_top = 100
	status_label.offset_bottom = 128
	add_child(status_label)

	hint_label = _make_label("", 18, Color("#7f8ba6"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 128
	hint_label.offset_bottom = 156
	add_child(hint_label)


func _build_board() -> void:
	board = BoardView.new()
	board.host = self
	add_child(board)
	for i in range(PEGS):
		var hit := Button.new()
		hit.text = ""
		hit.focus_mode = Control.FOCUS_NONE
		hit.flat = true
		hit.pressed.connect(_on_peg_pressed.bind(i))
		board.add_child(hit)
		peg_hits.append(hit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and board != null:
		_layout_board()
		_layout_disks(false)


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	board.position = Vector2(20, 170)
	board.size = Vector2(vp.x - 40.0, vp.y - 210.0)
	var col_w := board.size.x / PEGS
	for i in range(PEGS):
		peg_hits[i].position = Vector2(col_w * i, 0)
		peg_hits[i].size = Vector2(col_w, board.size.y)
	board.queue_redraw()


func _paint_board(c: Control) -> void:
	var s := c.size
	var col_w := s.x / PEGS
	var base_y := s.y - 36.0
	c.draw_rect(Rect2(20, base_y, s.x - 40.0, 16), Color("#1a2740"), true)
	for i in range(PEGS):
		var cx := col_w * (i + 0.5)
		var color := Color("#ffd75d") if i == selected else Color("#2a3a58")
		c.draw_rect(Rect2(cx - 8.0, 48.0, 16.0, base_y - 48.0), color, true)
		if i == 2:
			c.draw_rect(Rect2(cx - 28.0, 36.0, 56.0, 8.0), Color("#4ade80"), true)


func _start_level() -> void:
	phase = Phase.PLAY
	moves = 0
	elapsed = 0.0
	selected = -1
	animating = false
	pegs = [[], [], []]
	for size in range(disk_n, 0, -1):
		pegs[0].append(size)
	for node in disk_nodes.values():
		node.queue_free()
	disk_nodes.clear()
	for size in range(1, disk_n + 1):
		var disk := Panel.new()
		disk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = DISK_COLORS[(size - 1) % DISK_COLORS.size()]
		style.set_corner_radius_all(10)
		disk.add_theme_stylebox_override("panel", style)
		board.add_child(disk)
		disk_nodes[size] = disk
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	_layout_disks(false)
	_set_hint("把盘子移到右边绿线柱", Color("#7f8ba6"))
	_update_hud()
	board.queue_redraw()


func _layout_disks(animate: bool) -> void:
	var s := board.size
	var col_w := s.x / PEGS
	var base_y := s.y - 40.0
	var max_w := col_w - 24.0
	var min_w := col_w * 0.32
	var disk_h := clampf(28.0, 22.0, 36.0)
	for p in range(PEGS):
		var stack: Array = pegs[p]
		for i in range(stack.size()):
			var size: int = stack[i]
			var disk: Panel = disk_nodes[size]
			var t := float(size - 1) / float(maxi(disk_n - 1, 1))
			var w := lerpf(min_w, max_w, t)
			var pos := Vector2(col_w * (p + 0.5) - w / 2.0, base_y - (i + 1) * (disk_h + 4.0))
			disk.size = Vector2(w, disk_h)
			if animate:
				var tw := disk.create_tween()
				tw.tween_property(disk, "position", pos, 0.18)
			else:
				disk.position = pos


func _on_peg_pressed(peg: int) -> void:
	if phase != Phase.PLAY or animating:
		return
	if selected < 0:
		if pegs[peg].is_empty():
			return
		selected = peg
		_lift_top(peg)
		_set_hint("点目标柱放下", Color("#8ab4ff"))
		board.queue_redraw()
		return
	if peg == selected:
		selected = -1
		_layout_disks(true)
		_set_hint("把盘子移到右边绿线柱", Color("#7f8ba6"))
		board.queue_redraw()
		return
	var moving: int = pegs[selected].back()
	if not pegs[peg].is_empty() and moving > pegs[peg].back():
		_shake_disk(moving)
		_set_hint("大盘不能压小盘", Color("#ff5d73"))
		return
	pegs[selected].pop_back()
	pegs[peg].append(moving)
	selected = -1
	moves += 1
	animating = true
	_layout_disks(true)
	board.queue_redraw()
	_update_hud()
	await get_tree().create_timer(0.2).timeout
	animating = false
	if not is_inside_tree() or phase != Phase.PLAY:
		return
	_check_win()


func _lift_top(peg: int) -> void:
	if pegs[peg].is_empty():
		return
	var size: int = pegs[peg].back()
	var disk: Panel = disk_nodes[size]
	var tw := disk.create_tween()
	tw.tween_property(disk, "position:y", disk.position.y - 28.0, 0.12)


func _shake_disk(size: int) -> void:
	var disk: Panel = disk_nodes[size]
	var x := disk.position.x
	var tw := disk.create_tween()
	tw.tween_property(disk, "position:x", x + 10.0, 0.05)
	tw.tween_property(disk, "position:x", x - 10.0, 0.05)
	tw.tween_property(disk, "position:x", x, 0.05)


func _check_win() -> void:
	if pegs[2].size() < disk_n:
		return
	phase = Phase.WON
	var optimal := (1 << disk_n) - 1
	var limit := int(ceil(float(optimal) * 1.5))
	var gained := disk_n * BASE
	var extra := ""
	if moves <= optimal:
		gained += disk_n * OPTIMAL_BONUS
		extra = " · 最优"
		if disk_n < MAX_DISKS:
			disk_n += 1
			extra += " · 下一关加盘"
	elif moves <= limit:
		extra = " · 非最优，仍通过"
	else:
		extra = " · 步数偏多，仍通过"
	score += gained
	var is_best := score > best_score
	if is_best:
		best_score = score
		_save_best()
	_set_hint("过关 +%d%s" % [gained, extra], Color("#4ade80") if moves <= optimal else Color("#ffd75d"))
	_update_hud()
	if restart_button == null:
		restart_button = _make_restart_button(_next_or_restart)
		restart_button.text = "下一关"


func _optimal() -> int:
	return (1 << disk_n) - 1


func _process(delta: float) -> void:
	if phase == Phase.PLAY:
		elapsed += delta
		_update_hud()


func _update_hud() -> void:
	score_label.text = "得分 %d" % score
	status_label.text = "%d 盘　步数 %d／最优 %d　用时 %.0f 秒" % [disk_n, moves, _optimal(), elapsed]


func _set_hint(text: String, color: Color) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)


func _next_or_restart() -> void:
	if restart_button != null:
		restart_button.queue_free()
		restart_button = null
	_start_level()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		best_score = int(config.get_value("best", "score", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "score", best_score)
	config.save(BEST_PATH)


class BoardView extends Control:
	var host

	func _draw() -> void:
		if host != null:
			host._paint_board(self)
