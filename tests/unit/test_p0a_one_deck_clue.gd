extends GutTest
## P0a — THE CLUE "-One deck for all duels." GOES (the owner, 2026-10-28:
## "no — the player can have multiple decks": the rule stays dead and the
## clue line goes). The dungeons' rules word keeps its 0x20 bit
## ([constant DungeonDuels.ONE_DECK], read by nothing); no clue line says
## it any more, and a dungeon whose only rule was that bit says it has no
## special rules.

var player: AdventurePlayer
var world: ShandalarWorld


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.seed_text = "145729"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	world = player.world


func _rules_of(slot: int, rules: int) -> Array[String]:
	world.encounters[slot]["clues"] = WorldClues.RULES
	world.encounters[slot]["rules"] = rules
	world.encounters[slot]["card_in_effect"] = -1
	return WorldClues.lines(world, slot)


func test_no_clue_line_tells_of_one_deck_for_all_duels() -> void:
	var lines := _rules_of(7, 0x10 | DungeonDuels.ONE_DECK | 0x01)
	assert_false(lines.has("-One deck for all duels."), "%s" % [lines])
	for line in lines:
		assert_false(line.to_lower().contains("one deck"), line)
	assert_true(lines.has("-Life losses carried over."), "the other rules still said: %s" % [lines])
	assert_eq(lines.find("Dungeon Rules:") + 2, lines.find("-Life losses carried over."),
		"no-colour line, then the losses: nothing between")


func test_a_dungeon_with_that_bit_alone_has_no_special_rules() -> void:
	var lines := _rules_of(7, DungeonDuels.ONE_DECK)
	var at := lines.find("Dungeon Rules:")
	assert_gte(at, 0)
	assert_eq(lines.slice(at + 1, at + 2), ["-No special rules."] as Array[String],
		"never a heading over nothing: %s" % [lines])
	var none := _rules_of(7, 0)
	assert_eq(none[none.find("Dungeon Rules:") + 1], "-No special rules.", "as before for none")


func test_the_bit_stays_and_still_bars_nothing() -> void:
	assert_eq(DungeonDuels.ONE_DECK, 0x20, "the rules word as 1997 laid it out")
	assert_false(DungeonDuels.bars("Lightning Bolt", DungeonDuels.ONE_DECK, 4), "no reader")
