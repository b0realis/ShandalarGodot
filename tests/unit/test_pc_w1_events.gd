extends GutTest
## THE BOARD'S EVENTS AND ITS END (part C, stage C1, W1): the dice
## (dungeonEncounter.c 506–537; the owner's k2 and D9), the scroll's riddle
## (538–553), the rooms' and the wizard's outcomes (554–579, 634–661; the
## owner's g3), the treasure (580–633; D12's swap), the life pool and the
## next duel (896–906; a1, d2), leaving (697–715; D-4), and a dungeon that
## lasts while any of its cards remains (the owner's c2).

var player: AdventurePlayer
var world: ShandalarWorld
const DICE_CELL := Vector2i(8, 11)


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	world = player.world


## A hand-made board in slot [param slot]: the door, the start, and to the
## east event [param event]; the slot's colour and rules.
func _board(event: int, slot := 7) -> DungeonBoard:
	var board := DungeonBoard.new()
	board.cells.resize(DungeonBoard.CELLS)
	board.cells.fill(0)
	board.depth.resize(DungeonBoard.CELLS)
	board.depth.fill(0)
	for at in [DungeonBoard.ENTRANCE, DungeonBoard.START]:
		board.cells[at.x * DungeonBoard.HEIGHT + at.y] = DungeonBoard.OPEN
	board.index = slot
	board.castle = slot < 5
	board.color = int(world.encounters[slot]["color"])
	board.rules = int(world.encounters[slot]["rules"])
	board.difficulty = player.difficulty
	board.monsters = [1, 2, 3, 4, 5] as Array[int]
	board.dice = MsvcRandom.new(1)
	_arm(board, event)
	return board


## Event [param event] east of the start again, the hero on the start.
func _arm(board: DungeonBoard, event: int) -> void:
	board.cells[DICE_CELL.x * DungeonBoard.HEIGHT + DICE_CELL.y] = DungeonBoard.OPEN | (event << DungeonBoard.EVENT_SHIFT)
	board.hero = DungeonBoard.START
	board.pending = DungeonBoard.NOWHERE
	board.reveal(board.hero)
	var went := board.step(DungeonBoard.UP_RIGHT)
	assert_eq(went.get("kind"), "event", "the event waits")


## A dice state whose coin comes up odd (lives) or even (a card).
func _coin(odd: bool) -> MsvcRandom:
	for start in 1000:
		if (MsvcRandom.new(start).rand() & 1 == 1) == odd:
			return MsvcRandom.new(start)
	return null


func _deck(names: Array, deck := 0) -> void:
	player.cards = []
	for card_name in names:
		player.cards.append({"card": card_name, "decks": [deck]})
	player.current_deck = 0


# --------------------------------------------------------------- the dice --

func test_the_dice_give_lives() -> void:
	_deck(["Grizzly Bears", "Forest"])
	var board := _board(DungeonBoard.DICE)
	board.dice = _coin(true)
	board.dice_card = "Sol Ring"
	var got := board.roll_dice(player)
	var lives := int(got["lives"])
	assert_between(lives, 1, 3, "1–3 lives")
	assert_eq(board.life_pool, lives, "into the pool")
	assert_eq(board.dice_card, "", "one slot: the lives replace the dice's card")
	assert_eq(got["words"], "You get +%d (%d) Lives\nin the next duel!" % [lives, board.next_duel_life(player)])
	assert_eq(board.next_duel_life(player), player.mana_links() + lives, "links + the pool")
	assert_eq(board.hero, DICE_CELL, "the hero moves in")
	assert_eq(board.value(DICE_CELL), DungeonBoard.PASSED, "the dice gone")
	assert_eq(board.pending, DungeonBoard.NOWHERE)
	assert_eq(board.next_duel_line(player), "+%d (%d) Lives" % [lives, board.next_duel_life(player)])


