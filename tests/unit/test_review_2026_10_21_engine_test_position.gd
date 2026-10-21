extends GutTest
## Whole-project review of 2026-10-21, engine-5 — TEST HANDS NEVER PUT AN
## INSTANT OR A SORCERY ON THE TABLE.
##
## What was wrong: Magic Battle's Test hands (0.50.39) let "On the table"
## name any card of the deck, DuelPosition.refusal() checked only names,
## lives and counts, and MtgGame.begin_from_position put whatever was named
## onto the battlefield — a Lightning Bolt sat there as a permanent for the
## rest of the duel, where "destroy target permanent" could see it. An
## instant or a sorcery is never a permanent (CR 304.4, 307.4). The model
## now refuses such a position and names the card, and the engine's own
## placing step never puts a non-permanent onto the battlefield even when a
## position that skipped the model's check asks it to: the card stays where
## it was, in the library (CR 304.4: "it remains in its previous zone").
## The owner's ruling on the review: "All!".


func _game() -> MtgGame:
	var game := MtgGame.new()
	var deck: Array = []
	for i in 30:
		deck.append("Mountain")
	for i in 4:
		deck.append("Lightning Bolt")
	game.setup(deck, deck, "P0", "P1", 20, 20, 424242)
	return game


## A position that skips the model's own check — what a hand-edited
## settings file, or a future caller that forgot to ask, would hand the
## engine.
class Unchecked extends DuelPosition:
	func refusal() -> String:
		return ""


func _on_the_battlefield(game: MtgGame, card_name: String) -> bool:
	for pid in 2:
		for inst in game.players[pid].battlefield:
			if inst.data.card_name == card_name:
				return true
	return false


func _count_all(game: MtgGame, pid: int) -> int:
	var p := game.players[pid]
	return p.library.size() + p.hand.size() + p.battlefield.size() + p.graveyard.size()


func test_an_instant_on_the_table_is_refused_by_name() -> void:
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Mountain")
	position.add(0, DuelPosition.TABLE, "Lightning Bolt")
	assert_eq(position.refusal(),
		"Seat 1 puts Lightning Bolt on the table, but an instant or a sorcery is never a permanent. Put it in the hand, the graveyard or on top of the library.")


func test_several_are_named_together_and_the_seat_is_the_right_one() -> void:
	var position := DuelPosition.new()
	position.add(1, DuelPosition.TABLE, "Lightning Bolt")
	position.add(1, DuelPosition.TABLE, "Armageddon")
	position.add(1, DuelPosition.TABLE, "Lightning Bolt")
	assert_eq(position.refusal(),
		"Seat 2 puts Lightning Bolt, Armageddon on the table, but an instant or a sorcery is never a permanent. Put them in the hand, the graveyard or on top of the library.")


func test_an_instant_anywhere_but_the_table_is_fine() -> void:
	var position := DuelPosition.new()
	position.add(0, DuelPosition.HAND, "Lightning Bolt")
	position.add(0, DuelPosition.GRAVEYARD, "Lightning Bolt")
	position.add(0, DuelPosition.LIBRARY_TOP, "Armageddon")
	position.add(0, DuelPosition.TABLE, "Mountain")
	position.add(0, DuelPosition.TABLE, "Grizzly Bears")
	assert_eq(position.refusal(), "")


func test_the_picker_can_ask_the_model_what_fits_on_the_table() -> void:
	assert_true(DuelPosition.fits_on_table("Mountain"))
	assert_true(DuelPosition.fits_on_table("Grizzly Bears"))
	assert_true(DuelPosition.fits_on_table("Holy Strength"))
	assert_false(DuelPosition.fits_on_table("Lightning Bolt"))
	assert_false(DuelPosition.fits_on_table("Armageddon"))
	assert_false(DuelPosition.fits_on_table("Not A Real Card"))


func test_the_engine_refuses_it_and_moves_nothing() -> void:
	var game := _game()
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Lightning Bolt")
	var why := game.begin_from_position(position)
	assert_string_contains(why, "Lightning Bolt")
	assert_eq(game.turn_number, 0, "no turn began")
	assert_true(game.players[0].battlefield.is_empty())
	assert_eq(game.players[0].library.size(), 34)


func test_an_unchecked_position_still_never_puts_an_instant_on_the_battlefield() -> void:
	var game := _game()
	var position := Unchecked.new()
	position.add(0, DuelPosition.TABLE, "Mountain")
	position.add(0, DuelPosition.TABLE, "Lightning Bolt")
	assert_eq(game.begin_from_position(position), "")
	assert_false(_on_the_battlefield(game, "Lightning Bolt"),
		"an instant is never a permanent (CR 304.4)")
	assert_true(_on_the_battlefield(game, "Mountain"), "the land is placed as asked")
	assert_eq(_count_all(game, 0), 34, "the Bolt stayed in the library: no card lost")
	var in_library := 0
	for inst in game.players[0].library:
		if inst.data.card_name == "Lightning Bolt":
			assert_eq(inst.zone, Mtg.Zone.LIBRARY)
			in_library += 1
	assert_eq(in_library, 4)
