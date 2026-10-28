class_name CluesPane
extends StagePane
## THE DUNGEON & CASTLE CLUES (F4, the frame's gate; part C, stage C2) —
## the owner's ruling c4-3 of 2026-10-27, "Rich pane": OUR pane, with
## 1997's icons, the cards' pictures, the creatures' faces and a "Show on
## map" button [ours]. 1.3 showed two pages of its own (`ShowDungeonClues-
## Screen`, dungeonCluesScreen.c 579–978, the list; `ShowDungeonClueDetail-
## Screen` 981–1186, a place's page); this is that flow in one of the
## world's rounded panes ([StagePane]), the words [WorldClues]' (1997's
## `@CAVE_SHOWCLUES`, verbatim):
##  - THE LIST: "Dungeon & Castle Clues" (`[dunClues]` 0) over every castle
##    and dungeon the hero knows anything of ([method WorldClues.known]: a
##    dungeon while it holds a card), castles 0–4 then dungeons 5–14, three
##    across [ours: 1997's two columns of six scrolled past twelve; fifteen
##    fit here, nothing scrolls]. Each shows 1997'S ICON once where it
##    lies is known (dCS:707–725): a castle its world castle and its ground
##    half merged (the living castle's look, as 1997 kept it), a dungeon its
##    world marker pair ([method WorldView.dungeon_frames]) — each cropped to
##    its ink and fitted in the box (`EncodeMergedDungeonIconSprite`,
##    dCS:118–172) — else a "?" [ours: 1997 left the box black]; its name
##    and its kind ("Black Castle", "beaten" once he is; "Dungeon"). With
##    nothing known, 1997 showed nothing; ours says how clues are found
##    ([constant WorldClues.NONE_YET], QoL). Done closes the pane.
##  - A PLACE'S PAGE (a row clicked): its name and kind over 1997's own
##    page, the misty cave (`Clueback.pic`, `clue_detail`):
##     - THE CLUES in a dark well down the left, as 1997 laid them (x 24,
##       the lines indented to 32, wrapped at about 190), its inks —
##       headings #a5443f, lines #cdb08f — "Creatures:", "-Contains large
##       black creatures.", "Dungeon Rules:", "-No artifacts allowed.", …,
##       "Location:", "-East of Kraag Forge." ([method WorldClues.lines]; the
##       treasure's words left out: its cards are shown);
##     - THE TREASURE CARDS, always, whatever is known (dCS:1074–1083),
##       fanned at the right where 1997 fanned them; right click reads one.
##       A castle holds no cards: [ours] the wizard waiting in it stands
##       there, his face on its banner;
##     - [ours] THE CREATURES' FACES once the creatures are known, where
##       1997 drew its small view of the world: who the clue's "large black
##       creatures" are — a dungeon's four rooms (fixed by its colour and
##       size, [method DungeonBoard.creatures_for]), or every creature a
##       castle of that colour may set in its rooms ([method creatures_of]);
##     - 1997's Done (`Cluebutn.pic`'s three frames, `clue_detail_buttons`,
##       "Done" in #116f8e) at its place, back to the list;
##     - [ours] "SHOW ON MAP", once where it lies is known: the map
##       ([ClueMap]) over the screen, the place ringed on it, in place of
##       1997's small view; closed, the page again. Unknown, the note says
##       so ([constant NOT_WHERE]).
## KEYS: Escape — the page back to the list, the list closed; F4 closes;
## on a page the Left and Right arrows go to the place before and after
## [QoL]; a choice's first letter lights it, Enter or Space takes it; a
## drag on the glass moves the pane.
## 1997's side effect of viewing a castle's creature clue (its monster
## flags rewritten, dCS:1089; unused-features §30) is dead there and here.
## Without the 1997 pictures the page is a plain dark field under the same
## parts, the icons plain marks (a stone of the castle's colour, the
## world's plain dungeon).

## The pane is closed.
signal done

