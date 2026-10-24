extends GutTest
## THE CREATURES' DECKS AS 1997 PLAYED THEM (part B, 2026-10-23):
## [CreatureDeck] takes each `decks/1997/originals/*.deck` apart again into
## the 1997 maindeck (the main list less `.vNone`) and the six colour
## sections (the comment table) — pinned here against the files themselves
## and against the counts of the 1996 `Decks/0NNN.dck` (checked line for
## line, part B) — and plays them as the 1997 loader did: the maindeck and
## the learned colours' sections, never `.vNone` (the owner's ruling 3),
## the 0179 fallback, the basic-land trim, the creature's ante.

## The 1997 maindeck of each file, in cards (the 1996 files, part B).
const MAINDECKS := {"aga_galneer": 61, "alt_a_kesh": 62, "ape_lord": 60, "arch_angel": 57,
	"arzakon": 138, "astral_visionary": 59, "azaar_lichlord": 61, "beast_master": 57,
	"centaur_shaman": 57, "centaur_warchief": 57, "cleric": 57, "conjurer": 57, "crag_hydra": 57,
	"crusader": 59, "dracur": 59, "druid": 59, "elementalist": 57, "elvish_magi": 57,
	"enchantress": 59, "forest_dragon": 58, "fungus_master": 57, "goblin_warlord": 57,
	"great_druid": 57, "guardian_of_the_tusk": 60, "high_priest": 61, "kiska_ra": 66,
	"kzzy_n_the_dragon_lord": 64, "lord_of_fate": 57, "mandurang": 57, "merfolk_shaman": 60,
	"mind_stealer": 59, "necromancer": 57, "nether_fiend": 58, "paladin": 57, "priestess": 60,
	"prismat": 62, "queltosh": 57, "sainted_one": 57, "saltrem_tor": 60, "sea_drake": 57,
	"sedge_beast": 57, "seer": 60, "shapeshifter": 62, "sorcerer": 57, "sorceress": 57,
	"summoner": 57, "thought_invoker": 57, "troll_shaman": 57, "undead_knight": 57,
	"vampire_lord": 57, "war_mage": 57, "warlock": 57, "whim": 62, "winged_stallion": 61, "witch": 59}
## The ten files with no colour sections, and the four whose are empty.
const NO_SECTIONS: Array[String] = ["ape_lord", "kzzy_n_the_dragon_lord", "saltrem_tor", "kiska_ra",
	"high_priest", "shapeshifter", "azaar_lichlord", "merfolk_shaman", "seer", "guardian_of_the_tusk"]
const EMPTY_SECTIONS: Array[String] = ["alt_a_kesh", "whim", "prismat", "arzakon"]


func _file(row: int) -> String:
	return String(CreatureBook.ROWS[row][CreatureBook.DECK_FILE])


func _counts(names: Array) -> Dictionary:
	var out := {}
	for card_name in names:
		out[card_name] = int(out.get(card_name, 0)) + 1
	return out


func test_every_maindeck_is_1997s() -> void:
	for row in range(1, CreatureBook.size()):
		var file := _file(row)
		assert_eq(CreatureDeck.maindeck(row).size(), int(MAINDECKS[file]), "%s's maindeck" % file)


func test_the_sections_are_1997s() -> void:
	var with_sections := 0
	for file: String in MAINDECKS:
		var row := _row_of(file)
		var parts := CreatureDeck.sections(row)
		if file in NO_SECTIONS:
			assert_eq(parts, {}, "%s has none" % file)
			continue
		with_sections += 1
		var each := 0 if file in EMPTY_SECTIONS else 3
		for bit in [0x01, 0x02, 0x04, 0x08, 0x10]:
			assert_eq((parts.get(bit, []) as Array).size(), each, "%s section 0x%02x" % [file, bit])
		assert_eq((parts.get(0x20, []) as Array).size(), 5 if file == "sainted_one" else each,
			"%s's white section" % file)
	assert_eq(with_sections, 45)


func _row_of(file: String) -> int:
	for row in CreatureBook.size():
		if _file(row) == file:
			return row
	return -1


## Pinned against the files: the maindeck and `.vNone` together are the
## file's main list, and the file's `SB:` lines are, by name, the most of
## a card in any colour section less what `.vNone` holds (the files' own
## rule) — so the comment table read here is the one the files were made
## from.
func test_the_parse_is_the_files_own() -> void:
	for file: String in MAINDECKS:
		var row := _row_of(file)
		var listed := DeckList.load_file(CreatureBook.deck_path(row), false)
		assert_eq(listed.errors, [] as Array[String], file)
		var parts := CreatureDeck.sections(row)
		var none: Array = parts.get(CreatureDeck.NONE_BIT, [])
		assert_eq(_counts(CreatureDeck.maindeck(row) + none), _counts(listed.cards), "%s: main = maindeck + .vNone" % file)
		var most := {}
		for bit in [0x02, 0x04, 0x08, 0x10, 0x20]:
			var counted := _counts(parts.get(bit, []))
			for card_name in counted:
				most[card_name] = maxi(int(most.get(card_name, 0)), int(counted[card_name]))
		var none_counts := _counts(none)
		var side := {}
		for card_name in most:
			var extra := int(most[card_name]) - int(none_counts.get(card_name, 0))
			if extra > 0:
				side[card_name] = extra
		assert_eq(side, _counts(listed.sideboard), "%s: SB = the sections' most less .vNone" % file)


func test_the_witch_line_by_line() -> void:
	var expected: Array[String] = []
	for line in [[23, "Swamp"], [3, "Throne of Bone"], [4, "Nevinyrral's Disk"], [2, "Wall of Bone"],
			[4, "Drudge Skeletons"], [4, "Will-o'-the-Wisp"], [2, "Greed"], [3, "Clay Statue"],
			[3, "Diabolic Machine"], [4, "Unholy Strength"], [2, "Dark Ritual"], [3, "Scavenging Ghoul"],
			[2, "Drain Life"]]:
		for i in int(line[0]):
			expected.append(String(line[1]))
	assert_eq(CreatureDeck.maindeck(1), expected, "the 1996 file's maindeck, in its order")
	var parts := CreatureDeck.sections(1)
	assert_eq(parts.keys(), [0x01, 0x02, 0x04, 0x08, 0x10, 0x20], "in the 1997 order")
	assert_eq(parts[0x01], ["Weakness", "Weakness", "Weakness"] as Array[String])
	assert_eq(parts[0x20], ["Gloom", "Weakness", "Weakness"] as Array[String])


# ------------------------------------------------------- what is played --

func test_a_meeting_plays_the_maindeck_and_the_learned_colours() -> void:
	var witch := CreatureDeck.maindeck(1)
	assert_eq(CreatureDeck.for_meeting(1, 0), witch, "nothing learned: the maindeck alone")
	assert_eq(CreatureDeck.for_meeting(1, 0x01), witch, ".vNone is never played (ruling 3)")
	var white := witch.duplicate()
	white.append_array(["Gloom", "Weakness", "Weakness"])
	assert_eq(CreatureDeck.for_meeting(1, 0x20), white, "the white section after it")
	assert_eq(CreatureDeck.for_meeting(1, 0x22).size(), 59 + 6, "black and white")
	assert_eq(CreatureDeck.for_meeting(1, 0x3F).size(), 59 + 15, "every colour, never .vNone")
	assert_eq(CreatureDeck.for_meeting(8, 0x02).slice(57),
		["Swords to Plowshares", "Swords to Plowshares", "Karma"] as Array[String], "the Cleric against black")
	assert_eq(CreatureDeck.for_meeting(33, 0x3E).size(), 57 + 15)
	assert_eq(CreatureDeck.for_meeting(55, 0x3E).size(), 138, "Arzakon's sections are empty")
	assert_eq(CreatureDeck.for_meeting(56, 0), CreatureDeck.for_meeting(55, 0), "both Arzakon rows")


func test_a_creature_with_no_deck_plays_0179() -> void:
	assert_eq(CreatureDeck.file_row(0), CreatureDeck.FALLBACK_ROW, "the lair has no deck")
	assert_eq(CreatureDeck.file_row(-3), CreatureDeck.FALLBACK_ROW)
	assert_eq(CreatureDeck.file_row(1), 1)
	assert_eq(CreatureBook.name_of(CreatureDeck.FALLBACK_ROW), "Centaur Shaman")
	assert_eq(int(CreatureBook.ROWS[CreatureDeck.FALLBACK_ROW][CreatureBook.DECK_NUMBER]), 179)
	assert_eq(CreatureDeck.for_meeting(0, 0x04), CreatureDeck.for_meeting(39, 0x04))


## No card of the 55 files is unknown to the game.
func test_every_card_is_known() -> void:
	CardRegistry.ensure_loaded()
	for row in range(1, CreatureBook.size()):
		for entry in CreatureDeck.library(row, 0x3E):
			assert_true(bool(entry["known"]), "%s in %s" % [entry["name"], _file(row)])


## The 1997 trim: an unknown card takes half its count — plus one at an odd
## line — off the last basic land before it, when that land has more.
func test_an_unknown_card_trims_the_land_before_it() -> void:
	var known := func(card_name: String) -> bool: return card_name != "Mystery"
	var odd := CreatureDeck.parse_text("name: T\n20 Swamp\n3 Mystery\n3 Dark Ritual\n")
	var at_odd := CreatureDeck.library_of(odd, 0, known)
	assert_eq(at_odd[0], {"name": "Swamp", "count": 18, "known": true}, "(1 + 3) / 2 off at line 1")
	assert_eq(at_odd[1], {"name": "Mystery", "count": 3, "known": false}, "kept, marked")
	var even := CreatureDeck.parse_text("name: T\n20 Swamp\n3 Dark Ritual\n3 Mystery\n")
	assert_eq(int(CreatureDeck.library_of(even, 0, known)[0]["count"]), 19, "(0 + 3) / 2 off at line 2")
	var few := CreatureDeck.parse_text("name: T\n2 Swamp\n4 Mystery\n")
	assert_eq(int(CreatureDeck.library_of(few, 0, known)[0]["count"]), 2, "the land must have more")
	var none := CreatureDeck.parse_text("name: T\n4 Mystery\n20 Swamp\n")
	assert_eq(int(CreatureDeck.library_of(none, 0, known)[1]["count"]), 20, "only a land before it")
	# In a section: the section lines count — .vNone's marker at 1, its card
	# at 2, .vBlack's marker at 3, its card at 4.
	var text := "name: T\n21 Swamp\n1 Dark Ritual\n#   .vNone   1 Dark Ritual\n#   .vBlack  3 Mystery\n" \
		+ "#   .vBlue   (empty)\n#   .vGreen  (empty)\n#   .vRed    (empty)\n#   .vWhite  (empty)\n"
	var sectioned := CreatureDeck.parse_text(text)
	assert_true(bool(sectioned["sections"]))
	assert_eq(CreatureDeck.library_of(sectioned, 0, known).size(), 1, "the main list less .vNone: Swamp alone")
	assert_eq(int(CreatureDeck.library_of(sectioned, 0x02, known)[0]["count"]), 21 - 1, "(0 + 3) / 2 off at line 4")
	assert_eq(int(CreatureDeck.library_of(sectioned, 0x04, known)[0]["count"]), 21, "black not played: no trim")


# ------------------------------------------------------------- the ante --

## The creature's ante, drawn as 1997 draws it, replayed draw for draw.
func test_the_ante_is_drawn_as_1997() -> void:
	CardRegistry.ensure_loaded()
	var treasures := {}
	for treasure in ShandalarWorld.DUNGEON_CARDS:
		treasures[String(treasure[1])] = true
	for row in [1, 3, 10, 33, 46, 55]:
		var signature := CreatureBook.signature_card(row)
		var maindeck := CreatureDeck.maindeck(row)
		for seed_value in range(1, 41):
			var dice := MsvcRandom.new(seed_value)
			var ante := CreatureDeck.ante_draw(row, dice)
			assert_true(ante in maindeck, "%s antes from its maindeck" % CreatureBook.name_of(row))
			assert_false(ante in CreatureDeck.BASICS, "never a basic land")
			assert_false(treasures.has(ante), "never a dungeon's treasure")
			assert_ne(ante, signature, "never its signature card")
			# The replay: one card in the cards left, each copy alike.
			var replay := MsvcRandom.new(seed_value)
			var left := maindeck.duplicate()
			while true:
				var at := replay.below(left.size())
				var drawn: String = left[at]
				left.remove_at(at)
				if not drawn in CreatureDeck.BASICS and not treasures.has(drawn) and drawn != signature:
					assert_eq(drawn, ante, "seed %d" % seed_value)
					break
			assert_eq(dice.state, replay.state, "the same draws of the dice")


## The Warlock never antes Dark Ritual, the Crusader never White Knight —
## though both hold four.
func test_never_the_signature_card() -> void:
	assert_eq(_counts(CreatureDeck.maindeck(10)).get("White Knight", 0), 4)
	for seed_value in range(1, 200):
		assert_ne(CreatureDeck.ante_draw(10, MsvcRandom.new(seed_value)), "White Knight")
		assert_ne(CreatureDeck.ante_draw(3, MsvcRandom.new(seed_value)), "Dark Ritual")


func test_henchmen_ante_nothing() -> void:
	var dice := MsvcRandom.new(7)
	assert_eq(CreatureDeck.ante_draw(6, dice), "", "the Necromancer")
	assert_eq(dice.state, 7, "and draw no dice")
