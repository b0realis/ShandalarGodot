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
##    Cards, Edit deck/Sell cards, Speak to Wise Man (towns and cities
##    "Begin a Quest" when one is offered), Buy 10 food for (type + 2) × 5
##    gold, Leave the village.
##  - A TOWN A WIZARD RULES (its status's high byte): the same picture and
##    "This place is ruled by the %s." — "To free the city you must duel
##    this %s", " Never mind. / Duel the creature."
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
## Hints" when the seller has a hint ([CardHints]); a town's trade, "Trade
## red amulet for Any creatures", stands where the wise man is while it is
## offered ([CardTrade]), and opens the card trader ([CardTradePane]). A
## lair's own pane ([LairPane]) changes its words, choices and the card
## shown as its event goes ([method say], [method offer], [method
## show_card]). What is not made yet — the wise man and his quests, the
## duels for a ruled town and a castle, the dungeon board — is shown and
## waits, said in one line. Without the 1997 pictures the place is a plain
## dark field under its name.

## The hero leaves the place; [param then] what they chose to do next
## (`""`, `deck` for Edit deck, `shop` for Buy Cards, `trade` for the
## town's trade).
signal left(then: String)
## The card shown over the picture right-clicked, to be read full screen
## ([method WorldScreen.read_card]).
signal card_read(card_name: String)

const GOLD := Color8(232, 190, 110)
const INK := Color8(236, 222, 196)
const DIM := Color8(160, 146, 128)
const LIT := Color8(255, 236, 170)
const EDGE := Color8(20, 10, 8)
## The 1997 picture's size, and the most it is grown to.
const PICTURE := Vector2(512, 280)
const MOST := 1.5
const KINDS := ["village", "town", "city"]
const COMING := "The wise man and his quests, the duels and the dungeons come next."

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
					"actions": [["enter", "Enter the dungeon", false], ["leave", "Leave", true]]}
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
	var site: Dictionary = hero.world.sites[slot]
	var name := WorldNames.site_name(hero.world, slot)
	var picture := "visit_village" if kind == ShandalarWorld.VILLAGE else "visit_city"
	var ruler := (int(site["status"]) >> 8) & 0xFF
	if ruler >= 1 and ruler <= 5:
		var wizard: String = WorldNames.WIZARDS[ruler - 1]
		return {"kind": "ruled", "slot": slot, "name": name, "subtitle": "Ruled by the " + wizard,
			"picture": picture,
			"lines": ["This place is ruled by the %s." % wizard,
				"To free the city you must duel this %s's creature." % wizard],
			"actions": [["leave", "Never mind.", true], ["duel", "Duel the creature.", false]]}
	var price := food_price(kind)
	var buy := "Buy Cards/Card Hints" if not CardHints.current(hero, slot).is_empty() else "Buy Cards"
	var trade := CardTrade.town_offer(hero, slot)
	var fourth: Array = ["trade", String(trade["words"]), true] if not trade.is_empty() \
		else ["wiseman", "Speak to Wise Man", false]
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
		"actions": [["leave", "Well... No.", true], ["enter", "Yes, enter the castle.", false]]}


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
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.05, 0.03, 0.03, 0.92)
	face.border_color = Color(GOLD, 0.6)
	face.set_border_width_all(1)
	face.set_corner_radius_all(10)
	face.set_content_margin_all(14)
	add_theme_stylebox_override("panel", face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title := _label(String(place.get("name", "")), 26, GOLD)
	title.name = "PlaceName"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", EDGE)
	title.add_theme_constant_override("outline_size", 4)
	column.add_child(title)
	var subtitle := _label(String(place.get("subtitle", "")), 15, DIM)
	subtitle.name = "PlaceKind"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(_picture())
	var words: Array = place.get("lines", [])
	_said = _label("\n".join(words), 17, INK)
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
	_note = _label("", 14, DIM)
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(_width, 0)
	column.add_child(_note)
	_fill_choices()


## The picture, as large as the screen allows up to [constant MOST] times
## the 1997 size, in a thin gold frame.
func _picture() -> Control:
	var frame := PanelContainer.new()
	frame.name = "Picture"
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.02, 0.015, 0.015, 1.0)
	rim.border_color = Color(GOLD, 0.7)
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
	var grow := clampf(minf((room.x - 120.0) / PICTURE.x, (room.y - rest) / PICTURE.y), 0.6, MOST)
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = GameSkin.texture(String(place.get("picture", "")))
	art.custom_minimum_size = PICTURE * grow
	_width = PICTURE.x * grow
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	# A card shown over the picture's right side (a lair's find, a riddle's
	# answer), as 1997 showed it over the place.
	var holder := Control.new()
	holder.name = "CardHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.add_child(holder)
	_card = CardPreview.new()
	_card.name = "ShownCard"
	_card.docked = true
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(func(input: InputEvent) -> void:
		if CardShopPane._right_click(input) and _card_name != "":
			card_read.emit(_card_name))
	var fit := PICTURE.y * grow * 0.88 / CardPreview.SIZE.y
	_card.scale = Vector2(fit, fit)
	_card.position = Vector2(PICTURE.x * grow - CardPreview.SIZE.x * fit - 16.0 * grow,
		(PICTURE.y * grow - CardPreview.SIZE.y * fit) / 2.0)
	_card.visible = false
	holder.add_child(_card)
	return frame


func picture_key() -> String:
	return String(place.get("picture", ""))


func has_picture() -> bool:
	var art := find_child("Art", true, false) as TextureRect
	return art != null and art.texture != null


func _fill_choices() -> void:
	# Out now, freed after: the button pressed may be the one replaced.
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	var waiting := false
	for action in place.get("actions", []):
		var choice := _button(String(action[1]), String(action[0]))
		choice.disabled = not bool(action[2])
		if String(action[0]) in ["wiseman", "duel", "enter"]:
			waiting = true
		_choices.add_child(choice)
	_note.text = COMING if waiting else ""


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


func note() -> String:
	return _note.text if _note != null else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		left.emit("")


func _button(words: String, action: String) -> Button:
	var choice := Button.new()
	choice.name = "Choice_" + action
	choice.text = words
	choice.focus_mode = Control.FOCUS_NONE
	var face := GameSkin.font("font_title")
	if face != null:
		choice.add_theme_font_override("font", face)
	choice.add_theme_font_size_override("font_size", int(16 * k))
	choice.add_theme_color_override("font_color", INK)
	choice.add_theme_color_override("font_hover_color", LIT)
	choice.add_theme_color_override("font_pressed_color", LIT)
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
	var off := rest.duplicate() as StyleBoxFlat
	off.border_color = Color(GOLD, 0.15)
	choice.add_theme_stylebox_override("normal", rest)
	choice.add_theme_stylebox_override("hover", lit)
	choice.add_theme_stylebox_override("pressed", lit)
	choice.add_theme_stylebox_override("disabled", off)
	choice.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	choice.pressed.connect(choose.bind(action))
	return choice


func _label(text: String, size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_title")
	if face != null and size >= 15:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