const TITLE := "Dungeon & Castle Clues"
const DUNGEON := "Dungeon"
const BEATEN := "%s, beaten"
const SHOW_ON_MAP := "Show on map"
const DONE := "Done"
const NOT_WHERE := "Where it lies is not known yet."
## The list: three entries across, each this large, its icon's box.
const COLUMNS := 3
const ENTRY := Vector2(232, 60)
const ICON := 52.0
## The page (640 × 480): the clues' well and column, the inks.
const TEXT_WELL := Rect2(12, 12, 226, 398)
const TEXT_LEFT := 24.0
const LINE_LEFT := 32.0
const TEXT_WIDTH := 200.0
const TEXT_TOP := 22.0
const TEXT_FOOT := 400.0
const SECTION_GAP := 6.0
const HEADING_INK := Color8(165, 68, 63)
const LINE_INK := Color8(205, 176, 143)
const TEXT_MOST := 15
const TEXT_LEAST := 10
## The faces, where 1997 drew its view of the world (254, 22, 358 × 200).
const FACES_AT := Rect2(254, 22, 358, 200)
const FACE := 76.0
const FACE_GAP := 12.0
const FACE_NAME := 16.0
const FACES_ACROSS := 4
## The treasure cards fanned (1997's (320, 252), (402, 244), (484, 252),
## 160 wide; a little smaller and left so they stay on the page).
const CARD_WIDTH := 150.0
const CARD_FROM := 306.0
const CARD_TO := 626.0
const CARD_STEP := 82.0
const CARD_TOPS: Array[float] = [252.0, 244.0]
## A castle's wizard in place of the cards.
const WIZARD_AT := Rect2(398, 240, 180, 180)
const WIZARD_BANNER := Rect2(398, 420, 180, 35)
## 1997's Done (`Cluebutn.pic`: three frames, 89 × 35) and its inks.
const DONE_AT := Rect2(22, 418, 89, 35)
const DONE_FRAMES: Array[Rect2] = [Rect2(1, 1, 89, 35), Rect2(91, 1, 89, 35), Rect2(181, 1, 89, 35)]
const DONE_INK := Color8(17, 111, 142)
const DONE_LIT := Color8(34, 148, 162)

## The place whose page shows, −1 for the list.
var slot := -1
var _list_body: VBoxContainer
var _grid: GridContainer
var _map: ClueMap
var _closed := false
## The world sheets' frames' ink, by "key:frame" — 1997's crop of an icon.
var _images := {}
static var _inks := {}


## THE PANE for [param player]: not yet in the tree (the caller adds it,
## centres it — [method PaneStyle.centre] — and sets [member k]).
static func make(player: AdventurePlayer) -> CluesPane:
	var pane := CluesPane.new()
	pane.player = player
	return pane


func _make_stage() -> EncounterStage:
	return CluePage.new()


func _ready() -> void:
	super._ready()
	name = "CluesPane"
	show_list()


## The places known, castles then dungeons.
func known() -> Array[int]:
	return WorldClues.known(player.world) if player != null else [] as Array[int]


# ------------------------------------------------------------- the list --

## THE LIST (the class doc).
func show_list() -> void:
	slot = -1
	set_title(TITLE)
	if _list_body == null:
		_list_body = VBoxContainer.new()
		_list_body.name = "ClueList"
		_list_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid = GridContainer.new()
		_grid.name = "Places"
		_grid.columns = COLUMNS
		_grid.add_theme_constant_override("h_separation", 8)
		_grid.add_theme_constant_override("v_separation", 6)
		_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list_body.add_child(_grid)
	PaneStyle.drop_children(_grid)
	var places := known()
	for index in places:
		_grid.add_child(_entry(index))
	# The list is never narrower than the words under it want.
	_list_body.custom_minimum_size.x = ENTRY.x * COLUMNS + 8.0 * (COLUMNS - 1)
	show_body(_list_body)
	say([WorldClues.NONE_YET] if places.is_empty() else [])
	offer([["done", DONE, true]])


## Place [param index]'s entry: its icon, its name, its kind.
func _entry(index: int) -> Button:
	var entry := PaneStyle.button("", "Clue_%d" % index, 1.0)
	entry.custom_minimum_size = ENTRY
	entry.tooltip_text = ""
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 4
	row.offset_right = -6
	row.offset_bottom = -4
	entry.add_child(row)
	var icon := ClueIcon.new()
	icon.name = "Icon"
	icon.pane = self
	icon.index = index
	icon.color = color_of(index)
	icon.located = located(index)
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var named := PaneStyle.wrapped(WorldNames.dungeon_name(index), 15, ENTRY.x - ICON - 26.0, PaneStyle.INK)
	named.name = "Name"
	words.add_child(named)
	var kind := PaneStyle.label(kind_of(index), 13, PaneStyle.DIM)
	kind.name = "Kind"
	words.add_child(kind)
	row.add_child(words)
	entry.pressed.connect(func() -> void:
		WorldSoundscape.play_from(self, "sfx_click")
		show_clue.call_deferred(index))
	return entry


