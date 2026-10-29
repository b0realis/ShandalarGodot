class_name EncounterStage
extends Control
## THE 1997 SCREEN INSIDE A MEETING'S PANE — the 640 × 480 page the 1997
## encounter drew on (world_lair_monster_encounter.c 1612–1741 the meeting,
## 2296–2691 the spoils), laid out in 1997's own page pixels and shown at
## the pane's size ([member factor]): the ground picture, the creature's
## face in its frame with its name, the ante plaques and cards, the purse's
## panels, the quest scroll, the cards won fanned with their rarities, the
## dungeon's plaque, an amulet. The skin's pictures are W3's import
## (`preduel_<colour>`, `preduel_panels`, `preduel_frame`, `win_back_cards`,
## `win_back_reward`, `end_plaque`, `lose_card`, `game_over`; the faces
## `rogue_<name>`); without them each part is a plain dark field under its
## words — [ours: the fix pass of part B, c5, P4-2/P4-3] the purse's boxes
## apart, each saying what it counts, the scroll lettered in the panes' ink,
## a disc of the creature's colour for its face, a stone of the amulet's.
## Pane-agnostic: a lair's or a town's duel shows its spoils on one too
## ([EncounterPane]).
##
## Cards on it are read full screen with a right click ([signal
## card_read]); nothing else on it takes the mouse — a press on the stage
## is the pane's (it moves the pane).
##
## A FACE COMES IN as 1997's summoned creature's did ([method reveal_face],
## `DrawCreaturePortrait` mode 1): the new face over the old one in 3 × 3
## tiles, its name banner's middle in 2 × 2 ([TileReveal]).

## A card on the stage right-clicked.
signal card_read(card_name: String)

## The 1997 page.
const PAGE := Vector2(640, 480)
## `Prdfrmb.pic`'s pieces (W3): the portrait's frame, the name banner, the
## creature's ante plaque, the hero's.
const FACE_FRAME := Rect2(1, 165, 180, 180)
const NAME_BANNER := Rect2(1, 346, 179, 35)
const CREATURE_PLAQUE := Rect2(1, 382, 152, 35)
const HERO_PLAQUE := Rect2(1, 418, 128, 35)
## `Prdfrma.pic`'s panels (W3): gold, food, life (the ankh), the deck (the
## book), the quest scroll.
const PANEL_GOLD := Rect2(1, 1, 104, 44)
const PANEL_FOOD := Rect2(1, 46, 103, 49)
const PANEL_LIFE := Rect2(1, 96, 102, 44)
const PANEL_DECK := Rect2(1, 141, 121, 44)
const PANEL_SCROLL := Rect2(1, 186, 145, 114)
## Where 1997 drew them on the page (E:1627–1700): the face centred at 320
## from 10 down, the hero's plaque centred at 100 and the creature's at 544
## from 5 down, the panels from (12, 365), the scroll at (468, 350).
const FACE_AT := Rect2(230, 10, 180, 180)
## The face inside its frame, this far from the frame's edge.
const FACE_INSET := 12.0
const BANNER_AT := Rect2(230, 190, 180, 35)
const HERO_PLAQUE_AT := Rect2(36, 5, 128, 35)
const CREATURE_PLAQUE_AT := Rect2(468, 5, 152, 35)
const GOLD_AT := Rect2(20, 371, 104, 44)
const FOOD_AT := Rect2(116, 365, 103, 49)
const DECK_AT := Rect2(12, 415, 121, 44)
const LIFE_AT := Rect2(125, 415, 102, 44)
const SCROLL_AT := Rect2(468, 350, 145, 114)
## THE WORDS ON THE PICTURES, CENTRED WHERE 1997 CENTRED THEM: 1997's
## `DrawTextAt` centres its text on its point both ways (`DrawTextFormatted`
## with centre x and centre y set), so each number sits on its panel's point
## (E:1672–1675) and the quest's words on the scroll's (E:1682, (543, 409)).
## The scroll's words fill its parchment between the two rolls — 33 to 86
## points down the picture, 12 to 142 across — centred on that point
## [ours: slip of our own fixed — the words hung from the top roll].
const GOLD_POINT := Vector2(91, 392)
const FOOD_POINT := Vector2(189, 392)
const DECK_POINT := Vector2(91, 437)
const LIFE_POINT := Vector2(195, 437)
const SCROLL_WORDS := Rect2(482, 384, 126, 51)
## [Ours] The scroll without the skin: a plain box, wider to its left, where
## the page has room — its words in the panes' ink.
const PLAIN_SCROLL_AT := Rect2(392, 350, 221, 114)
## [Ours] The purse without the skin: four boxes in 1997's corner, apart
## (the pictures' places overlap by 8 points — their edges are clear in the
## skin, not in a plain box).
const PLAIN_GOLD_AT := Rect2(12, 365, 106, 44)
const PLAIN_FOOD_AT := Rect2(122, 365, 106, 44)
const PLAIN_DECK_AT := Rect2(12, 413, 106, 44)
const PLAIN_LIFE_AT := Rect2(122, 413, 106, 44)
## The quest scroll's ink on the 1997 scroll.
const SCROLL_INK := Color8(40, 24, 12)
## [Ours] The face's disc without the skin a shade under the amulets' ink,
## so the page's words stay the brightest thing on it.
const FACE_DIM := 0.25
## The cards on the page: an ante card is 120 wide (1997's `DrawAdventureCard`
## at the plaques), the creature's under its plaque, the hero's under theirs
## a step apart for each more stake.
const CARD_WIDTH := 120.0
const HERO_CARD_AT := Vector2(40, 48)
const CREATURE_CARD_AT := Vector2(484, 48)
const STAKE_STEP := Vector2(48, 24)
## The dungeon's plaque (`Endplak.pic`, 296 × 54) on the cards won, centred
## at 200 from 405 down (E:2311–2316).
const END_PLAQUE := Rect2(52, 405, 296, 54)
## The amulet stones (`world_amulets`, [constant WorldHud.AMULETS]).
const AMULET := Vector2(12, 17)
const DARK := Color(0.02, 0.015, 0.015, 1.0)

