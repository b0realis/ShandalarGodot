extends GameTest
## THE DECKLIST — [member MtgPlayer.deck_names], 2026-09-07. The names a
## player brought to the duel, recorded once by [method MtgGame.setup] and
## never moved by the cards moving: what a player knew before the first
## draw, so a card may be NAMED from it (Petra Sphinx from one's own,
## Nebuchadnezzar from the opponent's — the owner's ruling, "only display
## selection of cards from opponents deck (as you can see the deck
## beforehand in real mtg)") without reading a hand or a library.


func _fresh(deck0: Array, deck1: Array) -> void:
	g = MtgGame.new()
	g.setup(deck0, deck1, "P0", "P1", 20, 20, 7)
	g.start(0)


func test_setup_records_the_decklist_as_registered() -> void:
	_fresh(["Grizzly Bears", "Forest", "Grizzly Bears", "Hill Giant"],
		["Island", "Island"])
	assert_eq(g.players[0].deck_names,
		["Grizzly Bears", "Forest", "Grizzly Bears", "Hill Giant"] as Array[String],
		"every copy, in the order the deck was registered")
	assert_eq(g.players[1].deck_names, ["Island", "Island"] as Array[String])


func test_the_decklist_does_not_follow_the_cards() -> void:
	_fresh(["Grizzly Bears", "Forest", "Hill Giant"], ["Island"])
	var before: Array[String] = g.players[0].deck_names.duplicate()
	g.draw_cards(0, 2)
	var drawn: CardInstance = g.players[0].hand[0]
	g.discard_cards(0, [drawn])
	assert_eq(g.players[0].deck_names, before,
		"a card in hand or in the graveyard is still a card the player brought")


func test_a_wish_from_outside_the_game_joins_the_decklist() -> void:
	# Ring of Ma'rûf: the arrival is announced in the log, so the name is
	# public knowledge from that moment and Nebuchadnezzar may say it.
	var lotus := _make_instance(0, "Black Lotus")
	g.players[0].outside_the_game.append(lotus)
	assert_false(g.players[0].deck_names.has("Black Lotus"))
	g.take_from_outside_the_game(lotus, 0)
	assert_eq(g.players[0].deck_names.back(), "Black Lotus")


func test_the_wish_is_undone_with_the_search() -> void:
	var lotus := _make_instance(0, "Black Lotus")
	g.players[0].outside_the_game.append(lotus)
	var before: Array[String] = g.players[0].deck_names.duplicate()
	var mark := g.make_mark()
	g.take_from_outside_the_game(lotus, 0)
	assert_true(g.players[0].deck_names.has("Black Lotus"))
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[0].deck_names, before, "the journal put the decklist back")
	assert_true(g.players[0].outside_the_game.has(lotus))
