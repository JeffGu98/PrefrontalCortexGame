extends Control
## Main menu: one button per mini-game, grouped by executive function.


const GAMES := [
	{"title": "反向色字", "func": "抑制控制 · 干扰", "group": "抑制控制", "scene": "res://scenes/Stroop.tscn", "built": true},
	{"title": "反向反应", "func": "抑制控制 · 克制", "group": "抑制控制", "scene": "res://scenes/GoNoGo.tscn", "built": true},
	{"title": "红灯停", "func": "抑制控制 · 刹车", "group": "抑制控制", "scene": "res://scenes/StopSignal.tscn", "built": true},
	{"title": "舒尔特方格", "func": "专注 · 视觉搜索", "group": "注意", "scene": "res://scenes/Schulte.tscn", "built": true},
	{"title": "追踪异色球", "func": "注意 · 追踪", "group": "注意", "scene": "", "built": false},
	{"title": "N-Back", "func": "工作记忆 · 更新", "group": "工作记忆", "scene": "", "built": false},
	{"title": "看点数", "func": "工作记忆 · 瞬时", "group": "工作记忆", "scene": "res://scenes/Dots.tscn", "built": true},
	{"title": "任务切换", "func": "认知灵活性", "group": "认知灵活性", "scene": "", "built": false},
	{"title": "延迟满足", "func": "自控 · 延迟折扣", "group": "自控", "scene": "", "built": false},
	{"title": "汉诺塔", "func": "计划 · 前瞻", "group": "计划", "scene": "", "built": false},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_header()
	_build_list()


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
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 148
	scroll.offset_left = 28
	scroll.offset_right = -28
	scroll.offset_bottom = -28
	add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

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
