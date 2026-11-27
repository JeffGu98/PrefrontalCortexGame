extends Control
## Main menu: one button per mini-game, grouped by executive function.


const RELEASES_API := "https://api.github.com/repos/JeffGu98/PrefrontalCortexGame/releases/latest"
const RELEASES_PAGE := "https://github.com/JeffGu98/PrefrontalCortexGame/releases/latest"
const SEEN_PATH := "user://update_seen.cfg"
const DAILY_PATH := "user://daily.cfg"

var _scroll: ScrollContainer
var _release_url := RELEASES_PAGE
## If set, Hub calls this instead of changing scene (used by headless tests).
var open_intercept: Callable
var _quit_armed := false
var _quit_hint: Label
var _mute_btn: Button


const GAMES := [
	{"title": "反向色字", "func": "抑制控制 · 干扰", "group": "抑制控制", "scene": "res://scenes/Stroop.tscn", "built": true},
	{"title": "舒尔特方格", "func": "专注 · 视觉搜索", "group": "注意", "scene": "res://scenes/Schulte.tscn", "built": true},
	{"title": "追踪异色球", "func": "注意 · 追踪", "group": "注意", "scene": "res://scenes/Track.tscn", "built": true},
	{"title": "N-Back", "func": "工作记忆 · 更新", "group": "工作记忆", "scene": "res://scenes/NBack.tscn", "built": true},
	{"title": "积木跨度", "func": "工作记忆 · 空间序列", "group": "工作记忆", "scene": "res://scenes/Corsi.tscn", "built": true},
	{"title": "各点一次", "func": "工作记忆 · 自我监控", "group": "工作记忆", "scene": "res://scenes/SelfOrder.tscn", "built": true},
	{"title": "末项记", "func": "工作记忆 · 末项更新", "group": "工作记忆", "scene": "res://scenes/RunningSpan.tscn", "built": true},
	{"title": "看点数", "func": "工作记忆 · 瞬时", "group": "工作记忆", "scene": "res://scenes/Dots.tscn", "built": true},
	{"title": "任务切换", "func": "认知灵活性 · 线索切换", "group": "认知灵活性", "scene": "res://scenes/Switch.tscn", "built": true},
	{"title": "规则变了", "func": "认知灵活性 · 规则推断", "group": "认知灵活性", "scene": "res://scenes/RuleShift.tscn", "built": true},
	{"title": "汉诺塔", "func": "计划 · 前瞻", "group": "计划", "scene": "res://scenes/Hanoi.tscn", "built": true},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_header()
	_build_list()
	_check_for_update()
	_bind_system_back()


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

	_mute_btn = Button.new()
	_mute_btn.focus_mode = Control.FOCUS_NONE
	_mute_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_mute_btn.offset_left = -84
	_mute_btn.offset_top = 48
	_mute_btn.offset_right = -24
	_mute_btn.offset_bottom = 92
	_mute_btn.add_theme_font_size_override("font_size", 16)
	_mute_btn.pressed.connect(_toggle_mute)
	add_child(_mute_btn)
	_refresh_mute_button()

	var version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if not version.is_empty():
		var ver_label := Label.new()
		ver_label.name = "VersionLabel"
		ver_label.text = version if version.begins_with("v") or version.begins_with("V") else "v%s" % version
		ver_label.add_theme_font_size_override("font_size", 16)
		ver_label.add_theme_color_override("font_color", Color("#7f8ba6"))
		ver_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ver_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ver_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		ver_label.offset_left = 24
		ver_label.offset_top = 48
		ver_label.offset_right = 160
		ver_label.offset_bottom = 92
		add_child(ver_label)


func _toggle_mute() -> void:
	var base := load("res://scripts/GameBase.gd")
	if base == null:
		return
	base.set_muted(not base.is_muted())
	_refresh_mute_button()


func _refresh_mute_button() -> void:
	if _mute_btn == null:
		return
	var base := load("res://scripts/GameBase.gd")
	var muted: bool = base != null and base.is_muted()
	_mute_btn.text = "静音" if muted else "音效"
	_mute_btn.add_theme_color_override("font_color", Color("#7f8ba6") if muted else Color("#e8edff"))
	_style_button(_mute_btn, Color("#152034") if muted else Color("#1a2740"))


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

	list.add_child(_make_daily_card())
	list.add_child(_make_spacer(6))

	var last_group := ""
	for game in GAMES:
		var group: String = game["group"]
		if group != last_group:
			if last_group != "":
				list.add_child(_make_spacer(10))
			list.add_child(_make_group_header(group))
			last_group = group
		list.add_child(_make_game_button(game))


static func built_games() -> Array:
	# Daily pool = every built game in GAMES order (末项记 / 各点一次 / 规则变了 / … auto-join when built:true).
	var out: Array = []
	for game in GAMES:
		if game["built"]:
			out.append(game)
	return out


static func today_key() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


static func daily_index(count: int) -> int:
	if count <= 0:
		return 0
	var key := today_key()
	var h := 0
	for i in range(key.length()):
		h = (h * 31 + key.unicode_at(i)) & 0x7fffffff
	# Stable mix so nearby dates do not always pick neighbors.
	h = (h ^ (h >> 16)) & 0x7fffffff
	return h % count


static func daily_game() -> Dictionary:
	var built := built_games()
	if built.is_empty():
		return {}
	return built[daily_index(built.size())]


static func daily_scene_path() -> String:
	return str(daily_game().get("scene", ""))


static func is_daily_completed_today() -> bool:
	var config := ConfigFile.new()
	if config.load(DAILY_PATH) != OK:
		return false
	if str(config.get_value("daily", "played_date", "")) != today_key():
		return false
	var recorded_scene := str(config.get_value("daily", "played_scene", ""))
	if recorded_scene.is_empty():
		return true
	return recorded_scene == daily_scene_path()


static func mark_daily_completed(scene_path: String) -> bool:
	var target := daily_scene_path()
	if scene_path.is_empty() or scene_path != target:
		return false
	var config := ConfigFile.new()
	config.load(DAILY_PATH)
	config.set_value("daily", "played_date", today_key())
	config.set_value("daily", "played_scene", scene_path)
	config.save(DAILY_PATH)
	return true


func _built_games() -> Array:
	return built_games()


func _today_key() -> String:
	return today_key()


func _daily_index(count: int) -> int:
	return daily_index(count)


func _daily_game() -> Dictionary:
	return daily_game()


func _daily_played_today() -> bool:
	return is_daily_completed_today()


func _make_daily_card() -> HubCard:
	var game: Dictionary = _daily_game()
	var btn := _make_hub_card(108, Color("#243552"), not game.has("scene"))

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 14)
	btn.add_child(pad)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	pad.add_child(col)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)

	var badge := Label.new()
	badge.text = "今日一练"
	badge.add_theme_font_size_override("font_size", 15)
	badge.add_theme_color_override("font_color", Color("#ffd75d"))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(badge)

	if _daily_played_today():
		var done := Label.new()
		done.text = "今日已练"
		done.add_theme_font_size_override("font_size", 14)
		done.add_theme_color_override("font_color", Color("#4ade80"))
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(done)

	var title := Label.new()
	title.text = str(game.get("title", "—"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#e8edff"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	var func_label := Label.new()
	func_label.text = str(game.get("func", ""))
	func_label.add_theme_font_size_override("font_size", 15)
	func_label.add_theme_color_override("font_color", Color("#8ab4ff"))
	func_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(func_label)

	if game.has("scene"):
		btn.activated.connect(_open_daily.bind(str(game["scene"])))
	return btn


func _open_daily(scene_path: String) -> void:
	_open_game(scene_path)


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


func _make_hub_card(min_height: float, bg: Color, disabled: bool) -> HubCard:
	var card := HubCard.new()
	card.custom_minimum_size = Vector2(0, min_height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.setup(_scroll, bg, disabled)
	card.set_meta("hub_card", true)
	return card


func _make_game_button(game: Dictionary) -> HubCard:
	var built: bool = game["built"]
	var btn := _make_hub_card(88, Color("#1a2740") if built else Color("#12192a"), not built)
	btn.set_meta("hub_title", game["title"])

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
	else:
		var stat := game_stat_text(str(game["title"]))
		if not stat.is_empty():
			var stat_label := Label.new()
			stat_label.text = stat
			stat_label.add_theme_font_size_override("font_size", 14)
			stat_label.add_theme_color_override("font_color", Color("#7f8ba6"))
			stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(stat_label)

	if built:
		btn.activated.connect(_open_game.bind(game["scene"]))
	return btn


static func game_stat_text(title: String) -> String:
	var cfg := ConfigFile.new()
	match title:
		"反向色字":
			if cfg.load("user://stroop_best.cfg") != OK:
				return ""
			var legacy := int(cfg.get_value("best", "score", 0))
			var easy := int(cfg.get_value("best", "easy_score", legacy))
			var hard := int(cfg.get_value("best", "hard_score", 0))
			if easy > 0 and hard > 0:
				return "简 %d · 难 %d" % [easy, hard]
			if easy > 0:
				return "简单 %d" % easy
			if hard > 0:
				return "困难 %d" % hard
			return ""
		"舒尔特方格":
			if cfg.load("user://schulte_best.cfg") != OK:
				return ""
			var sz := clampi(int(cfg.get_value("best", "size", 5)), 5, 7)
			var t := float(cfg.get_value("best", "time_%d" % sz, -1.0))
			if t < 0.0 and sz == 5:
				t = float(cfg.get_value("best", "time", -1.0))
			if t > 0.0:
				return "%d×%d · %.1fs" % [sz, sz, t]
			return "已到 %d×%d" % [sz, sz] if sz > 5 else ""
		"追踪异色球":
			if cfg.load("user://track_best.cfg") != OK:
				return ""
			var balls := clampi(int(cfg.get_value("best", "balls", 6)), 6, 12)
			var sc := int(cfg.get_value("best", "score", 0))
			if balls > 6 and sc > 0:
				return "%d 球 · 最佳 %d" % [balls, sc]
			if balls > 6:
				return "已到 %d 球" % balls
			return "最佳 %d" % sc if sc > 0 else ""
		"N-Back":
			if cfg.load("user://nback_best.cfg") != OK:
				return ""
			var sc := int(cfg.get_value("best", "score", 0))
			return "最佳 %d" % sc if sc > 0 else ""
		"积木跨度":
			if cfg.load("user://corsi_best.cfg") != OK:
				return ""
			var span := int(cfg.get_value("best", "span", 3))
			var sc := int(cfg.get_value("best", "score", 0))
			if span > 3 and sc > 0:
				return "跨度 %d · 最佳 %d" % [span, sc]
			return "最佳 %d" % sc if sc > 0 else ""
		"各点一次":
			if cfg.load("user://selforder_best.cfg") != OK:
				return ""
			var best_set := int(cfg.get_value("best", "set", 4))
			var sc := int(cfg.get_value("best", "score", 0))
			if best_set > 4 and sc > 0:
				return "最多 %d · 最佳 %d" % [best_set, sc]
			return "最佳 %d" % sc if sc > 0 else ""
		"末项记":
			if cfg.load("user://running_span_best.cfg") != OK:
				return ""
			var span := int(cfg.get_value("best", "span", 2))
			var sc := int(cfg.get_value("best", "score", 0))
			if span > 2 and sc > 0:
				return "末项 %d · 最佳 %d" % [span, sc]
			return "最佳 %d" % sc if sc > 0 else ""
		"看点数":
			if cfg.load("user://dots_best.cfg") != OK:
				return ""
			var sc := int(cfg.get_value("best", "score", 0))
			return "最佳 %d" % sc if sc > 0 else ""
		"任务切换":
			if cfg.load("user://switch_best.cfg") != OK:
				return ""
			var sc := int(cfg.get_value("best", "score", 0))
			return "最佳 %d" % sc if sc > 0 else ""
		"规则变了":
			if cfg.load("user://ruleshift_best.cfg") != OK:
				return ""
			var sc := int(cfg.get_value("best", "score", 0))
			return "最佳 %d" % sc if sc > 0 else ""
		"汉诺塔":
			if cfg.load("user://hanoi_best.cfg") != OK:
				return ""
			var disks := clampi(int(cfg.get_value("best", "disks", 3)), 3, 6)
			var sc := int(cfg.get_value("best", "score", 0))
			if disks > 3 and sc > 0:
				return "%d 盘 · 最佳 %d" % [disks, sc]
			if disks > 3:
				return "已到 %d 盘" % disks
			return "最佳 %d" % sc if sc > 0 else ""
		_:
			return ""


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
	if open_intercept.is_valid():
		open_intercept.call(scene_path)
		return
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


func _bind_system_back() -> void:
	var win := get_window()
	if win != null and not win.go_back_requested.is_connected(_on_system_back):
		win.go_back_requested.connect(_on_system_back)
	if not tree_exiting.is_connected(_unbind_system_back):
		tree_exiting.connect(_unbind_system_back)


func _unbind_system_back() -> void:
	var win := get_window()
	if win != null and win.go_back_requested.is_connected(_on_system_back):
		win.go_back_requested.disconnect(_on_system_back)


func _on_system_back() -> void:
	_arm_or_quit()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE:
		return
	_arm_or_quit()
	get_viewport().set_input_as_handled()


func _arm_or_quit() -> void:
	if _quit_armed:
		get_tree().quit()
		return
	_quit_armed = true
	_show_quit_hint()
	get_tree().create_timer(2.0).timeout.connect(_disarm_quit)


func _disarm_quit() -> void:
	_quit_armed = false
	if _quit_hint != null:
		_quit_hint.queue_free()
		_quit_hint = null


func _show_quit_hint() -> void:
	if _quit_hint != null:
		_quit_hint.queue_free()
	_quit_hint = Label.new()
	_quit_hint.text = "再按一次返回退出"
	_quit_hint.add_theme_font_size_override("font_size", 18)
	_quit_hint.add_theme_color_override("font_color", Color("#e8edff"))
	_quit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quit_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quit_hint.z_index = 30
	_quit_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_quit_hint.offset_top = -88
	_quit_hint.offset_bottom = -44
	add_child(_quit_hint)


class HubCard extends Panel:
	## Menu card: a tap activates, a drag past the threshold scrolls the hub list.
	signal activated

	const DRAG_THRESHOLD := 14.0

	var scroll: ScrollContainer
	var is_disabled := false
	var _normal: StyleBoxFlat
	var _hover: StyleBoxFlat
	var _press: StyleBoxFlat
	var _tracking := false
	var _dragging := false
	var _press_pos := Vector2.ZERO
	var _last_pos := Vector2.ZERO
	var _hovering := false

	func setup(p_scroll: ScrollContainer, bg: Color, disabled: bool) -> void:
		scroll = p_scroll
		is_disabled = disabled
		mouse_filter = Control.MOUSE_FILTER_STOP
		_normal = _make_box(bg)
		_hover = _make_box(bg.lightened(0.12))
		_press = _make_box(bg.darkened(0.15))
		_apply_style()
		if not mouse_entered.is_connected(_on_mouse_entered):
			mouse_entered.connect(_on_mouse_entered)
		if not mouse_exited.is_connected(_on_mouse_exited):
			mouse_exited.connect(_on_mouse_exited)

	func _make_box(bg: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = bg
		style.set_corner_radius_all(12)
		return style

	func _apply_style() -> void:
		if _tracking and not _dragging and not is_disabled:
			add_theme_stylebox_override("panel", _press)
		elif _hovering and not _dragging and not is_disabled:
			add_theme_stylebox_override("panel", _hover)
		else:
			add_theme_stylebox_override("panel", _normal)

	func _on_mouse_entered() -> void:
		_hovering = true
		if not _tracking:
			_apply_style()

	func _on_mouse_exited() -> void:
		_hovering = false
		if not _tracking:
			_apply_style()

	func _gui_input(event: InputEvent) -> void:
		var mouse_btn := event as InputEventMouseButton
		if mouse_btn != null:
			if mouse_btn.pressed and (mouse_btn.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_btn.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				_scroll_by_wheel(mouse_btn)
				accept_event()
				return
			if mouse_btn.button_index == MOUSE_BUTTON_LEFT:
				if mouse_btn.pressed:
					_tracking = true
					_dragging = false
					_press_pos = mouse_btn.global_position
					_last_pos = mouse_btn.global_position
					_apply_style()
				else:
					var was_drag := _dragging
					_tracking = false
					_dragging = false
					_apply_style()
					if not was_drag and not is_disabled:
						activated.emit()
					accept_event()
				return
		var pan := event as InputEventPanGesture
		if pan != null:
			if scroll != null:
				scroll.scroll_vertical += int(round(pan.delta.y))
			accept_event()
			return
		var motion := event as InputEventMouseMotion
		if motion != null and _tracking:
			var pos := motion.global_position
			if not _dragging and pos.distance_to(_press_pos) >= DRAG_THRESHOLD:
				_dragging = true
				_apply_style()
			if _dragging and scroll != null:
				scroll.scroll_vertical -= int(round(pos.y - _last_pos.y))
				accept_event()
			_last_pos = pos

	func _scroll_by_wheel(wheel: InputEventMouseButton) -> void:
		if scroll == null:
			return
		var bar := scroll.get_v_scroll_bar()
		var page := bar.page if bar != null else 120.0
		var amount := page * maxf(wheel.factor, 0.1) / 8.0
		if amount < 16.0:
			amount = 16.0
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll.scroll_vertical -= int(round(amount))
		else:
			scroll.scroll_vertical += int(round(amount))