## Place [param index]'s kind under its name: its castle ("Black Castle",
## beaten once he is), or "Dungeon".
func kind_of(index: int) -> String:
	if index < 5:
		var castle: String = WorldNames.CASTLES[index]
		var beaten := player != null and AdventurePlayer.COLORS[index] in player.defeated_wizards
		return BEATEN % castle if beaten else castle
	return DUNGEON


## The colour of place [param index] (1 black … 5 white): a castle's by
## its index, a dungeon's its slot's.
func color_of(index: int) -> int:
	if index < 5:
		return index + 1
	var entry := _place(index)
	return clampi(int(entry.get("color", 1)), 1, 5)


## Whether where place [param index] lies is known (clue bit 1).
func located(index: int) -> bool:
	return int(_place(index).get("clues", 0)) & WorldClues.LOCATION != 0


func _place(index: int) -> Dictionary:
	if player == null or player.world == null or index < 0 or index >= player.world.encounters.size():
		return {}
	return player.world.encounters[index]


## The places listed now, in order.
func listed() -> Array[int]:
	var out: Array[int] = []
	if _grid == null:
		return out
	for child in _grid.get_children():
		if not child.is_queued_for_deletion():
			out.append(int(String(child.name).trim_prefix("Clue_")))
	return out


# ------------------------------------------------------------- the page --

## PLACE [param index]'S PAGE (the class doc); an unknown place, the list.
func show_clue(index: int) -> void:
	if _closed or not index in known():
		return
	slot = index
	set_title(WorldNames.dungeon_name(index), kind_of(index))
	show_body(null)
	draw_page(index)
	say([])
	var where := located(index)
	offer([["map", SHOW_ON_MAP, where]], "" if where else NOT_WHERE)


## The page of place [param index]: the ground, the clues' column, the
## faces, the treasure (or the wizard), 1997's Done.
func draw_page(index: int) -> void:
	var page := stage as CluePage
	var color := color_of(index)
	stage.clear()
	stage.hue = color
	stage.ground("clue_detail")
	stage.piece("", Rect2(), TEXT_WELL, "TextWell")
	_text_column(clue_lines(index))
	if int(_place(index).get("clues", 0)) & WorldClues.CREATURES != 0:
		_faces(creatures_of(player.world, index))
	if index < 5:
		stage.creature_face(CreatureBook.castle_row(color), WIZARD_AT, WIZARD_BANNER)
	else:
		_fan(WorldClues.treasures(player.world, index))
	page.done_button(DONE_AT, DONE_FRAMES, DONE, DONE_INK, DONE_LIT, show_list)


## What is known of place [param index], a line each — the treasure's
## words left out (its cards are on the page).
func clue_lines(index: int) -> Array[String]:
	var out: Array[String] = []
	for line in WorldClues.lines(player.world, index):
		if not line.begins_with("Treasure: "):
			out.append(line)
	return out


## The clues' column: headings at x 24, lines at 32, as large as fits.
func _text_column(lines: Array[String]) -> void:
	var points := TEXT_MOST
	while points > TEXT_LEAST and _column_high(lines, points) > TEXT_FOOT - TEXT_TOP:
		points -= 1
	var y := TEXT_TOP
	for i in lines.size():
		var heading := not lines[i].begins_with("-")
		if heading and i > 0:
			y += SECTION_GAP
		var left := TEXT_LEFT if heading else LINE_LEFT
		var width := TEXT_WIDTH - (left - TEXT_LEFT)
		var high := _line_high(lines[i], width, points)
		var label := stage.words(lines[i], Rect2(left, y, width, high), points,
			HEADING_INK if heading else LINE_INK, "ClueLine%d" % i, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		y += high


func _column_high(lines: Array[String], points: int) -> float:
	var y := 0.0
	for i in lines.size():
		var heading := not lines[i].begins_with("-")
		if heading and i > 0:
			y += SECTION_GAP
		var left := TEXT_LEFT if heading else LINE_LEFT
		y += _line_high(lines[i], TEXT_WIDTH - (left - TEXT_LEFT), points)
	return y


## How tall [param text] stands wrapped at [param width] at [param points]
## (page units), in the face the page's words wear ([method
## PaneStyle.label]) — a little room over, for the rounding at scale.
static func _line_high(text: String, width: float, points: int) -> float:
	var probe := PaneStyle.label(text, points)
	var face := probe.get_theme_font("font")
	var high := face.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, points).y
	probe.free()
	return high + 2.0


