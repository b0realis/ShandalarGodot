extends GutTest
## A LARGE DUNGEON'S CLUE SAYS "large" (part C, stage C1, W1; the owner's
## D11): [method WorldClues.lines] — 1997's detail screen said "small" for
## every dungeon (dungeonCluesScreen.c 1086–1095), though a large one
## (`monster_flags & 0x80`) draws its rooms from tiers 8–18 ([method
## DungeonBoard.creatures_for]); castles stay "large".

var world: ShandalarWorld


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	world = AdventureSetup.make_world(record)


func _creature_line(index: int) -> String:
	for line in WorldClues.lines(world, index):
		if line.begins_with("-Contains "):
			return line
	return ""


func test_a_large_dungeon_says_large() -> void:
	var slot: Dictionary = world.encounters[7]
	slot["clues"] = WorldClues.CREATURES
	var hue := WorldClues.COLOR_WORDS[int(slot["color"])]
	slot["monster_flags"] = 0x82
	assert_eq(_creature_line(7), "-Contains large %s creatures." % hue, "flag 0x80: large")
	slot["monster_flags"] = 0x83
	assert_eq(_creature_line(7), "-Contains large %s creatures." % hue)
	slot["monster_flags"] = 0x02
	assert_eq(_creature_line(7), "-Contains small %s creatures." % hue, "no 0x80: small")
	slot["monster_flags"] = 0x03
	assert_eq(_creature_line(7), "-Contains small %s creatures." % hue)


func test_a_castle_says_large() -> void:
	world.encounters[0]["clues"] = WorldClues.CREATURES
	assert_eq(_creature_line(0), "-Contains large black creatures.")
	world.encounters[4]["clues"] = WorldClues.CREATURES
	world.encounters[4]["monster_flags"] = 0x01
	assert_eq(_creature_line(4), "-Contains large white creatures.", "a castle, whatever its flags")


func test_the_world_s_dungeons_say_what_they_hold() -> void:
	var large := 0
	var small := 0
	for index in range(5, 15):
		var slot: Dictionary = world.encounters[index]
		slot["clues"] = WorldClues.CREATURES
		var big := int(slot["monster_flags"]) & DungeonBoard.LARGE != 0
		var tiers := []
		for row in DungeonBoard.creatures_for(MsvcRandom.new(index), int(slot["color"]), int(slot["monster_flags"]), false):
			tiers.append(CreatureBook.tier(row))
		assert_eq(_creature_line(index).contains("large"), big, "slot %d's words" % index)
		assert_eq(tiers.slice(0, 4), [8, 12, 16, 18] if big else [4, 6, 8, 12], "slot %d's rooms" % index)
		if big:
			large += 1
		else:
			small += 1
	assert_gt(large, 0, "control: a large dungeon in this world")
	assert_gt(small, 0, "control: a small one")
