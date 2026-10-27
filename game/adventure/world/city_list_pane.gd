class_name CityListPane
extends PanelContainer
## THE CITY LIST (F3; the owner, 2026-10-23: part A of the world's missing
## pieces) — 1.3's `ShowCityInfoScreen` (cityInfoScreen.c 248) and
## `DrawCityInfoTownRow` (639), on its own 640 × 480 ground (`Cityinfo.pic`)
## in the panes' glass, scaled to the screen:
##  - every town and city the hero has visited ([TownStatus.VISITED]), in
##    slot order, nine rows at a time;
##  - [ours] every wizard's CASTLE the hero has stood before (its site
##    marked visited as its pane opens), in the same order: its name in its
##    wizard's ink, the wizard's colour stone, the wizard — "beaten" once he
##    is — and the attempts at it (the slot's `entered`, [DungeonDoors]).
##    The owner, 2026-10-27: "Yes, list castles" — 1997's own castle rows
##    (`DrawCityInfoTownRow`, cityInfoScreen.c 639: "Castle" and its land)
##    could never be reached, no visit marking a castle (H5, both builds);
##  - each row its name in two lines, the colours of its land (the amulets'
##    stones), the cards it trades ([method CardTrade.wares]), the World
##    Magic it sells, and an X for a mana link;
##  - a row's ink: white when linked, yellow when not, the wizard's colour
##    when he holds it;
##  - the hero's amulets counted along the top (without `Cityinfo.pic`, a
##    coloured square where its painted stone stands [ours]);
##  - the four arrows (a row, eight rows) and Done (`Infobar.pic`); Space,
##    Enter, D or Escape close it. [Ours: the mouse wheel scrolls; a black
##    wizard's town is drawn dark grey on the dark ground — 1997 drew it
##    black, unreadable.]
##  - A ROW'S STEP SLIDES (H4): one row up or down glides the list by a
##    row's height, the row leaving drawn as it goes, as 1997 slid it in
##    3-pixel steps (cityInfoScreen.c 526–531, 551–556; [constant SLIDE],
##    [method slide_offset]); eight rows at a time (PgUp, PgDn) jump, as
##    1997's did (583–594). The list is clipped to its nine rows. Each row
##    lies on 1997's row panel (`Cinfopce.pic`, `city_list_row`, drawn under
##    every row, 357–372), which slides with it.
## Without the 1997 pictures the stage is plain and the buttons are words.

signal done

const SCREEN := Vector2(640, 480)
const ROWS := 9
const ROW_TOP := 82.0
const ROW_HEIGHT := 42.0
## The columns' middles: name, stones, trade, World Magic, link.
const COLUMNS: Array[float] = [90.0, 176.0, 303.0, 460.0, 572.0]
const COLUMN_WIDTHS: Array[float] = [84.0, 84.0, 166.0, 144.0, 74.0]
## `@CITYINFO`'s headings and their places.
const HEADINGS: Array[Array] = [["Your Mana Stones", 105, 40], ["City Name", 84, 69],
	["Mana Stones", 179, 69], ["Cards for Trade", 304, 69], ["World Magics", 460, 69],
	["Mana Links", 575, 69]]
## The amulets' stones in `Amsprite.spr` (white, blue, black, red, green),
## black to white.
const STONE_FRAMES: Array[int] = [2, 1, 4, 3, 0]
## The inks: a heading's (0xC8), a linked town's, an unlinked one's (0xE3),
## and a wizard's town's, black to white.
const HEADING_INK := Color8(147, 139, 123)
const LINKED_INK := Color8(255, 255, 255)
const UNLINKED_INK := Color8(255, 231, 27)
const RULER_INKS: Array[Color] = [Color8(70, 70, 70), Color8(0, 75, 187), Color8(0, 135, 43),
	Color8(191, 35, 15), Color8(187, 187, 187)]
## The arrows on `Infobar.pic`: page up, up, down, page down — where they
## are painted on the ground, and their cells (four states across).
const ARROWS_AT: Array[float] = [173.0, 223.0, 273.0, 323.0]
const ARROW_STEPS: Array[int] = [-8, -1, 1, 8]
## How long a row's step glides, in seconds.
const SLIDE := 0.12
## The row panel on `Cinfopce.pic`, and where a row's lies (1997's
## `list_panel_x` 0x30, its width 0x231).
const ROW_PANEL := Rect2(0, 26, 561, 42)
const ROW_LEFT := 48.0
## A castle's row [ours]: the wizard, beaten, the attempts.
const CASTLE_WORDS := "%s"
const BEATEN_WORDS := "%s, beaten"
const ATTEMPTS_WORDS := "Attempts: %d"

