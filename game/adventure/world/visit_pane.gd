class_name VisitPane
extends PanelContainer
## A PLACE VISITED (the owner, 2026-10-23: *"analyze every possible map
## location that can be visited and what screen the original game used in
## visiting … upon visiting that location an original graphic is displayed
## in a central pane in modern gui with original assets and feel"*). The
## 1.3 game showed every place in its map window on arrival — a 512 × 280
## picture zoomed in (`AnimateVisitBackdropZoomIn`, 004ed525) or revealed
## in tiles, the place's words over it — and this pane is that window,
## floating over the world in the panes' rounded glass:
##  - A VILLAGE, TOWN OR CITY (`VisitTownSlot` 004eda50,
##    `RunTownServicesMenu` 004ef1ea): `Village.pic` or `City.pic`, the
##    name on it, and the five choices of `@CITYSCREEN_BUTTONS` — Buy
##    Cards, Edit deck/Sell cards, Speak to Wise Man (or the town's trade,
##    or "Begin a Quest" — see below), Buy 10 food for (type + 2) × 5
##    gold, Leave the village.
##  - A TOWN A WIZARD RULES (its status's high byte; [RuledTowns]): the same
##    picture, and — drawn AS THE PANE OPENS, every entry, never in
##    [method describe] (the pointer's tip reads it too) — the hero's stake
##    ("Your ANTE"), the creature's face in its tinted frame and its stake
##    ("Wizard's ANTE") over it ([method show_cards], [method show_face]);
##    "This place is ruled by the %s." — "To free the city you must duel
##    this %s" (the creature), " Never mind. / Duel the creature." — the
##    duel the world screen opens ([method RuledTowns.open]). With no card
##    of the deck in use to stake, the game is over as the town is entered
##    (1997's `ExitIfNoUsableDeckCards`): the pane shows nothing and takes
##    its duel's door at once, where the end is shown.
##  - A WIZARD'S CASTLE (`0246`, `0364`, `0335`, `0737`, `0028` by its
##    colour): "Who dares to challenge the Mighty %s? Are you brave enough
##    to enter my castle?" — " Well... No. / Yes, enter the castle."; a
##    beaten wizard's: "The Mighty %s was crushed in epic combat by your
##    aegis! The people of Shandalar sing praises in your name!"
##  - A LAIR (`lair_backdrop_paths` by its colour — `0873`, the blue one,
##    the sunken ship): "You happen upon a %s!"
##  - A DUNGEON whose clues are known: 1997 opened straight onto the
##    dungeon board (`CaveBkgd.pic`); here its ground shows under the name.
## Buy Cards opens the town's card shop ([CardShopPane]) — "Buy Cards/Card
## Hints" when the seller has a hint ([CardHints]). The fifth choice is, as
## 1997 ordered it: a town's trade, "Trade red amulet for Any creatures",
## while it is offered ([CardTrade], the card trader [CardTradePane]); else
## "Begin a Quest" while the town has one to give ([Quests]: a village's
## deliveries, and every place's creature quests); else "Speak to Wise Man" ([WiseMan], [WiseManPane]). A lair's own pane ([LairPane]) and
## the wise man's change their words, choices and the card shown as they go
## ([method say], [method offer], [method show_card]; "Whose deck would you
## like to see?", [method ask_whose_deck]); a row of cards over the
## picture shows stakes and spoils ([method show_cards]), the picture itself
## may change ([method show_picture]). A castle's "Yes, enter the castle."
## and a known dungeon's "Enter the dungeon" go down onto the board (part
## C, [DungeonPane]). Without the 1997 pictures the place is a plain dark
## field under its name.
##
## [QoL] The pane stays on the screen: the picture gives way when the
## choices need the room ("Whose deck would you like to see?" adds a dozen
## creatures) and grows back as they go ([method _fit]).
##
## THE PICTURE COMES IN as 1997 brought it ([TileReveal], the owner's H7 of
## 2026-10-27; [method _transition_in]): a town's, the wise man's, the
## news's and a dungeon's [ours] zoomed in, every time the pane opens —
## 1997 zoomed again on coming back from a town's own screens
## (visitLocation.c 998–1077); a castle's in staggered tiles; a lair's in
## random 5 × 5 tiles, its card or hoard standing over it at once; a ruled
## town's creature face, once the town has zoomed in, in 3 × 3 tiles over
## the town (`DrawCreaturePortrait` mode 2, its banner at once). Short,
## skipped by any click or key, the words and the choices live from the
## first frame; off with the Options' "Transitions", and never headless.
##
## A QUESTION'S CHOICES ANSWER TO THEIR FIRST LETTER [1997] (the owner's
## C-5): as 1.3's text menus did (`RunTextMenuAt`, adventure_ui.c 186–222,
## its hotkeys 436–461), a letter moves to the next choice beginning with
## it — "Y" to "Yes, enter the castle.", "B" from Buy Cards to Buy 10 food
## and back — and Enter or Space takes the one lit; it never takes a choice
## by itself. Only a plain letter (no Ctrl, Alt or Meta), only on the pane
## on top, never while a text field has the keys, and a letter no choice
## begins with goes on unheard ([method letter_choice]; the meeting's and
## the ruled town's duel panes answer the same way).

