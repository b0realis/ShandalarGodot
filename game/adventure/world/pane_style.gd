class_name PaneStyle
extends RefCounted
## THE LOOK OF THE ADVENTURE'S PANES — the rounded dark glass, the gold
## rim, the 1997 lettering and the quiet buttons the owner chose for every
## pane over the world (2026-10-23: *"popup or hover panes with rounded
## corners"*). One place for it, so a town's pane, the card shop, the card
## trader, the World Magic seller, the city list and the rest look alike
## and change together.
##
## Each maker takes [param k], the size factor of the big buttons for a
## finger ([constant WorldHud.BIG], 1 otherwise).

const GOLD := Color8(232, 190, 110)
const INK := Color8(236, 222, 196)
const DIM := Color8(160, 146, 128)
const FAINT := Color8(120, 108, 96)
const LIT := Color8(255, 236, 170)
const EDGE := Color8(20, 10, 8)
## The dedicated quickslot and its brief save confirmation.
const QUICK_BLUE := Color8(125, 195, 255)
## A card's rarity as its set symbol wears it (the owner, 2026-10-23: *"the
## gold writing on black buttons should turn black on white, black on
## silver, black on gold or black on purple … depending on the card symbol
## and rarity of the card"*): common white, uncommon silver, rare gold,
## special purple — by [method CardShop.shop_rarity] (1–4).
const RARITY_COLORS := {1: Color8(240, 236, 228), 2: Color8(190, 196, 206),
	3: Color8(226, 182, 74), 4: Color8(156, 102, 204)}
## The ink on a lit rarity chip.
const ON_RARITY := Color8(12, 8, 6)
## The glass of a pane, and of a well inside one.
const GLASS := Color(0.05, 0.03, 0.03, 0.94)
const WELL := Color(0, 0, 0, 0.4)


## The pane's own face: dark glass, a thin gold rim, round corners.
static func glass(margin := 14.0, corner := 10) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = GLASS
	face.border_color = Color(GOLD, 0.6)
	face.set_border_width_all(1)
	face.set_corner_radius_all(corner)
	face.set_content_margin_all(margin)
	return face


## A darker well inside a pane (a list, a stage), its rim fainter.
static func well(margin := 6.0) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = WELL
	face.border_color = Color(GOLD, 0.35)
	face.set_border_width_all(1)
	face.set_corner_radius_all(6)
	face.set_content_margin_all(margin)
	return face


## Lettering: the 1997 title face from 15 points up, a shadow beneath.
static func label(text: String, size: int, color := INK) -> Label:
	var line := Label.new()
	line.text = text
	var face := GameSkin.font("font_title")
	if face != null and size >= 15:
		line.add_theme_font_override("font", face)
	line.add_theme_font_size_override("font_size", size)
	line.add_theme_color_override("font_color", color)
	line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	line.add_theme_constant_override("shadow_offset_x", 1)
	line.add_theme_constant_override("shadow_offset_y", 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## A pane's title: gold, outlined.
static func title(text: String, size := 26) -> Label:
	var line := label(text, size, GOLD)
	line.add_theme_color_override("font_outline_color", EDGE)
	line.add_theme_constant_override("outline_size", 4)
	return line


## A label that wraps at [param width] (a wrapping label has no width of its
## own: without one it breaks at every word).
static func wrapped(text: String, size: int, width: float, color := INK) -> Label:
	var line := label(text, size, color)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(width, 0)
	return line


## A choice: the title face on dark glass, lit gold under the pointer,
## named [param button_name]; [param size] its letters' size before [param k].
static func button(words: String, button_name: String, k := 1.0, size := 16) -> Button:
	var choice := Button.new()
	if button_name != "":
		choice.name = button_name
	choice.text = words
	choice.focus_mode = Control.FOCUS_NONE
	var face := GameSkin.font("font_title")
	if face != null:
		choice.add_theme_font_override("font", face)
	choice.add_theme_font_size_override("font_size", int(size * k))
	choice.add_theme_color_override("font_color", INK)
	choice.add_theme_color_override("font_hover_color", LIT)
	choice.add_theme_color_override("font_pressed_color", LIT)
	choice.add_theme_color_override("font_hover_pressed_color", LIT)
	choice.add_theme_color_override("font_disabled_color", Color(DIM, 0.6))
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0.35)
	rest.border_color = Color(GOLD, 0.45)
	rest.set_border_width_all(1)
	rest.set_corner_radius_all(6)
	rest.content_margin_left = 12 * k
	rest.content_margin_right = 12 * k
	rest.content_margin_top = 4 * k
	rest.content_margin_bottom = 4 * k
	var lit := rest.duplicate() as StyleBoxFlat
	lit.bg_color = Color(GOLD, 0.22)
	var on := rest.duplicate() as StyleBoxFlat
	on.bg_color = Color(GOLD, 0.32)
	on.border_color = Color(GOLD, 0.9)
	var off := rest.duplicate() as StyleBoxFlat
	off.border_color = Color(GOLD, 0.15)
	choice.add_theme_stylebox_override("normal", rest)
	choice.add_theme_stylebox_override("hover", lit)
	choice.add_theme_stylebox_override("pressed", on)
	choice.add_theme_stylebox_override("hover_pressed", on)
	choice.add_theme_stylebox_override("disabled", off)
	choice.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return choice


