class_name WorldMap
extends Control
## THE MAP OF THE WORLD (F2, M; the frame's map scroll) — 1.3's
## `ShowWorldMapScreen` (mapScreen.c 388; the owner, 2026-10-23: part A of
## the world's missing pieces), on its own 640 × 480 stone ground
## (`Mapback.pic`) scaled to the screen:
##  - the land the hero has explored, a 13-pixel diamond a tile in one of
##    three looks (`Ttsprite.spr`: look · 16 + terrain, the look by the
##    tile's place — two primes multiplied, modulo 3), the sea included;
##    the roads as short strokes; a place's icon (a village; a town or a
##    city; a castle) — never a dungeon, a lair or a creature;
##  - MAIN MAP: the towns, cities and castles named in two lines, white when
##    linked, yellow when not, a wizard's colour for his towns, and red
##    for a siege: ours reds the town the besieging creature names
##    ([method WorldStatus.siege_town]); 1997 redded the town NEAREST that
##    creature, the one in roaming slot 7 (`FindNearestTownIndex`,
##    mapScreen.c 605–610 and 676) — the same town while the creature
##    stands at it. No siege is set up yet (they come with the duels), so
##    neither shows today; INFO MAP: each one's land
##    colours as the amulets' stones, what it trades and the World Magic it
##    sells ([method info_words]); PLAIN MAP: the icons alone;
##  - the hero's square blinking (a small node of its own, so the blink
##    never paints the whole map again); the amulets counted down the left;
##    the buttons along the top — the two other maps, City Info (the city
##    list, F3) and Done (`Mapbttns.pic`); M, P, I, C, and Space, Enter, D
##    or Escape [ours: 1997's Escape did nothing here] for Done. M is 1997's
##    Main Map; on the Main Map itself it closes the map [ours], as the M
##    that opened it.
##  - [Ours] THE JOURNAL WALKED ON THE MAP (1997's stats screen journal,
##    `RunStatsWorldMapJournalMenu`, map mode 4): each line of the journal
##    at the place it was written, a marker and its words; Previous and
##    Next, the arrows or the wheel step through them.
## Without the 1997 pictures the same map is drawn plain: the terrain's
## colours, dots for the places, words for the buttons, a coloured square
## beside each amulet count ([method amulet_discs]).

## The map was closed (Done), or City Info asked for.
signal closed
signal city_info_pressed

enum Mode { MAIN, INFO, PLAIN, JOURNAL }

const SCREEN := Vector2(640, 480)
## A tile's diamond on the 1997 map: ((x + y) · 6 − 64, (y − x) · 6 + 264).
const STEP := 6.0
const ORIGIN := Vector2(-64, 264)
const PRIMES: Array[int] = [2, 3, 5, 7, 11, 13]
## `Ttsprite.spr` frames of the places: village, town and city, castle.
const ICON_VILLAGE := 48
const ICON_TOWN := 49
const ICON_CASTLE := 50
## The inks (`Advfac64.pic`): a linked place, an unlinked one, the town
## besieged, and the wizards' towns black to white; the roads; a box.
const LINKED_INK := Color8(255, 255, 255)
const UNLINKED_INK := Color8(255, 231, 27)
const BESIEGED_INK := Color8(255, 43, 15)
const RULER_INKS: Array[Color] = [Color8(70, 70, 70), Color8(147, 207, 239), Color8(7, 187, 55),
	Color8(255, 43, 15), Color8(187, 187, 187)]
const ROAD_INK := Color8(123, 63, 7)
const BOX := Color(0.0, 0.0, 0.0, 0.55)
## The buttons (`[mapButtons]`) and their rows on `Mapbttns.pic`.
const BUTTON_WORDS: Array[String] = ["Main Map", "Plain Map", "Info Map", "City Info", "Done"]
const BUTTON_SIZE := Vector2(94, 28)
## The amulets' stones in `Amsprite.spr` (white, blue, black, red, green),
## black to white.
const STONE_FRAMES: Array[int] = [2, 1, 4, 3, 0]

## How long the hero's square is lit, and then dark.
const BLINK := 0.33