## The hero leaves the place; [param then] what they chose to do next
## (`""`, `deck` for Edit deck, `shop` for Buy Cards, `trade` for the
## town's trade, `quest` for Begin a Quest, `wiseman` for the wise man,
## `duel` for a ruled town's Duel the creature).
signal left(then: String)
## A creature's deck is to be seen ([CreatureBook] row [param index]).
signal deck_wanted(index: int)
## The card shown over the picture right-clicked, to be read full screen
## ([method WorldScreen.read_card]).
signal card_read(card_name: String)

## The 1997 picture's size, the most it is grown to and the least it is
## shrunk to.
const PICTURE := Vector2(512, 280)
const MOST := 1.5
const LEAST := 0.6
const KINDS := ["village", "town", "city"]
## The room kept free above and below a pane on the screen, in all.
const ROOM_MARGIN := 32.0
## A card of a row over the picture ([method show_cards]): its width in the
## picture's own pixels (1997's 80-unit card on its 320-unit page, the
## picture 512 wide), and the row's gap and margin.
const ROW_CARD := 128.0
const ROW_GAP := 12.0
const ROW_MARGIN := 16.0
## The caption under a card of the row, its height in picture pixels.
const CAPTION := 18.0
## 1997's page units to the picture's pixels: its 320-unit page across the
## 512-pixel picture ([method page_point]).
const PAGE_SCALE := 1.6
## The creature's face over a ruled town ([method show_face]): its frame
## and the name banner under it, in picture pixels; the tinted frame's
## pieces (`Prdfrmc.pic`, as `Prdfrmb.pic`'s, [EncounterStage]).
const FACE_AT := Rect2(196, 18, 120, 120)
const FACE_BANNER_AT := Rect2(186, 140, 140, 26)
const FACE_INSET := 8.0
## The choice a letter lit ([method letter_choice]): its gold rim.
const LETTER_RIM := 2

var player: AdventurePlayer
## What is visited ([method describe]).
var place := {}
## The size factor of the choices: 1, or [constant WorldHud.BIG].
var k := 1.0
var _note: Label
var _choices: HFlowContainer
var _said: Label
var _card: CardPreview
var _card_name := ""
## The picture's width on the screen: the words wrap to it.
var _width := PICTURE.x
## The picture's size now, times the 1997 size ([method _set_grow]), and the
## most it may be: what the screen allowed beside the place's own words.
var _grow := 1.0
var _most := 1.0
var _art: TextureRect
## What is laid over the picture besides the one card: the row's cards and
## captions, the face — each `{node, at}` in picture pixels, placed again as
## the picture grows ([method _place_over]).
var _over: Control
var _over_parts: Array = []
var _row_names: Array[String] = []
## A ruled town's entry ([method RuledTowns.enter]), drawn as the pane opens.
var ruled := {}
## The place opened again where the hero stands, not entered anew
## ([method WorldScreen.walk_to_tile]'s entry latch): a ruled town keeps
## the entry it drew ([method RuledTowns.enter]).
var again := false
## Where the creature's face stands over the picture ([method show_face]).
var _face_at := FACE_AT


# ------------------------------------------------------------ the place --

## WHAT IS AT [param tile] for [param hero], or `{}` when nothing there is
## visited: `{kind, slot, name, subtitle, picture, lines, actions}` — the
## kind `village`, `town`, `city`, `ruled`, `castle`, `fallen`, `lair` or
## `dungeon`; the picture a skin key; the lines in the 1997 words; each
## action `[id, words, ready]`.
static func describe(hero: AdventurePlayer, tile: Vector2i) -> Dictionary:
	var world := hero.world
	if world == null:
		return {}
	for lair in WorldLairs.seen(hero):
		if Vector2i(int(lair["x"]) / 32, int(lair["y"]) / 32) == tile:
			return _lair(lair)
	var slot := site_slot(world, tile)
	if slot >= 0:
		var site: Dictionary = world.sites[slot]
		var kind := int(site["type"])
		if kind >= ShandalarWorld.CASTLE:
			return _castle(hero, slot, kind)
		if kind >= ShandalarWorld.VILLAGE:
			return _town(hero, slot, kind)
	if world.tile_flags(tile.x, tile.y) & ShandalarWorld.DUNGEON != 0:
		for index in range(5, world.encounters.size()):
			var dungeon: Dictionary = world.encounters[index]
			if int(dungeon.get("x", -1)) == tile.x and int(dungeon.get("y", -1)) == tile.y \
					and index in WorldClues.known(world):
				return {"kind": "dungeon", "slot": index, "name": WorldNames.dungeon_name(index),
					"subtitle": "Dungeon", "picture": "visit_dungeon",
					"lines": ["The way down into %s." % WorldNames.dungeon_name(index)]
						+ WorldClues.lines(world, index),
					"actions": [["enter", "Enter the dungeon", DungeonDoors.BOARD_READY], ["leave", "Leave", true]]}
	return {}


## The site slot at [param tile], or -1.
static func site_slot(world: ShandalarWorld, tile: Vector2i) -> int:
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		if int(site["x"]) == tile.x and int(site["y"]) == tile.y and int(site["type"]) > 0:
			return slot
	return -1


## Ten food's price at a site of [param kind] (1 village … 3 city):
## `(type + 2) × 5` gold (`RunTownServicesMenu`).
static func food_price(kind: int) -> int:
	return (kind + 2) * 5


static func _town(hero: AdventurePlayer, slot: int, kind: int) -> Dictionary:
	var name := WorldNames.site_name(hero.world, slot)
	var picture := "visit_village" if kind == ShandalarWorld.VILLAGE else "visit_city"
	var ruler := TownStatus.ruler(hero.world, slot)
	if ruler != 0:
		# The creature and the stakes are drawn as the pane opens ([method
		# _enter_ruled]), not here: this names the town for the pointer too.
		var wizard: String = WorldNames.WIZARDS[ruler - 1]
		return {"kind": "ruled", "slot": slot, "name": name, "subtitle": "Ruled by the " + wizard,
			"picture": picture, "lines": [RuledTowns.RULED_WORDS % wizard],
			"actions": [["leave", RuledTowns.NEVER_MIND, true], ["duel", RuledTowns.DUEL, true]]}
	var price := food_price(kind)
	var buy := "Buy Cards/Card Hints" if not CardHints.current(hero, slot).is_empty() else "Buy Cards"
	var trade := CardTrade.town_offer(hero, slot)
	var fourth: Array = ["wiseman", "Speak to Wise Man", true]
	if not trade.is_empty():
		fourth = ["trade", String(trade["words"]), true]
	elif Quests.offered(hero, slot):
		fourth = ["quest", "Begin a Quest", true]
	return {"kind": KINDS[clampi(kind - 1, 0, 2)], "slot": slot, "name": name,
		"subtitle": KINDS[clampi(kind - 1, 0, 2)].capitalize(), "picture": picture,
		"lines": [] as Array[String],
		"actions": [["buy", buy, true], ["deck", "Edit deck/Sell cards", true], fourth,
			["food", "Buy 10 food for %d gold" % price, hero.gold >= price],
			["leave", "Leave the village", true]]}


static func _castle(hero: AdventurePlayer, slot: int, kind: int) -> Dictionary:
	var castle := WorldNames.castle_of_site(hero.world, slot)
	var color: String = AdventurePlayer.COLORS[clampi(castle, 0, 4)]
	var wizard: String = WorldNames.WIZARDS[clampi(castle, 0, 4)]
	var name := WorldNames.dungeon_name(castle) if castle >= 0 else "Castle"
	var picture := "visit_castle_" + color
	if kind > ShandalarWorld.CASTLE or color in hero.defeated_wizards:
		return {"kind": "fallen", "slot": slot, "name": name, "subtitle": WorldNames.CASTLES[clampi(castle, 0, 4)],
			"picture": picture,
			"lines": ["The Mighty %s was crushed in epic combat by your aegis!" % wizard,
				"The people of Shandalar sing praises in your name!"],
			"actions": [["leave", "Leave", true]]}
	return {"kind": "castle", "slot": slot, "name": name, "subtitle": WorldNames.CASTLES[clampi(castle, 0, 4)],
		"picture": picture,
		"lines": ["Who dares to challenge the Mighty %s?" % wizard,
			"Are you brave enough to enter my castle?"],
		"actions": [["leave", "Well... No.", true], ["enter", "Yes, enter the castle.", DungeonDoors.BOARD_READY]]}


## A lair seen: walked onto, it is entered ([LairPane]); this names it for
## the pointer's tip.
static func _lair(lair: Dictionary) -> Dictionary:
	var color: String = AdventurePlayer.COLORS[clampi(int(lair.get("color", 1)) - 1, 0, 4)]
	return {"kind": "lair", "slot": int(lair.get("slot", -1)), "name": "Lair",
		"subtitle": "%s lair" % color.capitalize(), "picture": "visit_lair_" + color,
		"lines": [], "actions": [["leave", "Leave", true]]}


# --------------------------------------------------------------- the pane --

func _ready() -> void:
	name = "VisitPane"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title := PaneStyle.title(String(place.get("name", "")))
	title.name = "PlaceName"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := PaneStyle.label(String(place.get("subtitle", "")), 15, PaneStyle.DIM)
	subtitle.name = "PlaceKind"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(_picture())
	var words: Array = place.get("lines", [])
	_said = PaneStyle.label("\n".join(words), 17, PaneStyle.INK)
	_said.name = "PlaceWords"
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label has no width of its own: the picture's, or it
	# breaks at every word and the pane grows past the screen.
	_said.custom_minimum_size = Vector2(_width, 0)
	_said.visible = not words.is_empty()
	column.add_child(_said)
	# The choices wrap: a riddle's ten answers, five cards' names.
	_choices = HFlowContainer.new()
	_choices.name = "Choices"
	_choices.alignment = FlowContainer.ALIGNMENT_CENTER
	_choices.custom_minimum_size = Vector2(_width, 0)
	_choices.add_theme_constant_override("h_separation", int(8 * k))
	_choices.add_theme_constant_override("v_separation", int(6 * k))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_choices)
	_note = PaneStyle.label("", 14, PaneStyle.DIM)
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(_width, 0)
	column.add_child(_note)
	_fill_choices()
	# Each time the pane's parts are laid out anew, the picture is fitted.
	minimum_size_changed.connect(_fit)
	# AND AS THE PANE IS LAID OUT (the bug pass of part B): the choices wrap
	# in rows of their own width, and their rows can grow after the minimum
	# size was last told — the wise man's "whose deck" with big buttons held
	# at 843 px of the 800 (one run in four under load), the picture at its
	# widest and never looked at again. A new size looks again.
	resized.connect(_fit)
	if String(place.get("kind", "")) == "ruled" and player != null:
		_enter_ruled()
	_transition_in()


## THE PICTURE COMES IN as 1997 brought it (see the class doc): nothing
## while the pane is hidden (a ruled town with nothing to stake) or with
## the transitions off.
func _transition_in() -> void:
	if not visible or _art == null or not TileReveal.wanted():
		return
	match String(place.get("kind", "")):
		"castle", "fallen":
			# `ShowWizardVisitBackdrop` (visitLocation.c 4374, 4411).
			_cover_picture(TileReveal.CASTLE_GRID, TileReveal.CASTLE_SECONDS, TileReveal.Order.STAGGERED)
		"lair":
			# `ShowLairBackdropTransition` (world_lair_monster_encounter.c 984).
			_cover_picture(TileReveal.LAIR_GRID, TileReveal.LAIR_SECONDS, TileReveal.Order.RANDOM)
		_:
			# `AnimateVisitBackdropZoomIn` (visitLocation.c 4599, 4217, 877,
			# 635 …); a dungeon's pane is ours, zoomed as a place.
			TileReveal.zoom_in(_art)
			_reveal_face(TileReveal.ZOOM_SECONDS)


## THE TOWN COMES BACK from the map opened over it ([method
## WorldScreen.map_in_town]): its picture zoomed in again, as 1997 zoomed
## the town in after its map (visitLocation.c 1048, 2111) — with the
## transitions on, and not over a zoom still under way.
func come_back() -> void:
	if _art != null and _art.get_node_or_null(^"ZoomIn") == null:
		_transition_in()


## The whole picture hidden under the frame's dark ground, its [param
## tiles] coming in [param order] over [param length] seconds. Laid between
## the picture and what is over it: a lair's card or hoard stands at once,
## as its words do.
func _cover_picture(tiles: Vector2i, length: float, order: TileReveal.Order) -> void:
	var cover := TileReveal.make(tiles, length, order)
	if cover == null:
		return
	cover.name = "PictureReveal"
	_art.add_child(cover)
	_art.move_child(cover, 0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## THE CREATURE'S FACE COMES IN (`DrawCreaturePortrait` mode 2, a ruled
## town's, visitLocation.c 4286): its framed face hidden under the town's
## own picture, coming in 3 × 3 tiles after [param after] seconds (the
## zoom); its banner and name stand at once.
func _reveal_face(after: float) -> void:
	if face_name() == "":
		return
	var face := TileReveal.make(TileReveal.FACE_GRID, TileReveal.FACE_SECONDS)
	if face == null:
		return
	face.name = "FaceReveal"
	face.delay = after
	var town := _art.texture
	if town != null:
		var ratio := town.get_size() / PICTURE
		face.before = town
		face.source = Rect2(_face_at.position * ratio, _face_at.size * ratio)
	_add_over(face, _face_at, "face")


## A RULED TOWN ENTERED ([RuledTowns]): what it holds this time drawn —
## the stakes and the creature shown over the picture, the town's words and
## choices; with nothing to stake, the game's end: the pane hidden and its
## duel's door taken at once ([method RuledTowns.open] shows the end).
func _enter_ruled() -> void:
	ruled = RuledTowns.enter(player, int(place.get("slot", -1)), again)
	if ruled.is_empty():
		return
	if bool(ruled.get("no_ante", false)):
		visible = false
		_take_door.call_deferred("duel")
		return
	say(RuledTowns.words(player, ruled))
	offer(RuledTowns.choices(ruled))
	var row := int(ruled.get("row", 0))
	if row > 0:
		show_face(row)
	var hero: Array = ruled.get("hero_ante", [])
	var names: Array = hero.duplicate()
	var captions: Array = []
	var places: Array = []
	# The hero's stake fanned at the left, its caption under the last card;
	# the creature's at the right ([ours]: side by side in the picture, the
	# face between them — 1997 drew them over one another).
	for i in hero.size():
		captions.append(RuledTowns.YOUR_ANTE if i == hero.size() - 1 else "")
		places.append(Vector2(18 + 34 * i, 34 + 8 * i))
	for card_name in ruled.get("creature_ante", []):
		names.append(String(card_name))
		captions.append(RuledTowns.WIZARD_ANTE)
		places.append(Vector2(PICTURE.x - 18 - 100, 34))
	show_cards(names, captions, places, 100.0)


## The picture, as large as the screen allows up to [constant MOST] times
## the 1997 size, in a thin gold frame.
func _picture() -> Control:
	var frame := PanelContainer.new()
	frame.name = "Picture"
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.02, 0.015, 0.015, 1.0)
	rim.border_color = Color(PaneStyle.GOLD, 0.7)
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(4)
	rim.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", rim)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	# The rest of the pane: the name, the choices, a line of note and the
	# place's own lines.
	var rest := (250.0 + 24.0 * (place.get("lines", []) as Array).size()) * k
	_most = clampf(minf((room.x - 120.0) / PICTURE.x, (room.y - rest) / PICTURE.y), LEAST, MOST)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.texture = GameSkin.texture(String(place.get("picture", "")))
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The picture in a plain holder, not straight in the frame: a container
	# sets its children's scale back to 1 each time it lays them out, and
	# the zoom-in ([method _transition_in]) scales the picture.
	var stand := Control.new()
	stand.name = "ArtStand"
	stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stand)
	stand.add_child(_art)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A card shown over the picture's right side (a lair's find, a riddle's
	# answer), as 1997 showed it over the place.
	var holder := Control.new()
	holder.name = "CardHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.add_child(holder)
	_card = CardPreview.new()
	_card.name = "ShownCard"
	_card.docked = true
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(func(input: InputEvent) -> void:
		if PaneStyle.right_click(input) and _card_name != "":
			card_read.emit(_card_name))
	_card.visible = false
	holder.add_child(_card)
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.add_child(_over)
	_set_grow(_most)
	return frame


## The picture at [param grow] times the 1997 size: the words, the choices
## and the note wrap to its width, the card over it is fitted to it.
func _set_grow(grow: float) -> void:
	_grow = grow
	_width = PICTURE.x * grow
	_art.custom_minimum_size = PICTURE * grow
	(_art.get_parent() as Control).custom_minimum_size = PICTURE * grow
	for part: Control in [_said, _choices, _note]:
		if part != null:
			part.custom_minimum_size.x = _width
	var fit := PICTURE.y * grow * 0.88 / CardPreview.SIZE.y
	_card.scale = Vector2(fit, fit)
	_card.position = Vector2(PICTURE.x * grow - CardPreview.SIZE.x * fit - 16.0 * grow,
		(PICTURE.y * grow - CardPreview.SIZE.y * fit) / 2.0)
	for part in _over_parts:
		_place_over(part)


## THE PANE KEPT ON THE SCREEN, each time its parts are laid out anew: the
## picture gives way when the pane would be taller than the screen less
## [constant ROOM_MARGIN], and grows back, up to what the place's own words
## allowed, as the choices go. A new width wraps the words and the choices
## anew, so the pane is laid out again and looked at again until it holds.
func _fit() -> void:
	if not is_inside_tree() or _art == null:
		return
	var room := get_viewport_rect().size.y - ROOM_MARGIN
	var rest := get_combined_minimum_size().y - _art.custom_minimum_size.y
	var grow := clampf((room - rest) / PICTURE.y, LEAST, _most)
	if absf(grow - _grow) * PICTURE.y >= 1.0:
		_set_grow(grow)


func picture_key() -> String:
	return String(place.get("picture", ""))


func has_picture() -> bool:
	var art := find_child("Art", true, false) as TextureRect
	return art != null and art.texture != null


func _fill_choices() -> void:
	# Out now, freed after: the button pressed may be the one replaced.
	PaneStyle.drop_children(_choices)
	for action in place.get("actions", []):
		var choice := _button(String(action[1]), String(action[0]))
		choice.disabled = not bool(action[2])
		_choices.add_child(choice)
	_note.text = ""


## The place's words now: [param lines], a line each (none hides them).
func say(lines: Array) -> void:
	place["lines"] = lines
	_said.text = "\n".join(lines)
	_said.visible = not lines.is_empty()


## The choices now: [param actions], each `[id, words, ready]`; [param
## note] under them.
func offer(actions: Array, note_text := "") -> void:
	place["actions"] = actions
	_fill_choices()
	_note.text = note_text


