extends GameTest
## Pack 9 bug pass (fix-engine) — four smaller engine findings:
##  h5-2  a hand change paid as an ABILITY COST (Penance's library-top,
##        Elvish Spirit Guide's exile from hand) refreshes the statics that
##        read a hand size before anyone gets priority (CR 611.3a, 704.3);
##  h3-6  paying off a delayed trigger (Sabertooth Cobra / Nafs Asp) is an
##        action between passes (CR 117.3c, 117.4);
##  h3-7  Volrath's Curse's "ignore until end of turn" ends in the cleanup
##        step before anyone may receive priority there (CR 514.2, 514.3a);
##  h2-6  "X can't be 0" through a payment row that forces X to 0 (Dream
##        Halls: CR 107.3b) is refused at the announcement, so the row is
##        not offered as open.

const PRESETS: Array[String] = ["modern", "fifth"]


class Picker extends DecisionAgent:
	var pick: CardInstance
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if candidates.has(pick): return pick
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-5", true)
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_edition(preset)


# ---------------------------------------------------------------- h5-2 --

func test_maro_dies_when_a_library_top_cost_empties_the_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var maro := put_battlefield(0, "Maro")
		var penance := put_battlefield(0, "Penance")
		var card := give_hand(0, "Forest")
		g.recalculate()
		assert_eq(maro.cur_toughness, 1, "%s: precondition, one card" % preset)
		assert_ok(g.activate_ability(0, penance, 0))
		assert_eq(card.zone, Mtg.Zone.LIBRARY, preset)
		assert_eq(g.players[0].hand.size(), 0, preset)
		assert_eq(maro.zone, Mtg.Zone.GRAVEYARD,
			"%s: a 0/0 Maro is gone before anyone gets priority (CR 704.3)" % preset)


func test_maro_shrinks_when_a_library_top_cost_leaves_cards() -> void:
	var maro := put_battlefield(0, "Maro")
	var penance := put_battlefield(0, "Penance")
	give_hand(0, "Forest")
	give_hand(0, "Island")
	g.recalculate()
	assert_eq(maro.cur_toughness, 2)
	assert_ok(g.activate_ability(0, penance, 0))
	assert_eq(maro.cur_toughness, 1, "the cost took a card: Maro is 1/1 at once (CR 611.3a)")


func test_maro_dies_when_a_spirit_guide_exiles_the_last_card() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var maro := put_battlefield(0, "Maro")
		var guide := give_hand(0, "Elvish Spirit Guide")
		g.recalculate()
		assert_eq(maro.cur_toughness, 1, "%s: precondition, one card" % preset)
		assert_ok(g.tap_for_mana(0, guide))
		assert_eq(guide.zone, Mtg.Zone.EXILE, preset)
		assert_eq(maro.zone, Mtg.Zone.GRAVEYARD,
			"%s: exiled from the hand as a cost: Maro is a 0/0" % preset)


# ---------------------------------------------------------------- h3-6 --

static func _pay_debt(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	pass


static func _any_upkeep(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> bool:
	return true


func _debt(pid: int, source: CardInstance) -> Dictionary:
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _pay_debt, "At the next upkeep, a debt comes due.",
		_any_upkeep), 1 - pid, source, false, {}, "the debt")
	entry["settle_cost"] = ManaCost.parse("{2}")
	entry["settle_by"] = pid
	return entry


func _rows(pid: int, kind: String) -> Array:
	var out: Array = []
	for row in g.special_actions(pid):
		if String(row["kind"]) == kind: out.append(row)
	return out


func test_settling_a_debt_is_an_action_between_passes() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var source := put_battlefield(0, "Grizzly Bears")
		_debt(1, source)
		assert_eq(g.active_player, 0)
		assert_ok(g.pass_priority(0))            # P0 passes on an empty stack
		assert_eq(g.priority_player, 1)
		add_mana(1, Mtg.ManaColor.C, 2)
		var row: Dictionary = _rows(1, "settle")[0]
		assert_ok(g.take_special_action(1, row))  # P1 pays the ransom
		assert_eq(g.priority_player, 1, "%s: the payer keeps priority" % preset)
		assert_ok(g.pass_priority(1))            # ... and passes
		assert_eq(g.current_step(), Mtg.Step.MAIN1,
			"%s: P0 must receive priority again before the step ends (CR 117.4)" % preset)
		assert_eq(g.priority_player, 0, preset)


func test_settling_directly_resets_the_passes_too() -> void:
	var source := put_battlefield(0, "Grizzly Bears")
	var entry := _debt(1, source)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.settle_delayed_trigger(1, int(entry["id"])))
	assert_ok(g.pass_priority(1))
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	assert_eq(g.priority_player, 0)