## A PRICE OR NAME CHIP for a card of [param rarity] (1–4): at rest gold
## letters on dark glass; [param lit] (under the pointer, or chosen) black
## letters on the rarity's colour ([constant RARITY_COLORS]), the rim
## thicker when [param chosen].
static func dress_chip(chip: Label, rarity: int, lit: bool, chosen := false) -> void:
	var face := StyleBoxFlat.new()
	face.set_corner_radius_all(6)
	face.content_margin_left = 6
	face.content_margin_right = 6
	face.set_border_width_all(2 if chosen else 1)
	if lit:
		var hue: Color = RARITY_COLORS.get(clampi(rarity, 1, 4), RARITY_COLORS[1])
		face.bg_color = hue
		face.border_color = hue.lightened(0.35) if chosen else hue.darkened(0.25)
		chip.add_theme_color_override("font_color", ON_RARITY)
		chip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	else:
		face.bg_color = Color(0.05, 0.03, 0.03, 0.85)
		face.border_color = Color(GOLD, 0.35)
		chip.add_theme_color_override("font_color", GOLD)
		chip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	chip.add_theme_stylebox_override("normal", face)


## A NODE TAKEN AWAY SAFELY: out of its parent at once (no longer laid
## out, clicked or counted), freed at the end of the frame. Never freed on
## the spot: the node may be the one whose click or signal is being handled
## — Godot refuses that in a debug build ("Object is locked and can't be
## freed", and what called it stops halfway) and frees it under its own
## feet in a release build. Every pane that remakes its parts goes through
## this.
static func drop(node: Node) -> void:
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


## Every child of [param parent] taken away safely ([method drop]).
static func drop_children(parent: Node) -> void:
	for child in parent.get_children():
		drop(child)


## [param fresh] in [param old]'s place among its siblings, [param old]
## taken away safely ([method drop]).
static func swap(old: Node, fresh: Node) -> void:
	var parent := old.get_parent()
	var at := old.get_index()
	drop(old)
	parent.add_child(fresh)
	parent.move_child(fresh, at)


## CARD [param card_name] SHOWN LARGE in [param preview], unless it is the
## card already there: a card drawn costs a few milliseconds, and the
## pointer asks for one at every move. False for a name the card pool does
## not know (nothing shown).
static func show_card(preview: CardPreview, card_name: String) -> bool:
	if not CardRegistry.has_card(card_name):
		return false
	if preview._shown == null or preview._shown.data.card_name != card_name:
		preview.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
	return true


## A pane centred on its parent, growing both ways from the middle.
static func centre(pane: Control) -> void:
	pane.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pane.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pane.grow_vertical = Control.GROW_DIRECTION_BOTH


## A right press — the gesture that reads a card full screen (a finger's
## hold on a touch screen).
static func right_click(input: InputEvent) -> bool:
	var click := input as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT
