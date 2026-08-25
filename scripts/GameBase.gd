extends Control
## Shared scaffolding for every mini-game: dark background, back button, title.


const HUB_SCENE := "res://scenes/Hub.tscn"
const BG_COLOR := Color("#0d1220")

var title_text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_back_button()
	if title_text != "":
		_build_title()
	_build_game()


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


func _go_back() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style_button(btn: Button, bg: Color) -> void:
	btn.add_theme_stylebox_override("normal", _make_flat(bg))
	btn.add_theme_stylebox_override("hover", _make_flat(bg.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", _make_flat(bg.darkened(0.15)))
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