func test_the_dice_give_a_creature_or_artifact_of_the_deck_by_its_copies() -> void:
	_deck(["Grizzly Bears", "Grizzly Bears", "Grizzly Bears", "Sol Ring", "Lightning Bolt", "Forest"])
	player.cards.append({"card": "Juggernaut", "decks": [1]})
	var board := _board(DungeonBoard.DICE)
	board.dice = MsvcRandom.new(424242)
	var given := {}
	for n in 1200:
		_arm(board, DungeonBoard.DICE)
		var got := board.roll_dice(player)
		if String(got["card"]) != "":
			given[got["card"]] = int(given.get(got["card"], 0)) + 1
			assert_eq(board.dice_card, got["card"], "the dice's card waits")
			assert_eq(got["words"], "You get %s\nin the next duel!" % got["card"])
	assert_eq(given.keys().size(), 2, "only the creature and the artifact: %s" % given)
	var ratio := float(given.get("Grizzly Bears", 0)) / maxf(1.0, float(given.get("Sol Ring", 0)))
	assert_between(ratio, 2.2, 4.0, "three copies to one: %s" % given)
	assert_false(given.has("Juggernaut"), "never a card of another deck")


func test_the_dice_never_give_a_card_the_rules_bar() -> void:
	_deck(["Grizzly Bears", "Sol Ring", "Juggernaut", "Stangg", "Llanowar Elves"])
	var board := _board(DungeonBoard.DICE)
	board.color = 3
	board.rules = DungeonBoard.CARRIES | DungeonBoard.NO_COLOR
	var allowed := []
	for at in board.dice_cards(player):
		allowed.append(player.cards[at]["card"])
	assert_eq(allowed, ["Sol Ring", "Juggernaut"], "No Green cards: the green ones barred, the gold Stangg too")
	board.rules = DungeonBoard.CARRIES | DungeonBoard.NO_ARTIFACTS
	allowed = []
	for at in board.dice_cards(player):
		allowed.append(player.cards[at]["card"])
	assert_eq(allowed, ["Grizzly Bears", "Stangg", "Llanowar Elves"], "No artifacts: the artifact creature too")
	board.rules = DungeonBoard.CARRIES
	assert_eq(board.dice_cards(player).size(), 5, "control: no rule, all five")


func test_bars() -> void:
	assert_true(DungeonBoard.bars(DungeonBoard.NO_COLOR, 1, "Dakkon Blackblade"), "a gold card with black")
	assert_false(DungeonBoard.bars(DungeonBoard.NO_COLOR, 1, "Black Lotus"), "colourless Black Lotus allowed")
	assert_true(DungeonBoard.bars(DungeonBoard.NO_COLOR, 1, "Swamp"), "a Swamp is black, as 1997's table")
	assert_false(DungeonBoard.bars(DungeonBoard.NO_COLOR, 1, "Forest"))
	assert_true(DungeonBoard.bars(DungeonBoard.NO_ARTIFACTS, 1, "Juggernaut"), "an artifact creature")
	assert_true(DungeonBoard.bars(DungeonBoard.NO_INSTANTS, 1, "Lightning Bolt"))
	assert_false(DungeonBoard.bars(DungeonBoard.NO_INSTANTS, 1, "Grizzly Bears"))
	assert_false(DungeonBoard.bars(DungeonBoard.CARRIES | DungeonBoard.FRESH, 1, "Dakkon Blackblade"), "no ban")
	assert_false(DungeonBoard.bars(DungeonBoard.NO_COLOR, 1, "No Such Card"))


func test_with_no_creature_or_artifact_allowed_the_dice_give_lives() -> void:
	_deck(["Lightning Bolt", "Forest", "Giant Growth"])
	var board := _board(DungeonBoard.DICE)
	board.dice = _coin(false)
	var got := board.roll_dice(player)
	assert_between(int(got["lives"]), 1, 3, "the lives instead of drawing forever (D9)")
	assert_eq(got["card"], "")
	_deck(["Grizzly Bears"])
	board.color = 3
	board.rules = DungeonBoard.CARRIES | DungeonBoard.NO_COLOR
	_arm(board, DungeonBoard.DICE)
	board.dice = _coin(false)
	got = board.roll_dice(player)
	assert_between(int(got["lives"]), 1, 3, "none allowed (k2): the lives too")


func test_a_later_dice_replaces_the_dice_s_card() -> void:
	_deck(["Grizzly Bears", "Sol Ring"])
	var board := _board(DungeonBoard.DICE)
	board.dice = _coin(false)
	var first := String(board.roll_dice(player)["card"])
	assert_ne(first, "")
	_arm(board, DungeonBoard.DICE)
	board.dice = _coin(true)
	board.roll_dice(player)
	assert_eq(board.dice_card, "", "the card gone, as 1997's one slot")
	assert_gt(board.life_pool, 0, "the lives won stay in the pool")