## The creatures' faces, in rows of four where 1997 drew the world.
func _faces(rows: Array[int]) -> void:
	var page := stage as CluePage
	var lines := ceili(rows.size() / float(FACES_ACROSS))
	for line in lines:
		var count := mini(FACES_ACROSS, rows.size() - line * FACES_ACROSS)
		var wide := count * FACE + (count - 1) * FACE_GAP
		var left := FACES_AT.position.x + (FACES_AT.size.x - wide) / 2.0
		var top := FACES_AT.position.y + line * (FACE + FACE_NAME + 8.0)
		for i in count:
			var row := rows[line * FACES_ACROSS + i]
			page.small_face(row, Rect2(left + i * (FACE + FACE_GAP), top, FACE, FACE), "Face%d" % row)


## The treasure cards fanned at the right (1997's places, more spread
## closer).
func _fan(cards: Array[String]) -> void:
	var count := cards.size()
	if count == 0:
		return
	var step := minf(CARD_STEP, (CARD_TO - CARD_FROM - CARD_WIDTH) / maxf(count - 1, 1))
	var wide := step * (count - 1) + CARD_WIDTH
	var left := CARD_TO - wide if count < 3 else CARD_FROM
	for i in count:
		stage.card(cards[i], Vector2(left + step * i, CARD_TOPS[i % 2]), CARD_WIDTH, "Treasure%d" % i)


## THE CREATURES A CASTLE OR DUNGEON SETS IN ITS ROOMS, by [CreatureBook]
## row: a dungeon's four — its colour's creature of each room's tier,
## `[4, 6, 8, 12]`, or `[8, 12, 16, 18]` when large ([constant
## DungeonBoard.DUNGEON_TIERS]; one creature a tier a colour) — or, for a
## castle, every creature of its colour of the castle's room tiers
## (`[10, 11, 12, 13, 14, 16]`, [constant DungeonBoard.CASTLE_TIERS]),
## each the table's order; its wizard is shown apart.
static func creatures_of(world: ShandalarWorld, index: int) -> Array[int]:
	var out: Array[int] = []
	if world == null or index < 0 or index >= world.encounters.size():
		return out
	var entry: Dictionary = world.encounters[index]
	var color := index + 1 if index < 5 else clampi(int(entry.get("color", 1)), 1, 5)
	var tiers: Array[int] = []
	if index < 5:
		tiers = DungeonBoard.CASTLE_TIERS.duplicate()
	else:
		var large := 2 if int(entry.get("monster_flags", 0)) & DungeonBoard.LARGE != 0 else 0
		for room in 4:
			tiers.append(DungeonBoard.DUNGEON_TIERS[room + large])
	for tier in tiers:
		for row in CreatureBook.of_color(color):
			if CreatureBook.tier(row) == tier and CreatureBook.kind(row) != CreatureBook.CASTLE_WIZARD \
					and not row in out:
				out.append(row)
	return out


# -------------------------------------------------------------- the map --

## SHOW ON MAP: the map over the screen, the place ringed ([ClueMap]); this
## pane hidden under it until it closes.
func show_on_map() -> ClueMap:
	if slot < 0 or not located(slot) or player == null or get_parent() == null:
		return null
	close_map()
	var entry := _place(slot)
	var map := ClueMap.new()
	map.world = player.world
	map.player = player
	map.hero_tile = player.tile()
	map.mark_tile = Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
	map.mark_name = WorldNames.dungeon_name(slot)
	map.mark_dungeon = slot >= 5
	var lines := WorldClues.lines(player.world, slot)
	var where := lines.find("Location:")
	map.mark_line = "%s: %s" % [WorldNames.dungeon_name(slot), lines[where + 1].trim_prefix("-")] \
		if where >= 0 and where + 1 < lines.size() else WorldNames.dungeon_name(slot)
	_map = map
	get_parent().add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.closed.connect(close_map, CONNECT_DEFERRED)
	visible = false
	return map


## The map closed: the page again.
func close_map() -> void:
	if is_instance_valid(_map):
		PaneStyle.drop(_map)
	_map = null
	if not _closed:
		visible = true


