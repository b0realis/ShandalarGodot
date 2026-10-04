extends GameTest
## The Mirage bug pass (Pack 8, 0.50.11), engine batch B2 — six findings:
##
## (a) CR 305.7: a land whose subtype is SET to a basic land type loses
##     every ability from its rules text — its printed KEYWORDS too.
##     Teferi's Isle under Celestial Dawn is a Plains and no longer phases
##     (`CardInstance.become_basic_land_type`). A keyword granted from
##     outside the rules text is kept.
## (b) CR 613.7: Vision Charm's one-shot "Forests become Islands" and a
##     later Blanket of Night ("each land is a Swamp in addition") apply in
##     timestamp order — the Forest is an Island Swamp
##     (`ContinuousEffects` land-type waves merge battlefield and floating
##     retypers into one timestamp-ordered list).
## (c) CR 702.16 / 704.5m: a Ward's "This effect doesn't remove this Aura"
##     exempts its OWN grant only — protection from its colour from any
##     other source (Goblin Wizard) still removes it
##     (`CardInstance.cur_aura_protection`, the SBA's protection clause).
## (d) CR 613.8a: Chaosphere's "creatures without flying have reach"
##     DEPENDS on every effect that grants or removes flying, so it is
##     decided after layer 6 has settled flying
##     (`StaticAbility.reads_abilities`).
## (e) CR 704.5q (modern rules only): +1/+1 and -1/-1 counters on one
##     permanent annihilate in pairs (`RulesOptions.counters_annihilate`).
## (f) CR 510.2 / 120.3: "whenever ~ is dealt damage" triggers ONCE per
##     damage event, for the total — one combat damage step is one event
##     whatever the number of sources (`Mtg.EventType.WAS_DEALT_DAMAGE`).


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


class Seat extends DecisionAgent:
	var colors: Array = []
	var options: Array = []
	func answer_color(_g: MtgGame, _p: int, _prompt: String, hint: int) -> int:
		return int(colors.pop_front()) if not colors.is_empty() else hint
	func answer_option(_g: MtgGame, _p: int, _prompt: String,
			labels: Array[String], hint: int) -> int:
		if options.is_empty():
			return hint
		var want := String(options.pop_front()).to_lower()
		for i in labels.size():
			if labels[i].to_lower().contains(want):
				return i
		return hint


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s


func _cast(pid: int, card_name: String, targets: Array = [], mode := 0) -> CardInstance:
	var card := give_hand(pid, card_name)
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)
	assert_ok(g.cast_spell(pid, card, targets, 0, mode))
	resolve_stack()
	return card


func _items_of(card: CardInstance) -> int:
	var n := 0
	for item in g.stack:
		if item.card == card:
			n += 1
	return n


## From the declare-blockers step to the combat damage step, with the
## damage dealt and its triggers on the stack.
func _to_combat_damage() -> void:
	var guard := 0
	while g.current_step() != Mtg.Step.COMBAT_DAMAGE and guard < 40:
		_advance_once()
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.COMBAT_DAMAGE)


# ------------------------------------------------ (a) CR 305.7 keywords --

func test_celestial_dawn_takes_teferis_isles_printed_phasing() -> void:
	put_battlefield(0, "Celestial Dawn")
	var isle := put_battlefield(0, "Teferi's Isle")
	assert_true(isle.has_subtype("plains"), "the Isle is a Plains")
	assert_false(isle.has_keyword(Mtg.Keyword.PHASING),
		"CR 305.7: no ability from its rules text, phasing included")
	advance_to_next_turn()
	advance_to_next_turn()   # P0's untap step has run
	assert_eq(g.active_player, 0)
	assert_false(isle.phased_out, "it lost phasing, so it stays")
	isle.tapped = false
	assert_ok(g.tap_for_mana(0, isle))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 1, "a Plains taps for {W}")