func test_no_dice_no_roll() -> void:
	var board := _board(DungeonBoard.TREASURE)
	assert_eq(board.roll_dice(player), {}, "a treasure waits, not a dice")


# ------------------------------------------------------------ the scroll --

## An answer the riddle takes ([param right]) or refuses.
func _answer(asked: Dictionary, right: bool) -> int:
	for answer in (asked["answers"] as Array).size():
		if CardRiddle.correct(asked, answer) == right:
			return answer
	return -1


func test_the_scroll_answered_right() -> void:
	var board := _board(DungeonBoard.SCROLL)
	var asked := board.riddle(player)
	assert_false(asked.is_empty(), "a riddle")
	assert_eq(board.riddle(player), asked, "asked once")
	var said := board.riddle_answered(player, _answer(asked, true))
	assert_true(said["right"])
	assert_eq(said["words"], CardRiddle.CORRECT)
	assert_eq(said["card"], asked["card"])
	assert_eq(board.hero, DICE_CELL, "passed: the hero moves in")
	assert_eq(board.value(DICE_CELL), DungeonBoard.PASSED)
	assert_eq(board.riddle_answered(player, 0), {}, "answered once")


func test_the_scroll_answered_wrong_summons_the_strongest_room() -> void:
	var board := _board(DungeonBoard.SCROLL)
	var asked := board.riddle(player)
	var said := board.riddle_answered(player, _answer(asked, false))
	assert_false(said["right"])
	assert_true(said["summoned"])
	assert_eq(said["words"], CardRiddle.verdict(asked, _answer(asked, false)))
	assert_eq(board.hero, DungeonBoard.START, "the hero stays")
	assert_eq(board.value(DICE_CELL) & ~DungeonBoard.SEEN, DungeonBoard.SUMMONED, "0x61: a room of slot 3")
	assert_eq(board.event_at(DICE_CELL), 6)
	assert_true(board.seen(DICE_CELL), "seen at once from where the hero stands")
	assert_eq(said["creature"], board.monsters[3], "slot 3's creature")
	assert_eq(board.pending, DungeonBoard.NOWHERE)
	assert_eq(board.step(DungeonBoard.UP_RIGHT)["event"], 6, "now a room to fight")


# ------------------------------------------------------------- the rooms --

func test_a_room_won_is_passed() -> void:
	var board := _board(4)
	board.dice_card = "Sol Ring"
	board.dice_lives = 2
	var done := board.room_done(player, DungeonBoard.CLEARED)
	assert_eq(done, {"passed": true, "out": false, "booted": false, "beaten": false})
	assert_eq(board.hero, DICE_CELL)
	assert_eq(board.value(DICE_CELL), DungeonBoard.PASSED)
	assert_eq(board.code, 0, "between rooms")
	assert_eq(board.dice_card, "", "a duel spends the dice's card")
	assert_eq(board.dice_lives, 0)


func test_a_room_drawn_is_no_result() -> void:
	var board := _board(5)
	var done := board.room_done(player, DungeonBoard.AGAIN)
	assert_false(done["passed"])
	assert_false(done["out"])
	assert_eq(board.hero, DungeonBoard.START, "pushed back")
	assert_eq(board.event_at(DICE_CELL), 5, "the creature stays")
	assert_eq(board.step(DungeonBoard.UP_RIGHT)["kind"], "event", "and can be fought again")


func test_a_dungeon_room_lost_throws_the_hero_out() -> void:
	var board := _board(3)
	var done := board.room_done(player, DungeonBoard.THROWN_OUT)
	assert_true(done["out"])
	assert_false(done["booted"], "no booting from a dungeon")
	assert_true(board.over)
	assert_eq(board.value(DICE_CELL), 0, "the room turned solid, as 1997 (never seen)")
	var left := board.close(player)
	assert_eq(left["words"], [] as Array[String], "no words from a dungeon")
	assert_false(left["booted"])


