extends GameTest
## Pack 8, batch B1: the Visions and Weatherlight phasing cards
## (cards/sets/vis/_phasing.gd, cards/sets/wth/_phasing.gd) on engine
## package E1 (CR 702.26): Equipoise's three counted rounds, Teferi's
## Realm's per-upkeep choice, Time and Tide's simultaneous swap, the
## Shimmering Efreet's phase-in trigger, Ertai's Familiar's "phases out or
## leaves" and "can't phase out", Teferi's Veil's end-of-combat fade, and a
## phased-out permanent that is neither counted, targeted nor attacking.


class Scripted extends DecisionAgent:
	var options: Array = []
	var answers: Array = []
	var picks: Array = []
	var asked: Array[String] = []

	func answer_option(_g: MtgGame, _p: int, prompt: String,
			labels: Array[String], hint: int) -> int:
		asked.append(prompt)
		if options.is_empty():
			return hint
		var want: Variant = options.pop_front()
		if want is String:
			for i in labels.size():
				if labels[i].to_lower().contains(String(want).to_lower()):
					return i
			return hint
		return int(want)

	func answer_yes_no(_g: MtgGame, _p: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		if want == null:
			return null
		for c in candidates:
			if want is CardInstance and c == want:
				return c
			if want is String and c.data.card_name == want:
				return c
		return null if candidates.is_empty() else candidates[0]


var p0: Scripted
var p1: Scripted


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	p0 = seat(0)
	p1 = seat(1)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a


func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)


func cast(name: String, targets: Array = [], mode := 0, pid := 0) -> CardInstance:
	var card := give_hand(pid, name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets, 0, mode))
	resolve_stack()
	return card


func activate(inst: CardInstance, index: int, targets: Array = [], pid := 0) -> void:
	assert_ok(g.activate_ability(pid, inst, index, targets))
	resolve_stack()


func phased(list: Array) -> int:
	var n := 0
	for i in list:
		if i.phased_out: n += 1
	return n


# ------------------------------------------- printed phasing (both sets) --

func test_breezekeeper_and_tolarian_drake_fly_and_cycle() -> void:
	for name in ["Breezekeeper", "Tolarian Drake"]:
		var body := put_battlefield(0, name)
		assert_true(body.has_keyword(Mtg.Keyword.PHASING), name)
		assert_true(body.has_keyword(Mtg.Keyword.FLYING), name)
	var breeze := g.players[0].battlefield[0]
	var drake := g.players[0].battlefield[1]
	g.tap_permanent(breeze)
	advance_to_next_turn()
	assert_eq(phased([breeze, drake]), 0, "not on the opponent's untap step")
	advance_to_next_turn()   # turn 3
	assert_eq(phased([breeze, drake]), 2)
	assert_true(breeze.tapped)
	advance_to_next_turn()
	assert_eq(phased([breeze, drake]), 2, "out through P1's turn")
	advance_to_next_turn()   # turn 5
	assert_eq(phased([breeze, drake]), 0)
	assert_false(breeze.tapped, "phased in, then untapped")


# ---------------------------------------------- Rainbow Efreet / Honor Guard --

func test_rainbow_efreet_phases_out_in_response_and_the_bolt_fizzles() -> void:
	var efreet := put_battlefield(0, "Rainbow Efreet")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(efreet)]))
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, efreet, 0))
	resolve_stack()
	assert_true(efreet.phased_out)
	assert_eq(efreet.damage, 0)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "countered on resolution for its illegal target")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(efreet.phased_out)
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD)


func test_teferis_honor_guard_has_flanking_and_phases_out() -> void:
	var guard := put_battlefield(0, "Teferi's Honor Guard")
	assert_true(guard.has_keyword(Mtg.Keyword.FLANKING))
	add_mana(0, Mtg.ManaColor.U, 2)
	activate(guard, 0)
	assert_true(guard.phased_out)
	advance_to_next_turn()
	assert_true(guard.phased_out)
	advance_to_next_turn()
	assert_false(guard.phased_out)


# ------------------------------------------------------- Shimmering Efreet --

func test_shimmering_efreet_phases_a_creature_out_as_it_phases_in() -> void:
	var efreet := put_battlefield(0, "Shimmering Efreet")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: the Efreet phases out (no trigger)
	assert_true(efreet.phased_out)
	assert_false(giant.phased_out)
	advance_to_next_turn()
	advance_to_next_turn()   # turn 5: in; the trigger waits for the upkeep and takes the Giant
	assert_false(efreet.phased_out)
	assert_true(giant.phased_out, "whenever it phases in, target creature phases out")
	advance_to_next_turn()   # turn 6: P1's untap step brings it back
	assert_false(giant.phased_out)


# --------------------------------------------------------------- Vanishing --

func test_vanishing_phases_its_creature_out_and_rides_along() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var vanishing := cast("Vanishing", [TargetRef.card(bear)])
	add_mana(0, Mtg.ManaColor.U, 2)
	activate(vanishing, 0)
	assert_true(bear.phased_out)
	assert_true(vanishing.phased_out and vanishing.phased_indirectly)
	advance_to_next_turn()
	assert_true(bear.phased_out)
	advance_to_next_turn()
	assert_false(bear.phased_out)
	assert_eq(vanishing.attached_to, bear.id)


func test_vanishing_on_an_opponents_creature_returns_on_their_step() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var vanishing := cast("Vanishing", [TargetRef.card(giant)])
	add_mana(0, Mtg.ManaColor.U, 2)
	activate(vanishing, 0)
	assert_true(giant.phased_out)
	advance_to_next_turn()   # P1's untap step: the Giant and the rider back
	assert_false(giant.phased_out)
	assert_false(vanishing.phased_out)


# ----------------------------------------------------------- Time and Tide --

func test_time_and_tide_swaps_phased_out_creatures_and_phasers_at_once() -> void:
	var gone := put_battlefield(1, "Hill Giant")
	assert_true(g.phase_out(gone))
	var drake := put_battlefield(0, "Teferi's Drake")
	var their_drake := put_battlefield(1, "Tolarian Drake")
	var bear := put_battlefield(0, "Grizzly Bears")
	var land := put_battlefield(1, "Forest")
	assert_true(g.phase_out(land))
	cast("Time and Tide")
	assert_false(gone.phased_out, "all phased-out creatures phase in")
	assert_true(drake.phased_out and their_drake.phased_out, "all creatures with phasing phase out")
	assert_false(bear.phased_out, "no phasing: untouched")
	assert_true(land.phased_out, "only creatures phase in")


# --------------------------------------------------------------- Equipoise --

func test_equipoise_phases_out_the_excess_lands_artifacts_and_creatures() -> void:
	put_battlefield(0, "Equipoise")
	for i in 2: put_battlefield(0, "Plains")
	put_battlefield(0, "Grizzly Bears")
	var their_lands: Array[CardInstance] = []
	for i in 4: their_lands.append(put_battlefield(1, "Forest"))
	var ring := put_battlefield(1, "Sol Ring")
	var creatures: Array[CardInstance] = [put_battlefield(1, "Hill Giant"),
		put_battlefield(1, "Grizzly Bears"), put_battlefield(1, "Serra Angel")]
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: P0's upkeep
	assert_eq(phased(their_lands), 2, "two lands in excess")
	assert_true(ring.phased_out, "one artifact in excess")
	assert_eq(phased(creatures), 2, "two creatures in excess")
	assert_true(creatures[2].phased_out, "the hint picks the best creature first")
	advance_to_next_turn()   # turn 4: P1's untap step brings them all back
	assert_eq(phased(their_lands) + phased(creatures), 0)
	assert_false(ring.phased_out)


func test_equipoise_does_not_count_a_phased_out_creature() -> void:
	put_battlefield(0, "Equipoise")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Forest")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()   # turn 2: P1's
	assert_true(g.phase_out(giant))   # gone until P1's next untap step (turn 4)
	advance_to_next_turn()   # turn 3: P0's upkeep — one creature each
	assert_false(bear.phased_out, "a phased-out creature doesn't exist to be counted (702.26b)")


