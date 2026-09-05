extends GameTest
## Fidelity lifts of 2026-09-02, the DRAW / DISCARD batch: Jandor's Ring
## discards THE LAST CARD YOU DREW THIS TURN as a cost (Oracle; mage-go's
## discardLastDrawnCost), Land Tax shuffles ONCE after its searches, Library
## of Leng lets an effect's discard go to the top of the library instead
## (Duel.hlp rulings: cost discards do not qualify, Psychic Purge still
## bites), and Ring of Ma'rûf REPLACES the next draw this turn
## (`@RING_OF_MARUF`, Program/promptsX1.txt:353).


class Seat extends DecisionAgent:
	var cards: Array = []
	var yes := true
	var offered: Array = []     # [prompt, [ids]] per CARD question
	var yes_no_prompts: Array = []
	var numbers: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		var ids: Array = []
		for inst in candidates:
			ids.append(inst.id)
		offered.append([prompt, ids])
		if cards.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want := int(cards.pop_front())
		if want == -1:
			return null
		for inst in candidates:
			if inst.id == want:
				return inst
		return null if candidates.is_empty() else candidates[0]

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String,
			_hint: bool) -> bool:
		yes_no_prompts.append(prompt)
		return yes

	## A number question is an OPTION question whose labels are the numbers.
	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], hint: int) -> int:
		if numbers.is_empty():
			return hint
		var at := options.find(str(numbers.pop_front()))
		return at if at >= 0 else hint


func _seat(pid: int) -> Seat:
	var seat := Seat.new()
	g.set_agent(pid, seat)
	return seat


func _log_count(text: String) -> int:
	var n := 0
	for line in g.log_lines:
		if String(line).contains(text):
			n += 1
	return n


## Put [param name] on top of [param pid]'s library and draw it.
func _draw_named(pid: int, name: String) -> CardInstance:
	var inst := give_hand(pid, name)
	g.put_from_hand_on_top_of_library(inst)
	g.draw_cards(pid, 1)
	assert_eq(inst.zone, Mtg.Zone.HAND, "%s was drawn" % name)
	return inst


# ------------------------------------------------------------ Jandor's Ring --

func test_jandors_ring_cannot_be_activated_without_a_draw_this_turn() -> void:
	var ring := put_battlefield(0, "Jandor's Ring")
	give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, ring, 0, []), "drawn a card this turn")
	assert_eq(g.players[0].hand.size(), 1, "nothing was thrown away")


func test_jandors_ring_discards_the_last_card_drawn_this_turn() -> void:
	var ring := put_battlefield(0, "Jandor's Ring")
	advance_to_step(Mtg.Step.MAIN1)
	var kept := give_hand(0, "Grizzly Bears")
	var first := _draw_named(0, "Hill Giant")
	var last := _draw_named(0, "Gray Ogre")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, ring, 0, []))
	assert_eq(last.zone, Mtg.Zone.GRAVEYARD, "the LAST card drawn is the cost")
	assert_eq(first.zone, Mtg.Zone.HAND, "an earlier draw stays")
	assert_eq(kept.zone, Mtg.Zone.HAND, "a card never drawn is not on offer")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 3, "two kept plus the fresh draw")
	assert_true(ring.tapped)


func test_jandors_ring_needs_the_last_drawn_card_still_in_hand() -> void:
	var ring := put_battlefield(0, "Jandor's Ring")
	advance_to_step(Mtg.Step.MAIN1)
	_draw_named(0, "Hill Giant")
	var mountain := _draw_named(0, "Mountain")
	assert_ok(g.play_land(0, mountain))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, ring, 0, []), "no longer in your hand")


func test_jandors_ring_draw_history_resets_each_turn() -> void:
	var ring := put_battlefield(0, "Jandor's Ring")
	advance_to_step(Mtg.Step.MAIN1)
	_draw_named(0, "Hill Giant")
	advance_to_next_turn()   # P1's turn: P0 has drawn nothing THIS turn
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, ring, 0, []), "drawn a card this turn")


# ----------------------------------------------------------------- Land Tax --