func test_a_castle_room_lost_boots_the_hero() -> void:
	var board := _board(6, 0)
	var done := board.room_done(player, DungeonBoard.LOST)
	assert_true(done["out"], "rule 0x01 ends the visit")
	assert_true(done["booted"])
	var left := board.close(player)
	assert_eq(left["words"], ["You are unceremoniously booted from\nthe stronghold of the Mighty Black Wizard!"]
		as Array[String], "@DUNGEON 12")
	assert_true(left["booted"])
	assert_false(left["beaten"])


func test_a_room_lost_without_rule_one_stays() -> void:
	var board := _board(3)
	board.rules = 0
	var done := board.room_done(player, DungeonBoard.LOST)
	assert_false(done["out"], "no rule 0x01: the board goes on (never in 1997's worlds)")
	assert_eq(board.hero, DungeonBoard.START)
	assert_false(board.is_open(DICE_CELL), "the room a wall")


func test_the_castle_wizard() -> void:
	var board := _board(DungeonBoard.WIZARD, 4)
	assert_eq(board.code, DungeonBoard.WIZARD)
	assert_eq(board.room_creature(board.code), board.monsters[4], "slot 4")
	var done := board.room_done(player, DungeonBoard.AGAIN)
	assert_false(done["out"], "a draw: pushed back")
	assert_eq(board.event_at(DICE_CELL), DungeonBoard.WIZARD, "the wizard waits again")
	board.step(DungeonBoard.UP_RIGHT)
	done = board.room_done(player, DungeonBoard.LEFT)
	assert_true(done["out"], "lost: out")
	var left := board.close(player)
	assert_eq(left["words"], [] as Array[String], "no booted words after the wizard")
	assert_false(left["beaten"])
	board = _board(DungeonBoard.WIZARD, 4)
	done = board.room_done(player, DungeonBoard.BEATEN)
	assert_true(done["beaten"])
	assert_true(board.close(player)["beaten"], "the castle won, for the doors and CastleWin")


func test_a_game_over_in_a_room() -> void:
	var board := _board(3)
	board.room_done(player, DungeonBoard.GAME_OVER)
	assert_true(board.close(player)["game_over"], "the world shows the end")


func test_a_room_outcome_needs_a_room() -> void:
	var board := _board(DungeonBoard.DICE)
	assert_eq(board.room_done(player, DungeonBoard.CLEARED), {}, "a dice waits")
	board = _board(3)
	assert_eq(board.room_done(player, "won"), {}, "an unknown outcome")


# ------------------------------------------------------------ the treasure --

func test_a_treasure_card_found() -> void:
	world.encounters[7]["cards"] = [11, 0, 5] as Array[int]
	var bag := player.cards.size()
	var board := _board(DungeonBoard.TREASURE)
	var lines := player.journal.size()
	var got := board.open_treasure(player)
	var card_name := String(got["card"])
	assert_has(["Black Lotus", "Copy Artifact", "Berserk"], card_name)
	assert_eq(got["words"], "Found This Card")
	assert_false(got["bag_full"])
	assert_eq(player.cards.size(), bag + 1, "into the bag")
	assert_eq(player.cards[bag], {"card": card_name, "decks": []}, "in no deck")
	assert_eq((world.encounters[7]["cards"] as Array).size(), 2, "out of the dungeon")
	assert_eq(String(player.journal[lines]["event"]), "treasure", "the journal's treasure line")
	assert_eq(String(player.journal[lines]["card"]), card_name)
	# "Acquired spell" for a rare or special card (AdventurePlayer.add_card):
	# with the 1997 program's card table every dungeon treasure is special;
	# without it the card's printed rarity decides (Berserk is uncommon).
	if AdventurePlayer._rarity(card_name) >= 3:
		assert_eq(player.journal.size(), lines + 2, "the treasure line and the rare card's")
		assert_eq(String(player.journal[lines + 1]["text"]), "Acquired spell: %s" % card_name, "a rare card")
	else:
		assert_eq(player.journal.size(), lines + 1, "the treasure line alone")
	assert_eq(board.hero, DICE_CELL, "the hero moves in")


func test_the_cards_come_up_alike() -> void:
	var seen_cards := {}
	var board := _board(DungeonBoard.TREASURE)
	board.dice = MsvcRandom.new(606)
	for n in 300:
		world.encounters[7]["cards"] = [11, 0, 5] as Array[int]
		player.cards = []
		_arm(board, DungeonBoard.TREASURE)
		var card_name := String(board.open_treasure(player)["card"])
		seen_cards[card_name] = int(seen_cards.get(card_name, 0)) + 1
	assert_eq(seen_cards.size(), 3)
	for card_name in seen_cards:
		assert_between(int(seen_cards[card_name]), 70, 130, "a third each: %s" % seen_cards)


func test_a_full_bag_offers_the_swap() -> void:
	world.encounters[7]["cards"] = [11] as Array[int]
	player.cards = []
	for n in AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Forest" if n > 0 else "Grizzly Bears", "decks": [0]})
	var board := _board(DungeonBoard.TREASURE)
	var got := board.open_treasure(player)
	assert_eq(got, {"card": "Black Lotus", "words": "Found This Card", "bag_full": true})
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST, "nothing taken yet")
	assert_eq(board.pending, DICE_CELL, "the find waits for the choice")
	assert_eq(board.open_treasure(player), {}, "opened once")
	var swapped := board.treasure_swap(player, 0)
	assert_eq(swapped, {"card": "Black Lotus", "left": "Grizzly Bears"})
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST)
	assert_false(player.cards.any(func(c: Dictionary) -> bool: return c["card"] == "Grizzly Bears"), "left behind")
	assert_eq(player.cards[player.cards.size() - 1]["card"], "Black Lotus")
	assert_eq((world.encounters[7]["cards"] as Array).size(), 0, "out of the dungeon")
	assert_eq(WorldClues.left_cards(world.encounters[7]), ["Grizzly Bears"] as Array[String],
		"the card put back stays in the dungeon as its treasure")
	assert_eq(board.hero, DICE_CELL)
	assert_eq(board.treasure_swap(player, 0), {}, "once")


## A full bag: the swap leaves Grizzly Bears behind for the dungeon's last
## card, Black Lotus.
func _swapped_away() -> DungeonBoard:
	world.encounters[7]["cards"] = [11] as Array[int]
	world.encounters[7]["clues"] = WorldClues.CREATURES
	player.cards = []
	for n in AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Forest" if n > 0 else "Grizzly Bears", "decks": [0]})
	var board := _board(DungeonBoard.TREASURE)
	board.open_treasure(player)
	board.treasure_swap(player, 0)
	return board


func test_the_card_put_back_keeps_the_dungeon_and_its_clue() -> void:
	_swapped_away()
	var slot: Dictionary = world.encounters[7]
	assert_eq((slot["cards"] as Array).size(), 0, "the dungeon's own cards all taken")
	assert_true(WorldClues.holds_cards(slot), "it holds the card put back")
	assert_has(WorldClues.known(world), 7, "so it lasts (c2), the card counted")
	assert_true(WorldClues.on_world(world).any(func(d: Dictionary) -> bool: return int(d["index"]) == 7),
		"still drawn on the world")
	assert_eq(WorldClues.treasures(world, 7), ["Grizzly Bears"] as Array[String], "its treasure, truthfully")
	assert_has(WorldClues.lines(world, 7), "Treasure: Grizzly Bears", "the clue lists it")


func test_the_card_put_back_waits_for_a_later_visit() -> void:
	var board := _swapped_away()
	_arm(board, DungeonBoard.TREASURE)
	var again := board.open_treasure(player)
	assert_true(again.has("gold"), "not found again on the visit it was left on: gold")
	# A later visit: the bag has room again.
	player.cards.remove_at(0)
	var later := _board(DungeonBoard.TREASURE)
	var found := later.open_treasure(player)
	assert_eq(found, {"card": "Grizzly Bears", "words": "Found This Card", "bag_full": false}, "found again")
	assert_eq(player.cards[player.cards.size() - 1], {"card": "Grizzly Bears", "decks": []}, "back in the bag")
	assert_eq(WorldClues.left_cards(world.encounters[7]), [] as Array[String], "out of the dungeon")
	assert_does_not_have(WorldClues.known(world), 7, "no card left: the dungeon gone")
	var line: Dictionary = player.journal[player.journal.size() - 1]
	assert_eq([line["event"], line["card"]], ["treasure", "Grizzly Bears"], "the journal's treasure line")


func test_the_card_put_back_found_with_a_full_bag_again() -> void:
	_swapped_away()
	var later := _board(DungeonBoard.TREASURE)
	assert_eq(later.open_treasure(player)["bag_full"], true, "the bag still full")
	assert_eq(later.treasure_declined(player), {"card": "Grizzly Bears"}, "declined, as built")
	assert_eq(WorldClues.left_cards(world.encounters[7]), ["Grizzly Bears"] as Array[String], "still in the dungeon")
	later = _board(DungeonBoard.TREASURE)
	later.open_treasure(player)
	var lotus := player.cards.size() - 1
	assert_eq(later.treasure_swap(player, lotus), {"card": "Grizzly Bears", "left": "Black Lotus"},
		"swapped back: the Lotus put back in its place")
	assert_eq(WorldClues.left_cards(world.encounters[7]), ["Black Lotus"] as Array[String])


func test_the_card_put_back_is_saved() -> void:
	_swapped_away()
	var text := JSON.stringify(player.to_dict())
	var again := AdventurePlayer.from_dict(JSON.parse_string(text))
	assert_not_null(again)
	assert_eq(WorldClues.left_cards(again.world.encounters[7]), ["Grizzly Bears"] as Array[String],
		"a save and a load keep it")
	assert_has(WorldClues.known(again.world), 7)


func test_a_damaged_left_list_is_none() -> void:
	var slot := {"cards": [], WorldClues.LEFT_CARDS: "Grizzly Bears"}
	assert_eq(WorldClues.left_cards(slot), [] as Array[String], "not a list")
	assert_false(WorldClues.holds_cards(slot))
	slot[WorldClues.LEFT_CARDS] = [3, "", "Sol Ring", null]
	assert_eq(WorldClues.left_cards(slot), ["Sol Ring"] as Array[String], "names only")


func test_a_full_bag_declined_leaves_the_card_in_the_dungeon() -> void:
	world.encounters[7]["cards"] = [11] as Array[int]
	player.cards = []
	for n in AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Forest", "decks": []})
	var board := _board(DungeonBoard.TREASURE)
	board.open_treasure(player)
	assert_eq(board.treasure_swap(player, AdventurePlayer.BAG_MOST), {}, "no such card of the hero's")
	assert_eq(board.treasure_declined(player), {"card": "Black Lotus"})
	assert_eq(world.encounters[7]["cards"], [11], "still in the dungeon")
	assert_eq(board.value(DICE_CELL), DungeonBoard.PASSED, "the dead end passed")
	assert_eq(board.hero, DICE_CELL)
	assert_eq(board.treasure_declined(player), {}, "once")


func test_gold_and_jewels() -> void:
	world.encounters[7]["cards"] = [] as Array[int]
	for level in 4:
		var board := _board(DungeonBoard.TREASURE)
		board.difficulty = level
		board.dice = MsvcRandom.new(1000 + level)
		var least := 99999
		var most := 0
		var jewelled := 0
		var plain := 0
		for n in 200:
			_arm(board, DungeonBoard.TREASURE)
			var gold_before := player.gold
			var amulets_before := player.amulet_count()
			var got := board.open_treasure(player)
			var gold := int(got["gold"])
			assert_eq(gold % 10, 0, "a multiple of 10")
			assert_eq(player.gold, gold_before + gold, "into the purse")
			least = mini(least, gold)
			most = maxi(most, gold)
			var jewels: Dictionary = got["jewels"]
			var count := 0
			for hue in jewels:
				assert_eq(int(jewels[hue]), 1, "0 or 1 a colour")
				count += 1
			assert_eq(player.amulet_count(), amulets_before + count, "into the bag")
			if count == 0:
				plain += 1
				assert_eq(got["words"], "Found %d Gold" % gold)
			else:
				jewelled += 1
				assert_string_starts_with(String(got["words"]), "Found %d Gold\nand a bag with Jewels:\n" % gold)
		var ceiling := (99 * (level + 2) + 100) / 10 * 10
		assert_gte(least, 100, "level %d: from 100" % level)
		assert_lte(most, ceiling, "level %d: to %d" % [level, ceiling])
		assert_gt(most, ceiling - 60, "level %d: control, near the top" % level)
		assert_gt(jewelled, 0)
		assert_gt(plain, 0, "1 in 32 without a jewel")
	var line: Dictionary = player.journal[player.journal.size() - 1]
	assert_eq(line["event"], "treasure")
	assert_eq(line["text"], "", "no words, as 1997's type 19")
	assert_true(line.has("gold"))


