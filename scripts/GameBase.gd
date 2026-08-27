extends Control
## Shared scaffolding for every mini-game: dark background, back, title, help.


const HUB_SCENE := "res://scenes/Hub.tscn"
const BG_COLOR := Color("#0d1220")

var title_text := ""
var help_text := ""

var _help_overlay: Control
var _help_open := false
var _gate_panel: Panel
var _gate_label: Label
var _gate_continue_btn: Button
var _gate_fresh_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_back_button()
	if title_text != "":
		_build_title()
	_build_help_button()
	_build_progress_gate()
	_build_game()
	_build_help_overlay()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_back_button() -> void:
	var btn := Button.new()
	btn.text = "< 返回"
	btn.position = Vector2(16, 16)
	btn.size = Vector2(96, 48)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(btn, Color("#1a2740"))
	btn.pressed.connect(_go_back)
	add_child(btn)


func _build_title() -> void:
	var label := Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("#e8edff"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 120
	label.offset_right = -120
	label.offset_top = 20
	label.offset_bottom = 64
	add_child(label)


## Overridden by each game to build its own content.
func _build_game() -> void:
	pass


## Shared continue-or-restart gate used by games that remember a level.
func _build_progress_gate() -> void:
	_gate_panel = Panel.new()
	_gate_panel.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#152034")
	style.set_corner_radius_all(14)
	_gate_panel.add_theme_stylebox_override("panel", style)
	add_child(_gate_panel)
	_gate_label = _make_label("", 22, Color("#e8edff"))
	_gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gate_label.offset_left = 24
	_gate_label.offset_right = -24
	_gate_panel.add_child(_gate_label)

	_gate_continue_btn = Button.new()
	_gate_continue_btn.z_index = 21
	_gate_continue_btn.focus_mode = Control.FOCUS_NONE
	_gate_continue_btn.add_theme_font_size_override("font_size", 26)
	_gate_continue_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(_gate_continue_btn, Color("#4ade80"))
	_gate_continue_btn.pressed.connect(_on_progress_continue)
	add_child(_gate_continue_btn)

	_gate_fresh_btn = Button.new()
	_gate_fresh_btn.z_index = 21
	_gate_fresh_btn.focus_mode = Control.FOCUS_NONE
	_gate_fresh_btn.add_theme_font_size_override("font_size", 24)
	_gate_fresh_btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(_gate_fresh_btn, Color("#1a2740"))
	_gate_fresh_btn.pressed.connect(_on_progress_fresh)
	add_child(_gate_fresh_btn)
	_hide_progress_gate()
	_layout_progress_gate()


func _layout_progress_gate() -> void:
	if _gate_panel == null:
		return
	var vp := get_viewport_rect().size
	_gate_panel.position = Vector2(40, 220)
	_gate_panel.size = Vector2(vp.x - 80.0, 220)
	_gate_continue_btn.position = Vector2(40, _gate_panel.position.y + 236.0)
	_gate_continue_btn.size = Vector2(vp.x - 80.0, 72)
	_gate_fresh_btn.position = Vector2(40, _gate_continue_btn.position.y + 88.0)
	_gate_fresh_btn.size = Vector2(vp.x - 80.0, 64)


func _show_progress_gate(body: String, continue_text: String, fresh_text: String) -> void:
	_layout_progress_gate()
	_gate_label.text = body
	_gate_continue_btn.text = continue_text
	_gate_fresh_btn.text = fresh_text
	_gate_panel.visible = true
	_gate_continue_btn.visible = true
	_gate_fresh_btn.visible = true


func _hide_progress_gate() -> void:
	if _gate_panel == null:
		return
	_gate_panel.visible = false
	_gate_continue_btn.visible = false
	_gate_fresh_btn.visible = false


func _on_progress_continue() -> void:
	pass


func _on_progress_fresh() -> void:
	pass


func _build_help_button() -> void:
	if help_text == "":
		return
	var btn := Button.new()
	btn.text = "?"
	btn.focus_mode = Control.FOCUS_NONE
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.z_index = 110
	btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = -64
	btn.offset_top = 16
	btn.offset_right = -16
	btn.offset_bottom = 64
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color("#e8edff"))
	_style_button(btn, Color("#1a2740"))
	btn.pressed.connect(_toggle_help)
	add_child(btn)


