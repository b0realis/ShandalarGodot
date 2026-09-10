extends GameTest
## THE TRICK'S MANA, BOOKED (2026-09-10, [member AiProfile.holds_tricks];
## `docs/forge/combat.md` P5, `docs/forge/casting.md` P13).
##
## [method AiPlayer._attack_choice] already sends one extra body on the
## strength of a pump in hand, and [method
## AiPlayer._offensive_combat_response] already spends the pump to win
## that body's block. Between them sits the first main phase, which knew
## about neither: [method AiPlayer._held_reserve] books removal, a draw
## and a counterspell and skips a pump outright, so the {G} of a Giant
## Growth pays for a Grizzly Bears and the trick is a dead card.
## Reproduced before a line was written, two Forests and a Hurloon
## Minotaur facing a Hill Giant:
##
##     _held_reserve      {}                 -- nothing is kept open
##     main 1             cast Grizzly Bears -- both Forests tapped
##     _find_pump_instant null               -- the Giant Growth is dead
##
## And measured over 200 whole games of Big Green against White Knights:
## the pilot reached declare-blockers holding a pump 2,051 times and
## **could no longer pay for it in 531 of them (25.9%)**.
##
## P5's OTHER HALF DID NOT REPRODUCE and is not built. "Remember the
## body's id so the offensive response prefers it" answers a question the
## pilot is almost never asked: over those same 200 games the response
## found two or more of its own attackers that the pump could save in
## exactly ONE declare-blockers step, and in 2 of 200 on the tree that
## books the mana. `test_the_response_still_takes_the_one_body_in_front_of_it`
## is what stands in its place.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.holds_tricks = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.holds_tricks = false
	return profile


## Two Forests, our own body, and whatever they have. The hand is the
## trick and one cheap creature that would spend exactly the same mana.
func _board(theirs: Array, ours := "Hurloon Minotaur",
		spend := "Grizzly Bears") -> void:
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 2:
		put_battlefield(0, "Forest")
	put_battlefield(0, ours)
	for n in theirs:
		put_battlefield(1, n)
	give_hand(0, "Giant Growth")
	if spend != "":
		give_hand(0, spend)


func _untapped_lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


# ------------------------------------------------------- the booking itself --

func test_the_trick_books_the_forest_it_needs() -> void:
	var ai := _ai(_on())
	_board(["Hill Giant"])
	var trick := ai._trick_reserve(g)
	assert_false(trick.is_empty(), "a bait, so a booking")
	var bait: CardInstance = trick["bait"]
	assert_eq(bait.data.card_name, "Hurloon Minotaur")
	assert_eq(float(trick["value"]), Evaluator.permanent_value(bait, _on()),
		"worth exactly the body it is for")
	assert_eq(String(ai._held_reserve(g)["cost"].text), "{G}",
		"and the reserve every sorcery-speed cast is priced against carries it")


func test_off_the_trick_books_nothing() -> void:
	var ai := _ai(_off())
	_board(["Hill Giant"])
	assert_true(ai._trick_reserve(g).is_empty())
	assert_true(ai._held_reserve(g).is_empty(),
		"removal, a draw and a counterspell — a pump has never been in it")


func test_main_one_leaves_the_forests_open() -> void:
	var ai := _ai(_on())
	_board(["Hill Giant"])
	assert_eq(ai._try_cast_best(g), "", "the Bears waits a turn")
	assert_eq(_untapped_lands(0), 2)
	assert_not_null(ai._find_pump_instant(g), "and the trick can still be paid for")


func test_off_main_one_spends_them_and_the_trick_dies() -> void:
	var ai := _ai(_off())
	_board(["Hill Giant"])
	assert_eq(ai._try_cast_best(g), "cast Grizzly Bears")
	assert_eq(_untapped_lands(0), 0)
	assert_null(ai._find_pump_instant(g),
		"the reproduction: a Giant Growth in hand that nothing can pay for")


# ------------------------------------------- what it deliberately will NOT do --

func test_an_empty_board_over_there_books_nothing() -> void:
	# No blocker, no bait: every attack of ours is already sound, so the
	# trick has no body it is FOR and the Bears is cast on both arms.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		_board([])
		assert_true(ai._trick_reserve(g).is_empty())
		assert_eq(ai._try_cast_best(g), "cast Grizzly Bears")


func test_a_body_that_is_sound_without_the_trick_is_no_bait() -> void:
	# Our Craw Wurm walks past a Grizzly Bears without any help at all,
	# so the Giant Growth is not what is sending it and books nothing.
	var ai := _ai(_on())
	_board(["Grizzly Bears"], "Craw Wurm")
	assert_true(ai._trick_reserve(g).is_empty())


func test_on_their_turn_the_trick_books_nothing() -> void:
	var ai := _ai(_on())
	_board(["Hill Giant"])
	advance_to_next_turn()
	assert_eq(g.active_player, 1, "their first main phase")
	assert_true(ai._trick_reserve(g).is_empty(),
		"a bait attacker is a thing our own combat does")


func test_after_the_blocks_are_in_the_trick_books_nothing() -> void:
	var ai := _ai(_on())
	_board(["Hill Giant"])
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(ai._trick_reserve(g).is_empty(),
		"there is nothing left in the turn for the reservation to protect")


func test_the_clearly_better_cast_still_goes_ahead_of_it() -> void:
	# The 1.5x rule the held Counterspell has always lived under: a
	# reserve worth 5.0 does not stop a cast worth more than 7.5.
	var ai := _ai(_on())
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 6:
		put_battlefield(0, "Forest")
	put_battlefield(0, "Hurloon Minotaur")
	put_battlefield(1, "Hill Giant")
	give_hand(0, "Giant Growth")
	give_hand(0, "Force of Nature")
	assert_false(ai._trick_reserve(g).is_empty(), "the booking is made")
	assert_eq(ai._try_cast_best(g), "cast Force of Nature",
		"an 8/8 is worth more than the body the trick was for")


# ------------------------------------------------- and the trick is spent --

func test_the_response_still_takes_the_one_body_in_front_of_it() -> void:
	# The mana held is mana SPENT: the Minotaur is sent, the Hill Giant
	# blocks it, and the Giant Growth wins the block. Off, the same
	# response fires — when the mana happens to still be there. This is
	# what stands in place of P5's remembered attacker, which does not
	# reproduce.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		put_battlefield(0, "Forest")
		var mino := put_battlefield(0, "Hurloon Minotaur")
		var giant := put_battlefield(1, "Hill Giant")
		var growth := give_hand(0, "Giant Growth")
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(0, [mino.id]))
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(1, {giant.id: mino.id}))
		assert_string_contains(ai._offensive_combat_response(g), "Giant Growth")
		resolve_stack()
		assert_eq(growth.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(mino.cur_power, 5, "a 5/6 wins that block (%s)" % profile.profile_name)
