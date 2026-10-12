extends GutTest
## THE "FAIL TO FIND" MARK HOLDS NO NUL (campaign 2026-10-12, findings r1-4
## and r2-12). HumanAgent parks a name no card has when the player looks
## at a library search and picks nothing. It was "\u0000declined": Godot's
## strings cannot hold U+0000, so compiling it printed "Unexpected NUL
## character" three times in every launch that opened a duel, and the
## constant became "�declined". It is now plain text no card name can
## match, and declining a search still finds nothing.

func test_the_declined_mark_is_what_the_source_says() -> void:
	var mark := HumanAgent.DECLINED_PICK
	assert_false(mark.is_empty())
	for i in mark.length():
		assert_ne(mark.unicode_at(i), 0, "no NUL at %d" % i)
		assert_ne(mark.unicode_at(i), 0xFFFD, "no replacement character at %d" % i)


func test_no_card_is_named_like_the_declined_mark() -> void:
	CardRegistry.ensure_loaded()
	assert_false(CardRegistry.has_card(HumanAgent.DECLINED_PICK),
		"the mark can never name a real card")


func test_a_declined_search_finds_nothing() -> void:
	var game := MtgGame.new()
	var filler: Array = []
	for i in 10:
		filler.append("Forest")
	game.setup(filler, filler, "P0", "P1", 20, 20, 7)
	var agent := HumanAgent.new()
	agent.decline_search()
	assert_true(agent.has_preselection(), "control: the decline is parked")
	var candidates: Array[CardInstance] = []
	for inst in game.players[0].library:
		candidates.append(inst)
	assert_null(agent.answer_card(game, 0, candidates, "Search for a Forest."),
		"a declined search takes no card, even with Forests to find")
	assert_false(agent.has_preselection(), "and the decline is spent")