## The map open over the screen, or null.
func map_shown() -> ClueMap:
	return _map if is_instance_valid(_map) and not _map.is_queued_for_deletion() else null


# ------------------------------------------------------- choices, keys --

func choose(action: String) -> void:
	if _closed:
		return
	match action:
		"done":
			close()
		"map":
			show_on_map()


## Escape: the page back to the list, the list closed.
func escape() -> void:
	if slot >= 0:
		show_list()
	else:
		close()


## THE PANE CLOSED: [signal done], once; the map with it; the pane gone.
func close() -> void:
	if _closed:
		return
	_closed = true
	if is_instance_valid(_map):
		PaneStyle.drop(_map)
	done.emit()
	if get_parent() != null:
		PaneStyle.drop(self)
	else:
		queue_free()


## Whether the pane is closed.
func closed() -> bool:
	return _closed


## The place [param way] (−1 before, 1 after) of the one shown.
func step_place(way: int) -> void:
	var places := known()
	var at := places.find(slot)
	if at < 0 or places.is_empty():
		return
	show_clue(places[posmod(at + way, places.size())])


func _unhandled_input(input: InputEvent) -> void:
	if not is_visible_in_tree():
		var key_on_map := input as InputEventKey
		var map := map_shown()
		if map != null and key_on_map != null and key_on_map.pressed and not key_on_map.echo:
			get_viewport().set_input_as_handled()
			if input.is_action_pressed("ui_cancel"):
				close_map()
			else:
				map.key(key_on_map.keycode)
		return
	var key := input as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_F4:
			get_viewport().set_input_as_handled()
			close()
			return
		if slot >= 0 and key.keycode in [KEY_LEFT, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
			step_place(-1 if key.keycode == KEY_LEFT else 1)
			return
	super._unhandled_input(input)


# ------------------------------------------------------------ the icons --

## THE INK OF FRAME [param frame] OF WORLD SHEET [param key]: the part of
## its cell that is not clear, in the sheet's drawn (1997) pixels relative
## to the cell — measured on the 1997-sized picture ([method
## GameSkin.original]), once a game.
func ink_rect(art: WorldArt, key: String, frame: int) -> Rect2:
	var memo := "%s:%d" % [key, frame]
	if _inks.has(memo):
		return _inks[memo]
	var cell := art.frame_rect(key, frame)
	var found := Rect2(Vector2.ZERO, cell.size)
	var sheet := art.texture(key)
	if sheet == null:
		return found
	if not _images.has(key):
		var small := GameSkin.original(sheet)
		if small != null and small.is_compressed():
			small.decompress()
		_images[key] = small
	var img: Image = _images[key]
	if img == null:
		return found
	var used := img.get_region(Rect2i(cell)).get_used_rect()
	if used.has_area():
		found = Rect2(used)
	_inks[memo] = found
	return found


## Place [param index]'s icon parts: `[[key, frame], …]` drawn in order on
## one origin — a castle's ground half then its castle (the living look,
## [constant WorldView.CASTLE_FRAMES]), a dungeon's ground half then its
## marker ([method WorldView.dungeon_frames]).
static func icon_parts(index: int) -> Array:
	if index >= 0 and index < 5:
		var frames: Array = WorldView.CASTLE_FRAMES[index]
		return [_castle_frame(int(frames[1])), _castle_frame(int(frames[0]))]
	var pair := WorldView.dungeon_frames(index)
	if pair.is_empty():
		return []
	return [pair[1], pair[0]]


static func _castle_frame(at: int) -> Array:
	return ["world_castles1", at] if at < 12 else ["world_castles2", at - 12]


## THE ICON IN ITS BOX (the class doc): 1997's merged sprite cropped to
## its ink and fitted, centred; a plain mark without the sheets; a "?"
## while where it lies is unknown.
class ClueIcon extends Control:
	var pane: CluesPane
	var index := -1
	var color := 1
	var located := false
	var _art := WorldArt.new()

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color(0, 0, 0, 0.6))
		draw_rect(box, Color(PaneStyle.GOLD, 0.35), false, 1.0)
		var middle := size / 2.0
		if not located:
			var face := ThemeDB.fallback_font
			var mark := "?"
			var wide := face.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			draw_string(face, middle + Vector2(-wide / 2.0, 9), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
				Color(PaneStyle.DIM, 0.8))
			return
		var parts := CluesPane.icon_parts(index)
		var ink := Rect2()
		var sheets: Array = []
		for part in parts:
			var key := String(part[0])
			var sheet := _art.texture(key)
			if sheet == null:
				sheets.clear()
				break
			var used := pane.ink_rect(_art, key, int(part[1])) if pane != null else Rect2()
			ink = used if ink.size == Vector2.ZERO else ink.merge(used)
			sheets.append([sheet, _art.frame_rect(key, int(part[1]))])
		if sheets.is_empty() or not ink.has_area():
			_plain(middle)
			return
		var room := box.grow(-3)
		var fit := minf(room.size.x / ink.size.x, room.size.y / ink.size.y)
		var origin := room.position + (room.size - ink.size * fit) / 2.0 - ink.position * fit
		for entry in sheets:
			var cell: Rect2 = entry[1]
			draw_texture_rect_region(entry[0], Rect2(origin, cell.size * fit), cell)

	## A plain mark: the world's plain dungeon, or a stone of the castle's
	## colour.
	func _plain(middle: Vector2) -> void:
		if index >= 5:
			WorldView.draw_dungeon_plain(self, middle)
			return
		var ink: Color = WorldArt.AMULET_INKS[clampi(color, 1, 5) - 1]
		draw_circle(middle, 15, Color(0, 0, 0, 0.6))
		draw_circle(middle, 12, ink)
		draw_arc(middle, 13, 0.0, TAU, 24, PaneStyle.GOLD, 2.0)


