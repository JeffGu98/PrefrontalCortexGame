extends Control
## Main menu: one button per mini-game, grouped by executive function.


const RELEASES_API := "https://api.github.com/repos/JeffGu98/PrefrontalCortexGame/releases/latest"
const RELEASES_PAGE := "https://github.com/JeffGu98/PrefrontalCortexGame/releases/latest"
const SEEN_PATH := "user://update_seen.cfg"

var _scroll: ScrollContainer
var _release_url := RELEASES_PAGE


const GAMES := [
	{"title": "反向色字", "func": "抑制控制 · 干扰", "group": "抑制控制", "scene": "res://scenes/Stroop.tscn", "built": true},
	{"title": "反向反应", "func": "抑制控制 · 克制", "group": "抑制控制", "scene": "res://scenes/GoNoGo.tscn", "built": true},
	{"title": "红灯停", "func": "抑制控制 · 刹车", "group": "抑制控制", "scene": "res://scenes/StopSignal.tscn", "built": true},
	{"title": "中间箭头", "func": "抑制控制 · 侧翼", "group": "抑制控制", "scene": "res://scenes/Flanker.tscn", "built": true},
	{"title": "舒尔特方格", "func": "专注 · 视觉搜索", "group": "注意", "scene": "res://scenes/Schulte.tscn", "built": true},
	{"title": "追踪异色球", "func": "注意 · 追踪", "group": "注意", "scene": "res://scenes/Track.tscn", "built": true},
	{"title": "N-Back", "func": "工作记忆 · 更新", "group": "工作记忆", "scene": "res://scenes/NBack.tscn", "built": true},
	{"title": "看点数", "func": "工作记忆 · 瞬时", "group": "工作记忆", "scene": "res://scenes/Dots.tscn", "built": true},
	{"title": "任务切换", "func": "认知灵活性", "group": "认知灵活性", "scene": "res://scenes/Switch.tscn", "built": true},
	{"title": "汉诺塔", "func": "计划 · 前瞻", "group": "计划", "scene": "res://scenes/Hanoi.tscn", "built": true},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_header()
	_build_list()
	_check_for_update()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0d1220")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_header() -> void:
	var title := Label.new()
	title.text = "前额叶训练场"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#e8edff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 48
	title.offset_bottom = 100
	add_child(title)

	var ready := 0
	for game in GAMES:
		if game["built"]:
			ready += 1
	var sub := Label.new()
	sub.text = "每个游戏练一种执行功能 · %d / %d 可玩" % [ready, GAMES.size()]
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color("#7f8ba6"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 102
	sub.offset_bottom = 132
	add_child(sub)


func _build_list() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 148
	_scroll.offset_left = 28
	_scroll.offset_right = -28
	_scroll.offset_bottom = -28
	add_child(_scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)

	var last_group := ""
	for game in GAMES:
		var group: String = game["group"]
		if group != last_group:
			if last_group != "":
				list.add_child(_make_spacer(10))
			list.add_child(_make_group_header(group))
			last_group = group
		list.add_child(_make_game_button(game))


func _make_group_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#8ab4ff"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.custom_minimum_size = Vector2(0, 26)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _make_game_button(game: Dictionary) -> Button:
	var built: bool = game["built"]
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 88)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(btn, Color("#1a2740") if built else Color("#12192a"))

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	btn.add_child(pad)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	pad.add_child(row)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	var title := Label.new()
	title.text = game["title"]
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#e8edff") if built else Color("#5a6478"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	var func_label := Label.new()
	func_label.text = game["func"]
	func_label.add_theme_font_size_override("font_size", 15)
	func_label.add_theme_color_override("font_color", Color("#8ab4ff") if built else Color("#4a5568"))
	func_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(func_label)

	if not built:
		var tag := Label.new()
		tag.text = "即将推出"
		tag.add_theme_font_size_override("font_size", 14)
		tag.add_theme_color_override("font_color", Color("#5a6478"))
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)

	if built:
		btn.pressed.connect(_open_game.bind(game["scene"]))
	else:
		btn.disabled = true
	return btn


func _style_button(btn: Button, bg: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg.lightened(0.12)
	hover.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg.darkened(0.15)
	pressed.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = bg
	disabled.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("disabled", disabled)


func _open_game(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _check_for_update() -> void:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	http.use_threads = true
	add_child(http)
	http.request_completed.connect(_on_update_response.bind(http))
	var headers := PackedStringArray([
		"User-Agent: PrefrontalCortexGame",
		"Accept: application/vnd.github+json",
	])
	var err := http.request(RELEASES_API, headers)
	if err != OK:
		http.queue_free()


func _on_update_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var tag := str(data.get("tag_name", "")).strip_edges()
	if tag.is_empty() or not _is_newer(tag, str(ProjectSettings.get_setting("application/config/version", "0"))):
		return
	if _was_dismissed(tag):
		return
	var url := str(data.get("html_url", "")).strip_edges()
	if not url.is_empty():
		_release_url = url
	_show_update_banner(tag)


func _is_newer(remote: String, local: String) -> bool:
	var a := _semver(remote)
	var b := _semver(local)
	for i in range(3):
		if a[i] > b[i]:
			return true
		if a[i] < b[i]:
			return false
	return false


func _semver(raw: String) -> PackedInt32Array:
	var text := raw.strip_edges()
	if text.begins_with("v") or text.begins_with("V"):
		text = text.substr(1)
	var parts := text.split(".")
	var out := PackedInt32Array()
	for i in range(3):
		out.append(parts[i].to_int() if i < parts.size() else 0)
	return out


func _was_dismissed(tag: String) -> bool:
	var config := ConfigFile.new()
	if config.load(SEEN_PATH) != OK:
		return false
	return str(config.get_value("update", "dismissed", "")) == tag


func _dismiss_update(tag: String) -> void:
	var config := ConfigFile.new()
	config.set_value("update", "dismissed", tag)
	config.save(SEEN_PATH)


func _show_update_banner(tag: String) -> void:
	if _scroll != null:
		_scroll.offset_bottom = -96
	var bar := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a2740")
	style.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 28
	bar.offset_right = -28
	bar.offset_top = -84
	bar.offset_bottom = -20
	add_child(bar)

	var open_btn := Button.new()
	open_btn.text = "有新版本 %s　·　点此查看" % tag
	open_btn.focus_mode = Control.FOCUS_NONE
	open_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	open_btn.offset_right = -56
	open_btn.add_theme_font_size_override("font_size", 18)
	open_btn.add_theme_color_override("font_color", Color("#ffd75d"))
	open_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(open_btn, Color("#1a2740"))
	open_btn.pressed.connect(_open_release)
	bar.add_child(open_btn)

	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	close.offset_left = -52
	close.offset_right = -8
	close.offset_top = -22
	close.offset_bottom = 22
	close.add_theme_font_size_override("font_size", 22)
	close.add_theme_color_override("font_color", Color("#7f8ba6"))
	_style_button(close, Color("#1a2740"))
	close.pressed.connect(_hide_update_banner.bind(bar, tag))
	bar.add_child(close)


func _hide_update_banner(bar: Control, tag: String) -> void:
	_dismiss_update(tag)
	bar.queue_free()
	if _scroll != null:
		_scroll.offset_bottom = -28


func _open_release() -> void:
	OS.shell_open(_release_url)