func _build_help_overlay() -> void:
	if help_text == "":
		return
	_help_overlay = HelpLayer.new()
	_help_overlay.visible = false
	_help_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_help_overlay.z_index = 100
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.closed.connect(_hide_help)
	add_child(_help_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_help_dim_input)
	_help_overlay.add_child(dim)

	var card := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a2740")
	style.set_corner_radius_all(14)
	card.add_theme_stylebox_override("panel", style)
	card.anchor_left = 0.08
	card.anchor_right = 0.92
	card.anchor_top = 0.22
	card.anchor_bottom = 0.78
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.add_child(card)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_right = -28
	box.offset_top = 24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	var heading := _make_label("玩法", 28, Color("#e8edff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	if title_text != "":
		var sub := _make_label(title_text, 16, Color("#8ab4ff"))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)

	var body := _make_label(help_text, 20, Color("#e8edff"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "知道了"
	close_btn.custom_minimum_size = Vector2(0, 56)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_color_override("font_color", Color("#0d1220"))
	_style_button(close_btn, Color("#4ade80"))
	close_btn.pressed.connect(_hide_help)
	box.add_child(close_btn)


func _toggle_help() -> void:
	if _help_open:
		_hide_help()
	else:
		_show_help()


func _show_help() -> void:
	if _help_overlay == null:
		return
	_help_open = true
	_help_overlay.visible = true
	_help_overlay.move_to_front()
	get_tree().paused = true


func _hide_help() -> void:
	_help_open = false
	if _help_overlay != null:
		_help_overlay.visible = false
	get_tree().paused = false


func _on_help_dim_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_hide_help()


func _go_back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style_button(btn: Button, bg: Color) -> void:
	var pressed := _make_flat(bg.darkened(0.15))
	btn.add_theme_stylebox_override("normal", _make_flat(bg))
	btn.add_theme_stylebox_override("hover", _make_flat(bg.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("focus", _make_flat(bg))
	btn.add_theme_stylebox_override("disabled", _make_flat(bg.darkened(0.3)))


func _make_flat(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _make_restart_button(callback: Callable, y: float = -1.0) -> Button:
	var btn := Button.new()
	btn.text = "重新开始"
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color("#e8edff"))
	btn.custom_minimum_size = Vector2(220, 60)
	var vp := get_viewport_rect().size
	if y < 0.0:
		y = vp.y - 160.0
	btn.position = Vector2((vp.x - 220.0) / 2.0, y)
	_style_button(btn, Color("#1a2740"))
	btn.pressed.connect(callback)
	add_child(btn)
	return btn


func _burst_feedback(text: String, color: Color = Color("#4ade80")) -> void:
	var old := get_node_or_null("BurstFeedback")
	if old != null:
		old.queue_free()
	var old_wash := get_node_or_null("BurstWash")
	if old_wash != null:
		old_wash.queue_free()
	var wash := ColorRect.new()
	wash.name = "BurstWash"
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.z_index = 70
	wash.color = Color(color.r, color.g, color.b, 0.18)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	var wash_tw := create_tween()
	wash_tw.tween_property(wash, "modulate:a", 0.0, 0.28)
	wash_tw.tween_callback(wash.queue_free)

	var label := Label.new()
	label.name = "BurstFeedback"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 80
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#0d1220"))
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -280
	label.offset_right = 280
	label.offset_top = -70
	label.offset_bottom = 70
	label.pivot_offset = Vector2(280, 70)
	label.scale = Vector2(0.72, 0.72)
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.28)
	tw.tween_property(label, "modulate:a", 0.0, 0.22)
	tw.tween_callback(label.queue_free)


class HelpLayer extends Control:
	signal closed

	func _input(event: InputEvent) -> void:
		if not visible:
			return
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			closed.emit()
			get_viewport().set_input_as_handled()