## THE PAGE OF A PLACE: the meeting's stage ([EncounterStage]) with the
## parts only the clues draw — a small framed face, 1997's Done.
class CluePage extends EncounterStage:
	## Creature [param row]'s face, small, in the meeting's frame at
	## [param at], its name under it.
	func small_face(row: int, at: Rect2, part_name: String) -> void:
		var back := ColorRect.new()
		back.color = Color.BLACK
		_add(back, at, part_name + "Back")
		piece("preduel_frame", FACE_FRAME, at, part_name + "Frame")
		var inset := at.size.x * FACE_INSET / FACE_FRAME.size.x
		var shown := PortraitLibrary.texture(CreatureBook.face_id(row))
		if shown != null:
			var portrait := TextureRect.new()
			portrait.texture = shown
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_add(portrait, at.grow(-inset), part_name)
		else:
			var ink := WorldArt.AMULET_INKS[_face_color(row) - 1].darkened(FACE_DIM)
			_add(_stone(ink), at.grow(-inset * 2.0), part_name)
		words(CreatureBook.name_of(row), Rect2(at.position.x - 8, at.end.y + 1, at.size.x + 16, 16), 12,
			PaneStyle.GOLD, part_name + "Name", true)

	## 1997's Done at [param at]: [param frames] of `clue_detail_buttons`
	## (normal, lit, pressed) under the word [param word] in [param ink]
	## ([param lit] under the pointer); a plain button without the sheet.
	## [param pressed] when clicked.
	func done_button(at: Rect2, frames: Array[Rect2], word: String, ink: Color, lit: Color,
			pressed: Callable) -> BaseButton:
		var sheet := GameSkin.texture("clue_detail_buttons")
		var button: BaseButton
		if sheet != null:
			var cut := TextureButton.new()
			cut.texture_normal = WorldMap.cell(sheet, frames[0])
			cut.texture_hover = WorldMap.cell(sheet, frames[1])
			cut.texture_pressed = WorldMap.cell(sheet, frames[2])
			cut.ignore_texture_size = true
			cut.stretch_mode = TextureButton.STRETCH_SCALE
			button = cut
		else:
			button = PaneStyle.button("", "", 1.0, 14)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(func() -> void:
			WorldSoundscape.play_from(self, "sfx_click")
			pressed.call_deferred())
		_add(button, at, "PageDone")
		# The word over it, a part of the page of its own: it grows with
		# the page (1997 lettered it over the frames, 14 points).
		var shade := ink if sheet != null else PaneStyle.INK
		var label := words(word, at, 15, shade, "PageDoneWord")
		# 1997's teal on the brown frame, a dark shadow under it to read.
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		button.mouse_entered.connect(func() -> void:
			label.add_theme_color_override("font_color", lit if sheet != null else PaneStyle.LIT))
		button.mouse_exited.connect(func() -> void: label.add_theme_color_override("font_color", shade))
		return button
