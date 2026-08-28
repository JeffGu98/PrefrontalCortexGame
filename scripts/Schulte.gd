extends "res://scripts/GameBase.gd"
## 舒尔特方格：动物剪影切成不规则块，数字叠在块上。


const MIN_SIZE := 5
const MAX_SIZE := 7
const BEST_PATH := "user://schulte_best.cfg"
const ASSET_DIR := "res://assets/schulte/"
const NAMES_PATH := "res://assets/schulte/names.cfg"
const HUD_TOP := 156.0
const SIDE_MARGIN := 28.0
const BOTTOM_RESERVE := 108.0
const RESTART_W := 220.0
const RESTART_H := 60.0
const NEXT_BOARD_GAP := 0.7
const MASK_SIZE := 256
const CRACK := 1.2
const DEBUG_PERF := false
const LINE := Color("#f3ead2")
const WAIT_TINT := Color(0.82, 0.86, 0.94)
const DONE_NUM := Color("#2a3548")

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
var animals: Array = []

var board: Control
var time_label: Label
var status_label: Label
var restart_button: Button
var cells: Array = []


func _init() -> void:
	title_text = "舒尔特方格"
	help_text = "每盘抽一张动物剪影，沿外形切成不规则小块，数字叠在块上。从 1 开始按顺序点，越快越好。点对揭开这块，点错闪红但不重来。第一次点击开始计时。\n点完 5×5 会上 6×6，再上 7×7，换一张新图。块的位置不会在中途乱动。\n做到哪一档会记住。再进时选继续最新一档，或从 5×5 重来。"


func _build_game() -> void:
	_load_animals()
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
	board.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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


