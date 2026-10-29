class_name WorldClues
extends RefCounted
## THE DUNGEON & CASTLE CLUES (F4, the frame's gate) — 1.3's
## `ShowDungeonCluesScreen` (00509244) and `ShowDungeonClueDetailScreen`
## (0050caa0), in the words of `Advstrings.txt` (`@CAVELIST`,
## `@CAVE_SHOWCLUES`, `@COLORCARDS`). A castle or dungeon is listed once
## the hero has learned anything of it (its slot's `clues`; a dungeon only
## while it holds cards), with what is known:
##  - 2, its creatures: "-Contains large black creatures." for a castle
##    and a large dungeon, small for the others, in the slot's colour
##    ([method lines]);
##  - 4, its rules, a line for each (`rules`) and the card in effect;
##  - 1, where it lies: "-East of Kraag Forge.", the way from the town it
##    was placed by (`town`) — 1997's four ways are the screen's diagonals.
## The 1997 list showed nothing when nothing was known; ours says how
## clues are found [QoL]. A dungeon known is drawn on the world and on the
## small map ([method on_world]). Clues come from the wise men and the ruined
## towers ([method reveal_for_hint]: [WiseMan]'s clue gift, [LairEvent]'s
## Ruined Tower) and, by the same pick, from beaten creatures — the
## creature's spoils offer the clue INSTEAD of the cards won ([DuelSpoils]:
## [method pick_for_hint] before the cards are drawn, [method forget_marks]
## and the choice after, [method reveal] or [method mark_cards_taken]) — and
## from a tribute's "Secrets from the castle" ([CreatureMeeting]).
##
## THE CARDS-TAKEN MARK, rules bit 0x200 ([constant CARDS_TAKEN]; 1997's
## `rules_bitmap` of the slot): set on the slot whose clue the hero passed
## over for a creature's cards; it triples the slot's score in the next
## picks (the dice favour the lowest), so the wise men and the towers tell
## of other places for a while; after every such offer each slot forgets it
## one time in three (`RandomlyClearDungeonRuleFlag`,
## world_lair_monster_encounter.c 310–322). As played in 1997 the mark is
## also a rule bit: a slot holding it and no other rule lists no "No special
## rules." line ([method lines] reads the whole word, as 1997's detail
## screen did).
##
## THE CARDS A DUNGEON HOLDS ([method holds_cards], [method treasures]):
## its own treasures (`cards`, [constant ShandalarWorld.DUNGEON_CARDS]
## indices) and the cards the hero left behind in it ([constant
## LEFT_CARDS], names) — [ours, the owner's ruling of 2026-10-27 on D12: "the
## card the hero puts back STAYS AS TREASURE in that dungeon, to be found
## again on a later visit" ([method DungeonBoard.treasure_swap])]. A dungeon
## lasts while it holds any ([method known], the owner's c2), and its clue
## lists them all.

## Rules bit 0x200: the cards were taken over this slot's clue.
const CARDS_TAKEN := 0x200
## Rules bit 0x20, 1997's "one deck for all duels" ([constant
## DungeonDuels.ONE_DECK]): read by nothing, and its clue line dropped by
## the owner's ruling of 2026-10-28 ([method lines]).
const ONE_DECK_RULE := 0x20
## The castle and dungeon slots the pick and the forgetting walk (1997's
## fifteen, `g_castle_dungeon_slots`).
const SLOTS := 15
## A slot's key for the cards the hero left behind in it (names, in the
## order left; the class's notes).
const LEFT_CARDS := "left_cards"

const LOCATION := 1
const CREATURES := 2
const RULES := 4
## `@COLORCARDS`, by the slot's colour (0 colourless, 1 black … 5 white).
const COLOR_CARDS: Array[String] = ["Colorless cards", "Black cards", "Blue cards",
	"Green cards", "Red cards", "White cards"]
const COLOR_WORDS: Array[String] = ["", "black", "blue", "green", "red", "white"]
## The cards a castle or dungeon plays under, by their 1.3 card id
## (`find_internal_card_id_by_csv_id`; the ids in [WorldGenerator]'s
## tables), as the 1.3 card table names them.
const EFFECT_CARDS := {8: "Bad Moon", 867: "Power Struggle", 939: "Marsh Viper",
	178: "Orcish Oriflamme", 51: "Crusade", 159: "Meekstone", 287: "Winter Orb",
	63: "Dingus Egg", 114: "Howling Mine", 229: "Smoke", 5: "Ankh of Mishra",
	246: "Throne of Bone", 100: "Gloom", 208: "Rod of Ruin", 661: "Greed",
	52: "Crystal Rod", 494: "Energy Flux", 935: "Flood", 340: "Leviathan",
	288: "Wooden Sphere", 15: "Birds of Paradise", 262: "Verduran Enchantress",
	803: "Sylvan Library", 123: "Iron Star", 439: "Magnetic Mountain",
	192: "Power Surge", 155: "Mana Flare", 128: "Ivory Cup", 134: "Karma",
	28: "Castle", 620: "Elder Land Wurm"}
const NONE_YET := "No clues yet. The wise men in the villages, ruined towers and the creatures you beat tell of the castles and the dungeons, and of the cards they hold."


## A CLUE TOLD (a Ruined Tower, a wise man's gift): the slot the dice
## favour ([method pick_for_hint]) learns one more clue ([method reveal]).
## The slot, or −1 when none is left to tell of.
static func reveal_for_hint(player: AdventurePlayer) -> int:
	var best := pick_for_hint(player)
	if best >= 0:
		reveal(player, best)
	return best


## THE SLOT A HINT TELLS OF (1.3 `PickWisemanCastleDungeonSlotForHint`,
## 004f2232, visitLocation.c 3009): among the castles and dungeons still
## holding cards whose three clues are not all known, the one the dice
## favour — `rand(d) + d / 2` for its distance d from the hero, three times
## that where its rules hold [constant CARDS_TAKEN] (the hero lately chose
## cards over its clue), the lowest winning. Nothing is learned yet: a
## creature's spoils pick the slot before the cards are drawn and reveal
## only when the clue is chosen. −1 when none is left to tell of.
static func pick_for_hint(player: AdventurePlayer) -> int:
	var dice := MsvcRandom.new(player.dice)
	var world := player.world
	var best := -1
	var best_score := 0x7FFF
	var hero := player.tile()
	for i in mini(world.encounters.size(), SLOTS):
		var slot: Dictionary = world.encounters[i]
		if not holds_cards(slot) or int(slot.get("clues", 0)) & 7 == 7:
			continue
		var far := WorldGenerator.distance(hero.x - int(slot.get("x", 0)), hero.y - int(slot.get("y", 0)))
		var score := dice.below(far) + far / 2
		if int(slot.get("rules", 0)) & CARDS_TAKEN != 0:
			score *= 3
		if best_score > score:
			best = i
			best_score = score
	player.dice = dice.state
	return best


## ONE MORE CLUE OF SLOT [param index] LEARNED (1.3
## `RevealRandomCastleDungeonClue`, 00508970): a clue drawn — `rand(3)`
## again until one not yet known — where it lies, its creatures or its
## rules. The clue's bit ([constant LOCATION], [constant CREATURES],
## [constant RULES]), or 0 when all three were known already (1997 drew
## forever there; every caller tests it first).
static func reveal(player: AdventurePlayer, index: int) -> int:
	var world := player.world
	if world == null or index < 0 or index >= world.encounters.size():
		return 0
	var slot: Dictionary = world.encounters[index]
	if int(slot.get("clues", 0)) & 7 == 7:
		return 0
	var dice := MsvcRandom.new(player.dice)
	var clue := 0
	while true:
		clue = dice.below(3)
		if int(slot.get("clues", 0)) & (1 << clue) == 0:
			break
	slot["clues"] = int(slot.get("clues", 0)) | (1 << clue)
	player.dice = dice.state
	return 1 << clue


## THE CARDS TAKEN OVER SLOT [param index]'s CLUE (the creature's spoils,
## "Take the cards.", world_lair_monster_encounter.c 2373–2378): its rules
## get [constant CARDS_TAKEN].
static func mark_cards_taken(world: ShandalarWorld, index: int) -> void:
	if world == null or index < 0 or index >= world.encounters.size():
		return
	var slot: Dictionary = world.encounters[index]
	slot["rules"] = int(slot.get("rules", 0)) | CARDS_TAKEN


## THE MARKS FADE (`RandomlyClearDungeonRuleFlag`,
## world_lair_monster_encounter.c 310–322, before the spoils' question):
## each of the fifteen slots, in order, forgets [constant CARDS_TAKEN] one
## time in three — fifteen dice, whether or not a slot holds the mark.
static func forget_marks(player: AdventurePlayer) -> void:
	var dice := MsvcRandom.new(player.dice)
	var world := player.world
	for i in SLOTS:
		if dice.below(3) == 0 and world != null and i < world.encounters.size():
			var slot: Dictionary = world.encounters[i]
			if slot.has("rules"):
				slot["rules"] = int(slot["rules"]) & ~CARDS_TAKEN
	player.dice = dice.state


## Which clue the hint's plaque names: "(first clue)", "(second clue)",
## "(third clue)" by the clues of slot [param index] already known, "" from
## three (`@ENCOUNTER_POSTDUEL` 0–2, world_lair_monster_encounter.c
## 2330–2354).
static func clue_word(world: ShandalarWorld, index: int) -> String:
	if world == null or index < 0 or index >= world.encounters.size():
		return ""
	var clues := int((world.encounters[index] as Dictionary).get("clues", 0))
	var known := 0
	for bit in 4:
		if clues & (1 << bit) != 0:
			known += 1
	return CLUE_WORDS[known] if known < CLUE_WORDS.size() else ""


## `@ENCOUNTER_POSTDUEL` 0–2.
const CLUE_WORDS: Array[String] = ["(first clue)", "(second clue)", "(third clue)"]


## The treasure cards slot [param index] still holds, by name: its own,
## then the ones the hero left behind in it.
static func treasures(world: ShandalarWorld, index: int) -> Array[String]:
	var out: Array[String] = []
	if world == null or index < 0 or index >= world.encounters.size():
		return out
	var slot: Dictionary = world.encounters[index]
	for card in slot.get("cards", []):
		out.append(String(ShandalarWorld.DUNGEON_CARDS[int(card)][1]))
	out.append_array(left_cards(slot))
	return out


## The cards the hero left behind in [param slot] ([constant LEFT_CARDS]),
## by name — anything else a damaged save put there read as none.
static func left_cards(slot: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var kept: Variant = slot.get(LEFT_CARDS, [])
	if kept is Array:
		for card in kept:
			if card is String and card != "":
				out.append(card)
	return out


## Whether [param slot] holds any card — its own treasures or one the hero
## left behind (the class's notes).
static func holds_cards(slot: Dictionary) -> bool:
	return not (slot.get("cards", []) as Array).is_empty() or not left_cards(slot).is_empty()


## The slots (0–4 castles, 5–14 dungeons) the hero knows something of.
static func known(world: ShandalarWorld) -> Array[int]:
	var out: Array[int] = []
	if world == null:
		return out
	for i in world.encounters.size():
		var slot: Dictionary = world.encounters[i]
		if int(slot.get("clues", 0)) == 0:
			continue
		if i >= 5 and not holds_cards(slot):
			continue
		out.append(i)
	return out


## THE DUNGEONS DRAWN ON THE WORLD (1.3 `DrawWorldTileRange`,
## adventureWorldUi.c 1230–1257; retail glue_adventure.c 970–978 tests the
## same): `{index, x, y}` (x, y its tile) for every dungeon, slots 5–14,
## the hero knows anything of — ANY clue, where it lies, its creatures or
## its rules, not only "where" — still holding a card, standing on a tile
## that carries [constant ShandalarWorld.DUNGEON]. Castles never: their
## slots stand on their castle sites, and the generator's stray DUNGEON
## flag on the tile first drawn for each ([WorldGenerator]) has no slot on
## it. A dungeon moved as it is left ([DungeonDoors]: its "where" clue
## forgotten, the other two known) keeps being drawn at its new tile, as in
## 1997. The owner's ruling of 2026-10-27 (A-1, A-2) [QoL]: drawn even on
## land the hero has not seen — [WorldView] and [WorldMinimap] both show it
## — where 1997's window, which marked explored every tile it drew, never
## had unseen land to draw it on.
## [ours: 1997 slip A-s1 — 1997 tested the FIRST of the slot's three card
## places (`card_slot_1 != -1`), and the treasure takes one of the three at
## random (dungeonEncounter.c 582–600): a dungeon whose first card went
## first vanished from the world, the clues and the entry with cards still
## inside. The slot's `cards` here is a list: any card left keeps it.]
static func on_world(world: ShandalarWorld) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null:
		return out
	for index in known(world):
		if index < 5 or index >= SLOTS:
			continue
		var slot: Dictionary = world.encounters[index]
		var x := int(slot.get("x", -1))
		var y := int(slot.get("y", -1))
		if world.tile_flags(x, y) & ShandalarWorld.DUNGEON == 0:
			continue
		out.append({"index": index, "x": x, "y": y})
	return out


## The slot's name in the list: "Castle Necris (Black Castle)", or the
## dungeon's.
static func title(index: int) -> String:
	if index < 5:
		return "%s (%s)" % [WorldNames.dungeon_name(index), WorldNames.CASTLES[index]]
	return WorldNames.dungeon_name(index)


## What is known of slot [param index], a line each, as the detail screen
## words it.
static func lines(world: ShandalarWorld, index: int) -> Array[String]:
	var out: Array[String] = []
	var slot: Dictionary = world.encounters[index]
	var clues := int(slot.get("clues", 0))
	var color := clampi(int(slot.get("color", 0)), 0, 5)
	var cards := treasures(world, index)
	if not cards.is_empty():
		out.append("Treasure: " + ", ".join(cards))
	if clues & CREATURES != 0:
		out.append("Creatures:")
		# A castle's are large; a dungeon's by its size, `monster_flags &
		# 0x80` — the tiers its rooms draw from ([method DungeonBoard.
		# creatures_for]). [ours: 1997 slip N4, the owner's D11 — 1997's
		# detail screen said "small" for every dungeon (dungeonCluesScreen.c
		# 1086–1095), a large one's too.]
		var large := index < 5 or int(slot.get("monster_flags", 0)) & DungeonBoard.LARGE != 0
		out.append("-Contains %s %s creatures." % ["large" if large else "small", COLOR_WORDS[color]])
	if clues & RULES != 0:
		out.append("Dungeon Rules:")
		var rules := int(slot.get("rules", 0))
		if rules & 0x10 != 0:
			out.append("-No %s allowed." % COLOR_CARDS[color])
		# 0x20, "-One deck for all duels.", is not said [ours: the owner's
		# ruling of 2026-10-28 — "the player can have multiple decks": the
		# rule stays dead (no code reads the bit, in 1997 or here;
		# docs/adventure-unused-1997-features.md §26) and its clue line
		# goes]; a dungeon whose only rule it was has none to tell.
		if rules & 0x40 != 0:
			out.append("-No artifacts allowed.")
		if rules & 0x80 != 0:
			out.append("-No instants or interrupts allowed.")
		if rules & 0x01 != 0:
			out.append("-Life losses carried over.")
		if rules & 0x02 != 0:
			out.append("-Remaining life added to next duel.")
		var effect := int(slot.get("card_in_effect", -1))
		if effect != -1:
			out.append("-%s permanently in effect." % String(EFFECT_CARDS.get(effect, "A card")))
		elif rules & ~ONE_DECK_RULE == 0:
			out.append("-No special rules.")
	if clues & LOCATION != 0:
		out.append("Location:")
		var town := int(slot.get("town", -1))
		if town >= 0 and town < world.sites.size():
			var place := Vector2i(int(world.sites[town]["x"]), int(world.sites[town]["y"]))
			out.append("-%s of %s." % [WorldNames.direction(place, Vector2i(int(slot["x"]), int(slot["y"]))),
				WorldNames.site_name(world, town)])
	return out
