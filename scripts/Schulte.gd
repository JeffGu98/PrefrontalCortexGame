extends "res://scripts/GameBase.gd"
## 舒尔特方格：动物线图沿轮廓切成不规则块，数字叠在块上。


const MIN_SIZE := 5
const MAX_SIZE := 7
const BEST_PATH := "user://schulte_best.cfg"
const HUD_TOP := 156.0
const SIDE_MARGIN := 28.0
const BOTTOM_RESERVE := 108.0
const RESTART_W := 220.0
const RESTART_H := 60.0
const NEXT_BOARD_GAP := 0.7
const MASK_SIZE := 240
const CRACK := 1.6
const BG := Color("#0d1220")
const LINE := Color("#f3ead2")
const ANIMALS := [
	{"id": "cat", "name": "猫", "path": "res://assets/schulte/cat.png"},
	{"id": "dog", "name": "狗", "path": "res://assets/schulte/dog.png"},
	{"id": "fox", "name": "狐狸", "path": "res://assets/schulte/fox.png"},
	{"id": "panda", "name": "熊猫", "path": "res://assets/schulte/panda.png"},
	{"id": "elephant", "name": "大象", "path": "res://assets/schulte/elephant.png"},
	{"id": "owl", "name": "猫头鹰", "path": "res://assets/schulte/owl.png"},
	{"id": "tiger", "name": "老虎", "path": "res://assets/schulte/tiger.png"},
	{"id": "rabbit", "name": "兔子", "path": "res://assets/schulte/rabbit.png"},
	{"id": "penguin", "name": "企鹅", "path": "res://assets/schulte/penguin.png"},
	{"id": "deer", "name": "小鹿", "path": "res://assets/schulte/deer.png"},
]

enum Phase { GATE, PLAY }

var phase := Phase.PLAY
var grid_size := MIN_SIZE
var latest_size := MIN_SIZE
var next_number := 1
var started := false
var elapsed := 0.0
var finished := false
var mistakes := 0
var board_id := 0
var best_times := {5: -1.0, 6: -1.0, 7: -1.0}
var last_animal_id := ""
var animal_id := ""
var animal_name := ""
var animal_img: Image
var piece_info: Array = []

var board: Control
var time_label: Label
var status_label: Label
var restart_button: Button
var cells: Array = []


func _init() -> void:
	title_text = "舒尔特方格"
	help_text = "每盘抽一张动物线图，沿外轮廓切成不规则小块，数字叠在块上。从 1 开始按顺序点，越快越好。点对揭开这块，点错闪红但不重来。第一次点击开始计时。\n点完 5×5 会上 6×6，再上 7×7，换一张新图。块的位置不会在中途乱动。\n做到哪一档会记住。再进时选继续最新一档，或从 5×5 重来。"


func _build_game() -> void:
	_load_best()
	_build_hud()
	_build_board()
	_build_restart_button()
	_layout_board()
	if latest_size > MIN_SIZE:
		_show_gate()
	else:
		_start_board(MIN_SIZE)


func _build_hud() -> void:
	time_label = _make_label("时间  0.00 秒", 26, Color("#e8edff"))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	time_label.offset_top = 72
	time_label.offset_bottom = 108
	add_child(time_label)

	status_label = _make_label("", 20, Color("#7f8ba6"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_top = 110
	status_label.offset_bottom = 144
	add_child(status_label)


func _build_board() -> void:
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)


func _build_restart_button() -> void:
	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.add_theme_font_size_override("font_size", 22)
	restart_button.add_theme_color_override("font_color", Color("#e8edff"))
	restart_button.custom_minimum_size = Vector2(RESTART_W, RESTART_H)
	_style_button(restart_button, Color("#1a2740"))
	restart_button.pressed.connect(_start_new)
	add_child(restart_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and board != null:
		_layout_board()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var avail_w := vp.x - SIDE_MARGIN * 2.0
	var avail_h := vp.y - HUD_TOP - BOTTOM_RESERVE
	var side := minf(avail_w, avail_h)
	board.position = Vector2((vp.x - side) / 2.0, HUD_TOP)
	board.size = Vector2(side, side)
	var font_size := clampi(int(side / float(grid_size) * 0.36), 14, 34)
	var outline := clampi(int(side / float(grid_size) * 0.08), 4, 10)
	for btn in cells:
		_layout_piece(btn, font_size, outline)
	restart_button.position = Vector2((vp.x - RESTART_W) / 2.0, board.position.y + side + 20.0)
	_layout_progress_gate()


func _layout_piece(btn: TextureButton, font_size: int, outline: int) -> void:
	var uv: Rect2 = btn.get_meta("uv_rect")
	var centroid: Vector2 = btn.get_meta("centroid")
	btn.position = uv.position * board.size
	btn.size = uv.size * board.size
	var num: Label = btn.get_node("Num")
	num.add_theme_font_size_override("font_size", font_size)
	num.add_theme_constant_override("outline_size", outline)
	var local := (centroid - uv.position) / uv.size
	num.size = Vector2(font_size * 2.2, font_size * 1.4)
	num.position = local * btn.size - num.size * 0.5


func _cell_count() -> int:
	return grid_size * grid_size


func _size_label(n: int = -1) -> String:
	if n < 0:
		n = grid_size
	return "%d×%d" % [n, n]


func _show_gate() -> void:
	phase = Phase.GATE
	finished = true
	started = false
	board.visible = false
	restart_button.visible = false
	_show_progress_gate(
		"上次做到 %s。\n这一局进最新一档，还是从 5×5 重来？" % _size_label(latest_size),
		"进入最新一关（%s）" % _size_label(latest_size),
		"从头开始（5×5）"
	)
	status_label.add_theme_color_override("font_color", Color("#7f8ba6"))
	status_label.text = "选这一局从哪档开始"
	time_label.text = "时间  —"


func _hide_gate() -> void:
	_hide_progress_gate()
	board.visible = true
	restart_button.visible = true


func _on_progress_continue() -> void:
	if phase != Phase.GATE:
		return
	_hide_gate()
	_start_board(latest_size)


func _on_progress_fresh() -> void:
	if phase != Phase.GATE:
		return
	latest_size = MIN_SIZE
	_save_progress()
	_hide_gate()
	_start_board(MIN_SIZE)


func _pick_animal() -> void:
	var pool: Array = []
	for a in ANIMALS:
		if String(a["id"]) != last_animal_id:
			pool.append(a)
	if pool.is_empty():
		pool = ANIMALS.duplicate()
	var picked: Dictionary = pool.pick_random()
	animal_id = String(picked["id"])
	animal_name = String(picked["name"])
	last_animal_id = animal_id
	var tex := load(String(picked["path"])) as Texture2D
	animal_img = null
	if tex != null:
		animal_img = tex.get_image()
	if animal_img == null:
		animal_img = Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
		animal_img.fill(BG)
	else:
		animal_img.convert(Image.FORMAT_RGBA8)


func _start_new() -> void:
	if phase == Phase.GATE:
		return
	if finished and grid_size < MAX_SIZE:
		_start_board(grid_size + 1)
	else:
		_start_board(grid_size)


func _start_board(size: int) -> void:
	phase = Phase.PLAY
	board_id += 1
	grid_size = clampi(size, MIN_SIZE, MAX_SIZE)
	next_number = 1
	started = false
	elapsed = 0.0
	finished = false
	mistakes = 0
	time_label.text = "时间  0.00 秒"
	_hide_gate()
	_pick_animal()
	_shatter()
	_rebuild_cells()
	_layout_board()
	_remember_level()
	_refresh_status()


func _clear_board() -> void:
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	cells.clear()


func _rebuild_cells() -> void:
	_clear_board()
	var numbers: Array = []
	for i in range(1, _cell_count() + 1):
		numbers.append(i)
	numbers.shuffle()
	for i in range(piece_info.size()):
		var info: Dictionary = piece_info[i]
		var btn := TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.texture_normal = info["tex"]
		btn.texture_click_mask = info["mask"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.modulate = Color(0.82, 0.86, 0.94)
		btn.set_meta("num", numbers[i])
		btn.set_meta("done", false)
		btn.set_meta("uv_rect", info["uv_rect"])
		btn.set_meta("centroid", info["centroid"])
		btn.pressed.connect(_on_cell_pressed.bind(btn))
		var num := Label.new()
		num.name = "Num"
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.add_theme_color_override("font_color", Color("#f4f7ff"))
		num.add_theme_color_override("font_outline_color", Color("#0d1220"))
		num.add_theme_constant_override("outline_size", 8)
		num.text = str(numbers[i])
		btn.add_child(num)
		board.add_child(btn)
		cells.append(btn)


func _on_cell_pressed(btn: TextureButton) -> void:
	if phase != Phase.PLAY or finished or bool(btn.get_meta("done")):
		return
	if not started:
		started = true
	var number: int = btn.get_meta("num")
	if number == next_number:
		next_number += 1
		_mark_correct(btn)
		if next_number > _cell_count():
			_finish()
		else:
			_refresh_status()
	else:
		mistakes += 1
		_flash_wrong(btn)
		_refresh_status()


func _mark_correct(btn: TextureButton) -> void:
	btn.set_meta("done", true)
	btn.get_node("Num").visible = false
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(1.06, 1.06)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.22)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _flash_wrong(btn: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "modulate", Color(1.0, 0.4, 0.45), 0.05)
	tween.tween_property(btn, "modulate", Color(0.82, 0.86, 0.94), 0.28)


func _process(delta: float) -> void:
	if phase != Phase.PLAY or not started or finished:
		return
	elapsed += delta
	time_label.text = "时间  %.2f 秒" % elapsed


func _finish() -> void:
	finished = true
	started = false
	var is_best := _record_best()
	var suffix := " · 新纪录" if is_best else ""
	status_label.text = "%s %s 完成 %.2f 秒（点错 %d）%s" % [animal_name, _size_label(), elapsed, mistakes, suffix]
	status_label.add_theme_color_override("font_color", Color("#ffd75d") if is_best else Color("#4ade80"))
	if grid_size < MAX_SIZE:
		var nxt := grid_size + 1
		latest_size = nxt
		_save_progress()
		_burst_feedback(animal_name, Color("#ffd75d") if is_best else Color("#4ade80"))
		var id := board_id
		await get_tree().create_timer(NEXT_BOARD_GAP).timeout
		if not is_inside_tree() or id != board_id or phase != Phase.PLAY:
			return
		_start_board(nxt)
	else:
		_save_progress()
		_burst_feedback(animal_name, Color("#ffd75d") if is_best else Color("#4ade80"))


func _refresh_status() -> void:
	if finished or phase != Phase.PLAY:
		return
	if not started:
		status_label.add_theme_color_override("font_color", Color("#7f8ba6"))
		status_label.text = _idle_text()
		return
	status_label.add_theme_color_override("font_color", Color("#8ab4ff"))
	var body := "%s  %s  下一个 %d／%d" % [animal_name, _size_label(), next_number, _cell_count()]
	if mistakes > 0:
		body += " · 点错 %d" % mistakes
	status_label.text = body


func _idle_text() -> String:
	var best: float = best_times.get(grid_size, -1.0)
	var head := "%s  %s  下一个 1／%d" % [animal_name, _size_label(), _cell_count()]
	if best > 0.0:
		return "%s · 最佳 %.2f 秒" % [head, best]
	return "%s · 按顺序点击" % head


func _record_best() -> bool:
	var prev: float = best_times.get(grid_size, -1.0)
	var is_best := prev < 0.0 or elapsed < prev
	if is_best:
		best_times[grid_size] = elapsed
		_save_progress()
	return is_best


func _remember_level() -> void:
	latest_size = clampi(maxi(latest_size, grid_size), MIN_SIZE, MAX_SIZE)
	_save_progress()


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		var legacy := float(config.get_value("best", "time", -1.0))
		best_times[5] = float(config.get_value("best", "time_5", legacy))
		best_times[6] = float(config.get_value("best", "time_6", -1.0))
		best_times[7] = float(config.get_value("best", "time_7", -1.0))
		latest_size = clampi(int(config.get_value("best", "size", MIN_SIZE)), MIN_SIZE, MAX_SIZE)


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("best", "time", best_times.get(5, -1.0))
	config.set_value("best", "time_5", best_times.get(5, -1.0))
	config.set_value("best", "time_6", best_times.get(6, -1.0))
	config.set_value("best", "time_7", best_times.get(7, -1.0))
	config.set_value("best", "size", clampi(latest_size, MIN_SIZE, MAX_SIZE))
	config.save(BEST_PATH)


func _shatter() -> void:
	piece_info.clear()
	if animal_img == null:
		return
	var src := animal_img.duplicate()
	src.convert(Image.FORMAT_RGBA8)
	src.resize(MASK_SIZE, MASK_SIZE, Image.INTERPOLATE_BILINEAR)
	var inside := _silhouette(src)
	var n := grid_size
	var count := n * n
	var sites := _place_sites(inside, n)
	var labels := PackedInt32Array()
	labels.resize(MASK_SIZE * MASK_SIZE)
	labels.fill(-1)
	_assign_voronoi(inside, sites, labels)
	_lloyd(inside, sites, labels)
	_assign_voronoi(inside, sites, labels)
	var crack2 := CRACK * CRACK
	var mins: Array[Vector2i] = []
	var maxs: Array[Vector2i] = []
	var sums: Array[Vector2] = []
	var area: PackedInt32Array = PackedInt32Array()
	area.resize(count)
	for i in range(count):
		mins.append(Vector2i(MASK_SIZE, MASK_SIZE))
		maxs.append(Vector2i(-1, -1))
		sums.append(Vector2.ZERO)
	for y in range(MASK_SIZE):
		for x in range(MASK_SIZE):
			var idx := y * MASK_SIZE + x
			if not inside[idx]:
				continue
			var lab := labels[idx]
			if lab < 0:
				continue
			var best_d := _dist2(Vector2(x, y), sites[lab])
			var second := INF
			for j in range(count):
				if j == lab:
					continue
				var d := _dist2(Vector2(x, y), sites[j])
				if d < second:
					second = d
			if second - best_d < crack2:
				labels[idx] = -1
				continue
			area[lab] += 1
			sums[lab] += Vector2(x, y)
			mins[lab] = Vector2i(mini(mins[lab].x, x), mini(mins[lab].y, y))
			maxs[lab] = Vector2i(maxi(maxs[lab].x, x), maxi(maxs[lab].y, y))
	for i in range(count):
		if area[i] <= 0:
			var p: Vector2 = sites[i]
			var px := clampi(int(p.x), 0, MASK_SIZE - 1)
			var py := clampi(int(p.y), 0, MASK_SIZE - 1)
			mins[i] = Vector2i(maxi(px - 4, 0), maxi(py - 4, 0))
			maxs[i] = Vector2i(mini(px + 4, MASK_SIZE - 1), mini(py + 4, MASK_SIZE - 1))
			sums[i] = Vector2(px, py)
			area[i] = 1
		var x0: int = mins[i].x
		var y0: int = mins[i].y
		var w: int = maxi(maxs[i].x - x0 + 1, 1)
		var h: int = maxi(maxs[i].y - y0 + 1, 1)
		var piece := Image.create(w, h, false, Image.FORMAT_RGBA8)
		piece.fill(Color(0, 0, 0, 0))
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				if labels[y * MASK_SIZE + x] != i:
					continue
				var c: Color = src.get_pixel(x, y)
				c.a = 1.0
				piece.set_pixel(x - x0, y - y0, c)
		var tex := ImageTexture.create_from_image(piece)
		var bm := BitMap.new()
		bm.create_from_image_alpha(piece, 0.12)
		var scale := 1.0 / float(MASK_SIZE)
		var centroid := sums[i] / float(area[i])
		piece_info.append({
			"tex": tex,
			"mask": bm,
			"uv_rect": Rect2(Vector2(x0, y0) * scale, Vector2(w, h) * scale),
			"centroid": centroid * scale,
		})


func _silhouette(src: Image) -> PackedByteArray:
	var w := MASK_SIZE
	var total := w * w
	var wall := PackedByteArray()
	wall.resize(total)
	for y in range(w):
		for x in range(w):
			var c: Color = src.get_pixel(x, y)
			var d := absf(c.r - BG.r) + absf(c.g - BG.g) + absf(c.b - BG.b)
			wall[y * w + x] = 1 if d > 0.28 else 0
	var dilated := PackedByteArray()
	dilated.resize(total)
	for y in range(w):
		for x in range(w):
			var on := 0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= w or ny >= w:
						continue
					if wall[ny * w + nx] == 1:
						on = 1
						break
				if on == 1:
					break
			dilated[y * w + x] = on
	var exterior := PackedByteArray()
	exterior.resize(total)
	var q: Array[int] = []
	for x in range(w):
		_try_flood(dilated, exterior, q, x, 0)
		_try_flood(dilated, exterior, q, x, w - 1)
	for y in range(w):
		_try_flood(dilated, exterior, q, 0, y)
		_try_flood(dilated, exterior, q, w - 1, y)
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var x := i % w
		var y := int(i / w)
		_try_flood(dilated, exterior, q, x - 1, y)
		_try_flood(dilated, exterior, q, x + 1, y)
		_try_flood(dilated, exterior, q, x, y - 1)
		_try_flood(dilated, exterior, q, x, y + 1)
	var inside := PackedByteArray()
	inside.resize(total)
	for i in range(total):
		inside[i] = 0 if exterior[i] == 1 else 1
	return inside


func _try_flood(wall: PackedByteArray, exterior: PackedByteArray, q: Array[int], x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= MASK_SIZE or y >= MASK_SIZE:
		return
	var i := y * MASK_SIZE + x
	if wall[i] == 1 or exterior[i] == 1:
		return
	exterior[i] = 1
	q.append(i)


func _place_sites(inside: PackedByteArray, n: int) -> PackedVector2Array:
	var sites := PackedVector2Array()
	sites.resize(n * n)
	for row in range(n):
		for col in range(n):
			var gx := (col + 0.5 + randf_range(-0.18, 0.18)) / float(n) * MASK_SIZE
			var gy := (row + 0.5 + randf_range(-0.18, 0.18)) / float(n) * MASK_SIZE
			var p := _nearest_inside(inside, Vector2(gx, gy))
			sites[row * n + col] = p
	return sites


func _nearest_inside(inside: PackedByteArray, p: Vector2) -> Vector2:
	var x0 := clampi(int(p.x), 0, MASK_SIZE - 1)
	var y0 := clampi(int(p.y), 0, MASK_SIZE - 1)
	if inside[y0 * MASK_SIZE + x0] == 1:
		return Vector2(x0, y0)
	for r in range(1, MASK_SIZE):
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if maxi(absi(ox), absi(oy)) != r:
					continue
				var x := x0 + ox
				var y := y0 + oy
				if x < 0 or y < 0 or x >= MASK_SIZE or y >= MASK_SIZE:
					continue
				if inside[y * MASK_SIZE + x] == 1:
					return Vector2(x, y)
	return Vector2(MASK_SIZE * 0.5, MASK_SIZE * 0.5)


func _assign_voronoi(inside: PackedByteArray, sites: PackedVector2Array, labels: PackedInt32Array) -> void:
	var count := sites.size()
	for y in range(MASK_SIZE):
		for x in range(MASK_SIZE):
			var idx := y * MASK_SIZE + x
			if inside[idx] == 0:
				labels[idx] = -1
				continue
			var best := 0
			var best_d := INF
			var px := float(x)
			var py := float(y)
			for i in range(count):
				var d := _dist2(Vector2(px, py), sites[i])
				if d < best_d:
					best_d = d
					best = i
			labels[idx] = best


func _lloyd(inside: PackedByteArray, sites: PackedVector2Array, labels: PackedInt32Array) -> void:
	var count := sites.size()
	var sums: Array[Vector2] = []
	var area := PackedInt32Array()
	area.resize(count)
	sums.resize(count)
	for i in range(count):
		sums[i] = Vector2.ZERO
	for y in range(MASK_SIZE):
		for x in range(MASK_SIZE):
			var lab := labels[y * MASK_SIZE + x]
			if lab < 0:
				continue
			sums[lab] += Vector2(x, y)
			area[lab] += 1
	for i in range(count):
		if area[i] > 0:
			sites[i] = sums[i] / float(area[i])


func _dist2(a: Vector2, b: Vector2) -> float:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy
