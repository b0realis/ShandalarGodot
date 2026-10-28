extends GutTest
## THE CREATURE TABLE'S NUMBERS (part B, 2026-10-23): [CreatureBook]'s
## flags by name, its strength, bribe and duel life, its faces, voices and
## map figures, the cards it names, the minions, and the 1997 pick on the
## adventure's dice — each against the 1997 values of the part B specs
## (b1 §1–2, b3 §2.2 and §4, b4 §1.1–1.2).


# ------------------------------------------------------------ the flags --

func test_every_bit_of_the_table_has_a_name() -> void:
	for row in CreatureBook.size():
		for field in [CreatureBook.MOVE_FLAGS, CreatureBook.PREDUEL_FLAGS, CreatureBook.REWARD_FLAGS]:
			var bits := int(CreatureBook.ROWS[row][field])
			for word in CreatureBook.flag_names(field, bits):
				assert_false(word.begins_with("0x"), "row %d field %d: %s named" % [row, field, word])


func test_the_flags_read_as_the_spec_table() -> void:
	var move := CreatureBook.MOVE_FLAGS
	var pre := CreatureBook.PREDUEL_FLAGS
	var reward := CreatureBook.REWARD_FLAGS
	assert_eq(CreatureBook.flag_names(move, CreatureBook.move_flags(5)), ["fast"] as Array[String])
	assert_eq(CreatureBook.flag_names(move, CreatureBook.move_flags(6)), ["disguise"] as Array[String])
	assert_eq(CreatureBook.flag_names(move, CreatureBook.move_flags(17)), ["hidden"] as Array[String])
	assert_eq(CreatureBook.flag_names(move, CreatureBook.move_flags(34)), ["blink"] as Array[String])
	assert_eq(CreatureBook.flag_names(move, CreatureBook.move_flags(42)),
		["terrain 0x080 (never used)", "wide range (never used)"] as Array[String], "the Centaur Warchief's dead bits")
	assert_eq(CreatureBook.flag_names(move, CreatureBook.move_flags(39)),
		["terrain 0x008 (never used)", "terrain 0x020 (never used)"] as Array[String])
	assert_eq(CreatureBook.flag_names(pre, CreatureBook.preduel_flags(1)), ["summons"] as Array[String])
	assert_eq(CreatureBook.flag_names(pre, CreatureBook.preduel_flags(2)), ["first strike"] as Array[String])
	assert_eq(CreatureBook.flag_names(pre, CreatureBook.preduel_flags(9)), ["mind control"] as Array[String])
	assert_eq(CreatureBook.flag_names(pre, CreatureBook.preduel_flags(17)), ["try this deck"] as Array[String])
	assert_eq(CreatureBook.flag_names(pre, CreatureBook.preduel_flags(20)), ["unread 0x020 (never used)"] as Array[String])
	for row in [6, 7, 19, 26, 27, 32, 41, 44, 50, 52, 53, 54, 55]:
		assert_true(CreatureBook.preduel_flags(row) & CreatureBook.PRE_CARD != 0, "%d starts with a card" % row)
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(4)), ["life carried"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(12)), ["lives"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(40)), ["teleport"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(37)), ["gold"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(18)), ["food"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(17)), ["duplicate"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(44)), ["any card"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(24)), ["artifact in play next"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(10)), ["card in play next"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, CreatureBook.reward_flags(3)), ["card"] as Array[String])
	assert_eq(CreatureBook.flag_names(reward, 0x4000), ["0x4000"] as Array[String], "a bit no name covers")


## The random reward's mask names 0x1000, which `1 << rand(12)` never
## reaches (DESIGNED, NEVER USED).
func test_the_random_reward_never_reaches_the_duplicate() -> void:
	var reachable := 0
	for bit in 12:
		reachable |= (1 << bit) & CreatureBook.REWARD_RANDOM
	assert_eq(reachable, 0x0A19, "life carried, gold, first move, food, lives")
	assert_eq(CreatureBook.REWARD_RANDOM & ~reachable, CreatureBook.REWARD_DUPLICATE)


func test_spoils_only_from_kinds_one_to_ten() -> void:
	for row in CreatureBook.size():
		var k := CreatureBook.kind(row)
		assert_eq(CreatureBook.gives_spoils(row), k >= 1 and k <= 10, "row %d" % row)


# ---------------------------------------------------------- the numbers --

## b1 §1 "str→bribe": strength = base + tier / 2, 0 for kinds 11 and up.
func test_strength_and_bribe_as_1997() -> void:
	var expected := {1: 4, 2: 4, 3: 7, 4: 8, 5: 10, 8: 4, 9: 6, 10: 6, 11: 8, 12: 10, 15: 4, 16: 4,
		17: 7, 18: 8, 19: 10, 22: 4, 23: 4, 24: 7, 25: 8, 26: 10, 29: 4, 30: 6, 31: 5, 32: 8, 33: 10,
		36: 7, 37: 7, 38: 9, 39: 10, 40: 9, 41: 8, 42: 9, 43: 8, 44: 9, 45: 8, 46: 8, 47: 8, 48: 8,
		49: 8, 50: 11, 51: 11, 52: 11, 53: 11, 54: 11}
	for row in range(1, CreatureBook.size()):
		var strength: int = expected.get(row, 0)
		assert_eq(CreatureBook.strength(row), strength, "%s's strength" % CreatureBook.name_of(row))
		assert_eq(CreatureBook.bribe(row), strength * 10, "%s's bribe" % CreatureBook.name_of(row))
	assert_eq(CreatureBook.bribe(0), 0, "no bribe at a lair")
	assert_eq(CreatureBook.strength(-1), 0)
	assert_eq(CreatureBook.base_strength(3), 3)


## b3 §4 "Life A/M/S/W", and the henchmen, castle wizards and Arzakon.
func test_duel_life_as_1997() -> void:
	var lives := {1: [4, 6, 8, 10], 2: [6, 8, 10, 12], 3: [8, 10, 12, 14], 4: [12, 14, 16, 18],
		5: [16, 18, 20, 22], 31: [8, 10, 12, 14], 36: [10, 12, 14, 16], 39: [14, 16, 18, 20],
		46: [13, 15, 17, 19], 50: [18, 20, 22, 24], 13: [11, 13, 15, 17]}
	for row in lives:
		for d in 4:
			assert_eq(CreatureBook.duel_life(row, d), int(lives[row][d]),
				"%s at difficulty %d" % [CreatureBook.name_of(row), d])
	# A henchman: one more for each World Magic owned among the first ten.
	var owned: Array[String] = ["Sleight of Hand", "Dwarven Pick", "Sword of Resistance", "Ring of the Guardian"]
	assert_eq(CreatureBook.duel_life(6, 1, {"world_magics": owned}), 13 + 2,
		"Sword of Resistance and Ring of the Guardian (bits 10, 11) do not count")
	# A castle wizard: tier + 5d + 10 − wins + towns·d, never under 5d + 20.
	assert_eq(CreatureBook.duel_life(7, 0), 30)
	assert_eq(CreatureBook.duel_life(14, 2, {"wins": 3, "towns": 2}), 20 + 10 + 10 - 3 + 4)
	assert_eq(CreatureBook.duel_life(35, 3, {"wins": 40, "towns": 2}), 35, "held at 5d + 20")
	# Arzakon: 100 and 100 a step, whatever the rest.
	for d in 4:
		assert_eq(CreatureBook.duel_life(55, d), 100 * d + 100)
		assert_eq(CreatureBook.duel_life(56, d), 100 * d + 100)
	# The Spectral Arena's creature at tier 16 [ours].
	assert_eq(CreatureBook.duel_life(1, 2, {"tier": 16}), 16 + 4)


func test_kind_tier_gender_and_names() -> void:
	assert_eq([CreatureBook.kind(1), CreatureBook.tier(1)], [CreatureBook.FEMALE_WIZARD, 4])
	assert_eq(CreatureBook.kind(6), CreatureBook.HENCHMAN)
	assert_eq(CreatureBook.kind(57), -1, "no row")
	assert_eq(CreatureBook.tier(55), 100)
	assert_true(CreatureBook.feminine(1), "the Witch")
	assert_true(CreatureBook.feminine(35), "the Dragon Lord")
	assert_false(CreatureBook.feminine(3), "the Warlock")
	assert_eq(CreatureBook.row_named("Hydra"), 33)
	assert_eq(CreatureBook.row_named("Arzakon"), 55, "the first of two")
	assert_eq(CreatureBook.row_named("Nobody"), -1)


func test_castle_rows_by_colour() -> void:
	assert_eq([CreatureBook.castle_row(1), CreatureBook.castle_row(2), CreatureBook.castle_row(3),
		CreatureBook.castle_row(4), CreatureBook.castle_row(5)], [7, 21, 28, 35, 14])
	for color in range(1, 6):
		var row := CreatureBook.castle_row(color)
		assert_eq(CreatureBook.kind(row), CreatureBook.CASTLE_WIZARD)
		assert_true(CreatureBook.is_of(row, color), "%s is of colour %d" % [CreatureBook.name_of(row), color])
	assert_eq(CreatureBook.castle_row(0), 0)


# --------------------------------------------- faces, names and voices --

func test_faces_and_duel_names() -> void:
	assert_eq(CreatureBook.face_id(1), "rogue_witch")
	assert_eq(CreatureBook.face_id(4), "rogue_vampirelord")
	assert_eq(CreatureBook.face_id(47), "rogue_alt-a-kesh")
	assert_eq(CreatureBook.face_id(55), "rogue_uber_villain")
	assert_eq(CreatureBook.face_id(56), "rogue_uber_villain", "row 56 wears row 55's face")
	assert_eq(CreatureBook.face_id(0), "")
	assert_eq(CreatureBook.face_id(57), "")
	assert_eq(CreatureBook.DUEL_NAMES[3], "Vampirelord", "@DECKFACES' own spelling, kept as 1997 wrote it")
	assert_eq(CreatureBook.duel_name(4), "VampireLord",
		"[ours: 1997 slip] the duel says the creature's own @CREATURENAMES spelling, as the journal does")
	assert_eq(CreatureBook.duel_name(56), "Uber Villain")
	assert_eq(CreatureBook.duel_name(0), "")
	for i in CreatureBook.FACES.size():
		assert_eq(CreatureBook.FACES[i], CreatureBook.DUEL_NAMES[i].to_lower().replace(" ", "_"),
			"face %d is its @DECKFACES name" % (i + 1))


## THE DUEL AND THE JOURNAL NAME A CREATURE ALIKE (2026-10-28): every row's
## duel name is its book name — the creature's own `@CREATURENAMES` spelling,
## the journal's "Defeated %s" — but Arzakon's, two different names (his
## duel's is [FinalBattle]'s to give).
func test_the_duel_and_the_journal_name_every_creature_alike() -> void:
	for row in range(1, CreatureBook.ROWS.size()):
		if CreatureBook.kind(row) == CreatureBook.ARZAKON:
			continue
		assert_eq(CreatureBook.duel_name(row), CreatureBook.name_of(row), "row %d" % row)
		assert_string_contains(DuelSpoils.DEFEATED % CreatureBook.called(row), CreatureBook.duel_name(row))


## The faces are the importer's names for `Faces/NNN.pic`.
func test_faces_are_the_importers_names() -> void:
	var text := FileAccess.get_file_as_string("res://tools/import_original.py")
	var head := "ROGUE_NAMES: list[str] = ["
	var start := text.find(head)
	assert_gt(start, 0, "the importer's table")
	start += head.length()
	var block := text.substr(start, text.find("]", start) - start)
	var names: Array[String] = []
	for found in RegEx.create_from_string("\"([^\"]+)\"").search_all(block):
		names.append(found.get_string(1))
	assert_eq(names, CreatureBook.FACES)


func test_the_cries_by_kind() -> void:
	assert_eq(CreatureBook.cry_key(3), "sfx_cry_malewiz", "a male wizard")
	assert_eq(CreatureBook.cry_key(1), "sfx_cry_fewiz", "a female wizard")
	assert_eq(CreatureBook.cry_key(2), "sfx_cry_knight")
	assert_eq(CreatureBook.cry_key(46), "sfx_cry_djinn")
	assert_eq(CreatureBook.cry_key(50), "sfx_cry_dragon")
	assert_eq(CreatureBook.cry_key(12), "sfx_cry_archmage")
	assert_eq(CreatureBook.cry_key(5), "sfx_cry_flying", "[ours] the flyer's Flying.wav (1997 asked for flyer.wav)")
	assert_eq(CreatureBook.cry_key(40), "sfx_cry_flying")
	for row in [0, 6, 7, 55, 56, -1]:
		assert_eq(CreatureBook.cry_key(row), "", "no cry for row %d" % row)


## b1 §4: 49 body and 32 shadow sheets, keyed `world_creature_<stem>`.
func test_the_map_figures() -> void:
	assert_eq(CreatureBook.sprite_keys(1), {"body": "world_creature_bk_fwz", "shadow": "world_creature_sfwz"})
	assert_eq(CreatureBook.sprite_keys(39), {"body": "world_creature_m_cen2", "shadow": "world_creature_sm_cen"},
		"the centaurs' crossed shadows, as 1997")
	assert_eq(CreatureBook.sprite_keys(35), CreatureBook.sprite_keys(34), "the Dragon Lord wears the War Mage's")
	for row in [0, 7, 14, 21, 28, 55, 56, 99]:
		assert_eq(CreatureBook.sprite_keys(row), {"body": "", "shadow": ""}, "no figure for row %d" % row)
	var bodies := {}
	var shadows := {}
	for row in CreatureBook.size():
		var stems: Array = CreatureBook.SPRITES[row]
		var keys := CreatureBook.sprite_keys(row)
		if String(stems[0]) != "":
			bodies[stems[0]] = true
			shadows[stems[1]] = true
			assert_eq(keys["body"], "world_creature_" + String(stems[0]).to_lower())
			assert_eq(keys["shadow"], "world_creature_" + String(stems[1]).to_lower())
	assert_eq(CreatureBook.SPRITES.size(), CreatureBook.size())
	assert_eq(bodies.size(), 49)
	assert_eq(shadows.size(), 32)


func test_stride_and_the_disguise() -> void:
	assert_eq(CreatureBook.stride(0), 0, "a lair never moves")
	assert_eq(CreatureBook.stride(1), 1)
	assert_eq(CreatureBook.stride(5), 2, "fast")
	assert_eq(CreatureBook.stride(40), 2, "a flyer")
	assert_eq(CreatureBook.shown_row(17, 64), 17, "not disguised")
	assert_eq([CreatureBook.shown_row(6, 0), CreatureBook.shown_row(6, 32), CreatureBook.shown_row(6, 64),
		CreatureBook.shown_row(6, 96), CreatureBook.shown_row(6, 128)], [6, 5, 4, 3, 6],
		"the Necromancer as the Nether Fiend, the VampireLord, the Warlock")
	var shown := CreatureBook.shown_row(19, 64)
	assert_eq(CreatureBook.name_of(shown), "Conjurer", "the Shapeshifter disguised")
	assert_true(CreatureBook.move_flags(shown) & CreatureBook.MOVE_HIDDEN != 0, "and lurking as the Conjurer does")


# ------------------------------------------------------------ the cards --

func test_the_cards_the_table_names() -> void:
	assert_eq(CreatureBook.reward_card(3), "Dark Ritual")
	assert_eq(CreatureBook.reward_card(6), "Will-o'-the-Wisp")
	assert_eq(CreatureBook.reward_card(46), "Junún Efreet")
	assert_eq(CreatureBook.reward_card(50), "Necropolis of Azar")
	assert_eq(CreatureBook.reward_card(51), "Power Struggle")
	assert_eq(CreatureBook.reward_card(55), "Celestial Prism")
	assert_eq(CreatureBook.reward_card(1), "", "the Witch names none")
	assert_eq(CreatureBook.signature_card(3), "Dark Ritual", "the Warlock never antes it")
	assert_eq(CreatureBook.signature_card(1), "Darkpact")
	assert_eq(CreatureBook.signature_card(10), "White Knight")
	assert_eq(CreatureBook.signature_card(50), "", "no card has the dragons' deck numbers")
	assert_eq(CreatureBook.signature_card(55), "")
	for row in CreatureBook.size():
		var reward_id := int(CreatureBook.ROWS[row][CreatureBook.REWARD_CARD])
		if reward_id != 0:
			assert_ne(CreatureBook.reward_card(row), "", "row %d's reward card %d is named" % [row, reward_id])


## Every name is a card of the game (Word of Command only in pack 1), and
## each id the deck converter's table knows names the same card.
func test_the_card_names_are_the_engines() -> void:
	CardRegistry.ensure_loaded()
	for id in CreatureBook.CARDS_1997:
		var card_name := String(CreatureBook.CARDS_1997[id])
		if card_name != "Word of Command":
			assert_true(CardRegistry.has_card(card_name), "%s (%d) is a card" % [card_name, id])
	var compared := 0
	for line in FileAccess.get_file_as_string("res://cards/data/dck_ids.txt").split("\n"):
		var parts := line.split("|")
		if line.begins_with("#") or parts.size() != 2 or not parts[1].is_valid_int():
			continue
		var id := parts[1].to_int()
		if CreatureBook.CARDS_1997.has(id) and CardRegistry.has_card(String(CreatureBook.CARDS_1997[id])):
			assert_eq(CardValue.engine_name(parts[0]), String(CreatureBook.CARDS_1997[id]), "id %d" % id)
			compared += 1
	assert_gt(compared, 50, "most ids are in the converter's table")


func test_the_minions() -> void:
	CardRegistry.ensure_loaded()
	assert_eq(CreatureBook.MINIONS.keys(), [1, 2, 3, 4, 5])
	assert_eq(CreatureBook.MINIONS[1], ["Vampire Bats", "Carrion Ants", "Hypnotic Specter"])
	assert_eq(CreatureBook.MINIONS[5], ["Benalish Hero", "Mesa Pegasus", "War Elephant"])
	for color in CreatureBook.MINIONS:
		assert_eq((CreatureBook.MINIONS[color] as Array).size(), 3)
		for card_name in CreatureBook.MINIONS[color]:
			assert_true(CardRegistry.has_card(card_name), card_name)


## CreatureBook.deck is the maindeck the Ghost and the wise man show.
func test_the_deck_shown_is_the_maindeck() -> void:
	var deck := CreatureBook.deck(1)
	assert_not_null(deck)
	assert_eq(deck.cards, CreatureDeck.maindeck(1))
	assert_eq(deck.cards.size(), 59, "the Witch's 1997 maindeck")
	assert_false(deck.cards.has("Weakness"), "its .vNone section's Weakness left out")
	assert_eq(deck.deck_name, "Witch")
	assert_null(CreatureBook.deck(0), "the lair has none")


# ------------------------------------------------------------- the pick --

## b4 §1.1: the creatures of each tier and colour.
func test_who_can_spawn() -> void:
	assert_eq(_rows(5, 13), [] as Array[int], "no white tier 13")
	assert_eq(_rows(1, 13), [46] as Array[int])
	assert_eq(_rows(2, 10), [41, 43, 45] as Array[int])
	assert_eq(_rows(5, 14), [40, 42, 44] as Array[int])
	assert_eq(_rows(0, 4), [1, 8, 15, 22, 29] as Array[int])
	assert_eq(_rows(0, 100), [55, 56] as Array[int])


func _rows(color: int, wanted_tier: int) -> Array[int]:
	var out: Array[int] = []
	for row in range(1, CreatureBook.size()):
		if CreatureBook.tier(row) == wanted_tier and (color == 0 or CreatureBook.is_of(row, color)):
			out.append(row)
	return out


## The pick draws `rand(56) + 1` until a row fits, and only so many.
func test_the_pick_draws_as_1997() -> void:
	for seed_value in [1, 77, 4242, 123456789]:
		for ask in [[1, 4], [3, 10], [0, 16], [4, 14], [2, 18]]:
			var dice := MsvcRandom.new(seed_value)
			var row := CreatureBook.pick(dice, ask[0], ask[1])
			assert_eq(CreatureBook.tier(row), ask[1], "seed %d %s: the tier" % [seed_value, ask])
			assert_true(ask[0] == 0 or CreatureBook.is_of(row, ask[0]), "and the colour")
			var replay := MsvcRandom.new(seed_value)
			var drawn := 0
			while true:
				drawn = replay.below(56) + 1
				if drawn == row:
					break
			assert_eq(replay.state, dice.state, "the first fitting draw, no further")


func test_a_pick_that_cannot_be_is_the_lair_after_999_draws() -> void:
	var dice := MsvcRandom.new(99)
	assert_eq(CreatureBook.pick(dice, 5, 13), CreatureBook.LAIR, "no white djinn")
	var replay := MsvcRandom.new(99)
	for i in 999:
		replay.below(56)
	assert_eq(dice.state, replay.state, "999 draws of the dice")
	dice = MsvcRandom.new(5)
	var row := CreatureBook.pick(dice, 0, 100)
	assert_true(row == 55 or row == 56, "Arzakon")