func test_equipoise_targeting_yourself_does_nothing() -> void:
	put_battlefield(0, "Equipoise")
	var theirs := [put_battlefield(1, "Grizzly Bears"), put_battlefield(1, "Hill Giant")]
	advance_to_next_turn()
	p0.options = [1]   # the trigger's player target: the second one offered — P0
	advance_to_next_turn()
	assert_eq(phased(theirs), 0)
	assert_true(p0.asked.size() >= 1)


# ------------------------------------------------------------ Teferi's Realm --

func test_teferis_realm_phases_out_the_chosen_type_on_each_upkeep() -> void:
	put_battlefield(0, "Teferi's Realm")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var token: CardInstance = g.create_token(1, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	var land := put_battlefield(1, "Forest")
	p1.options = ["Creature"]
	advance_to_next_turn()   # turn 2: P1's upkeep — P1 chooses
	assert_true(mine.phased_out and theirs.phased_out, "all nontoken creatures")
	assert_false(token.phased_out, "tokens stay")
	assert_false(land.phased_out)
	assert_true(p1.asked.any(func(q: String) -> bool: return q.begins_with("Teferi's Realm")))
	p0.options = ["Land"]
	advance_to_next_turn()   # turn 3: P0's untap brings the Bears back, P0's upkeep takes lands
	assert_false(mine.phased_out)
	assert_true(theirs.phased_out, "P1's Giant waits for P1's untap step")
	assert_true(land.phased_out)


func test_teferis_realm_non_aura_enchantment_spares_auras() -> void:
	var realm := put_battlefield(0, "Teferi's Realm")
	var bear := put_battlefield(0, "Grizzly Bears")
	var vanishing := cast("Vanishing", [TargetRef.card(bear)])
	p1.options = ["Non-Aura"]
	advance_to_next_turn()
	assert_true(realm.phased_out, "the Realm itself is a non-Aura enchantment")
	assert_false(vanishing.phased_out)


# ------------------------------------------------------------ Vision Charm --

func test_vision_charm_mills_four() -> void:
	var before := g.players[1].library.size()
	cast("Vision Charm", [TargetRef.player(1)], 0)
	assert_eq(g.players[1].library.size(), before - 4)
	assert_eq(g.players[1].graveyard.size(), 4)


func test_vision_charm_retypes_the_lands_of_a_type_until_end_of_turn() -> void:
	var islands := [put_battlefield(0, "Island"), put_battlefield(0, "Island")]
	var forest := put_battlefield(0, "Forest")
	p0.options = ["Island", "Mountain"]
	cast("Vision Charm", [], 1)
	for island in islands:
		assert_true(island.has_subtype("mountain"))
		assert_false(island.has_subtype("island"), "becomes the second type (CR 305.7)")
	assert_true(forest.has_subtype("forest"))
	assert_ok(g.tap_for_mana(0, islands[0]))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1, "a Mountain taps for {R}")
	var late := put_battlefield(0, "Island")
	assert_true(late.has_subtype("island"), "only the lands of that type as it resolved (CR 611.2c)")
	advance_to_next_turn()
	for island in islands:
		assert_true(island.has_subtype("island"), "until end of turn")


func test_vision_charm_phases_out_only_an_artifact() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var bear := put_battlefield(1, "Grizzly Bears")
	var charm := give_hand(0, "Vision Charm")
	fund(0, charm)
	assert_refused(g.cast_spell(0, charm, [TargetRef.card(bear)], 0, 2), "")
	assert_ok(g.cast_spell(0, charm, [TargetRef.card(ring)], 0, 2))
	resolve_stack()
	assert_true(ring.phased_out)


# --------------------------------------------------------- Katabatic Winds --

func test_katabatic_winds_grounds_flyers_and_bans_their_tap_abilities() -> void:
	var winds := put_battlefield(1, "Katabatic Winds")
	assert_true(winds.has_keyword(Mtg.Keyword.PHASING))
	var angel := put_battlefield(0, "Serra Angel")
	var birds := put_battlefield(0, "Birds of Paradise")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.tap_for_mana(0, birds), "")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [angel.id]))
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var their_flyer := put_battlefield(1, "Serra Angel")
	assert_refused(g.declare_blockers(1, {their_flyer.id: bear.id}), "")