var player: AdventurePlayer
var k := 1.0
## The first row shown.
var top := 0
## A row's step jumps, as a page's does (tests; nothing else).
var instant := false
var _towns: Array[int] = []
var _stage: Control
var _scale := 1.0
## The nine rows' window, clipped; the rows in it, at their place on the
## stage when not sliding ([method slide_offset] 0).
var _list: Control
var _rows: Control
## The row leaving during a slide, freed as it ends.
var _leaving: Control
var _slide: Tween
var _arrows: Array[BaseButton] = []
var _art := WorldArt.new()


## The places listed, in slot order: the towns and cities visited, and
## the castles stood before [ours].
static func towns(world: ShandalarWorld) -> Array[int]:
	var out: Array[int] = []
	for slot in world.sites.size():
		if TownStatus.visited(world, slot) and (TownStatus.is_town(world, slot)
				or WorldNames.castle_of_site(world, slot) >= 0):
			out.append(slot)
	return out


func _ready() -> void:
	name = "CityList"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass(10.0))
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	_scale = clampf(minf((room.x - 60.0) / SCREEN.x, (room.y - 60.0) / SCREEN.y), 0.6, 1.25)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.custom_minimum_size = SCREEN * _scale
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_stage)
	var ground := GameSkin.texture("city_list")
	if ground != null:
		var art := TextureRect.new()
		art.texture = ground
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.size = SCREEN * _scale
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(art)
	else:
		var plain := ColorRect.new()
		plain.color = Color(0.13, 0.12, 0.12)
		plain.size = SCREEN * _scale
		plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(plain)
	for heading in HEADINGS:
		_text(String(heading[0]), Vector2(heading[1], heading[2]), 12, HEADING_INK, 140.0)
	for i in 5:
		_text(str(int(player.amulets.get(AdventurePlayer.COLORS[i], 0))), Vector2(204 + 42 * i, 42),
			15, Color.WHITE, 30.0)
		if ground == null:
			var disc := WorldArt.amulet_disc(i, 9.0 * _scale)
			disc.name = "Amulet_%s" % AdventurePlayer.COLORS[i]
			disc.position = Vector2(186 + 42 * i, 35) * _scale
			_stage.add_child(disc)
	_list = Control.new()
	_list.name = "List"
	_list.position = Vector2(0, ROW_TOP) * _scale
	_list.size = Vector2(SCREEN.x, ROWS * ROW_HEIGHT) * _scale
	_list.clip_contents = true
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_list)
	_rows = Control.new()
	_rows.name = "Rows"
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.position = Vector2(0, -ROW_TOP * _scale)
	_list.add_child(_rows)
	for b in 4:
		_arrows.append(_arrow(b))
	_done_button()
	_towns = towns(player.world)
	refresh()


## The rows from [member top], the arrows lit or dimmed.
func refresh() -> void:
	top = clampi(top, 0, maxi(0, _towns.size() - ROWS))
	_stop_slide()
	for child in _rows.get_children():
		child.queue_free()
	for j in mini(ROWS, _towns.size() - top):
		_rows.add_child(_row(_towns[top + j], j))
	var first := top <= 0
	var last := top >= _towns.size() - ROWS
	for b in 4:
		_arrows[b].disabled = first if b < 2 else last


## Scroll by [param rows] (a row, or eight); a row's step slides.
func scroll(rows: int) -> void:
	var was := top
	top += rows
	refresh()
	var moved := top - was
	if absi(moved) == 1 and not instant:
		_slide_by(moved, was)


## How far the rows stand from their place, in the stage's pixels: 0 at
## rest, a row's height as a step's slide begins.
func slide_offset() -> float:
	return _rows.position.y + ROW_TOP * _scale


