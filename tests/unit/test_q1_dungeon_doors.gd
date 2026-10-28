extends GutTest
## THE CASTLES' AND THE DUNGEONS' DOORS (the quick world package,
## 2026-10-27, step 3 — items D, F and E): [DungeonDoors], the world side
## of 1997's `RunCastleDungeonBoard` (dungeonEncounter.c 232–343, 697–740):
## the door ([method DungeonDoors.at]), going in (the journal, the attempt
## counted — `entered`, saved —, roaming slots 0–4 emptied), coming out (a
## dungeon moved, its clues `(c & ~1) | 6`, the next duel's gifts kept by
## the owner's ruling D-4) and the retaliation on Wizard
## (visitLocation.c 4388–4395).

var player: AdventurePlayer
var world: ShandalarWorld


func before_each() -> void:
	player = _adventure(1)
	world = player.world


func _adventure(difficulty: int) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = difficulty
	setup.seed_text = "145729"
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func _slot(index: int) -> Dictionary:
	return world.encounters[index]


func _tile_of(index: int) -> Vector2i:
	return Vector2i(int(_slot(index)["x"]), int(_slot(index)["y"]))


## Every roaming slot 0–5 and the besieger's 7 held by a lair or a creature.
func _fill_slots() -> void:
	player.monsters = [] as Array
	for slot in [0, 1, 2, 3, 4, 5]:
		player.monsters.append({"slot": slot, "kind": "lair", "x": 100 + slot * 64, "y": 100, "color": 1})
	player.monsters.append({"slot": 7, "kind": "creature", "creature": 3, "x": 400, "y": 400, "color": 2,
		"heading": 0, "frame": 0, "town": 0})


func _slots_held() -> Array[int]:
	var held: Array[int] = []
	for one in player.monsters:
		held.append(int((one as Dictionary)["slot"]))
	held.sort()
	return held


# ------------------------------------------------------------ the door --

func test_the_door_is_a_known_dungeon_with_a_card() -> void:
	var tile := _tile_of(7)
	assert_eq(DungeonDoors.at(world, tile), -1, "nothing known: no door")
	_slot(7)["clues"] = WorldClues.CREATURES
	assert_eq(DungeonDoors.at(world, tile), 7, "a clue and a card: slot 7's door")
	_slot(7)["cards"] = [] as Array[int]
	assert_eq(DungeonDoors.at(world, tile), -1, "no card left: no door")
	# The owner's ruling of 2026-10-27: a card put back in a full-bag swap
	# stays as treasure, so the dungeon's door stays too.
	_slot(7)[WorldClues.LEFT_CARDS] = ["Kird Ape"]
	assert_eq(DungeonDoors.at(world, tile), 7, "a card put back keeps the door")
	_slot(7)[WorldClues.LEFT_CARDS] = [3, ""]
	assert_eq(DungeonDoors.at(world, tile), -1, "a damaged list holds no card")
	_slot(7).erase(WorldClues.LEFT_CARDS)
	assert_eq(DungeonDoors.at(world, tile + Vector2i(40, 40)), -1, "elsewhere none")
	assert_eq(DungeonDoors.at(null, tile), -1, "no world none")


func test_a_castle_s_stray_flag_is_no_door() -> void:
	var slots := {}
	for index in world.encounters.size():
		slots[_tile_of(index)] = index
		_slot(index)["clues"] = 7
	var strays := 0
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			var tile := Vector2i(x, y)
			if world.tile_flags(x, y) & ShandalarWorld.DUNGEON != 0 and not slots.has(tile):
				strays += 1
				assert_eq(DungeonDoors.at(world, tile), -1, "the stray flag at %s" % tile)
	assert_gt(strays, 0, "control: the generator's stray flags")
	for castle in 5:
		assert_eq(DungeonDoors.at(world, _tile_of(castle)), -1, "castle %d's site is no dungeon door" % castle)
	for site in world.sites.size():
		if int(world.sites[site]["type"]) == ShandalarWorld.CASTLE:
			var castle := DungeonDoors.castle_of(world, site)
			assert_true(castle >= 0 and castle < 5, "a castle site is a castle's door")
			assert_eq(_tile_of(castle), Vector2i(int(world.sites[site]["x"]), int(world.sites[site]["y"])))
	assert_eq(DungeonDoors.castle_of(world, -1), -1)


# ------------------------------------------------------------ going in --

