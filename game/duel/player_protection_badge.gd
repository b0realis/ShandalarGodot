class_name PlayerProtectionBadge
extends Button
## [QoL] A compact portrait shield, with live, readable public effect details.

var popup_host: Control
var _lines: Array[String] = []
var _title := "Active protection"
var _dialog: OriginalDialog
var _details: Label

func _init() -> void:
	custom_minimum_size = Vector2(32, 20)
	add_theme_font_size_override("font_size", 11)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("163e36") if state == "normal" else Color("256253")
		box.border_color = Color("bba46a")
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		box.set_content_margin_all(2)
		add_theme_stylebox_override(state, box)
	add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	for role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(role, Color("f4e5bc"))
	var glyph := Image.new()
	glyph.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="12" height="14"><path d="M1 1 L11 1 L11 7 Q10 11 6 13 Q2 11 1 7 Z" fill="#5c9d87" stroke="#ead8a1" stroke-width="1"/></svg>')
	icon = ImageTexture.create_from_image(glyph)
	pressed.connect(open_details)
	visible = false

func present(player_name: String, lines: Array[String]) -> void:
	_title = player_name.left(48) + " — active protection"
	_lines = lines.duplicate()
	visible = not _lines.is_empty()
	text = str(_lines.size())
	tooltip_text = _title + "\n" + "\n".join(_lines) + "\nClick for details."
	if is_instance_valid(_dialog):
		if _lines.is_empty(): close_details()
		elif is_instance_valid(_details): _details.text = "\n\n".join(_lines)

func open_details() -> void:
	if _lines.is_empty(): return
	if is_instance_valid(_dialog):
		close_details()
		return
	var room := get_viewport_rect().size
	_dialog = OriginalDialog.create("", Vector2(minf(430, room.x - 24), minf(300, room.y - 24)))
	_dialog.name = "ProtectionDetails"
	_dialog.z_index = 280
	var heading := OriginalDialog.label(_title, 18, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog.body().add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog.body().add_child(scroll)
	_details = OriginalDialog.label("\n\n".join(_lines), 15)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_details)
	_dialog.add_button("Close").pressed.connect(close_details)
	(popup_host if popup_host != null else get_tree().root).add_child(_dialog)

func details_open() -> bool:
	return is_instance_valid(_dialog)

func close_details() -> void:
	if is_instance_valid(_dialog): _dialog.queue_free()
	_dialog = null
	_details = null

func _exit_tree() -> void:
	close_details()