## The rows glide from where they stood to their place, the row that left
## drawn beside them until the glide ends.
func _slide_by(moved: int, was: int) -> void:
	var leaving := was if moved > 0 else was + ROWS - 1
	if leaving >= 0 and leaving < _towns.size():
		_leaving = _row(_towns[leaving], -1 if moved > 0 else ROWS)
		_rows.add_child(_leaving)
	var rest := -ROW_TOP * _scale
	_rows.position.y = rest + moved * ROW_HEIGHT * _scale
	_slide = create_tween()
	_slide.tween_property(_rows, "position:y", rest, SLIDE)
	_slide.finished.connect(_stop_slide)


## The slide ended or cut short: the rows at their place, the leaving row
## gone.
func _stop_slide() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = null
	if _rows != null:
		_rows.position.y = -ROW_TOP * _scale
	if _leaving != null and is_instance_valid(_leaving):
		_leaving.queue_free()
	_leaving = null


## Site [param slot]'s row, the [param j]th of the window (−1 above it, 9
## under), its text centred on its middle: a town's or a castle's.
func _row(slot: int, j: int) -> Control:
	var row := Control.new()
	row.name = "Row_%d" % slot
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := GameSkin.texture("city_list_row")
	if panel != null:
		var lay := TextureRect.new()
		lay.name = "Panel"
		lay.texture = WorldMap.cell(panel, ROW_PANEL)
		lay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lay.stretch_mode = TextureRect.STRETCH_SCALE
		lay.position = Vector2(ROW_LEFT, ROW_TOP + ROW_HEIGHT * j) * _scale
		lay.size = ROW_PANEL.size * _scale
		lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lay)
	var y := ROW_TOP + 22.0 + ROW_HEIGHT * j
	var castle := WorldNames.castle_of_site(player.world, slot)
	if castle >= 0:
		_castle_row(row, slot, castle, y)
		return row
	var world := player.world
	var ink := LINKED_INK if TownStatus.linked(world, slot) else UNLINKED_INK
	var ruler := TownStatus.ruler(world, slot)
	if ruler != 0:
		ink = RULER_INKS[ruler - 1]
	var name_lines := WorldNames.two_lines(WorldNames.site_name(world, slot))
	_text("\n".join(name_lines), Vector2(COLUMNS[0], y), 13, ink, COLUMN_WIDTHS[0], row)
	# The stones: a colour of the land each, black to white.
	var mask := CardShop.town_colors(world, slot)
	var stones: Array[int] = []
	for i in 5:
		if mask & CardShop.COLOR_BITS[i] != 0:
			stones.append(i)
	var width := stones.size() * 12 + maxi(stones.size() - 1, 0) * 5
	for n in stones.size():
		_stone(stones[n], Vector2(COLUMNS[1] - width / 2.0 + n * 17, y - 8.5), row)
	_text(CardTrade.wares(int(world.sites[slot].get("trade", 0))), Vector2(COLUMNS[2], y), 13, ink,
		COLUMN_WIDTHS[2], row)
	var magic := WorldMagicShop.sold_at(world, slot)
	_text(AdventurePlayer.WORLD_MAGICS[magic] if magic >= 0 else "", Vector2(COLUMNS[3], y), 13, ink,
		COLUMN_WIDTHS[3], row)
	_text("X" if TownStatus.linked(world, slot) else "", Vector2(COLUMNS[4], y), 15, ink, COLUMN_WIDTHS[4], row)
	return row


## A CASTLE'S ROW [ours]: its name in its wizard's ink, his colour's stone,
## the wizard — beaten or not — and the attempts at the castle.
func _castle_row(row: Control, slot: int, castle: int, y: float) -> void:
	var world := player.world
	var ink := RULER_INKS[castle]
	var name_lines := WorldNames.two_lines(WorldNames.site_name(world, slot))
	_text("\n".join(name_lines), Vector2(COLUMNS[0], y), 13, ink, COLUMN_WIDTHS[0], row)
	_stone(castle, Vector2(COLUMNS[1] - 6.0, y - 8.5), row)
	var wizard := WorldNames.WIZARDS[castle]
	var beaten := AdventurePlayer.COLORS[castle] in player.defeated_wizards
	_text((BEATEN_WORDS if beaten else CASTLE_WORDS) % wizard, Vector2(COLUMNS[2], y), 13, ink,
		COLUMN_WIDTHS[2], row)
	_text(ATTEMPTS_WORDS % DungeonDoors.entered(world, castle), Vector2(COLUMNS[3], y), 13, ink, COLUMN_WIDTHS[3], row)