func test_going_into_a_dungeon() -> void:
	_fill_slots()
	var before := player.journal.size()
	var setup := DungeonDoors.enter(player, 7)
	assert_eq(player.journal.size(), before + 1, "a line written")
	var line: Dictionary = player.journal[player.journal.size() - 1]
	assert_eq(String(line["text"]), "Explored Mound of the Warrior Kings", "@LOGSTRINGS 6")
	assert_eq(String(line["event"]), "dungeon")
	assert_eq(int(line["slot"]), 7)
	assert_eq(int(_slot(7)["entered"]), 1, "the first attempt counted")
	assert_eq(int(setup["tries"]), 0, "the board reads 1997's times_entered: 0 the first time")
	assert_eq(int(setup["index"]), 7)
	assert_false(bool(setup["castle"]))
	assert_eq(int(setup["color"]), int(_slot(7)["color"]), "the slot's colour")
	assert_eq(_slots_held(), [5, 7] as Array[int], "roaming slots 0–4 emptied; 5 and the besieger stay")
	setup = DungeonDoors.enter(player, 7)
	assert_eq(int(_slot(7)["entered"]), 2)
	assert_eq(int(setup["tries"]), 1, "denser rooms the second time")
	assert_eq(DungeonDoors.entered(world, 7), 2)
	assert_eq(DungeonDoors.entered(world, 8), 0, "the others untouched")


func test_going_into_a_castle() -> void:
	var setup := DungeonDoors.enter(player, 0)
	var line: Dictionary = player.journal[player.journal.size() - 1]
	assert_eq(String(line["text"]), "Entered Castle Necris (Black Castle)", "@LOGSTRINGS 8")
	assert_eq(String(line["event"]), "castle")
	assert_true(bool(setup["castle"]))
	assert_eq(int(setup["color"]), 1, "black")
	DungeonDoors.enter(player, 2)
	DungeonDoors.enter(player, 2)
	var tries: Array[int] = []
	for castle in 5:
		tries.append(DungeonDoors.entered(world, castle))
	assert_eq(tries, [1, 0, 2, 0, 0] as Array[int], "each castle counts its own attempts")
	assert_true(DungeonDoors.enter(player, 15).is_empty(), "no such slot")
	assert_true(DungeonDoors.enter(player, -1).is_empty())


func test_the_attempts_are_saved_and_an_old_save_reads_none() -> void:
	DungeonDoors.enter(player, 2)
	DungeonDoors.enter(player, 2)
	DungeonDoors.enter(player, 2)
	DungeonDoors.enter(player, 9)
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var back := AdventurePlayer.from_dict(data)
	assert_not_null(back, "control: the save reads")
	assert_eq(DungeonDoors.entered(back.world, 2), 3, "three attempts kept")
	assert_true(back.world.encounters[2]["entered"] is int, "a whole number")
	assert_eq(DungeonDoors.entered(back.world, 9), 1)
	assert_false(back.world.encounters[4].has("entered"), "never entered: nothing written")
	for slot in data["world"]["encounters"]:
		(slot as Dictionary).erase("entered")
	data["world"]["encounters"][3]["entered"] = -5
	var old := AdventurePlayer.from_dict(data)
	assert_eq(DungeonDoors.entered(old.world, 2), 0, "a save from before the count reads 0")
	assert_eq(int(old.world.encounters[3]["entered"]), 0, "a count below 0 read as 0")


# ----------------------------------------------------------- coming out --

func test_coming_out_of_a_dungeon_moves_it() -> void:
	_slot(7)["clues"] = WorldClues.LOCATION
	var old := _tile_of(7)
	DungeonDoors.enter(player, 7)
	var dice := player.dice
	var news := DungeonDoors.leave(player, 7, {})
	assert_true(news.is_empty(), "a dungeon brings no news")
	var now := _tile_of(7)
	assert_ne(now, old, "moved")
	assert_ne(player.dice, dice, "on the adventure's dice")
	assert_eq(world.tile_flags(old.x, old.y) & ShandalarWorld.DUNGEON, 0, "the old tile lost its flag")
	assert_ne(world.tile_flags(now.x, now.y) & ShandalarWorld.DUNGEON, 0, "the new one has it")
	assert_true(world.is_land(now.x, now.y), "on land")
	assert_eq(world.tile_flags(now.x, now.y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD), 0, "no site, no road")
	assert_ne(now, player.tile(), "not under the hero")
	for other in range(5, 15):
		if other != 7:
			assert_ne(_tile_of(other), now, "no other dungeon there (1997 slip D-s1)")
	assert_eq(int(_slot(7)["clues"]), 6, "where forgotten, creatures and rules known")
	assert_eq(int(_slot(7)["entered"]), 1, "it keeps its attempts")
	var drawn := WorldClues.on_world(world)
	assert_eq(drawn.size(), 1, "a moved dungeon is still drawn (1997)")
	assert_eq(Vector2i(int(drawn[0]["x"]), int(drawn[0]["y"])), now, "at its new tile")
	assert_eq(DungeonDoors.at(world, now), 7, "and entered there")
	assert_eq(DungeonDoors.at(world, old), -1, "not where it was")