## Card [param card_name] shown over the picture ("" hides it).
func show_card(card_name: String) -> void:
	if card_name == "" or not CardRegistry.has_card(card_name):
		_card.visible = false
		_card_name = ""
		return
	_card.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
	_card.visible = true
	_card_name = card_name


## The card shown over the picture, "" for none.
func shown_card() -> String:
	return _card_name


## THE PICTURE NOW skin picture [param key] (a lair's spoils on
## `win_back_cards`; "" the place's own again).
func show_picture(key: String) -> void:
	var shown := key if key != "" else String(place.get("picture", ""))
	_art.texture = GameSkin.texture(shown)
	_art.set_meta("key", shown)


## The skin key of the picture shown now.
func shown_picture() -> String:
	return String(_art.get_meta("key", place.get("picture", ""))) if _art != null else ""


## A ROW OF CARDS OVER THE PICTURE — a lair's hoard, a ruled town's stakes,
## the cards won — each [param width] picture pixels wide (the card's
## height to match), [param captions]' line under each ("" none), at
## [param places] (each card's top left in the picture's own pixels, kept
## inside it; [method page_point] turns 1997's page into them), else in a
## row about the middle, fanned when it does not fit. Right click reads a
## card. The one card ([method show_card]) gives way to it; [param names]
## empty takes the row away (the face stays: [method show_face]).
func show_cards(names: Array, captions: Array = [], places: Array = [], width := ROW_CARD) -> void:
	_drop_over("card")
	_row_names.clear()
	if names.is_empty():
		return
	show_card("")
	var high := width * CardPreview.SIZE.y / CardPreview.SIZE.x
	var count := names.size()
	var step := width + ROW_GAP
	if count > 1 and step * (count - 1) + width > PICTURE.x - 2.0 * ROW_MARGIN:
		step = (PICTURE.x - 2.0 * ROW_MARGIN - width) / (count - 1)
	var left := (PICTURE.x - (step * (count - 1) + width)) / 2.0
	var top := (PICTURE.y - high - CAPTION) / 2.0
	for i in count:
		var card_name := String(names[i])
		if not CardRegistry.has_card(card_name):
			continue
		var at: Vector2 = Vector2(places[i]) if i < places.size() else Vector2(left + step * i, top)
		var caption := String(captions[i]) if i < captions.size() else ""
		at.x = clampf(at.x, 0.0, PICTURE.x - width)
		at.y = clampf(at.y, 0.0, maxf(PICTURE.y - high - (CAPTION if caption != "" else 0.0), 0.0))
		var shown := CardPreview.new()
		shown.name = "RowCard%d" % i
		shown.docked = true
		shown.mouse_filter = Control.MOUSE_FILTER_STOP
		shown.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
		shown.set_meta("card", card_name)
		shown.gui_input.connect(func(input: InputEvent) -> void:
			if PaneStyle.right_click(input):
				card_read.emit(card_name))
		_add_over(shown, Rect2(at, Vector2(width, high)), "card")
		_row_names.append(card_name)
		if caption != "":
			var line := PaneStyle.label(caption, 13, PaneStyle.GOLD)
			line.name = "RowCaption%d" % i
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			line.add_theme_color_override("font_outline_color", PaneStyle.EDGE)
			line.add_theme_constant_override("outline_size", 4)
			line.set_meta("points", 13)
			_add_over(line, Rect2(at + Vector2(-16, high + 1), Vector2(width + 32, CAPTION)), "card")


## The pane left by [param then] after the frame (whoever opened it has
## connected [signal left] by then).
func _take_door(then: String) -> void:
	if is_inside_tree():
		left.emit(then)


## The names of the row's cards, in order ([method show_cards]).
func cards_shown() -> Array[String]:
	return _row_names.duplicate()


## 1997's page point [param at] (its 320-unit page) in the picture's pixels.
static func page_point(at: Vector2) -> Vector2:
	return at * PAGE_SCALE


## THE CREATURE'S FACE over the picture (1997's `DrawCreaturePortrait` with
## the tinted frame, `Prdfrmc.pic` — `preduel_frame_tinted`): its portrait
## in the frame at [param at], its name on the banner under it; row 0 takes
## the face away.
func show_face(row: int, at := FACE_AT, banner_at := FACE_BANNER_AT) -> void:
	_drop_over("face")
	if row <= 0:
		return
	_face_at = at
	var back := ColorRect.new()
	back.name = "FaceBack"
	back.color = Color.BLACK
	_add_over(back, at, "face")
	_add_over(_frame_piece(EncounterStage.FACE_FRAME, "FaceFrame"), at, "face")
	var portrait := TextureRect.new()
	portrait.name = "Face"
	portrait.texture = PortraitLibrary.texture(CreatureBook.face_id(row))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_add_over(portrait, at.grow(-FACE_INSET), "face")
	_add_over(_frame_piece(EncounterStage.NAME_BANNER, "FaceBanner"), banner_at, "face")
	var named := PaneStyle.label(CreatureBook.name_of(row), 15, PaneStyle.GOLD)
	named.name = "FaceName"
	named.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	named.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	named.clip_text = true
	named.set_meta("points", 15)
	_add_over(named, banner_at, "face")