var world: ShandalarWorld
## The adventure, for the amulets, the links and the journal; may be null.
var player: AdventurePlayer
## The hero's tile; setting it moves the blinking square.
var hero_tile := Vector2i.ZERO:
	set(value):
		hero_tile = value
		_place_hero()
## Whether unexplored land is left off, as the original's map did.
var explored_only := true
var mode := Mode.MAIN
## The journal line shown in [constant Mode.JOURNAL].
var journal_index := -1
## Seconds the map has been shown, for the blink.
var _blink := 0.0
## The hero's blinking square, under the buttons.
var _hero_mark: ColorRect
var _art := WorldArt.new()
var _buttons := {}
var _font: Font


func _ready() -> void:
	_font = GameSkin.font("font_title")
	if _font == null:
		_font = ThemeDB.fallback_font
	_hero_mark = ColorRect.new()
	_hero_mark.name = "HeroMark"
	_hero_mark.color = Color.WHITE
	_hero_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero_mark)
	resized.connect(_layout)
	for i in BUTTON_WORDS.size():
		var button := _map_button(i)
		_buttons[BUTTON_WORDS[i]] = button
		add_child(button)
	for words in ["Previous", "Next"]:
		var step := PaneStyle.button(words, "Journal" + words, 1.0, 14)
		step.pressed.connect(step_journal.bind(-1 if words == "Previous" else 1))
		_buttons[words] = step
		add_child(step)
	visibility_changed.connect(func() -> void:
		if visible:
			_layout())
	_layout()


## The blink: the hero's square lit for [constant BLINK] seconds, then dark
## as long. Only the square's own node changes — the map itself is painted
## again only when what it shows changes (its mode, the journal line, the
## world screen's ticks).
func _process(delta: float) -> void:
	if not visible:
		return
	_blink += delta
	_hero_mark.visible = world != null and fmod(_blink, BLINK * 2.0) < BLINK


## Whether tile ([param x], [param y]) is on the map.
func shows(x: int, y: int) -> bool:
	return not explored_only or world.is_explored(x, y)


## Show map [param shown] ([enum Mode]).
func show_mode(shown: Mode) -> void:
	mode = shown
	_place_buttons()
	queue_redraw()


## THE JOURNAL WALKED ON THE MAP from its last line.
func walk_journal() -> void:
	mode = Mode.JOURNAL
	journal_index = _written(player.journal.size() - 1, -1) if player != null else -1
	_place_buttons()
	queue_redraw()


## On to the next written journal line ([param way] 1) or back (−1); at
## the first line and at the last it stays.
func step_journal(way: int) -> void:
	var at := _written(journal_index + way, way)
	if at >= 0:
		journal_index = at
	queue_redraw()


## The journal line at or after [param from] going [param way] (1 on, −1
## back) that has words, or −1 when none is left that way.
func _written(from: int, way: int) -> int:
	if player == null:
		return -1
	var at := from
	while at >= 0 and at < player.journal.size():
		if String((player.journal[at] as Dictionary).get("text", "")) != "":
			return at
		at += way if way != 0 else -1
	return -1


# ------------------------------------------------------------ the stage --

## The 1997 screen's scale and place on this control.
func stage() -> Transform2D:
	var fit := minf(size.x / SCREEN.x, size.y / SCREEN.y)
	var offset := (size - SCREEN * fit) / 2.0
	return Transform2D(0.0, Vector2(fit, fit), 0.0, offset)


## A tile's point on the 1997 screen.
static func tile_point(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + tile.y) * STEP, (tile.y - tile.x) * STEP) + ORIGIN


## A tile's look on `Ttsprite.spr` (0–2): the primes of its place.
static func tile_look(tile: Vector2i) -> int:
	var a: int = PRIMES[posmod(tile.x + tile.y, 6)]
	var b: int = PRIMES[posmod(tile.x * tile.y, 6)]
	return (a * b) % 3


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.02, 0.96))
	if world == null:
		return
	draw_set_transform_matrix(stage())
	var ground := GameSkin.texture("map_ground")
	if ground != null:
		draw_texture_rect(ground, Rect2(Vector2.ZERO, SCREEN), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.12, 0.11, 0.1))
	_draw_land()
	_draw_places()
	if mode == Mode.JOURNAL:
		_draw_journal()
	else:
		_draw_amulets()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_land() -> void:
	var tiles := _art.texture("world_map_tiles")
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if not shows(x, y):
				continue
			var at := tile_point(Vector2i(x, y))
			var code := world.terrain(x, y) & 0x0F
			if tiles != null:
				var frame := tile_look(Vector2i(x, y)) * 16 + code
				var cell := _art.frame_rect("world_map_tiles", frame)
				draw_texture_rect_region(tiles, Rect2(at - Vector2(6, 6), Vector2(13, 13)),
					Rect2(cell.position, Vector2(13, 13)))
			elif code != ShandalarWorld.OCEAN:
				draw_colored_polygon(PackedVector2Array([at + Vector2(-6, 0), at + Vector2(0, -6),
					at + Vector2(6, 0), at + Vector2(0, 6)]), WorldView.PLAIN.get(code, WorldView.PLAIN[0]))
	# The roads: world direction (k mod 8) + 1 drawn as screen direction k.
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			var roads := world.road_bits(x, y)
			if roads == 0 or not shows(x, y):
				continue
			var at := tile_point(Vector2i(x, y))
			for k in range(1, 9):
				var d := (k % 8) + 1
				if roads & (1 << (d - 1)) != 0:
					draw_line(at, at + Vector2(ShandalarWorld.DX[k], ShandalarWorld.DY[k]) * 7.0, ROAD_INK, 2.0)


func _draw_places() -> void:
	var tiles := _art.texture("world_map_tiles")
	var besieged := WorldStatus.siege_town(player) if player != null else -1
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		var kind := int(site["type"])
		var tile := Vector2i(int(site["x"]), int(site["y"]))
		if kind <= 0 or not shows(tile.x, tile.y):
			continue
		var at := tile_point(tile)
		var icon := ICON_VILLAGE if kind == ShandalarWorld.VILLAGE else (ICON_TOWN if kind < ShandalarWorld.CASTLE else ICON_CASTLE)
		if tiles != null:
			draw_texture_rect_region(tiles, Rect2(at - Vector2(7, 18), Vector2(13, 20)),
				_art.frame_rect("world_map_tiles", icon))
		else:
			draw_circle(at, [0, 2.5, 3.5, 4.0, 5.0, 5.0][clampi(kind, 0, 5)], Color8(236, 222, 196) if kind < 4 else Color8(232, 190, 110))
		if kind == ShandalarWorld.VILLAGE or mode == Mode.PLAIN or mode == Mode.JOURNAL:
			continue
		var ink := _ink(slot, besieged)
		if mode == Mode.MAIN or kind == ShandalarWorld.CASTLE:
			_name(slot, at, ink)
		if mode == Mode.INFO:
			_info(slot, at, ink)


## A place's ink on the map.
func _ink(slot: int, besieged: int) -> Color:
	var ruler := TownStatus.ruler(world, slot)
	if ruler != 0:
		return RULER_INKS[ruler - 1]
	if slot == besieged:
		return BESIEGED_INK
	return LINKED_INK if TownStatus.linked(world, slot) else UNLINKED_INK


## A place's name in two lines, on a dark box, centred under its icon.
func _name(slot: int, at: Vector2, ink: Color) -> void:
	var name := WorldNames.site_name(world, slot)
	var lines := WorldNames.two_lines(name)
	for i in lines.size():
		_boxed(lines[i], at + Vector2(0, i * 9.0), ink, 8)


## The Info Map: the land's stones (white to black; a square of each
## colour without `Amsprite.spr`), and under the name the words of
## [method info_words].
func _info(slot: int, at: Vector2, ink: Color) -> void:
	var words := info_words(slot)
	for i in words.size():
		_boxed(words[i], at + Vector2(0, 9.0 * i), ink, 8)
	var mask := CardShop.town_colors(world, slot)
	var stones: Array[int] = []
	for i in range(4, -1, -1):
		if mask & CardShop.COLOR_BITS[i] != 0:
			stones.append(i)
	var sheet := _art.texture("world_amulets")
	var width := stones.size() * 12
	for n in stones.size():
		var spot := at + Vector2(-width / 2.0 + n * 12, 12)
		if sheet != null:
			draw_texture_rect_region(sheet, Rect2(spot, Vector2(12, 17) * 0.6),
				_art.frame_rect("world_amulets", STONE_FRAMES[stones[n]]))
		else:
			draw_rect(Rect2(spot + Vector2(0.6, 2), Vector2(6, 6)), WorldArt.AMULET_INKS[stones[n]])


## The Info Map's words for place [param slot], a line each: what it
## trades, then the World Magic it sells ([method WorldMagicShop.sold_at]);
## none for a castle.
func info_words(slot: int) -> PackedStringArray:
	var words := PackedStringArray()
	var site: Dictionary = world.sites[slot]
	if int(site["type"]) >= ShandalarWorld.CASTLE:
		return words
	var trade := CardTrade.wares(int(site.get("trade", 0))).replace("Any land", "Lands") \
		.replace("Any fast effects", "Instants")
	if trade.begins_with("Any "):
		trade = trade.trim_prefix("Any ").capitalize()
	words.append(trade)
	var magic := WorldMagicShop.sold_at(world, slot)
	if magic >= 0:
		words.append(AdventurePlayer.WORLD_MAGICS[magic])
	return words


## [param text] centred at [param at] (its top), on a dark box.
func _boxed(text: String, at: Vector2, ink: Color, size_px: int) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var box := Rect2(at + Vector2(-width / 2.0 - 2, -1), Vector2(width + 4, size_px + 2))
	draw_rect(box, BOX)
	var base := at + Vector2(-width / 2.0, size_px - 1)
	if ink != RULER_INKS[0]:
		draw_string(_font, base + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, 0.9))
	draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)


## The amulets down the left (`Mapbttns.pic`'s panel, its stones
## painted on it), counted.
func _draw_amulets() -> void:
	if player == null:
		return
	var sheet := GameSkin.texture("map_buttons")
	if sheet != null:
		draw_texture_rect_region(sheet, Rect2(Vector2(0, 133), Vector2(43, 233)), Rect2(1, 141, 43, 233))
	var discs := amulet_discs()
	for i in discs.size():
		draw_rect(discs[i], WorldArt.AMULET_INKS[i])
	for i in 5:
		var count := str(int(player.amulets.get(AdventurePlayer.COLORS[i], 0)))
		var width := _font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, Vector2(30 - width / 2.0, 202 + 26 * i), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


## [ours] Without `Mapbttns.pic` the amulets' colours, black to white: a
## square each where the panel's stone stands, beside its count (on the
## 1997 screen; [constant WorldArt.AMULET_INKS]). None when the panel
## paints them.
func amulet_discs() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if GameSkin.texture("map_buttons") != null:
		return out
	for i in 5:
		out.append(Rect2(5, 193 + 26 * i, 9, 9))
	return out


## The journal line shown: a marker at its place and its words.
func _draw_journal() -> void:
	if journal_index < 0 or player == null:
		_boxed("The journal is empty.", Vector2(320, 450), Color.WHITE, 12)
		return
	var entry: Dictionary = player.journal[journal_index]
	var tile := Vector2i(int(entry.get("x", 0)) / 32, int(entry.get("y", 0)) / 32)
	var at := tile_point(tile)
	draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), Color.WHITE)
	_boxed(String(entry.get("text", "")).replace("\n", " "), at + Vector2(0, 6), Color.WHITE, 10)
	_boxed("Day %d — line %d of %d" % [int(entry.get("day", 0)), journal_index + 1, player.journal.size()],
		Vector2(320, 450), PaneStyle.GOLD, 11)


# ---------------------------------------------------------- the buttons --

func _map_button(row: int) -> BaseButton:
	var sheet := GameSkin.texture("map_buttons")
	var button: BaseButton
	if sheet != null:
		var cut := TextureButton.new()
		cut.texture_normal = cell(sheet, Rect2(1, 28 * row + 1, 93, 27))
		cut.texture_hover = cell(sheet, Rect2(95, 28 * row + 1, 93, 27))
		cut.texture_pressed = cell(sheet, Rect2(189, 28 * row + 1, 93, 27))
		cut.ignore_texture_size = true
		cut.stretch_mode = TextureButton.STRETCH_SCALE
		var word := PaneStyle.label(BUTTON_WORDS[row], 14, Color8(147, 207, 239))
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cut.add_child(word)
		button = cut
	else:
		button = PaneStyle.button(BUTTON_WORDS[row], "", 1.0, 14)
	button.name = "Map_" + BUTTON_WORDS[row].replace(" ", "")
	button.focus_mode = Control.FOCUS_NONE
	match row:
		0:
			button.pressed.connect(show_mode.bind(Mode.MAIN))
		1:
			button.pressed.connect(show_mode.bind(Mode.PLAIN))
		2:
			button.pressed.connect(show_mode.bind(Mode.INFO))
		3:
			button.pressed.connect(func() -> void: city_info_pressed.emit())
		4:
			button.pressed.connect(func() -> void: closed.emit())
	return button


## A button's cell [param region] cut from a painted sheet (`Mapbttns.pic`,
## `Infobar.pic`). Clipped to its region: the sheets part their cells with
## lines of the transparent key (magenta), and a scaled, filtered button
## would otherwise pick them up as a thin purple frame.
static func cell(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = region
	cut.filter_clip = true
	return cut


## Everything placed on the stage: the buttons and the hero's square.
func _layout() -> void:
	_place_buttons()
	_place_hero()


## The hero's square: 4 × 4 of the 1997 screen, a pixel up and left of
## their tile's point.
func _place_hero() -> void:
	if _hero_mark == null:
		return
	var at := stage()
	_hero_mark.position = at * (tile_point(hero_tile) - Vector2(1, 1))
	_hero_mark.size = Vector2(4, 4) * at.get_scale()


## The buttons along the top: the two other maps at 48 and 148, City Info
## at 398, Done at 499; in the journal, Previous and Next instead of the maps.
func _place_buttons() -> void:
	if _buttons.is_empty():
		return
	var at := stage()
	var shown := {"Main Map": false, "Plain Map": false, "Info Map": false, "City Info": mode != Mode.JOURNAL,
		"Done": true, "Previous": mode == Mode.JOURNAL, "Next": mode == Mode.JOURNAL}
	var left: Array[String] = []
	match mode:
		Mode.MAIN:
			left = ["Plain Map", "Info Map"]
		Mode.INFO:
			left = ["Main Map", "Plain Map"]
		Mode.PLAIN:
			left = ["Main Map", "Info Map"]
		Mode.JOURNAL:
			left = ["Previous", "Next"]
	for i in left.size():
		shown[left[i]] = true
		_put(_buttons[left[i]], Vector2(48 + 100 * i, 5), at)
	_put(_buttons["City Info"], Vector2(398, 5), at)
	_put(_buttons["Done"], Vector2(499, 5), at)
	for key in _buttons:
		(_buttons[key] as Control).visible = bool(shown.get(key, false))


func _put(button: Control, spot: Vector2, at: Transform2D) -> void:
	button.position = at * spot
	button.size = BUTTON_SIZE * at.get_scale()


func _gui_input(input: InputEvent) -> void:
	var wheel := input as InputEventMouseButton
	if mode == Mode.JOURNAL and wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			step_journal(-1)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step_journal(1)


## The map's keys ([method WorldScreen._unhandled_input] passes them): true
## when one was taken.
func key(code: int) -> bool:
	match code:
		KEY_M:
			# 1997's Main Map; on the Main Map itself, Done [ours] — the M
			# that opened the map closes it, as F2 does.
			if mode == Mode.MAIN:
				closed.emit()
			else:
				show_mode(Mode.MAIN)
		KEY_P:
			show_mode(Mode.PLAIN)
		KEY_I:
			show_mode(Mode.INFO)
		KEY_C:
			city_info_pressed.emit()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_D, KEY_F2:
			closed.emit()
		KEY_LEFT, KEY_UP:
			if mode != Mode.JOURNAL:
				return false
			step_journal(-1)
		KEY_RIGHT, KEY_DOWN:
			if mode != Mode.JOURNAL:
				return false
			step_journal(1)
		_:
			return false
	return true