func test_a_refused_settle_changes_nothing() -> void:
	var source := put_battlefield(0, "Grizzly Bears")
	var entry := _debt(1, source)
	assert_ok(g.pass_priority(0))
	assert_refused(g.settle_delayed_trigger(1, int(entry["id"])), "not enough mana")
	assert_eq(g.priority_player, 1)
	assert_ok(g.pass_priority(1))
	assert_ne(g.current_step(), Mtg.Step.MAIN1,
		"nothing was done: both passed in succession and the step ended")


# ---------------------------------------------------------------- h3-7 --

static func _noop(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	pass


static func _any_cleanup(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> bool:
	return true


func test_the_curse_ignore_ends_before_cleanup_priority() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
		var forest := put_battlefield(0, "Forest")
		var curse := give_hand(1, "Volrath's Curse")
		g.attach_aura_from_anywhere(curse, sorcerer, 1)
		var seat := Picker.new()
		seat.pick = forest
		g.set_agent(0, seat)
		g.priority_player = 0
		assert_ok(g.ignore_static_effect(0, curse))
		assert_true(g.effect_ignored_by(curse, 0), "%s: precondition, ignored" % preset)
		# Something triggers at the beginning of the cleanup step, so the
		# active player receives priority there (CR 514.3a).
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.CLEANUP_START, _noop,
			"At the beginning of the next cleanup step, nothing.", _any_cleanup), 0, sorcerer,
			false, {}, "a cleanup trigger")
		var guard := 0
		while g.current_step() != Mtg.Step.CLEANUP and guard < 60:
			_advance_once()
			guard += 1
		assert_eq(g.current_step(), Mtg.Step.CLEANUP, preset)
		assert_eq(g.turn_number, 1, "%s: still the turn the ignore was taken in" % preset)
		assert_false(g.effect_ignored_by(curse, 0),
			"%s: 'until end of turn' ended in the cleanup step (CR 514.2)" % preset)
		while not g.stack.is_empty() and guard < 80:
			assert_ok(g.pass_priority(g.priority_player))
			guard += 1
		assert_eq(g.current_step(), Mtg.Step.CLEANUP, preset)
		g.priority_player = 0
		assert_refused(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]), "Volrath's Curse")


func test_the_curse_ignore_lasts_through_the_turn_before_cleanup() -> void:
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var forest := put_battlefield(0, "Forest")
	var curse := give_hand(1, "Volrath's Curse")
	g.attach_aura_from_anywhere(curse, sorcerer, 1)
	var seat := Picker.new()
	seat.pick = forest
	g.set_agent(0, seat)
	g.priority_player = 0
	assert_ok(g.ignore_static_effect(0, curse))
	advance_to_step(Mtg.Step.END)
	assert_true(g.effect_ignored_by(curse, 0), "still ignored in the end step")
	g.priority_player = 0
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))


# ---------------------------------------------------------------- h2-6 --

func _meddling_under_dream_halls() -> CardInstance:
	put_battlefield(0, "Dream Halls")
	var meddling := give_hand(0, "Ertai's Meddling")
	give_hand(0, "Island Fish Jasconius")   # a blue card to discard
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	g.priority_player = 1
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return meddling


func test_x_cant_be_0_is_refused_at_the_announcement_of_a_row_that_forces_x_0() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var meddling := _meddling_under_dream_halls()
		assert_eq(g.payment_rows(0, meddling).size(), 2, "%s: printed + Dream Halls" % preset)
		assert_string_contains(g.spell_announce_refusal(0, meddling, 0, 1), "X can't be 0")
		assert_false(SgDuelActions.open_modes(g, 0, meddling).has(1),
			"%s: the Dream Halls row is never castable for an X-can't-be-0 spell" % preset)


func test_the_printed_row_of_an_x_cant_be_0_spell_is_still_open() -> void:
	var meddling := _meddling_under_dream_halls()
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_eq(g.spell_announce_refusal(0, meddling, 0, 0), "",
		"the printed row may still announce an X it can pay")
	assert_eq(g.spell_announce_refusal(0, meddling, 1, 0), "")


func test_a_forced_x_row_of_an_ordinary_x_spell_stays_open() -> void:
	put_battlefield(0, "Dream Halls")
	var blast := give_hand(0, "Disintegrate")
	give_hand(0, "Lightning Bolt")   # a red card to discard
	assert_eq(g.payment_rows(0, blast).size(), 2)
	assert_eq(g.spell_announce_refusal(0, blast, 0, 1), "", "X = 0 through the row is legal")
