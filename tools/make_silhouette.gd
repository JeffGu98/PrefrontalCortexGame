extends SceneTree
## Convert black-on-white renders into cream silhouettes with transparent outside.


const OUT_DIR := "res://assets/schulte/"
const FILL := Color("#f3ead2")
const SIZE := 1024
const PAD := 0.10
const INK := 0.42


func _init() -> void:
	_run()
	quit()


func _run() -> void:
	var base := "/Users/shukun/.grok/sessions/%2FUsers%2Fshukun%2FDocuments%2Fgit%2Fgodot%2FPrefrontalCortexGame/01a04769-f7ab-7443-b2a6-697ec354cca8/images/"
	var jobs := [
		["cat", base + "4.jpg"],
		["dog", base + "2.jpg"],
		["fox", base + "5.jpg"],
		["panda", base + "13.jpg"],
		["elephant", base + "7.jpg"],
		["owl", base + "12.jpg"],
		["tiger", base + "3.jpg"],
		["rabbit", base + "1.jpg"],
		["penguin", base + "9.jpg"],
		["deer", base + "10.jpg"],
	]
	var thumbs: Array[Image] = []
	for job in jobs:
		var name := str(job[0])
		var src := Image.new()
		var err := src.load(str(job[1]))
		if err != OK:
			push_error("load failed " + name + " " + str(err))
			continue
		src.convert(Image.FORMAT_RGBA8)
		var out := _to_silhouette(src)
		var dest := ProjectSettings.globalize_path(OUT_DIR + name + ".png")
		out.save_png(dest)
		print("%s  inside=%d  %s" % [name, int(out.get_meta("inside_count", 0)), dest])
		var thumb := out.duplicate()
		thumb.resize(256, 256, Image.INTERPOLATE_BILINEAR)
		thumbs.append(thumb)
	if thumbs.size() == 10:
		var sheet := Image.create(1280, 512, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.2, 0.25, 0.32, 1))
		for i in range(10):
			sheet.blit_rect(thumbs[i], Rect2i(0, 0, 256, 256), Vector2i((i % 5) * 256, int(i / 5) * 256))
		sheet.save_png("/tmp/schulte_silhouettes.png")
		print("preview /tmp/schulte_silhouettes.png")


func _to_silhouette(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var total := w * h
	var ink := PackedByteArray()
	ink.resize(total)
	for y in range(h):
		for x in range(w):
			var c: Color = src.get_pixel(x, y)
			var lum := (c.r + c.g + c.b) / 3.0
			ink[y * w + x] = 1 if lum < INK else 0
	ink = _dilate(ink, w, h, 1)
	var body := _largest(ink, w, h)
	var exterior := _flood_zero(body, w, h)
	var inside := PackedByteArray()
	inside.resize(total)
	for i in range(total):
		inside[i] = 0 if exterior[i] == 1 else 1
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	var count := 0
	for y in range(h):
		for x in range(w):
			if inside[y * w + x] == 0:
				continue
			count += 1
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x)
			y1 = maxi(y1, y)
	if count == 0:
		var empty := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		empty.fill(Color(0, 0, 0, 0))
		empty.set_meta("inside_count", 0)
		return empty
	var bw := x1 - x0 + 1
	var bh := y1 - y0 + 1
	var pad := int(maxi(bw, bh) * PAD)
	var side := maxi(bw, bh) + pad * 2
	var ox := (side - bw) / 2
	var oy := (side - bh) / 2
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	for y in range(bh):
		for x in range(bw):
			if inside[(y0 + y) * w + (x0 + x)] == 1:
				square.set_pixel(ox + x, oy + y, FILL)
	square.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	for y in range(SIZE):
		for x in range(SIZE):
			var a := square.get_pixel(x, y).a
			if a <= 0.02:
				square.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				square.set_pixel(x, y, Color(FILL.r, FILL.g, FILL.b, a))
	square.set_meta("inside_count", count)
	return square


func _dilate(src: PackedByteArray, w: int, h: int, times: int) -> PackedByteArray:
	var cur := src
	for _t in range(times):
		var nxt := PackedByteArray()
		nxt.resize(w * h)
		for y in range(h):
			for x in range(w):
				var on := 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var nx := x + ox
						var ny := y + oy
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						if cur[ny * w + nx] == 1:
							on = 1
							break
					if on == 1:
						break
				nxt[y * w + x] = on
		cur = nxt
	return cur


func _flood_zero(wall: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var mark := PackedByteArray()
	mark.resize(w * h)
	var q: Array[int] = []
	for x in range(w):
		_push(wall, mark, q, w, h, x, 0)
		_push(wall, mark, q, w, h, x, h - 1)
	for y in range(h):
		_push(wall, mark, q, w, h, 0, y)
		_push(wall, mark, q, w, h, w - 1, y)
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var x := i % w
		var y := int(i / w)
		_push(wall, mark, q, w, h, x - 1, y)
		_push(wall, mark, q, w, h, x + 1, y)
		_push(wall, mark, q, w, h, x, y - 1)
		_push(wall, mark, q, w, h, x, y + 1)
	return mark


func _push(wall: PackedByteArray, mark: PackedByteArray, q: Array[int], w: int, h: int, x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var i := y * w + x
	if wall[i] == 1 or mark[i] == 1:
		return
	mark[i] = 1
	q.append(i)


func _largest(mask: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var best: Array[int] = []
	for y in range(h):
		for x in range(w):
			var start := y * w + x
			if mask[start] == 0 or seen[start] == 1:
				continue
			var q: Array[int] = [start]
			seen[start] = 1
			var head := 0
			while head < q.size():
				var i: int = q[head]
				head += 1
				var cx := i % w
				var cy := int(i / w)
				var nbs := [cx - 1, cy, cx + 1, cy, cx, cy - 1, cx, cy + 1]
				var k := 0
				while k < nbs.size():
					var nx: int = nbs[k]
					var ny: int = nbs[k + 1]
					k += 2
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni := ny * w + nx
					if mask[ni] == 0 or seen[ni] == 1:
						continue
					seen[ni] = 1
					q.append(ni)
			if q.size() > best.size():
				best = q
	var out := PackedByteArray()
	out.resize(w * h)
	for i in best:
		out[i] = 1
	return out