func test_the_clues_after_a_dungeon() -> void:
	for case in [[1, 6], [2, 6], [4, 6], [7, 6], [3, 6], [5, 6]]:
		_slot(8)["clues"] = case[0]
		DungeonDoors.leave(player, 8, {})
		assert_eq(int(_slot(8)["clues"]), case[1], "clues %d → %d" % case)


func test_the_same_dice_move_it_to_the_same_tile() -> void:
	var twin := _adventure(1)
	player.dice = 777
	twin.dice = 777
	DungeonDoors.leave(player, 11, {})
	DungeonDoors.leave(twin, 11, {})
	assert_eq(_tile_of(11), Vector2i(int(twin.world.encounters[11]["x"]), int(twin.world.encounters[11]["y"])),
		"the move is the adventure's, played again the same")


func test_the_next_duel_s_gifts_are_kept() -> void:
	player.next_duel_life = 3
	player.next_duel_life_carried = -2
	player.next_duel_card = "Lord of Atlantis"
	player.next_duel_first_move = true
	DungeonDoors.enter(player, 7)
	DungeonDoors.leave(player, 7, {})
	DungeonDoors.enter(player, 1)
	DungeonDoors.leave(player, 1, {"beaten": false, "booted": true})
	assert_eq(player.next_duel_life, 3, "the gift's lives kept (1997 wiped them: slip, ruling D-4)")
	assert_eq(player.next_duel_life_carried, -2, "the carried lives kept")
	assert_eq(player.next_duel_card, "Lord of Atlantis", "the card kept")
	assert_true(player.next_duel_first_move, "the first move kept")


func test_a_castle_does_not_move() -> void:
	var castle := _tile_of(3)
	DungeonDoors.leave(player, 3, {})
	assert_eq(_tile_of(3), castle, "a castle stays")


# ------------------------------------------------------- the retaliation --

func test_a_castle_left_unbeaten_on_wizard_is_retaliated_for() -> void:
	player = _adventure(3)
	world = player.world
	var news := DungeonDoors.leave(player, 3, {"beaten": false})
	assert_eq(news.size(), 1, "one news flash")
	assert_eq(String(news[0]["kind"]), "siege")
	assert_string_starts_with(String(news[0]["lines"][0]),
		"In retaliation for your effrontery the Great Red Wizardess sends", "@NEWSFLASH 2/3")
	assert_true(player.siege_active, "a siege under way")
	var besieger := WorldLairs.held_in(player, Sieges.SLOT)
	assert_eq(int(besieger.get("color", 0)), 4, "the red wizard's creature in slot 7")
	assert_eq(int(news[0]["wizard"]), 4)


func test_no_retaliation_below_wizard_or_when_beaten() -> void:
	var news := DungeonDoors.leave(player, 3, {"beaten": false})
	assert_true(news.is_empty(), "Magician: none")
	assert_false(player.siege_active)
	player = _adventure(2)
	assert_true(DungeonDoors.leave(player, 3, {}).is_empty(), "Sorcerer: none")
	player = _adventure(3)
	assert_true(DungeonDoors.leave(player, 3, {"beaten": true}).is_empty(), "the castle won: none")
	player.defeated_wizards.append("red")
	assert_true(DungeonDoors.leave(player, 3, {}).is_empty(), "a beaten wizard sends none")
	assert_false(player.siege_active)


func test_no_retaliation_while_a_siege_is_under_way() -> void:
	player = _adventure(3)
	player.siege_active = true
	var dice := player.dice
	assert_true(DungeonDoors.leave(player, 3, {}).is_empty(), "a siege under way: none")
	assert_eq(player.dice, dice, "no die drawn")


func test_a_dungeon_is_never_retaliated_for() -> void:
	player = _adventure(3)
	assert_true(DungeonDoors.leave(player, 9, {}).is_empty())
	assert_false(player.siege_active)


func test_a_card_put_back_is_saved_and_a_damaged_list_reads_clean() -> void:
	_slot(9)[WorldClues.LEFT_CARDS] = ["Kird Ape"]
	_slot(10)[WorldClues.LEFT_CARDS] = ["Shivan Dragon", 4, "", {"x": 1}]
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var back := AdventurePlayer.from_dict(data)
	assert_not_null(back, "control: the save reads")
	assert_eq(back.world.encounters[9][WorldClues.LEFT_CARDS], ["Kird Ape"] as Array[String], "kept by name")
	assert_eq(back.world.encounters[10][WorldClues.LEFT_CARDS], ["Shivan Dragon"] as Array[String],
		"the junk dropped on load")
	assert_false(back.world.encounters[11].has(WorldClues.LEFT_CARDS), "none put back: nothing written")
