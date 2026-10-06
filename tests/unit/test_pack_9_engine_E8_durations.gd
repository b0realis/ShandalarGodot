extends GameTest
## Pack 9 engine package E8 — DURATIONS AND CAPS the Tempest block prints
## that the engine did not have:
##   * an untap cap over EVERY permanent — "As long as this artifact is
##     untapped, players can't untap more than two permanents during their
##     untap steps" (Static Orb, CR 502.3): the "permanent" untap kind,
##     counted with Smoke's / Winter Orb's kinds through the same question;
##   * a text change that lasts UNTIL END OF TURN (Whim of Volrath, CR 612,
##     514.2): flagged entries are dropped at cleanup;
##   * control "for as long as that creature is enchanted" (Rootwater
##     Matriarch, CR 611.2b): a control effect whose duration tracks the
##     VICTIM, not the source.
## Synthetic cards throughout; the card batches pin the printed cards.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


## Picks named cards, in order; the first candidate otherwise.
class ListSeat extends DecisionAgent:
	var picks: Array = []
	var asked: Array[String] = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if not picks.is_empty():
			var wanted := String(picks.pop_front())
			for inst in candidates:
				if inst.data.card_name == wanted:
					return inst
		return candidates[0] if not candidates.is_empty() else null


# -------------------------------------------------------------- Static Orb --

## Static Orb's shape.
func _orb() -> CardData:
	return CardData.new("Synthetic Orb", "{3}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_orb_apply,
			"As long as this artifact is untapped, players can't untap more than two permanents during their untap steps.")) \
		.oracle("As long as this artifact is untapped, players can't untap more than two permanents during their untap steps.")


static func _orb_apply(game: MtgGame, source: CardInstance) -> void:
	if not source.tapped:
		game.cap_untaps("permanent", 2, source)


func _tapped(pid: int, names: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for card_name in names:
		var inst := put_battlefield(pid, String(card_name))
		inst.tapped = true
		out.append(inst)
	g.recalculate()
	return out


func _to_our_next_untap() -> void:
	advance_to_next_turn()   # the opponent's turn
	advance_to_next_turn()   # ours: the untap step has run


func _untapped_names(cards: Array[CardInstance]) -> Array[String]:
	var out: Array[String] = []
	for inst in cards:
		if not inst.tapped:
			out.append(inst.data.card_name)
	out.sort()
	return out


func test_static_orb_lets_two_permanents_untap_of_the_controllers_choice() -> void:
	put_synthetic(0, _orb())
	var cards := _tapped(0, ["Forest", "Island", "Mountain", "Grizzly Bears", "Hill Giant"])
	var seat := ListSeat.new()
	seat.picks = ["Hill Giant", "Island"]
	g.agents[0] = seat
	_to_our_next_untap()
	assert_eq(_untapped_names(cards), ["Hill Giant", "Island"] as Array[String])
	assert_eq(seat.asked.size(), 2, "one question per permanent")
	assert_eq(seat.asked[0], "Select permanent to untap.")


func test_static_orb_counts_lands_and_creatures_together() -> void:
	put_synthetic(0, _orb())
	var cards := _tapped(0, ["Forest", "Island", "Grizzly Bears"])
	var seat := ListSeat.new()
	seat.picks = ["Forest", "Island"]
	g.agents[0] = seat
	_to_our_next_untap()
	assert_eq(_untapped_names(cards), ["Forest", "Island"] as Array[String])
	assert_true(cards[2].tapped, "the third permanent stays tapped")


func test_static_orb_binds_both_players() -> void:
	put_synthetic(0, _orb())
	var theirs := _tapped(1, ["Forest", "Island", "Mountain"])
	advance_to_next_turn()   # the opponent's untap step
	var untapped := 0
	for inst in theirs:
		if not inst.tapped: untapped += 1
	assert_eq(untapped, 2)


func test_a_tapped_static_orb_does_nothing() -> void:
	var orb := put_synthetic(0, _orb())
	orb.tapped = true
	var cards := _tapped(0, ["Forest", "Island", "Mountain", "Grizzly Bears"])
	_to_our_next_untap()
	assert_eq(_untapped_names(cards).size(), 4, "every permanent untaps")
	assert_false(orb.tapped, "the Orb with them")


func test_static_orb_and_winter_orb_both_hold() -> void:
	put_synthetic(0, _orb())
	put_battlefield(0, "Winter Orb")
	var cards := _tapped(0, ["Forest", "Island", "Grizzly Bears"])
	var seat := ListSeat.new()
	seat.picks = ["Forest", "Island"]   # the Island is refused by Winter Orb
	g.agents[0] = seat
	_to_our_next_untap()
	assert_eq(_untapped_names(cards), ["Forest", "Grizzly Bears"] as Array[String])


func test_static_orb_lets_the_player_skip_the_capped_kind() -> void:
	# Smoke allows one creature, the Orb two permanents: two LANDS is a
	# legal choice, and the player is never forced onto the creature.
	put_synthetic(0, _orb())
	put_battlefield(0, "Smoke")
	var cards := _tapped(0, ["Forest", "Island", "Grizzly Bears"])
	var seat := ListSeat.new()
	seat.picks = ["Forest", "Island"]
	g.agents[0] = seat
	_to_our_next_untap()
	assert_eq(_untapped_names(cards), ["Forest", "Island"] as Array[String])


func test_static_orb_holds_a_human_seat_in_the_untap_step() -> void:
	put_synthetic(0, _orb())
	var cards := _tapped(0, ["Forest", "Island", "Grizzly Bears"])
	_human_seat(0)
	advance_to_next_turn()
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_not_null(g.awaiting_choice)
	assert_eq(g.current_step(), Mtg.Step.UNTAP)
	assert_eq(g.awaiting_choice.source, "Synthetic Orb", "the question wears the lock's name")
	assert_eq(g.awaiting_choice.prompt, "Select permanent to untap.")
	assert_eq(g.awaiting_choice.candidates.size(), 3)
	assert_ok(g.answer_choice(cards[2].id))
	assert_not_null(g.awaiting_choice, "and the second pick")
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_ok(g.answer_choice(cards[1].id))
	assert_null(g.awaiting_choice)
	assert_eq(_untapped_names(cards), ["Grizzly Bears", "Island"] as Array[String])
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)


func test_every_permanent_is_of_the_permanent_untap_kind() -> void:
	var forest := put_battlefield(0, "Forest")
	var orb := put_synthetic(0, _orb())
	assert_true(MtgGame._untap_kinds(forest).has("permanent"))
	assert_true(MtgGame._untap_kinds(orb).has("permanent"))
	assert_true(MtgGame._untap_kinds(forest).has("land"), "and still its own kinds")


# ------------------------------------------------- text change until EOT --

func test_an_until_end_of_turn_text_change_ends_at_cleanup() -> void:
	var forest := put_battlefield(0, "Forest")
	g.change_text(forest, "land_type", "forest", "island", true)
	assert_true(forest.has_subtype("island"))
	assert_false(forest.has_subtype("forest"))
	advance_to_next_turn()
	assert_true(forest.has_subtype("forest"), "back after cleanup (CR 514.2)")
	assert_false(forest.has_subtype("island"))
	assert_true(forest.text_changes.is_empty())


func test_an_indefinite_text_change_outlives_the_turn() -> void:
	var forest := put_battlefield(0, "Forest")
	var swamp := put_battlefield(0, "Swamp")
	g.change_text(forest, "land_type", "forest", "island")
	g.change_text(swamp, "land_type", "swamp", "mountain", true)
	g.change_text(swamp, "land_type", "mountain", "plains")
	advance_to_next_turn()
	assert_true(forest.has_subtype("island"), "Magical Hack's change is indefinite")
	assert_eq(swamp.text_changes.size(), 1, "only the until-end-of-turn entry is dropped")
	assert_true(swamp.has_subtype("swamp"), "its EOT change gone, the later one no longer matches")


func test_an_eot_text_change_keeps_the_shape_the_network_validates() -> void:
	var forest := put_battlefield(0, "Forest")
	g.change_text(forest, "land_type", "forest", "island", true)
	var keys: Array = forest.text_changes[0].keys()
	keys.sort()
	assert_eq(keys, ["from", "kind", "to"], "the duration is kept beside the change")
	assert_true(SgViewProtocol.text_effects(forest.text_changes.duplicate(true)))


func test_an_eot_change_on_a_permanent_that_left_and_came_back_is_not_reapplied() -> void:
	var forest := put_battlefield(0, "Forest")
	g.change_text(forest, "land_type", "forest", "island", true)
	g.return_to_hand(forest)
	assert_true(forest.text_changes.is_empty(), "a new object (CR 400.7)")
	assert_ok(g.play_land(0, forest))
	g.change_text(forest, "land_type", "forest", "swamp")   # indefinite, same index
	advance_to_next_turn()
	assert_eq(forest.text_changes.size(), 1, "the old object's expiry touches nothing")
	assert_true(forest.has_subtype("swamp"))


func test_an_eot_text_change_journal_round_trip() -> void:
	var forest := put_battlefield(0, "Forest")
	var mark := g.make_mark()
	g.change_text(forest, "land_type", "forest", "island", true)
	assert_eq(forest.text_changes.size(), 1)
	g.unmake_to(mark)
	g.end_search()
	assert_true(forest.text_changes.is_empty())
	assert_true(forest.has_subtype("forest"))


func test_the_cleanup_expiry_is_journaled() -> void:
	var forest := put_battlefield(0, "Forest")
	g.change_text(forest, "land_type", "forest", "island", true)
	var mark := g.make_mark()
	advance_to_next_turn()
	assert_true(forest.text_changes.is_empty())
	g.unmake_to(mark)
	g.end_search()
	assert_eq(forest.text_changes.size(), 1, "the dropped entry came back with the rewind")
	assert_true(forest.has_subtype("island"))


# -------------------------------------------------- control while enchanted --

## Rootwater Matriarch's predicate.
static func _enchanted(game: MtgGame, victim: CardInstance) -> bool:
	return game.is_enchanted(victim)


func _enchant(host: CardInstance, pid: int) -> CardInstance:
	var aura := give_hand(pid, "Holy Strength")
	g.attach_aura_from_anywhere(aura, host, pid)
	return aura


func _matriarch() -> CardInstance:
	return put_synthetic(0, CardData.new("Synthetic Matriarch", "{2}{U}{U}", Mtg.CardType.CREATURE).pt(2, 3).oracle("..."))


func test_control_lasts_while_the_victim_is_enchanted_not_while_the_source_stays() -> void:
	var matriarch := _matriarch()
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := _enchant(bear, 1)
	assert_true(g.is_enchanted(bear))
	g.gain_control_while(bear, 0, _enchanted, matriarch)
	assert_eq(bear.controller_id, 0)
	g.destroy(matriarch)
	assert_eq(bear.controller_id, 0, "the Matriarch leaving does not end it")
	g.destroy(aura)
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.controller_id, 1, "the last Aura leaving does")


func test_an_unenchanted_victim_is_not_taken_at_all() -> void:
	var matriarch := _matriarch()
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_false(g.is_enchanted(bear))
	g.gain_control_while(bear, 0, _enchanted, matriarch)
	assert_eq(bear.controller_id, 1, "the duration was over before it began (CR 611.2b)")
	_enchant(bear, 1)
	g.recalculate()
	assert_eq(bear.controller_id, 1, "and enchanting it later does not start it")


func test_control_ends_with_the_last_of_two_auras_and_never_revives() -> void:
	var matriarch := _matriarch()
	var bear := put_battlefield(1, "Grizzly Bears")
	var first := _enchant(bear, 1)
	var second := _enchant(bear, 1)
	g.gain_control_while(bear, 0, _enchanted, matriarch)
	assert_eq(bear.controller_id, 0)
	g.destroy(first)
	assert_eq(bear.controller_id, 0, "still enchanted")
	g.destroy(second)
	assert_eq(bear.controller_id, 1)
	_enchant(bear, 1)
	g.recalculate()
	assert_eq(bear.controller_id, 1, "a broken duration never revives")


func test_the_duration_ends_when_the_victim_phases_out() -> void:
	var matriarch := _matriarch()
	var bear := put_battlefield(1, "Grizzly Bears")
	_enchant(bear, 1)
	g.gain_control_while(bear, 0, _enchanted, matriarch)
	assert_eq(bear.controller_id, 0)
	assert_true(g.phase_out(bear))
	g.recalculate()
	assert_true(g.phase_in(bear))
	g.recalculate()
	assert_eq(bear.controller_id, 1, "CR 702.26f: a 'for as long as' duration tracking it ends")


func test_control_while_journal_round_trip() -> void:
	var matriarch := _matriarch()
	var bear := put_battlefield(1, "Grizzly Bears")
	_enchant(bear, 1)
	var mark := g.make_mark()
	g.gain_control_while(bear, 0, _enchanted, matriarch)
	assert_eq(bear.controller_id, 0)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.controller_id, 1)
	assert_true(g.players[1].battlefield.has(bear))
	assert_false(g._control_layers.has(bear.id))