## A line of text centred at [param at] (640 × 480 units), into [param
## into] (a row), else the stage.
func _text(text: String, at: Vector2, size: int, ink: Color, width: float, into: Control = null) -> Label:
	var line := PaneStyle.label(text, int(size * _scale), ink)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.size = Vector2(width, ROW_HEIGHT - 4.0) * _scale
	line.position = (at - Vector2(width / 2.0, (ROW_HEIGHT - 4.0) / 2.0)) * _scale
	line.clip_text = true
	(into if into != null else _stage).add_child(line)
	return line


## An amulet's stone, colour [param color] (0 black … 4 white), its top
## left at [param at], into [param row].
func _stone(color: int, at: Vector2, row: Control) -> void:
	var sheet := _art.texture("world_amulets")
	if sheet == null:
		var dot := WorldArt.amulet_disc(color, 8.0 * _scale)
		dot.position = (at + Vector2(2, 4)) * _scale
		row.add_child(dot)
		return
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = _art.frame_rect("world_amulets", STONE_FRAMES[color])
	var stone := TextureRect.new()
	stone.texture = cut
	stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stone.position = at * _scale
	stone.size = cut.region.size * _scale
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stone)


## Arrow [param b] (page up, up, down, page down), on the painted one.
func _arrow(b: int) -> BaseButton:
	var sheet := GameSkin.texture("city_list_buttons")
	var button: BaseButton
	if sheet != null:
		var cut := TextureButton.new()
		cut.texture_normal = WorldMap.cell(sheet, Rect2(43, 28 + 49 * b, 17, 47))
		cut.texture_hover = WorldMap.cell(sheet, Rect2(61, 28 + 49 * b, 17, 47))
		cut.texture_pressed = WorldMap.cell(sheet, Rect2(79, 28 + 49 * b, 17, 47))
		cut.texture_disabled = WorldMap.cell(sheet, Rect2(97, 28 + 49 * b, 17, 47))
		cut.ignore_texture_size = true
		cut.stretch_mode = TextureButton.STRETCH_SCALE
		button = cut
	else:
		button = PaneStyle.button(["⇞", "↑", "↓", "⇟"][b], "", 1.0, 12)
	button.name = "Arrow_%d" % b
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(27, ARROWS_AT[b]) * _scale
	button.size = Vector2(17, 47) * _scale
	button.pressed.connect(scroll.bind(ARROW_STEPS[b]))
	_stage.add_child(button)
	return button


func _done_button() -> void:
	var sheet := GameSkin.texture("city_list_buttons")
	var button: BaseButton
	if sheet != null:
		var cut := TextureButton.new()
		cut.texture_normal = WorldMap.cell(sheet, Rect2(43, 1, 58, 24))
		cut.texture_hover = WorldMap.cell(sheet, Rect2(103, 1, 58, 24))
		cut.texture_pressed = WorldMap.cell(sheet, Rect2(163, 1, 58, 24))
		cut.ignore_texture_size = true
		cut.stretch_mode = TextureButton.STRETCH_SCALE
		var word := PaneStyle.label("Done", int(13 * _scale), PaneStyle.INK)
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cut.add_child(word)
		button = cut
	else:
		button = PaneStyle.button("Done", "", 1.0, 13)
	button.name = "Done"
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(544, 28) * _scale
	button.size = Vector2(58, 24) * _scale
	button.pressed.connect(func() -> void: done.emit())
	_stage.add_child(button)


## The names shown now, top to bottom.
func shown() -> Array[String]:
	var out: Array[String] = []
	for j in mini(ROWS, _towns.size() - top):
		out.append(WorldNames.site_name(player.world, _towns[top + j]))
	return out


func _gui_input(input: InputEvent) -> void:
	var wheel := input as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll(-1)
			accept_event()
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll(1)
			accept_event()


func _unhandled_input(input: InputEvent) -> void:
	var key := input as InputEventKey
	if input.is_action_pressed("ui_cancel") or (key != null and key.pressed and not key.echo
			and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_D, KEY_F3]):
		get_viewport().set_input_as_handled()
		done.emit()
		return
	if key != null and key.pressed:
		var step := {KEY_UP: -1, KEY_DOWN: 1, KEY_PAGEUP: -8, KEY_PAGEDOWN: 8}.get(key.keycode, 0) as int
		if step != 0:
			get_viewport().set_input_as_handled()
			scroll(step)