## The page's size on the screen, times 1997's.
var factor := 1.0
## The colour the creature is met as (1 black … 5 white), for its face
## without the skin; 0 for the first of its own ([method CreatureBook.is_of]).
var hue := 0
var _ground: TextureRect
var _plain: ColorRect
var _parts: Array = []
var _art := WorldArt.new()


func _ready() -> void:
	name = "EncounterStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_plain = ColorRect.new()
	_plain.name = "Plain"
	_plain.color = DARK
	_plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plain)
	_ground = TextureRect.new()
	_ground.name = "Ground"
	_ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ground.stretch_mode = TextureRect.STRETCH_SCALE
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)
	set_factor(factor)


## The page at [param value] times 1997's size: every part placed again.
func set_factor(value: float) -> void:
	factor = value
	custom_minimum_size = PAGE * factor
	size = custom_minimum_size
	if _ground == null:
		return
	_plain.size = custom_minimum_size
	_ground.size = custom_minimum_size
	for part in _parts:
		_place(part)


## The ground: skin picture [param key] (the plain field without it).
func ground(key: String) -> void:
	_ground.texture = GameSkin.texture(key)
	_ground.set_meta("key", key)


## The ground's skin key.
func ground_key() -> String:
	return String(_ground.get_meta("key", ""))


## Whether the ground shows a 1997 picture.
func has_ground() -> bool:
	return _ground.texture != null


## Every part taken off the page (the ground stays).
func clear() -> void:
	for part in _parts:
		var node: Node = part["node"]
		if is_instance_valid(node):
			PaneStyle.drop(node)
	_parts.clear()


# ---------------------------------------------------------------- parts --

## A piece of a skin sheet [param key] — [param region] in its own pixels —
## at [param at] on the page; a dim box in its place without the sheet.
## CUT CLEAN [ours] (the polish pass, 2026-10-28): clipped to its region
## ([method cut_of]).
func piece(key: String, region: Rect2, at: Rect2, part_name := "") -> Control:
	var sheet := GameSkin.texture(key)
	if sheet == null:
		var box := Panel.new()
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.08, 0.05, 0.04, 0.85)
		face.border_color = Color(PaneStyle.GOLD, 0.5)
		face.set_border_width_all(1)
		face.set_corner_radius_all(4)
		box.add_theme_stylebox_override("panel", face)
		return _add(box, at, part_name)
	var shown := TextureRect.new()
	shown.texture = cut_of(sheet, region)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	return _add(shown, at, part_name)


## [param region] of the frames' sheet [param sheet], CLIPPED TO IT: the
## sheets part their pieces with lines of the transparent key — in
## `preduel_frame` and `preduel_frame_tinted` a magenta column at x = 129,
## just right of the hero's plaque (1..128) — and a piece drawn scaled and
## filtered took that line in at its edge: the 1-px purple line at the
## right end of "Your Ante", with the 1997 skin and the 2x one alike (the
## owner's polish list, 2026-10-28). The map's buttons were cut so before
## ([method WorldMap.cell]).
static func cut_of(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = region
	cut.filter_clip = true
	return cut


## Words at [param at] on the page: [param size] page points, centred.
func words(text: String, at: Rect2, size_points: int, color := PaneStyle.INK, part_name := "",
		wrap := false, most := Rect2()) -> Label:
	var line := PaneStyle.label(text, size_points, color)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.clip_text = not wrap
	if wrap:
		# Wrapped words stay centred on their place, a size smaller each
		# until they fit it ([method _place]).
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.set_meta("fit", true)
		# Too many lines even at the smallest size: the larger place [param
		# most] their part allows, still centred on theirs.
		if most.has_area():
			line.set_meta("most", most)
	line.set_meta("points", size_points)
	return _add(line, at, part_name) as Label


## How tall [param label]'s words stand at [param points], wrapped at
## [param width] — measured on its own font.
static func _words_high(label: Label, width: float, points: int) -> float:
	var font := label.get_theme_font("font")
	return font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, width, points).y \
		+ label.get_theme_constant("line_spacing") * label.text.count("\n")


## Words [param box] in size, centred on 1997's point [param point]
## (`DrawTextAt`).
static func centred(point: Vector2, box: Vector2) -> Rect2:
	return Rect2(point - box / 2.0, box)


## THE CREATURE'S FACE (`DrawCreaturePortrait`): its portrait ([method
## CreatureBook.face_id]) in the 1997 frame at [param at], its name on the
## banner under it; [param tinted] the reward's and the draw's dimmed face.
func creature_face(row: int, at := FACE_AT, banner_at := BANNER_AT, tinted := false) -> void:
	var shown := PortraitLibrary.texture(CreatureBook.face_id(row))
	# The frame's own outline was drawn on black in 1997 (W3: index 0 clear);
	# the face goes over the frame's middle, as `DrawCreaturePortrait` laid
	# the face into it.
	var back := ColorRect.new()
	back.color = Color.BLACK
	_add(back, at, "FaceBack")
	piece("preduel_frame", FACE_FRAME, at, "FaceFrame")
	var face: Control
	if shown != null:
		var portrait := TextureRect.new()
		portrait.texture = shown
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face = _add(portrait, at.grow(-FACE_INSET), "Face")
	else:
		# [Ours] No face to show: a disc of the creature's colour, its name on
		# the banner under it (the fix pass of part B, c5, P4-3).
		var ink := WorldArt.AMULET_INKS[_face_color(row) - 1].darkened(FACE_DIM)
		face = _add(_stone(ink), at.grow(-FACE_INSET * 2.0), "FaceDisc")
	if tinted:
		face.modulate = Color(0.75, 0.62, 0.55)
	piece("preduel_frame", NAME_BANNER, banner_at, "NameBanner")
	words(CreatureBook.name_of(row), banner_at, 16, PaneStyle.GOLD, "CreatureName")


## THE NEW FACE COMES IN OVER THE OLD (`DrawCreaturePortrait` mode 1,
## visitLocation.c 2540–2625; a summoned or substituted creature,
## world_lair_monster_encounter.c 2183): [param was], the screen as it
## stood before the face was drawn anew ([method TileReveal.picture_of]),
## hides the face block at [param at] — coming in 3 × 3 tiles — and the
## middle of the name banner at [param banner_at], its width less 22 —
## coming in 2 × 2. Nothing without a picture or with the transitions off.
func reveal_face(was: Texture2D, at := FACE_AT, banner_at := BANNER_AT) -> void:
	if was == null:
		return
	var face := TileReveal.make(TileReveal.FACE_GRID, TileReveal.FACE_SECONDS)
	if face == null:
		return
	_add(face, at, "FaceReveal")
	face.take_screen(was)
	var banner := TileReveal.make(TileReveal.BANNER_GRID, TileReveal.FACE_SECONDS)
	_add(banner, banner_at.grow_individual(-TileReveal.BANNER_TRIM, 0, -TileReveal.BANNER_TRIM, 0),
		"BannerReveal")
	banner.take_screen(was)


## The colour of creature [param row]'s face without the skin: [member hue],
## else the first of its own (1 black … 5 white), else black.
func _face_color(row: int) -> int:
	if hue >= 1 and hue <= 5:
		return hue
	for color in range(1, 6):
		if CreatureBook.is_of(row, color):
			return color
	return 1


## A round stone of [param ink], rimmed in gold (a face's or an amulet's
## stand-in without the skin).
func _stone(ink: Color) -> Panel:
	var stone := Panel.new()
	var face := StyleBoxFlat.new()
	face.bg_color = ink
	face.border_color = Color(PaneStyle.GOLD, 0.8)
	face.set_border_width_all(2)
	# Rounded as far as the stone's size allows: a disc, or an oval.
	face.set_corner_radius_all(4096)
	stone.add_theme_stylebox_override("panel", face)
	return stone


## The ante plaques: "Your Ante" over the hero's stake, "Opponent Ante" over
## the creature's (`@ENCOUNTER_PREDUEL` 0, 1).
func ante_plaques() -> void:
	piece("preduel_frame", HERO_PLAQUE, HERO_PLAQUE_AT, "HeroPlaque")
	words(CreatureMeeting.ANTE_WORDS[1], HERO_PLAQUE_AT, 15, PaneStyle.GOLD, "HeroPlaqueWords")
	piece("preduel_frame", CREATURE_PLAQUE, CREATURE_PLAQUE_AT, "CreaturePlaque")
	words(CreatureMeeting.ANTE_WORDS[0], CREATURE_PLAQUE_AT, 15, PaneStyle.GOLD, "CreaturePlaqueWords")


## A card at [param top_left] on the page, [param width] wide, named
## [param part_name]; [param caption] under it. Null for a card the pool
## does not know.
func card(card_name: String, top_left: Vector2, width := CARD_WIDTH, part_name := "",
		caption := "") -> CardPreview:
	if not CardRegistry.has_card(card_name):
		return null
	var shown := CardPreview.new()
	shown.docked = true
	shown.mouse_filter = Control.MOUSE_FILTER_STOP
	shown.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
	shown.set_meta("card", card_name)
	shown.gui_input.connect(func(input: InputEvent) -> void:
		if PaneStyle.right_click(input):
			card_read.emit(card_name))
	var high := width * CardPreview.SIZE.y / CardPreview.SIZE.x
	_add(shown, Rect2(top_left, Vector2(width, high)), part_name)
	if caption != "":
		words(caption, Rect2(top_left + Vector2(-10, high + 2), Vector2(width + 20, 18)), 13,
			PaneStyle.GOLD, part_name + "Caption")
	return shown


## The stakes: the hero's [param hero] under "Your Ante" (a step apart each),
## the creature's [param creature] under "Opponent Ante".
func stakes(hero: Array, creature: Array) -> void:
	for i in hero.size():
		card(String(hero[i]), HERO_CARD_AT + STAKE_STEP * i, CARD_WIDTH, "HeroAnte%d" % i)
	for i in creature.size():
		card(String(creature[i]), CREATURE_CARD_AT + STAKE_STEP * i, CARD_WIDTH, "CreatureAnte%d" % i)


## THE PURSE'S PANELS (E:1627–1683): gold, food, the deck in use's cards of
## all owned ("%d/%d") and the life the links give — the life duels start
## from ([method AdventurePlayer.duel_start_life]: under the Embark's "Base
## 10 + links" the base with the links, since 0.50.65). [Ours] Without the skin
## (no picture says which is which) four boxes apart, each its word: "Gold
## 1000", "Food 50", "Deck 39/39", "Life 10".
func purse(player: AdventurePlayer) -> void:
	var deck := "%d/%d" % [player.deck_cards().size(), player.cards.size()]
	if GameSkin.texture("preduel_panels") == null:
		var counts := [["Gold", PLAIN_GOLD_AT, str(player.gold)], ["Food", PLAIN_FOOD_AT, str(player.food)],
			["Deck", PLAIN_DECK_AT, deck], ["Life", PLAIN_LIFE_AT, str(player.duel_start_life())]]
		for count in counts:
			var at: Rect2 = count[1]
			piece("preduel_panels", Rect2(), at, String(count[0]) + "Panel")
			words("%s %s" % [count[0], count[2]], at.grow_individual(-4, -6, -4, -6), 14, PaneStyle.LIT,
				String(count[0]))
		return
	piece("preduel_panels", PANEL_GOLD, GOLD_AT, "GoldPanel")
	piece("preduel_panels", PANEL_FOOD, FOOD_AT, "FoodPanel")
	piece("preduel_panels", PANEL_DECK, DECK_AT, "DeckPanel")
	piece("preduel_panels", PANEL_LIFE, LIFE_AT, "LifePanel")
	words(str(player.gold), centred(GOLD_POINT, Vector2(58, 32)), 15, PaneStyle.LIT, "Gold")
	words(str(player.food), centred(FOOD_POINT, Vector2(58, 32)), 15, PaneStyle.LIT, "Food")
	words(deck, centred(DECK_POINT, Vector2(76, 32)), 15, PaneStyle.LIT, "Deck")
	words(str(player.duel_start_life()), centred(LIFE_POINT, Vector2(56, 32)), 15, PaneStyle.LIT, "Life")


## THE QUEST SCROLL (E:1684–1688, `BuildQuestStatusMessage`): what calls the
## hero — [method WorldStatus.lines] — small on the scroll; [ours] in the
## panes' ink on the plain box without the skin (the scroll's dark ink was
## unreadable there, P4-2).
func scroll(lines: Array[String]) -> void:
	var skin := GameSkin.texture("preduel_panels") != null
	piece("preduel_panels", PANEL_SCROLL, SCROLL_AT if skin else PLAIN_SCROLL_AT, "Scroll")
	words("\n".join(lines), SCROLL_WORDS if skin else PLAIN_SCROLL_AT.grow(-8), 12,
		SCROLL_INK if skin else PaneStyle.INK, "ScrollWords", true, SCROLL_AT.grow(-4) if skin else Rect2())


## THE CARDS WON fanned across the page (E:2296–2308): each over its
## rarity's caption (`@BROWSE` 13–16), [param heights] 1997's `rand(10)`
## each.
func fan(cards: Array, rarities: Array, heights: Array) -> void:
	var count := cards.size()
	if count == 0:
		return
	var width := CARD_WIDTH if count <= 4 else 104.0
	var room := PAGE.x - 40.0 - width
	var step := minf(width + 10.0, room / maxf(count - 1, 1))
	var left := (PAGE.x - (step * (count - 1) + width)) / 2.0
	for i in count:
		var height := int(heights[i]) if i < heights.size() else 0
		var rarity := int(rarities[i]) if i < rarities.size() else 1
		card(String(cards[i]), Vector2(left + step * i, 32 + height * 2), width, "Won%d" % i,
			DuelSpoils.rarity_word(rarity))


## THE DUNGEON'S PLAQUE (`Endplak.pic`, E:2309–2354): its name, its
## treasures, "(first clue)" ….
func end_plaque(plaque: Dictionary) -> void:
	piece("end_plaque", Rect2(Vector2.ZERO, END_PLAQUE.size), END_PLAQUE, "EndPlaque")
	words(String(plaque.get("name", "")), Rect2(END_PLAQUE.position + Vector2(8, 2), Vector2(280, 18)), 15,
		PaneStyle.LIT, "PlaqueName")
	words(String(plaque.get("cards", "")), Rect2(END_PLAQUE.position + Vector2(8, 19), Vector2(280, 16)), 12,
		PaneStyle.INK, "PlaqueCards")
	words(String(plaque.get("clue", "")), Rect2(END_PLAQUE.position + Vector2(8, 34), Vector2(280, 16)), 12,
		PaneStyle.GOLD, "PlaqueClue")


## AN AMULET of colour [param stone_hue] (a word of [constant
## AdventurePlayer.COLORS]) in the middle of the page, large; [ours] without
## the skin a rimmed stone of its colour ([constant WorldArt.AMULET_INKS]),
## not a bare square (P4-3).
func amulet(stone_hue: String) -> Control:
	var at := Rect2(PAGE.x / 2.0 - AMULET.x * 3, 200, AMULET.x * 6, AMULET.y * 6)
	var frame := -1
	for gem in WorldHud.AMULETS:
		if String(gem[0]) == stone_hue:
			frame = int(gem[1])
	var sheet := _art.texture("world_amulets")
	if sheet == null or frame < 0:
		var ink := WorldArt.AMULET_INKS[clampi(AdventurePlayer.COLORS.find(stone_hue), 0, 4)]
		return _add(_stone(ink), at, "Amulet")
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = _art.frame_rect("world_amulets", frame)
	var shown := TextureRect.new()
	shown.texture = cut
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return _add(shown, at, "Amulet")


## The part named [param part_name], or null.
func part(part_name: String) -> Node:
	for entry in _parts:
		var node: Node = entry["node"]
		if is_instance_valid(node) and node.name == part_name:
			return node
	return null


## The names of the cards on the page, in order.
func cards_shown() -> Array[String]:
	var out: Array[String] = []
	for entry in _parts:
		var node: Node = entry["node"]
		if is_instance_valid(node) and node is CardPreview:
			out.append(String(node.get_meta("card", "")))
	return out


# -------------------------------------------------------------- placing --

func _add(node: Control, at: Rect2, part_name := "") -> Control:
	if part_name != "":
		node.name = part_name
	if node.mouse_filter != Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	var entry := {"node": node, "at": at}
	_parts.append(entry)
	_place(entry)
	return node


func _place(entry: Dictionary) -> void:
	var node: Control = entry["node"]
	if not is_instance_valid(node):
		return
	var at: Rect2 = entry["at"]
	node.position = at.position * factor
	if node is CardPreview:
		var fit := at.size.x / CardPreview.SIZE.x * factor
		node.scale = Vector2(fit, fit)
		return
	node.size = at.size * factor
	if node is Label and node.has_meta("points"):
		var label := node as Label
		var points := maxi(int(round(int(node.get_meta("points")) * factor)), 8)
		label.add_theme_font_size_override("font_size", points)
		if node.has_meta("fit"):
			var room := at.size * factor
			while points > 8 and _words_high(label, room.x, points) > room.y:
				points -= 1
			label.add_theme_font_size_override("font_size", points)
			var place := at
			var high := _words_high(label, room.x, points) / factor
			if high > at.size.y and node.has_meta("most"):
				var most: Rect2 = node.get_meta("most")
				var tall := minf(high, most.size.y)
				var top := clampf(at.get_center().y - tall / 2.0, most.position.y, most.end.y - tall)
				place = Rect2(at.position.x, top, at.size.x, tall)
			# A label grown by its words is put back to its place.
			node.position = place.position * factor
			label.size = place.size * factor