func test_land_tax_shuffles_once_after_all_its_searches() -> void:
	put_battlefield(0, "Land Tax")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	var seat := _seat(0)
	advance_to_next_turn()
	advance_to_next_turn()   # P0's upkeep fired on the way to its MAIN1
	assert_eq(g.players[0].hand.size(), 4, "three basic lands fetched, plus the draw")
	assert_eq(seat.offered.size(), 3, "three searches")
	assert_eq(seat.offered[1][0], "Pick up to 2 more basic lands.")
	assert_eq(seat.offered[2][0], "Pick up to 1 more basic land.")
	assert_eq(_log_count("shuffles their library"), 1, "ONE shuffle, at the end")
	var last_find := -1
	var shuffle_at := -1
	for i in g.log_lines.size():
		var line := String(g.log_lines[i])
		if line.contains("searches their library and finds"):
			last_find = i
		if line.contains("shuffles their library"):
			shuffle_at = i
	assert_true(shuffle_at > last_find, "the shuffle follows the last find")


func test_land_tax_declined_neither_searches_nor_shuffles() -> void:
	put_battlefield(0, "Land Tax")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	var seat := _seat(0)
	seat.numbers = [0]
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), 1, "just the draw")
	assert_eq(seat.offered.size(), 0, "no search")
	assert_eq(_log_count("shuffles their library"), 0, "no shuffle either")


# ---------------------------------------------------------- Library of Leng --

func _twist_one_card(caster: int, victim: int) -> void:
	var twist := give_hand(caster, "Mind Twist")
	add_mana(caster, Mtg.ManaColor.B, 1)
	add_mana(caster, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(caster, twist, [TargetRef.player(victim)], 1))
	resolve_stack()


func test_library_of_leng_offers_the_top_of_the_library_for_an_effects_discard() -> void:
	put_battlefield(0, "Library of Leng")
	var bears := give_hand(0, "Grizzly Bears")
	var seat := _seat(0)
	advance_to_next_turn()   # P1's main phase
	var library_before := g.players[0].library.size()
	_twist_one_card(1, 0)
	assert_eq(seat.yes_no_prompts, [
		"Library of Leng: Put Grizzly Bears on top of your library instead of into your graveyard?"])
	assert_eq(bears.zone, Mtg.Zone.LIBRARY, "discarded to the library")
	assert_eq(g.players[0].library.size(), library_before + 1)
	assert_true(g.players[0].library[-1] == bears, "on TOP of the library")
	assert_eq(g.players[0].graveyard.size(), 0)
	assert_eq(g.players[0].hand.size(), 0, "it was still discarded")


func test_library_of_leng_declined_sends_the_card_to_the_graveyard() -> void:
	put_battlefield(0, "Library of Leng")
	var bears := give_hand(0, "Grizzly Bears")
	var seat := _seat(0)
	seat.yes = false
	advance_to_next_turn()
	_twist_one_card(1, 0)
	assert_eq(seat.yes_no_prompts.size(), 1, "asked once")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_library_of_leng_ignores_a_cost_discard() -> void:
	# Duel.hlp, Library of Leng: "Effects that require you to discard as
	# part of the cost of playing them do not force you to discard" —
	# Jandor's Ring's cost goes to the graveyard, no question asked.
	put_battlefield(0, "Library of Leng")
	var ring := put_battlefield(0, "Jandor's Ring")
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var drawn := _draw_named(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, ring, 0, []))
	assert_eq(drawn.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(seat.yes_no_prompts.size(), 0, "a cost discard is not an effect's")


func test_library_of_leng_keeps_psychic_purge_biting() -> void:
	# Duel.hlp: "you are still discarding, just to your library rather than
	# your graveyard. So if you're forced to discard Psychic Purge, your
	# opponent loses 5 life, even if you discard the Purge to your library."
	put_battlefield(0, "Library of Leng")
	var purge := give_hand(0, "Psychic Purge")
	_seat(0)
	advance_to_next_turn()
	_twist_one_card(1, 0)
	assert_eq(purge.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].life, 15, "the Purge still punished its discarder")


func test_library_of_leng_applies_to_your_own_wheel_of_fortune() -> void:
	# Duel.hlp: "using Sindbad or Wheel of Fortune is considered a forced
	# discard" — the classic Leng + Wheel: the hand goes on top of the
	# library and the seven draws bring it right back.
	put_battlefield(0, "Library of Leng")
	var bears := give_hand(0, "Grizzly Bears")
	var giant := give_hand(0, "Hill Giant")
	var wheel := give_hand(0, "Wheel of Fortune")
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wheel, []))
	resolve_stack()
	assert_eq(seat.yes_no_prompts.size(), 2, "asked per card")
	assert_eq(g.players[0].hand.size(), 7)
	assert_true(g.players[0].hand.has(bears), "Bears came straight back")
	assert_true(g.players[0].hand.has(giant), "so did the Giant")
	assert_eq(g.players[0].graveyard.size(), 1, "only the Wheel itself")
	assert_eq(g.players[1].hand.size(), 7, "the opponent just wheels")


func test_library_of_leng_only_helps_its_own_controller() -> void:
	put_battlefield(0, "Library of Leng")
	var bears := give_hand(1, "Grizzly Bears")
	var seat := _seat(1)
	advance_to_step(Mtg.Step.MAIN1)
	_twist_one_card(0, 1)
	assert_eq(seat.yes_no_prompts.size(), 0, "P1 has no Library")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- Ring of Ma'rûf --

func test_ring_of_maruf_replaces_the_next_draw_this_turn() -> void:
	var ring := put_battlefield(0, "Ring of Ma'rûf")
	var wish := _make_instance(0, "Black Lotus")
	g.players[0].outside_the_game.append(wish)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, ring, 0, []))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.EXILE, "the Ring exiles itself as a cost")
	assert_eq(g.players[0].hand.size(), 0, "nothing yet — the DRAW is what fetches")
	assert_true(g.players[0].outside_the_game.has(wish))
	var library_before := g.players[0].library.size()
	g.draw_cards(0, 1)
	assert_eq(wish.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(wish))
	assert_eq(g.players[0].library.size(), library_before, "no card was drawn")
	g.draw_cards(0, 1)
	assert_eq(g.players[0].library.size(), library_before - 1,
		"only the NEXT draw was replaced")


func test_ring_of_maruf_asks_with_the_original_prompt() -> void:
	var ring := put_battlefield(0, "Ring of Ma'rûf")
	var lotus := _make_instance(0, "Black Lotus")
	var bolt := _make_instance(0, "Lightning Bolt")
	g.players[0].outside_the_game.append(lotus)
	g.players[0].outside_the_game.append(bolt)
	var seat := _seat(0)
	seat.cards = [bolt.id]
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, ring, 0, []))
	resolve_stack()
	g.draw_cards(0, 1)
	assert_eq(seat.offered.size(), 1)
	assert_eq(seat.offered[0][0], "Ring of Ma'ruf: Select target out of play card.")
	assert_eq(seat.offered[0][1], [lotus.id, bolt.id])
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].outside_the_game.has(lotus))


func test_ring_of_maruf_replaces_the_draw_even_with_nothing_outside() -> void:
	var ring := put_battlefield(0, "Ring of Ma'rûf")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, ring, 0, []))
	resolve_stack()
	var library_before := g.players[0].library.size()
	g.draw_cards(0, 1)
	assert_eq(g.players[0].hand.size(), 0)
	assert_eq(g.players[0].library.size(), library_before,
		"the draw was replaced by nothing at all")
	assert_true(_log_count("nothing outside the game") == 1)


func test_ring_of_maruf_lapses_at_end_of_turn() -> void:
	var ring := put_battlefield(0, "Ring of Ma'rûf")
	var wish := _make_instance(0, "Black Lotus")
	g.players[0].outside_the_game.append(wish)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, ring, 0, []))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()   # P0's draw step came and went
	assert_true(g.players[0].outside_the_game.has(wish), "still outside")
	assert_eq(g.players[0].hand.size(), 1, "a plain draw")
