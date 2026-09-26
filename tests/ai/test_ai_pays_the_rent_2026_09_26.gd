extends GameTest
## THE RENT (2026-09-26, [member AiProfile.pays_the_rent]). A Stasis
## charges {U} at its controller's upkeep and takes the untap step away
## with the other hand, so the {U} has to STILL BE THERE — booked the way
## a held instant's mana is ([method AiPlayer._rent_reserve]), and only
## under a freeze ([method AiPlayer._mana_frozen]). The cast is gated by
## the freeze's worth ([method AiPlayer._lock_worth]) and by whether the
## spell and its first rent are both payable now ([method
## AiPlayer._rent_affordable]); the rent's own question at the upkeep is
## answered off the same worth ([method AiPlayer.answer_yes_no]).
##
## The reader is card-name-free: [method EffectIntent.rent_of_line] reads
## the printed upkeep line, [method AiPlayer._card_freezes] the printed
## static. Both arms of the knob are pinned.


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## On to [param step] of seat 0's NEXT turn with seat 0 holding priority
## and the stack empty — through seat 1's turn, nothing declared.
func _our_next_turn_step(step: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.turn_number > turn and g.active_player == 0 and g.current_step() == step
			and not g.awaiting_attackers and not g.awaiting_blockers
			and g.priority_player == 0 and g.stack.is_empty()) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached our %s" % Mtg.step_name(step))


func _tap(inst: CardInstance) -> void:
	inst.tapped = true


func _islands(pid: int, count: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in count:
		out.append(put_battlefield(pid, "Island"))
	return out


func _untapped_lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


# ============================================================== the reader --

func test_the_reader_prices_a_rent_and_nothing_else() -> void:
	assert_eq(EffectIntent.rent_of_line(
		"At the beginning of your upkeep, sacrifice this enchantment unless you pay {U}."),
		"{U}", "Stasis")
	assert_eq(EffectIntent.rent_of_line(
		"At the beginning of your upkeep, destroy this creature unless you pay {3}{B}{B}{B}. "
		+ "If this creature is destroyed this way, it deals 3 damage to you."),
		"{3}{B}{B}{B}", "Cosmic Horror")
	assert_eq(EffectIntent.rent_of_line(
		"At the beginning of your upkeep, unless you pay {B}{B}{B}, tap this creature "
		+ "and sacrifice a land."), "{B}{B}{B}", "Demonic Hordes")
	assert_eq(EffectIntent.rent_of_line(
		"At the beginning of your upkeep, put a wind counter on this enchantment, then "
		+ "sacrifice it unless you pay {G} for each wind counter on it."),
		"", "Cyclone's count is not read")
	assert_eq(EffectIntent.rent_of_line(
		"At the beginning of your upkeep, this creature deals 1 damage to you."),
		"", "a toll is not a rent")
	assert_eq(EffectIntent.rent_of_line(
		"At the beginning of your upkeep, you may pay {X}. If you do, this deals X damage to you."),
		"", "a price that is X is not read")


func test_the_freeze_is_read_off_the_static() -> void:
	var stasis := put_battlefield(0, "Stasis")
	var vault := put_battlefield(0, "Time Vault")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_true(AiPlayer._card_freezes(stasis.data), "Stasis takes the untap step away")
	assert_false(AiPlayer._card_freezes(vault.data),
		"Time Vault only holds itself: 'doesn't untap' is not 'skip their untap step'")
	assert_false(AiPlayer._card_freezes(bears.data))
	assert_eq(AiPlayer._rent_of_data(stasis.data), "{U}")
	assert_eq(AiPlayer._rent_of_data(vault.data), "")


func test_the_reserve_books_the_rent_only_under_a_freeze() -> void:
	var ai := _wizard(0)
	var forces := put_battlefield(0, "Phantasmal Forces")
	_islands(0, 3)
	assert_eq(ai._rent_of(g, forces), "{U}", "the Forces charge {U} at our upkeep")
	assert_false(ai._mana_frozen(g))
	assert_true(ai._rent_reserve(g).is_empty(),
		"while our lands untap, the rent is paid out of the untap step")
	put_battlefield(0, "Stasis")
	g.recalculate()
	assert_true(ai._mana_frozen(g), "a Stasis of ours freezes our lands")
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Grizzly Bears"))
	var reserve := ai._rent_reserve(g)
	assert_false(reserve.is_empty(), "under the freeze the rent is booked")
	assert_eq(reserve["cost"].mana_value(), 2, "the Forces' {U} and the Stasis's {U}, as one cost")
	assert_eq(int(reserve["cost"].colored.get(Mtg.ManaColor.U, 0)), 2)
	assert_gt(float(reserve["value"]), 0.0)
	ai.profile.pays_the_rent = false
	assert_true(ai._held_reserve(g).is_empty(), "off, the held reserve knows no rent")
	ai.profile.pays_the_rent = true
	var held := ai._held_reserve(g)
	assert_eq(held["cost"].mana_value(), 2, "on, the held reserve carries it")


# ================================================================ the cast --
#
# Asked in the second main phase: the pilot develops after combat, and
# a permanent with no attack to make is the first main phase's "wait".

func test_a_stasis_is_not_cast_with_nothing_left_for_its_rent() -> void:
	var ai := _wizard(0)
	give_hand(0, "Stasis")
	_islands(0, 2)
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Grizzly Bears"))
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(ai._try_cast_best(g), "", "two Islands: the spell, and nothing for the {U}")
	ai.profile.pays_the_rent = false
	assert_eq(ai._try_cast_best(g), "cast Stasis", "off, it is cast and the rent is a surprise")


func test_a_stasis_is_cast_with_its_rent_in_hand_and_the_lock_in_our_favour() -> void:
	var ai := _wizard(0)
	give_hand(0, "Stasis")
	_islands(0, 3)
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Grizzly Bears"))
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(ai._try_cast_best(g), "cast Stasis")
	resolve_stack()
	assert_eq(_untapped_lands(0), 1, "one Island left untapped for the upkeep's {U}")


func test_a_stasis_is_not_cast_into_a_vigilance_angel() -> void:
	var ai := _wizard(0)
	give_hand(0, "Stasis")
	_islands(0, 3)
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(angel.has_keyword(Mtg.Keyword.VIGILANCE))
	assert_lt(ai._lock_worth(g, []), 0.0, "an untapped vigilance attacker is the freeze's hole")
	assert_eq(ai._try_cast_best(g), "", "the freeze would hold nothing of theirs")
	ai.profile.pays_the_rent = false
	assert_eq(ai._try_cast_best(g), "cast Stasis", "off, the pilot casts into the Angel")


func test_a_rent_permanent_that_does_not_freeze_is_cast_off_a_full_untap() -> void:
	var ai := _wizard(0)
	give_hand(0, "Phantasmal Forces")
	var lands := _islands(0, 5)
	_tap(lands[0])
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(ai._try_cast_best(g), "cast Phantasmal Forces",
		"{3}{U} taps the last four Islands: the untap step refills the {U}")
	assert_eq(_untapped_lands(0), 0, "tapped out, and rightly")


func test_under_our_own_stasis_the_last_island_is_kept_for_the_rent() -> void:
	var ai := _wizard(0)
	put_battlefield(0, "Stasis")
	g.recalculate()
	_islands(0, 2)
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Grizzly Bears"))
	give_hand(0, "Howling Mine")
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(ai._mana_frozen(g))
	assert_eq(ai._try_cast_best(g), "", "a Howling Mine with the last Island is a Stasis lost")
	ai.profile.pays_the_rent = false
	assert_eq(ai._try_cast_best(g), "cast Howling Mine", "off, the Mine is cast")


# ============================================================== the upkeep --

func test_the_rent_is_paid_while_the_freeze_is_worth_having() -> void:
	var ai := _wizard(0)
	var stasis := put_battlefield(0, "Stasis")
	g.recalculate()
	_islands(0, 2)
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Mountain"))
	_tap(put_battlefield(1, "Grizzly Bears"))
	_our_next_turn_step(Mtg.Step.MAIN1)
	assert_eq(stasis.zone, Mtg.Zone.BATTLEFIELD, "the {U} was paid")
	assert_eq(_untapped_lands(0), 1, "one Island paid it")


func test_a_freeze_that_is_against_us_is_let_go_at_the_upkeep() -> void:
	var ai := _wizard(0)
	var stasis := put_battlefield(0, "Stasis")
	g.recalculate()
	_islands(0, 2)
	put_battlefield(1, "Serra Angel")
	_our_next_turn_step(Mtg.Step.MAIN1)
	assert_eq(stasis.zone, Mtg.Zone.GRAVEYARD, "the Angel attacks through it every turn: let it go")
	assert_eq(_untapped_lands(0), 2, "and the Islands are kept")


func test_off_the_rent_is_paid_on_the_authors_hint() -> void:
	var ai := _wizard(0)
	ai.profile.pays_the_rent = false
	var stasis := put_battlefield(0, "Stasis")
	g.recalculate()
	_islands(0, 2)
	put_battlefield(1, "Serra Angel")
	_our_next_turn_step(Mtg.Step.MAIN1)
	assert_eq(stasis.zone, Mtg.Zone.BATTLEFIELD, "off, 'can we afford it' says yes")