## Whether the creature's face shows ([method show_face]), and whose.
func face_name() -> String:
	for part in _over_parts:
		var node := _over_node(part)
		if node != null and node.name == "FaceName":
			return (node as Label).text
	return ""


## A piece of the tinted frame's sheet (a dim box without the skin), cut
## clean of the sheet's key lines ([method EncounterStage.cut_of]).
func _frame_piece(region: Rect2, part_name: String) -> Control:
	var sheet := GameSkin.texture("preduel_frame_tinted")
	if sheet == null:
		var box := Panel.new()
		box.name = part_name
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.06, 0.06, 0.14, 0.9)
		face.border_color = Color(PaneStyle.GOLD, 0.5)
		face.set_border_width_all(1)
		box.add_theme_stylebox_override("panel", face)
		return box
	var shown := TextureRect.new()
	shown.name = part_name
	shown.texture = EncounterStage.cut_of(sheet, region)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	return shown


## [param node] laid over the picture at [param at] (picture pixels), of
## [param group] (`card`, `face`): only a card takes the mouse (its right
## click reads it).
func _add_over(node: Control, at: Rect2, group: String) -> void:
	if not node is CardPreview:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(node)
	var part := {"node": node, "at": at, "group": group}
	_over_parts.append(part)
	_place_over(part)


func _drop_over(group: String) -> void:
	var kept: Array = []
	for part in _over_parts:
		if String(part["group"]) == group:
			var node := _over_node(part)
			if node != null:
				PaneStyle.drop(node)
		else:
			kept.append(part)
	_over_parts = kept


## The node of part [param part] over the picture, or null once it is gone.
## The ruled town's face reveal ([method _reveal_face]) frees itself when
## it is over and stays among the parts; read straight into a typed
## variable it was a script error ("previously freed instance") on the
## next resize or face (the 0.50.66 bug campaign, h1-1). Looked at first,
## untyped.
static func _over_node(part: Dictionary) -> Control:
	var node: Variant = part.get("node")
	return node as Control if is_instance_valid(node) else null


## A part over the picture placed at the picture's size now.
func _place_over(part: Dictionary) -> void:
	var node := _over_node(part)
	if node == null:
		return
	var at: Rect2 = part["at"]
	node.position = at.position * _grow
	if node is CardPreview:
		var fit := at.size.x * _grow / CardPreview.SIZE.x
		node.scale = Vector2(fit, fit)
		return
	node.size = at.size * _grow
	if node is Label and node.has_meta("points"):
		(node as Label).add_theme_font_size_override("font_size",
			maxi(int(round(int(node.get_meta("points")) * _grow)), 8))


## "Whose deck would you like to see?" (`@LAIR` 17): a choice for each
## creature of [param color] (1 black … 5 white, [method
## CreatureBook.of_color]) and Never mind.
func ask_whose_deck(color: int) -> void:
	var lines: Array = (place.get("lines", []) as Array).duplicate()
	lines.append("Whose deck would you like to see?")
	say(lines)
	var actions: Array = []
	for index in CreatureBook.of_color(color):
		actions.append(["deck_%d" % index, CreatureBook.name_of(index), true])
	actions.append(["leave", "Never mind.", true])
	offer(actions)


func words() -> String:
	return _said.text if _said != null and _said.visible else ""


## What a choice does.
func choose(action: String) -> void:
	match action:
		"leave":
			left.emit("")
		"deck":
			left.emit("deck")
		"buy":
			left.emit("shop")
		"trade":
			left.emit("trade")
		"quest":
			left.emit("quest")
		"wiseman":
			left.emit("wiseman")
		"duel":
			# A ruled town's creature: its duel, over the world
			# ([method RuledTowns.open]).
			if String(place.get("kind", "")) == "ruled":
				left.emit("duel")
		"enter":
			# A castle's or a dungeon's door: its board, over the world
			# ([method WorldScreen._enter_board], [DungeonPane]).
			if String(place.get("kind", "")) in ["castle", "dungeon"]:
				left.emit("enter")
		"food":
			var kind := int(player.world.sites[int(place["slot"])]["type"])
			var price := food_price(kind)
			if player.gold < price:
				_note.text = "Insufficient Funds"
				return
			player.gold -= price
			player.food += 10
			# The button stays (it is the one pressed); it dims when the
			# purse can buy no more.
			(_choices.get_node("Choice_food") as Button).disabled = player.gold < price
			_note.text = "You buy 10 food: %d food, %d gold left." % [player.food, player.gold]
		_:
			if action.begins_with("deck_"):
				deck_wanted.emit(int(action.trim_prefix("deck_")))