func test_without_the_dawn_the_isle_still_phases() -> void:
	var isle := put_battlefield(0, "Teferi's Isle")
	assert_true(isle.has_keyword(Mtg.Keyword.PHASING))
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(isle.phased_out, "control: its printed phasing works")


func test_a_keyword_granted_from_outside_the_rules_text_is_kept() -> void:
	put_battlefield(0, "Celestial Dawn")
	var isle := put_battlefield(0, "Teferi's Isle")
	g.continuous.add_until_eot_keywords(isle.id, [Mtg.Keyword.PHASING])
	g.recalculate()
	assert_true(isle.has_subtype("plains"))
	assert_true(isle.has_keyword(Mtg.Keyword.PHASING),
		"a granted keyword is not from its rules text (CR 305.7)")


func test_a_durationless_grant_survives_the_retype_too() -> void:
	put_battlefield(0, "Celestial Dawn")
	var isle := put_battlefield(0, "Teferi's Isle")
	g.grant_keyword_permanently(isle, Mtg.Keyword.PHASING)
	assert_true(isle.has_subtype("plains"))
	assert_true(isle.has_keyword(Mtg.Keyword.PHASING),
		"the GRANTED phasing stays where the printed one went (CR 305.7)")


# ---------------------------------------- (b) CR 613.7 land-type timestamps --

func test_blanket_of_night_after_vision_charm_still_adds_swamp() -> void:
	var p0 := _seat(0)
	var forest := put_battlefield(0, "Forest")
	p0.options = ["Forest", "Island"]
	_cast(0, "Vision Charm", [], 1)
	assert_true(forest.has_subtype("island"))
	assert_false(forest.has_subtype("forest"))
	_cast(0, "Blanket of Night")
	assert_true(forest.has_subtype("island"), "still an Island")
	assert_true(forest.has_subtype("swamp"),
		"Blanket of Night's LATER timestamp adds Swamp on top (CR 613.7)")
	var colors: Array[int] = []
	for ability in forest.cur_mana_abilities:
		for pair in ability.produces:
			colors.append(int(pair[0]))
	assert_true(colors.has(Mtg.ManaColor.U) and colors.has(Mtg.ManaColor.B),
		"an Island Swamp taps for {U} or {B}")


func test_vision_charm_after_blanket_of_night_replaces_both_types() -> void:
	var p0 := _seat(0)
	var forest := put_battlefield(0, "Forest")
	_cast(0, "Blanket of Night")
	assert_true(forest.has_subtype("swamp") and forest.has_subtype("forest"))
	p0.options = ["Forest", "Island"]
	_cast(0, "Vision Charm", [], 1)
	assert_true(forest.has_subtype("island"))
	assert_false(forest.has_subtype("swamp"),
		"control: the Charm is later, and setting a type replaces the Blanket's Swamp (CR 305.7)")


# ------------------------------------------- (c) a Ward's own grant only --

func test_ward_of_lights_falls_off_to_another_sources_protection_from_its_colour() -> void:
	var s0 := _seat(0)
	s0.colors = [Mtg.ManaColor.W]
	var wizard := put_battlefield(0, "Goblin Wizard")
	var ward := give_hand(0, "Ward of Lights")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(wizard)]))
	resolve_stack()
	assert_ne(wizard.cur_protection & Mtg.ManaColor.W, 0, "the Ward grants protection from white")
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "its own protection does not remove it")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, wizard, 1, [TargetRef.card(wizard)]))
	resolve_stack()
	assert_eq(ward.zone, Mtg.Zone.GRAVEYARD,
		"the Wizard's protection from white removes the white Ward (CR 702.16, 704.5m)")


func test_white_ward_falls_off_to_another_sources_protection_from_white() -> void:
	var wizard := put_battlefield(0, "Goblin Wizard")
	var ward := give_hand(0, "White Ward")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(wizard)]))
	resolve_stack()
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "its own grant does not remove it")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, wizard, 1, [TargetRef.card(wizard)]))
	resolve_stack()
	assert_eq(ward.zone, Mtg.Zone.GRAVEYARD, "the White Ward's printed note: any OTHER pro-white source removes it")
	assert_ne(wizard.cur_protection & Mtg.ManaColor.W, 0, "the Wizard's own grant stands")


