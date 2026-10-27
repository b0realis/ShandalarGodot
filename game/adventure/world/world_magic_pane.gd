class_name WorldMagicPane
extends PanelContainer
## THE WORLD MAGIC SELLER, as the hero leaves a town ([WorldMagicShop]) —
## 1.3 `VisitTownSlot`'s screen: `Worlbak1.pic` (a skull, a candle and a
## crystal ball), the World Magic's icon in the ball (`Worlds.spr`), and
## centred beside it "WORLDMAGIC:", its name, "costs %d gold pieces." and
## its words; then "Travel North to Kraag Temple." — or, in the town that
## sells it, "To release the WORLDMAGIC spell … you must pay … gold
## pieces." with Never mind / Pay the gold, or "Insufficient Funds". The
## 1997 places and colours, on a stage scaled to the screen, in the panes'
## glass ([PaneStyle]); a plain dark stage without the 1997 pictures.

## Closed: bought or not.
signal done

## The 1997 screen, and where its lines stand on it (640 × 480 units).
const SCREEN := Vector2(640, 480)
const ICON_AT := Vector2(348, 88)
const TEXT_X := 374.0
const TEXT_WIDTH := 300.0
## The 1997 inks (`Advfac64.pic`'s palette: 0x7B, 0x40, 0x8D, 0xBE).
const SAND := Color8(243, 211, 175)
const SKY := Color8(147, 207, 239)
const YELLOW := Color8(255, 211, 39)
const RED := Color8(255, 43, 15)

var player: AdventurePlayer
## What is offered ([method WorldMagicShop.offer]).
var offer := {}
var k := 1.0
var _stage: Control
var _scale := 1.0
var _note: Label
## The choices, answering to their first letter ([method
## VisitPane.letter_choice]).
var _choices: HBoxContainer
## Whether [signal done] has been sent: the pane closes once, however many
## clicks and keys arrive before the world screen frees it (deferred) —
## leaving the town runs on that signal.
var _closed := false


func _ready() -> void:
	name = "WorldMagicPane"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass(10.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	_scale = clampf(minf((room.x - 80.0) / SCREEN.x, (room.y - 160.0 * k) / SCREEN.y), 0.6, 1.25)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.custom_minimum_size = SCREEN * _scale
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage)
	var ground := GameSkin.texture("world_magic_seller")
	if ground != null:
		var art := TextureRect.new()
		art.name = "Ground"
		art.texture = ground
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.size = SCREEN * _scale
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(art)
	else:
		var plain := ColorRect.new()
		plain.color = Color(0.04, 0.03, 0.05)
		plain.size = SCREEN * _scale
		plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(plain)
	_icon()
	var index := int(offer.get("index", 0))
	var magic := String(offer.get("name", ""))
	# 1997 centred the heading on its point (`DrawTextAt`, both ways); the
	# lines under it hang from theirs (`DrawUiScaledCenteredText`, the top).
	var heading := _line(WorldMagicShop.HEADING, 75, SAND, 18)
	heading.position.y -= heading.get_line_height() / 2.0
	_line(magic, 146, SKY, 18)
	_line(WorldMagicShop.COSTS % int(offer.get("price", 0)), 162, SAND, 16)
	_line("(%s)" % String(WorldHud.MAGIC_TIPS.get(magic, "")), 178, SAND, 15)
	var words := WorldMagicShop.words(offer)
	var here := bool(offer.get("here", false))
	var afford := bool(offer.get("afford", false))
	if not here:
		_line(words[0], 226, YELLOW, 18)
	elif not afford:
		_line(words[0], 226, RED, 18)
	else:
		_line(words[0], 226, SAND, 16)
	var buttons := HBoxContainer.new()
	_choices = buttons
	buttons.name = "Choices"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(10 * k))
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if here and afford:
		var never := PaneStyle.button(WorldMagicShop.NEVER_MIND, "Never", k)
		never.pressed.connect(close)
		buttons.add_child(never)
		var pay := PaneStyle.button(WorldMagicShop.PAY, "Pay", k)
		pay.pressed.connect(buy)
		buttons.add_child(pay)
	else:
		var leave := PaneStyle.button("Done", "Done", k)
		leave.pressed.connect(close)
		buttons.add_child(leave)
	column.add_child(buttons)
	_note = PaneStyle.label("", 14, PaneStyle.DIM)
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)
	set_meta("index", index)


## The World Magic's icon in the crystal ball (`Worlds.spr` frame `index`).
func _icon() -> void:
	var art := WorldArt.new()
	var sheet := art.texture("world_magics")
	if sheet == null:
		return
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = art.frame_rect("world_magics", int(offer.get("index", 0)))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = cut
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = ICON_AT * _scale
	icon.size = cut.region.size * _scale
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(icon)


## A line centred on the 1997 column at height [param y] (640 × 480 units).
func _line(text: String, y: float, ink: Color, size: int) -> Label:
	var line := PaneStyle.label(text, int(size * _scale), ink)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.position = Vector2((TEXT_X - TEXT_WIDTH / 2.0) * _scale, y * _scale)
	line.size = Vector2(TEXT_WIDTH * _scale, 0)
	line.custom_minimum_size = Vector2(TEXT_WIDTH * _scale, 0)
	_stage.add_child(line)
	return line


## PAY THE GOLD: the World Magic is the hero's ([method WorldMagicShop.buy]).
func buy() -> void:
	var said := WorldMagicShop.buy(player, offer)
	_note.text = said
	if said != "":
		close()


## CLOSE the pane: [signal done], once.
func close() -> void:
	if _closed:
		return
	_closed = true
	done.emit()


func note() -> String:
	return _note.text


func _input(event: InputEvent) -> void:
	VisitPane.drop_letter(_choices, event)


func _unhandled_input(input: InputEvent) -> void:
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif VisitPane.letter_choice(self, _choices, input):
		# A choice by its first letter (N, P, D), Enter takes it (C-5).
		get_viewport().set_input_as_handled()