func note() -> String:
	return _note.text if _note != null else ""


func _unhandled_input(event: InputEvent) -> void:
	# Hidden (a pane over it, the game's end taken), it is not the one left.
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		left.emit("")
	elif visible and letter_choice(self, _choices, event):
		get_viewport().set_input_as_handled()


## A press of the mouse puts out the choice a letter lit: the keys and the
## mouse do not both hold a choice.
func _input(event: InputEvent) -> void:
	drop_letter(_choices, event)


# ------------------------------------------------- a choice's first letter --

## A QUESTION'S CHOICE BY ITS FIRST LETTER (see the class doc): [param
## event] a plain letter on [param pane], the one on top, that one of
## [param choices]' buttons begins with — the next such after the one lit
## (round again from the first) is lit, Enter or Space to take it. True
## when the letter was the pane's (the caller marks it handled); false
## leaves it to the rest of the game.
static func letter_choice(pane: Control, choices: Container, event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed \
			or key.meta_pressed or key.keycode < KEY_A or key.keycode > KEY_Z:
		return false
	if pane == null or choices == null or not pane.is_visible_in_tree() or not on_top(pane):
		return false
	var held := pane.get_viewport().gui_get_focus_owner()
	if held is LineEdit or held is TextEdit:
		return false
	var letter := char(key.keycode)
	var answering: Array[Button] = []
	for child in choices.get_children():
		var button := child as Button
		if button != null and button.visible and not button.disabled \
				and not button.is_queued_for_deletion() and first_letter(button.text) == letter:
			answering.append(button)
	if answering.is_empty():
		return false
	var lit := answering.find(held as Button)
	_light(answering[(lit + 1) % answering.size()])
	return true


## The letter a choice's [param words] answer to, upper case: their first
## letter or digit — 1997's hotkey, the character after the line's leading
## space — "" for none.
static func first_letter(words: String) -> String:
	for i in words.length():
		var c := words[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			return c.to_upper()
		if c != " " and c != "_" and c != "\"" and c != "'":
			return ""
	return ""


## Whether [param pane] is on top: no later pane over it (a shown control
## of its parent's that stops the mouse — the card trader over a lair, the
## list of a creature's deck over the wise man).
static func on_top(pane: Control) -> bool:
	var parent := pane.get_parent()
	if parent == null:
		return true
	for i in range(pane.get_index() + 1, parent.get_child_count()):
		var other := parent.get_child(i) as Control
		if other != null and other.visible and other.mouse_filter == Control.MOUSE_FILTER_STOP:
			return false
	return true


## [param button] lit as the choice Enter or Space takes: it takes the keys
## and wears a gold rim, its words lit.
static func _light(button: Button) -> void:
	if button.focus_mode != Control.FOCUS_ALL:
		button.focus_mode = Control.FOCUS_ALL
		# Unlit as it loses the keys, so only a letter lights a choice (a
		# click later on it never leaves it lit for an Enter or a Space).
		if not button.has_meta("letter_lit"):
			button.set_meta("letter_lit", true)
			button.focus_exited.connect(func() -> void: button.focus_mode = Control.FOCUS_NONE)
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.border_color = PaneStyle.GOLD
		rim.set_border_width_all(LETTER_RIM)
		rim.set_corner_radius_all(6)
		button.add_theme_stylebox_override("focus", rim)
		button.add_theme_color_override("font_focus_color", PaneStyle.LIT)
	button.grab_focus()


## The choice a letter lit among [param choices] put out by a press of the
## mouse ([param event]).
static func drop_letter(choices: Container, event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or choices == null or not choices.is_inside_tree():
		return
	var held := choices.get_viewport().gui_get_focus_owner()
	if held != null and held.get_parent() == choices:
		held.release_focus()


func _button(words: String, action: String) -> Button:
	var choice := PaneStyle.button(words, "Choice_" + action, k)
	# A town's choices click as 1997's town icons did (`Button.wav`).
	choice.pressed.connect(func() -> void: WorldSoundscape.play_from(self, "sfx_button"))
	choice.pressed.connect(choose.bind(action))
	# A DOUBLE CLICK'S SECOND PRESS IS NO CHOICE (the playtest of part B,
	# P2-1; the meeting's q2-2 guard): a pane opens where the last one's
	# button stood — a news flash read on the step that reaches a ruled town
	# opens the town under the click — so a double click on Continue began a
	# duel never chosen. Every place's pane: a town, a ruled town, the news,
	# a lair, the wise man — but a town's food, whose button stays where it
	# was pressed (bought again on purpose, each click ten more).
	if action != "food":
		choice.gui_input.connect(func(input: InputEvent) -> void:
			var press := input as InputEventMouseButton
			if press != null and press.double_click:
				choice.accept_event())
	return choice