# -------------------------------------------- (d) Chaosphere's dependency --

func test_chaosphere_reach_for_a_mist_dragon_that_lost_flying_later() -> void:
	var dragon := put_battlefield(0, "Mist Dragon")
	assert_ok(g.activate_ability(0, dragon, 0))
	resolve_stack()
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING))
	put_battlefield(1, "Chaosphere")
	assert_false(dragon.has_keyword(Mtg.Keyword.REACH), "a flyer has no reach")
	assert_ok(g.activate_ability(0, dragon, 1))
	resolve_stack()
	assert_false(dragon.has_keyword(Mtg.Keyword.FLYING), "lost flying")
	assert_true(dragon.has_keyword(Mtg.Keyword.REACH),
		"a creature without flying has reach, whatever the timestamps (CR 613.8a)")


func test_chaosphere_reach_for_an_earthbound_flyer() -> void:
	put_battlefield(1, "Chaosphere")
	var angel := put_battlefield(0, "Serra Angel")
	_cast(0, "Earthbind", [TargetRef.card(angel)])
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "Earthbind took flying")
	assert_true(angel.has_keyword(Mtg.Keyword.REACH),
		"creatures without flying have reach (CR 613.8a)")


func test_chaosphere_no_reach_for_a_bear_that_jumped_later() -> void:
	put_battlefield(1, "Chaosphere")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(bear.has_keyword(Mtg.Keyword.REACH))
	_cast(0, "Jump", [TargetRef.card(bear)])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_false(bear.has_keyword(Mtg.Keyword.REACH),
		"it HAS flying, so Chaosphere gives it nothing (CR 613.8a)")


# ----------------------------------------- (e) CR 704.5q, modern rules only --

func _lichenthrope_and_djinn() -> CardInstance:
	put_battlefield(0, "Aku Djinn")
	var pinger := put_battlefield(0, "Prodigal Sorcerer")
	var lichen := put_battlefield(1, "Lichenthrope")
	advance_to_next_turn()          # turn 2, P1's main (P1's upkeep already past)
	assert_eq(g.active_player, 1)
	g.deal_damage(pinger, TargetRef.card(lichen), 1)
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 1, "damage became a -1/-1 counter")
	advance_to_next_turn()          # turn 3: P0's upkeep, Aku Djinn's counter
	assert_eq(g.active_player, 0)
	return lichen


func test_counters_annihilate_under_modern_rules() -> void:
	assert_true(g.rules.counters_annihilate(), "the modern default")
	var lichen := _lichenthrope_and_djinn()
	assert_eq([lichen.cur_power, lichen.cur_toughness], [5, 5])
	assert_eq(int(lichen.counters.get("+1/+1", 0)), 0, "CR 704.5q")
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 0, "CR 704.5q")
	advance_to_next_turn()          # turn 4: P1's upkeep — nothing to remove
	assert_eq([lichen.cur_power, lichen.cur_toughness], [5, 5],
		"Lichenthrope does not outgrow its printed 5/5")


func test_counters_coexist_under_fifth_edition() -> void:
	g.rules.set_edition("fifth")
	assert_false(g.rules.counters_annihilate(), "no such rule in 1997")
	var lichen := _lichenthrope_and_djinn()
	assert_eq(int(lichen.counters.get("+1/+1", 0)), 1)
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 1)
	assert_eq([lichen.cur_power, lichen.cur_toughness], [5, 5])


func test_phyrexian_marauders_counters_cancel_a_minus_counter() -> void:
	var marauder := give_hand(0, "Phyrexian Marauder")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, marauder, [], 3))
	resolve_stack()
	assert_eq(int(marauder.counters.get("+1/+1", 0)), 3)
	g.add_counters(marauder, "-1/-1", 1)
	assert_eq(int(marauder.counters.get("+1/+1", 0)), 2, "one pair annihilated (CR 704.5q)")
	assert_false(marauder.counters.has("-1/-1"))
	assert_eq([marauder.cur_power, marauder.cur_toughness], [2, 2])


func test_other_counter_kinds_do_not_annihilate() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.add_counters(bear, "+1/+1", 1)
	g.add_counters(bear, "-0/-1", 1)
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1, "only +1/+1 and -1/-1 pair off")
	assert_eq(int(bear.counters.get("-0/-1", 0)), 1)


# ------------------------------- (f) one damage event, one "is dealt" trigger --

func test_binding_agony_triggers_once_for_one_combat_damage_step() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var agony := _cast(0, "Binding Agony", [TargetRef.card(wurm)])
	advance_to_next_turn()   # P1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {a.id: wurm.id, b.id: wurm.id}))
	_to_combat_damage()
	assert_eq(_items_of(agony), 1, "one damage event, one trigger (CR 510.2)")
	resolve_stack()
	assert_eq(g.players[1].life, 16, "for the total: 4")


func test_binding_agony_triggers_per_event_for_two_separate_pings() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	var one := put_battlefield(0, "Prodigal Sorcerer")
	var two := put_battlefield(0, "Prodigal Sorcerer")
	var agony := _cast(0, "Binding Agony", [TargetRef.card(wurm)])
	assert_ok(g.activate_ability(0, one, 0, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, two, 0, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "control: two events, two triggers of 1")
	assert_eq(_items_of(agony), 0)


func test_fungusaur_grows_once_for_two_simultaneous_blockers() -> void:
	var fungus := put_battlefield(0, "Fungusaur")
	g.add_counters(fungus, "+1/+1", 2)   # a 4/4, so it lives through it
	var a := put_battlefield(1, "Mons's Goblin Raiders")
	var b := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [fungus.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: fungus.id, b.id: fungus.id}))
	_to_combat_damage()
	assert_eq(_items_of(fungus), 1, "dealt damage ONCE by the two blockers")
	resolve_stack()
	assert_eq(fungus.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(fungus.counters.get("+1/+1", 0)), 3, "one more counter, not two")


func test_mortal_wound_triggers_once_for_two_blockers() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var wound := _cast(0, "Mortal Wound", [TargetRef.card(wurm)])
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {a.id: wurm.id, b.id: wurm.id}))
	_to_combat_damage()
	assert_eq(_items_of(wound), 1, "one damage event, one trigger")


func test_living_artifact_charges_once_for_two_unblocked_attackers() -> void:
	var thopter := put_battlefield(0, "Ornithopter")
	var battery := _cast(0, "Living Artifact", [TargetRef.card(thopter)])
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()   # P1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id, giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	_to_combat_damage()
	assert_eq(_items_of(battery), 1, "you were dealt damage once, by two sources")
	resolve_stack()
	assert_eq(int(battery.counters.get("vitality", 0)), 5, "that much: 2 + 3")


func test_first_strike_and_regular_damage_are_two_events() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	var knight := put_battlefield(0, "White Knight")   # first strike
	var bear := put_battlefield(0, "Grizzly Bears")
	var agony := _cast(0, "Binding Agony", [TargetRef.card(wurm)])
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {knight.id: wurm.id, bear.id: wurm.id}))
	var guard := 0
	while _items_of(agony) == 0 and guard < 40:
		_advance_once()
		guard += 1
	assert_eq(_items_of(agony), 1, "the first-strike step is an event of its own")
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	_to_combat_damage()
	assert_eq(_items_of(agony), 1, "and the regular step another")
	resolve_stack()
	assert_eq(g.players[1].life, 16)


## The AI's aftermath forecast is event-agnostic: Fungusaur's one
## WAS_DEALT_DAMAGE trigger is settled in the preview (one counter, not
## two) and the preview leaves the position untouched.
func test_the_damage_forecast_settles_the_one_victim_trigger() -> void:
	var fungus := put_battlefield(0, "Fungusaur")
	g.add_counters(fungus, "+1/+1", 2)
	var a := put_battlefield(1, "Mons's Goblin Raiders")
	var b := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [fungus.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: fungus.id, b.id: fungus.id}))
	var before := AiObservation.key(g, 0)
	var future := g.forecast_damage(true, false, true)
	assert_true(bool(future.aftermath.complete))
	assert_eq(int(future.aftermath.resolved), 1, "one trigger to settle")
	assert_eq(future.stats[fungus.id], Vector2i(5, 5), "one more counter")
	assert_eq(AiObservation.key(g, 0), before, "the preview changes nothing")
	assert_eq(int(fungus.counters.get("+1/+1", 0)), 2)


## The online journal (SgJournal) mirrors event types by name: the damage
## lines come from DAMAGE_DEALT alone, one per packet, and the new victim
## event adds none.
func test_the_online_journal_ignores_the_victim_event() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var journal := SgJournal.new(g)
	var seen := {"dealt": 0, "was_dealt": 0}
	var count := func(event: GameEvent) -> void:
		if event.type == Mtg.EventType.DAMAGE_DEALT: seen["dealt"] += 1
		elif event.type == Mtg.EventType.WAS_DEALT_DAMAGE: seen["was_dealt"] += 1
	g.event_occurred.connect(count)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {a.id: wurm.id, b.id: wurm.id}))
	_to_combat_damage()
	g.event_occurred.disconnect(count)
	assert_eq(int(seen["was_dealt"]), 3, "the Wurm once, each bear once")
	for viewer in 2:
		var lines := 0
		for entry in journal.entries[viewer]:
			if String(entry["kind"]) == "damage":
				lines += 1
		assert_eq(lines, int(seen["dealt"]), "one journal line per packet, none for the victim event")
	g.event_occurred.disconnect(journal._event)
	g.information_revealed.disconnect(journal._information)
	g.state_changed.disconnect(journal.observe)


## CR 704.5q's answer is DERIVED from the transmitted forks: the LAN
## referee (SgTableRules.apply) and every seat's view of the table
## (SgTableRules.options) agree on every preset and on a hand-mixed table,
## which follows the damage-prevention window fork.
func test_lan_table_rules_give_every_seat_the_same_annihilation_answer() -> void:
	var tables: Array[Dictionary] = []
	var expected: Array[bool] = []
	for preset in ["modern", "modern_mana_burn", "fifth"]:
		var options := RulesOptions.new()
		options.set_preset(preset)
		tables.append(SgTableRules.from_options(20, options))
		expected.append(preset != "fifth")
	var mixed := RulesOptions.new()
	mixed.set_preset("fifth")
	mixed.damage_prevention_window = false
	tables.append(SgTableRules.from_options(20, mixed))
	expected.append(true)
	mixed = RulesOptions.new()
	mixed.damage_prevention_window = true
	tables.append(SgTableRules.from_options(20, mixed))
	expected.append(false)
	tables.append(SgTableRules.standard())
	expected.append(true)
	for i in tables.size():
		var wire := SgTableRules.normalize(tables[i].duplicate(true))
		assert_true(SgTableRules.valid(wire))
		var referee := MtgGame.new()
		SgTableRules.apply(referee, wire)
		var host_view := SgTableRules.options(wire)
		var guest_view := SgTableRules.options(SgTableRules.normalize(wire.duplicate(true)))
		assert_eq(referee.rules.counters_annihilate(), expected[i], "table %d" % i)
		assert_eq(host_view.counters_annihilate(), expected[i], "table %d, host's view" % i)
		assert_eq(guest_view.counters_annihilate(), expected[i], "table %d, guest's view" % i)