func test_a_castle_s_treasure_is_gold() -> void:
	var board := _board(DungeonBoard.TREASURE, 1)
	var got := board.open_treasure(player)
	assert_true(got.has("gold"), "castles hold no cards")


func test_a_dungeon_lasts_while_any_card_remains() -> void:
	world.encounters[7]["cards"] = [11, 0] as Array[int]
	world.encounters[7]["clues"] = WorldClues.CREATURES
	var board := _board(DungeonBoard.TREASURE)
	board.open_treasure(player)
	assert_has(WorldClues.known(world), 7, "one card left: still known")
	assert_eq(DungeonDoors.at(world, Vector2i(int(world.encounters[7]["x"]), int(world.encounters[7]["y"]))), 7,
		"and entered")
	_arm(board, DungeonBoard.TREASURE)
	board.open_treasure(player)
	assert_does_not_have(WorldClues.known(world), 7, "the last card taken: gone")


# ---------------------------------------------------- the life pool --

func test_the_pool_carries_from_room_to_room() -> void:
	var board := _board(3)
	board.dice = _coin(true)
	_arm(board, DungeonBoard.DICE)
	var lives := int(board.roll_dice(player)["lives"])
	assert_eq(board.life_pool, lives, "the dice's lives in the pool")
	board.cells[9 * DungeonBoard.HEIGHT + 11] = DungeonBoard.OPEN | (3 << DungeonBoard.EVENT_SHIFT)
	assert_eq(board.step(DungeonBoard.UP_RIGHT)["kind"], "event")
	# The duels write the pool in the run record (DungeonDuels.settle).
	board.run["life_pool"] = lives - 6
	board.room_done(player, DungeonBoard.CLEARED)
	assert_eq(board.life_pool, lives - 6, "kept for the next room")
	assert_eq(board.next_duel_life(player), player.mana_links() + lives - 6)


func test_the_next_duel_s_life_and_line() -> void:
	var board := _board(3)
	player.next_duel_life = 2
	player.next_duel_life_carried = -1
	board.life_pool = 3
	var links := player.mana_links()
	assert_eq(board.next_duel_life(player), links + 2 - 1 + 3, "links + carried + the world's gift + the pool")
	assert_eq(DungeonBoard.life_in_next_duel(player, board.run), board.next_duel_life(player))
	assert_eq(board.next_duel_line(player), "+2 (%d) Lives" % board.next_duel_life(player), "the world's gift")
	player.next_duel_card = "Llanowar Elves"
	player.next_duel_first_move = true
	board.dice_card = "Sol Ring"
	assert_eq(board.next_duel_line(player), "+2 (%d) Lives, Llanowar Elves, Sol Ring, First Move"
		% board.next_duel_life(player), "both cards: the duel puts both in play")
	board.dice_card = ""
	player.next_duel_life = 0
	assert_eq(board.next_duel_line(player), "Llanowar Elves, First Move")
	player.next_duel_card = ""
	player.next_duel_first_move = false
	assert_eq(board.next_duel_line(player), "", "nothing waits")


# ------------------------------------------------------------- leaving --

func test_leaving_spends_the_board_s_and_keeps_the_world_s_gifts() -> void:
	var board := _board(DungeonBoard.DICE)
	player.next_duel_life = 2
	player.next_duel_card = "Llanowar Elves"
	player.next_duel_first_move = true
	player.next_duel_life_carried = 3
	board.life_pool = 5
	board.dice_card = "Sol Ring"
	board.dice_lives = 2
	var left := board.close(player)
	assert_eq(left, {"index": 7, "beaten": false, "booted": false, "game_over": false, "words": [] as Array[String]})
	assert_eq(board.life_pool, 0, "the pool spent")
	assert_eq(board.dice_card, "", "the dice's card spent")
	assert_eq(board.pending, DungeonBoard.NOWHERE)
	assert_eq([player.next_duel_life, player.next_duel_card, player.next_duel_first_move,
		player.next_duel_life_carried], [2, "Llanowar Elves", true, 3], "the world's gifts kept (D-4)")