func test_katabatic_winds_phased_out_lets_flyers_fly() -> void:
	var winds := put_battlefield(1, "Katabatic Winds")
	var angel := put_battlefield(0, "Serra Angel")
	advance_to_next_turn()   # P1's untap step: the Winds phase out
	assert_true(winds.phased_out)
	advance_to_next_turn()   # turn 3, P0
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [angel.id]))   # the Winds don't exist while phased out


# --------------------------------------------------------- Ertai's Familiar --

func test_ertais_familiar_mills_three_as_it_phases_out() -> void:
	var familiar := put_battlefield(0, "Ertai's Familiar")
	advance_to_next_turn()
	var before := g.players[0].library.size()
	advance_to_next_turn()   # turn 3: out at the untap step; mill at the upkeep; then the draw
	assert_true(familiar.phased_out)
	assert_eq(g.players[0].library.size(), before - 4, "three milled plus the draw")
	assert_eq(g.players[0].graveyard.size(), 3)


func test_ertais_familiar_mills_three_as_it_dies() -> void:
	var familiar := put_battlefield(0, "Ertai's Familiar")
	var before := g.players[0].library.size()
	g.destroy(familiar)
	resolve_stack()
	assert_eq(g.players[0].library.size(), before - 3)


func test_a_stolen_ertais_familiar_mills_its_last_controller() -> void:
	var familiar := put_battlefield(1, "Ertai's Familiar")
	g.change_control(familiar, 0)
	var mine := g.players[0].library.size()
	var theirs := g.players[1].library.size()
	g.destroy(familiar)
	resolve_stack()
	assert_eq(g.players[0].library.size(), mine - 3, "\"you\" is the trigger's controller (CR 603.3a)")
	assert_eq(g.players[1].library.size(), theirs)


func test_ertais_familiar_can_hold_itself_in_until_the_next_upkeep() -> void:
	var familiar := put_battlefield(0, "Ertai's Familiar")
	add_mana(0, Mtg.ManaColor.U)
	activate(familiar, 0)
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: the untap step comes before the upkeep
	assert_false(familiar.phased_out, "can't phase out")
	assert_eq(g.players[0].graveyard.size(), 0, "and so nothing was milled")
	assert_false(familiar.cur_cant_phase_out, "until your next upkeep — over now")
	advance_to_next_turn()
	advance_to_next_turn()   # turn 5
	assert_true(familiar.phased_out)


# ------------------------------------------------------------ Teferi's Veil --

func test_teferis_veil_fades_its_attackers_at_end_of_combat() -> void:
	put_battlefield(0, "Teferi's Veil")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var home := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id, giant.id])
	assert_eq(g.players[1].life, 15, "they dealt their damage first")
	resolve_stack()   # each fade is a delayed trigger on the stack (CR 603.7)
	assert_true(bear.phased_out and giant.phased_out, "phased out at end of combat")
	assert_false(home.phased_out, "only the creatures that attacked")
	advance_to_next_turn()
	assert_true(bear.phased_out, "not there to block on P1's turn")
	advance_to_next_turn()
	assert_false(bear.phased_out or giant.phased_out)


func test_teferis_veil_ignores_the_opponents_attackers() -> void:
	put_battlefield(0, "Teferi's Veil")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()
	run_combat([giant.id])
	assert_false(giant.phased_out)


# ------------------------------------------------------ Vodalian Illusionist --

func test_vodalian_illusionist_taps_to_phase_a_creature_out() -> void:
	var illusionist := put_battlefield(0, "Vodalian Illusionist")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.U, 2)
	activate(illusionist, 0, [TargetRef.card(giant)])
	assert_true(illusionist.tapped)
	assert_true(giant.phased_out)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, illusionist, 0, [TargetRef.card(illusionist)]))
	advance_to_next_turn()
	assert_false(giant.phased_out)