func _load_animals() -> void:
	animals.clear()
	var labels := {}
	var cfg := ConfigFile.new()
	if cfg.load(NAMES_PATH) == OK:
		for key in cfg.get_section_keys("names"):
			labels[String(key)] = str(cfg.get_value("names", key))
	var files: Array[String] = []
	var dir := DirAccess.open(ASSET_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.get_extension().to_lower() == "png" and not fname.begins_with("_"):
				files.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()
	files.sort()
	for fname in files:
		var id := fname.get_basename()
		animals.append({
			"id": id,
			"name": str(labels.get(id, id)),
			"path": ASSET_DIR + fname,
		})


func _pick_animal() -> void:
	var pool: Array = []
	for a in animals:
		if String(a["id"]) != last_animal_id:
			pool.append(a)
	if pool.is_empty():
		pool = animals.duplicate()
	animal_img = Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	animal_img.fill(Color(0, 0, 0, 0))
	if pool.is_empty():
		animal_id = ""
		animal_name = "剪影"
		return
	var picked: Dictionary = pool.pick_random()
	animal_id = String(picked["id"])
	animal_name = String(picked["name"])
	last_animal_id = animal_id
	var tex := load(String(picked["path"])) as Texture2D
	if tex != null:
		var img := tex.get_image()
		if img != null:
			animal_img = img
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
	var t0 := Time.get_ticks_msec()
	_pick_animal()
	var t1 := Time.get_ticks_msec()
	_shatter()
	var t2 := Time.get_ticks_msec()
	_rebuild_cells()
	var t3 := Time.get_ticks_msec()
	_layout_board()
	_remember_level()
	_refresh_status()
	if DEBUG_PERF:
		print("schulte board %dx%d pick=%d shatter=%d rebuild=%d total=%d" % [
			grid_size, grid_size, t1 - t0, t2 - t1, t3 - t2, t3 - t0
		])


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
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		btn.texture_normal = info["tex"]
		btn.texture_click_mask = info["mask"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.modulate = WAIT_TINT
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
	var num: Label = btn.get_node("Num")
	num.visible = true
	num.add_theme_color_override("font_color", DONE_NUM)
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(1.06, 1.06)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.22)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _flash_wrong(btn: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "modulate", Color(1.0, 0.4, 0.45), 0.05)
	tween.tween_property(btn, "modulate", WAIT_TINT, 0.28)


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
	var t0 := Time.get_ticks_msec()
	var src_full := animal_img.duplicate()
	src_full.convert(Image.FORMAT_RGBA8)
	var src := src_full.duplicate()
	src.resize(MASK_SIZE, MASK_SIZE, Image.INTERPOLATE_BILINEAR)
	var t1 := Time.get_ticks_msec()
	var inside := _alpha_mask(src)
	var center := _mask_center(inside)
	var n := grid_size
	var count := n * n
	var sites := _place_sites(inside, n, center)
	var t2 := Time.get_ticks_msec()
	var labels := PackedInt32Array()
	labels.resize(MASK_SIZE * MASK_SIZE)
	labels.fill(-1)
	_assign_voronoi(inside, sites, labels, n)
	var t3 := Time.get_ticks_msec()
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
			var lab := labels[y * MASK_SIZE + x]
			if lab < 0:
				continue
			area[lab] += 1
			sums[lab] += Vector2(x, y)
			mins[lab] = Vector2i(mini(mins[lab].x, x), mini(mins[lab].y, y))
			maxs[lab] = Vector2i(maxi(maxs[lab].x, x), maxi(maxs[lab].y, y))
	var t4 := Time.get_ticks_msec()
	var paint := src_full
	if src_full.get_width() > 512:
		paint = src_full.duplicate()
		paint.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	var src_w: int = paint.get_width()
	var src_h: int = paint.get_height()
	var src_bytes: PackedByteArray = paint.get_data()
	var sx := float(src_w) / float(MASK_SIZE)
	var sy := float(src_h) / float(MASK_SIZE)
	var cream_r := int(LINE.r * 255.0)
	var cream_g := int(LINE.g * 255.0)
	var cream_b := int(LINE.b * 255.0)
	for i in range(count):
		if area[i] <= 0:
			var p: Vector2 = sites[i]
			var fx := clampi(int(p.x), 0, MASK_SIZE - 1)
			var fy := clampi(int(p.y), 0, MASK_SIZE - 1)
			mins[i] = Vector2i(maxi(fx - 4, 0), maxi(fy - 4, 0))
			maxs[i] = Vector2i(mini(fx + 4, MASK_SIZE - 1), mini(fy + 4, MASK_SIZE - 1))
			sums[i] = Vector2(fx, fy)
			area[i] = 1
		var x0: int = mins[i].x
		var y0: int = mins[i].y
		var w: int = maxi(maxs[i].x - x0 + 1, 1)
		var h: int = maxi(maxs[i].y - y0 + 1, 1)
		var src_x0 := clampi(int(floor(float(x0) * sx)), 0, src_w - 1)
		var src_y0 := clampi(int(floor(float(y0) * sy)), 0, src_h - 1)
		var pw := clampi(int(ceil(float(w) * sx)), 1, src_w - src_x0)
		var ph := clampi(int(ceil(float(h) * sy)), 1, src_h - src_y0)
		var piece_bytes := PackedByteArray()
		piece_bytes.resize(pw * ph * 4)
		for py in range(ph):
			var src_row := ((src_y0 + py) * src_w + src_x0) * 4
			var dst_row := py * pw * 4
			for px in range(pw):
				var mx := clampi(int(floor(float(src_x0 + px) / sx)), 0, MASK_SIZE - 1)
				var my := clampi(int(floor(float(src_y0 + py) / sy)), 0, MASK_SIZE - 1)
				if labels[my * MASK_SIZE + mx] != i:
					continue
				var si: int = src_row + px * 4
				var a: int = src_bytes[si + 3]
				if a <= 5:
					continue
				var di: int = dst_row + px * 4
				if a < 51:
					piece_bytes[di] = cream_r
					piece_bytes[di + 1] = cream_g
					piece_bytes[di + 2] = cream_b
					piece_bytes[di + 3] = a
				else:
					piece_bytes[di] = src_bytes[si]
					piece_bytes[di + 1] = src_bytes[si + 1]
					piece_bytes[di + 2] = src_bytes[si + 2]
					piece_bytes[di + 3] = a
		var piece := Image.create_from_data(pw, ph, false, Image.FORMAT_RGBA8, piece_bytes)
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
	if DEBUG_PERF:
		print("schulte shatter resize=%d mask=%d voronoi=%d crack=%d paint=%d" % [
			t1 - t0, t2 - t1, t3 - t2, t4 - t3, Time.get_ticks_msec() - t4
		])


func _alpha_mask(src: Image) -> PackedByteArray:
	var data: PackedByteArray = src.get_data()
	var total := MASK_SIZE * MASK_SIZE
	var inside := PackedByteArray()
	inside.resize(total)
	var p := 3
	for i in range(total):
		inside[i] = 1 if data[p] > 10 else 0
		p += 4
	return inside


func _mask_center(inside: PackedByteArray) -> Vector2:
	var sx := 0
	var sy := 0
	var n := 0
	for y in range(MASK_SIZE):
		for x in range(MASK_SIZE):
			if inside[y * MASK_SIZE + x] == 0:
				continue
			sx += x
			sy += y
			n += 1
	if n == 0:
		return Vector2(MASK_SIZE * 0.5, MASK_SIZE * 0.5)
	return Vector2(float(sx) / float(n), float(sy) / float(n))


func _place_sites(inside: PackedByteArray, n: int, center: Vector2) -> PackedVector2Array:
	var sites := PackedVector2Array()
	sites.resize(n * n)
	for row in range(n):
		for col in range(n):
			var gx := (col + 0.5 + randf_range(-0.18, 0.18)) / float(n) * MASK_SIZE
			var gy := (row + 0.5 + randf_range(-0.18, 0.18)) / float(n) * MASK_SIZE
			sites[row * n + col] = _nearest_inside(inside, Vector2(gx, gy), center)
	return sites


func _nearest_inside(inside: PackedByteArray, p: Vector2, center: Vector2) -> Vector2:
	var x := clampi(int(p.x), 0, MASK_SIZE - 1)
	var y := clampi(int(p.y), 0, MASK_SIZE - 1)
	if inside[y * MASK_SIZE + x] == 1:
		return Vector2(x, y)
	var cx := int(center.x)
	var cy := int(center.y)
	for _s in range(MASK_SIZE):
		if x != cx:
			x += 1 if cx > x else -1
		if y != cy:
			y += 1 if cy > y else -1
		if inside[y * MASK_SIZE + x] == 1:
			return Vector2(x, y)
		if x == cx and y == cy:
			break
	return center


func _assign_voronoi(inside: PackedByteArray, sites: PackedVector2Array, labels: PackedInt32Array, n: int) -> void:
	var crack2 := CRACK * CRACK
	for y in range(MASK_SIZE):
		var row_guess := clampi(int(float(y) * float(n) / float(MASK_SIZE)), 0, n - 1)
		for x in range(MASK_SIZE):
			var idx := y * MASK_SIZE + x
			if inside[idx] == 0:
				labels[idx] = -1
				continue
			var col_guess := clampi(int(float(x) * float(n) / float(MASK_SIZE)), 0, n - 1)
			var best := row_guess * n + col_guess
			var best_d := INF
			var second := INF
			var px := float(x)
			var py := float(y)
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					var nr: int = row_guess + dr
					var nc: int = col_guess + dc
					if nr < 0 or nc < 0 or nr >= n or nc >= n:
						continue
					var i: int = nr * n + nc
					var d := _dist2(Vector2(px, py), sites[i])
					if d < best_d:
						second = best_d
						best_d = d
						best = i
					elif d < second:
						second = d
			if second - best_d < crack2:
				labels[idx] = -1
			else:
				labels[idx] = best


func _dist2(a: Vector2, b: Vector2) -> float:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy
