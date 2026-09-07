extends GameTest
## THE COUNT (2026-09-07, "The Deck, second pass"). The pilot sized every
## X spell to the mana it had and every extra draw to the hand it wanted,
## never to the cards in front of it: Mind Twist for X=20 at an empty
## hand, Braingeyser for X=19 into a library of nine, a Tome ticking into
## a hand of fifteen — and a third of its long games lost by drawing from
## an empty library at 30 to 47 life. Measured on The Deck against the
## five shipped starters (docs/ROADMAP.md, "The Deck, second pass").
##
## Everything here acts through AiPlayer.act and the public MtgGame API.
## One knob gates it, [member AiProfile.counts_cards] — the sizing, the
## hand room, the draw that wins — so each behaviour is pinned twice: it
## happens for a profile that counts and does not for one that does not.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


func _counting() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.counts_cards = true
	return profile


func _not_counting() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.counts_cards = false
	return profile


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	assert_eq(g.priority_player, 1, "the active player gets priority first")
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------- the X discard's ceiling --

func test_mind_twist_is_sized_to_their_hand() -> void:
	var ai := _ai(_counting())
	give_hand(0, "Mind Twist")
	_lands(0, "Swamp", 6)   # X could be 5
	give_hand(1, "Grizzly Bears")
	give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Mind Twist")
	assert_eq(g.stack.back().x_value, 2, "X is their hand, not our mana")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)


func test_mind_twist_waits_for_a_hand_to_twist() -> void:
	var ai := _ai(_counting())
	var twist := give_hand(0, "Mind Twist")
	_lands(0, "Swamp", 6)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "nothing to discard, nothing to cast")
	assert_eq(twist.zone, Mtg.Zone.HAND)


func test_mind_twist_for_one_waits_when_they_hold_more() -> void:
	var ai := _ai(_counting())
	var twist := give_hand(0, "Mind Twist")
	_lands(0, "Swamp", 2)   # X could be 1
	give_hand(1, "Grizzly Bears")
	give_hand(1, "Giant Growth")
	give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "the deck's one Twist waits for a real one")
	assert_eq(twist.zone, Mtg.Zone.HAND)


func test_a_pilot_that_does_not_count_casts_the_twist_at_full_x() -> void:
	# The null: the behaviour the measurement was taken against.
	var ai := _ai(_not_counting())
	give_hand(0, "Mind Twist")
	_lands(0, "Swamp", 6)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Mind Twist")
	assert_eq(g.stack.back().x_value, 5, "every land, at an empty hand")


# --------------------------------------------------- the X draw's ceiling --

func test_braingeyser_is_sized_to_the_room_in_our_hand() -> void:
	var ai := _ai(_counting())
	give_hand(0, "Braingeyser")
	for _i in 5:
		give_hand(0, "Craw Wurm")   # six in hand with the Geyser; no green to cast one
	_lands(0, "Island", 12)   # {X}{U}{U}: X could be 10
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Braingeyser")
	# Seven is the maximum hand size; five stay in hand once the Geyser is
	# on the stack, and a main phase plays two more: room for four.
	assert_eq(g.stack.back().x_value, 4)


func test_braingeyser_never_draws_the_last_card() -> void:
	var ai := _ai(_counting())
	give_hand(0, "Braingeyser")
	_lands(0, "Island", 12)
	g.players[0].library.resize(3)   # test surgery: a library of three
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Braingeyser")
	assert_eq(g.stack.back().x_value, 2, "two of three: the draw step needs one")


func test_a_pilot_that_does_not_count_geysers_for_everything() -> void:
	var ai := _ai(_not_counting())
	give_hand(0, "Braingeyser")
	for _i in 5:
		give_hand(0, "Craw Wurm")
	_lands(0, "Island", 12)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Braingeyser")
	assert_eq(g.stack.back().x_value, 10, "every land, into a hand of six")


# ------------------------------------------------------ the draw that wins --

func test_braingeyser_empties_their_library_when_it_can() -> void:
	var ai := _ai(_counting())
	give_hand(0, "Braingeyser")
	_lands(0, "Island", 6)   # X could be 5
	g.players[1].library.resize(4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Braingeyser")
	var item = g.stack.back()
	assert_eq(item.x_value, 4, "exactly their library")
	assert_true(item.targets[0].is_player and item.targets[0].player_id == 1,
		"pointed at them")
	resolve_stack()
	assert_eq(g.players[1].library.size(), 0)
	# CR 704.5b: the loss comes at their next draw.
	advance_to_next_turn()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


func test_braingeyser_does_not_reach_for_a_library_it_cannot_empty() -> void:
	var ai := _ai(_counting())
	give_hand(0, "Braingeyser")
	_lands(0, "Island", 4)   # X could be 3
	g.players[1].library.resize(4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Braingeyser")
	var item = g.stack.back()
	assert_true(item.targets[0].player_id == 0, "three of four is not a win: draw our own")


func test_ancestral_recall_at_their_end_step_finishes_a_library_of_three() -> void:
	var ai := _ai(_counting())
	give_hand(0, "Ancestral Recall")
	_lands(0, "Island", 1)
	g.players[1].library.resize(3)
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "cast Ancestral Recall")
	var item = g.stack.back()
	assert_true(item.targets[0].is_player and item.targets[0].player_id == 1)


func test_a_pilot_that_does_not_count_draws_its_own_three() -> void:
	var ai := _ai(_not_counting())
	give_hand(0, "Ancestral Recall")
	_lands(0, "Island", 1)
	g.players[1].library.resize(3)
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "cast Ancestral Recall")
	assert_true(g.stack.back().targets[0].player_id == 0)


# --------------------------------------------------- the room in the hand --

func test_a_tome_does_not_draw_into_a_full_hand() -> void:
	var ai := _ai(_counting())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	for _i in 8:
		give_hand(0, "Craw Wurm")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "pass", "a ninth card is a card discarded at cleanup")


func test_a_tome_draws_into_a_hand_with_room() -> void:
	var ai := _ai(_counting())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	for _i in 4:
		give_hand(0, "Craw Wurm")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "activated Jayemdae Tome")


func test_library_of_alexandria_still_draws_at_exactly_seven() -> void:
	# The one card whose whole point is a draw at a full hand, at the
	# moment the pilot already used it — their end step, a card ahead of
	# our own draw. The room for one is there: the count must not take
	# it away.
	var ai := _ai(_counting())
	put_battlefield(0, "Library of Alexandria")
	for _i in 7:
		give_hand(0, "Craw Wurm")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "activated Library of Alexandria")


# ------------------------------------------------------------- the ladder --

func test_the_ladder_counts_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().counts_cards)
	assert_false(AiProfile.magician().counts_cards)
	assert_true(AiProfile.sorcerer().counts_cards)
	assert_true(AiProfile.wizard().counts_cards)


func test_the_knob_reads_from_the_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("counts_cards=off"), "")
	assert_false(profile.counts_cards)
