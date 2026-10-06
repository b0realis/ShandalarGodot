extends GameTest
## Pack 9 bug pass (fix-engine) — Humility as printed against what a
## permanent does as it ENTERS (CR 614.12), as it LEAVES (CR 603.10a), as
## it untaps (CR 613.1f) and against a durationless grant made after it
## (CR 613.7, 611.2). Findings h4-1, h4-2 / h6-1, h4-3 and h4-4.
##
## The 1997 preset has no rule fork for any of this (the layers and the
## look-back are the same in both), so the main shapes are run in both.

const PRESETS: Array[String] = ["modern", "fifth"]


## A seat whose card answers are scripted by name (else the first), and
## which remembers every prompt it was asked.
class Seat extends DecisionAgent:
	var prefer: Array = []
	var asked: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-2", true)   # Dwarven Ruins (Fallen Empires)
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_edition(preset)


func _enchant_named(pid: int, card_name: String, host: CardInstance) -> CardInstance:
	var aura := _make_instance(pid, card_name)
	g._put_on_battlefield(aura, pid, host)
	return aura


# ---------------------------------------------------------------- h4-1 --
# CR 603.10a: a leaves-the-battlefield ability "looks back in time". A
# creature that left while it had NO abilities (Humility, face down) has
# no printed dies trigger to fire.

func test_a_humbled_personal_incarnation_dying_costs_nothing() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var avatar := put_battlefield(0, "Personal Incarnation")
		put_battlefield(1, "Humility")
		assert_true(avatar.cur_abilities_silenced, "%s: precondition, humbled" % preset)
		g.destroy(avatar)
		resolve_stack()
		assert_eq(avatar.zone, Mtg.Zone.GRAVEYARD, "%s: precondition, it died" % preset)
		assert_eq(g.players[0].life, 20,
			"%s: it had no 'When this creature dies' ability as it left (CR 603.10a)" % preset)


func test_a_humbled_creature_in_a_wrath_fires_no_printed_dies_trigger() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Humility")
	var wrath := give_hand(1, "Wrath of God")
	advance_to_next_turn()   # P1's main phase
	add_mana(1, Mtg.ManaColor.W, 2)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, wrath))
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.GRAVEYARD, "precondition: it died")
	assert_eq(g.players[0].life, 20,
		"it had no 'When this creature dies' ability as it left (CR 603.10a)")


func test_a_face_down_personal_incarnation_dying_costs_nothing() -> void:
	var avatar := give_hand(0, "Personal Incarnation")
	g.put_from_hand_face_down(avatar, 0)   # Illusionary Mask's route
	assert_true(avatar.face_down, "precondition: a nameless 2/2")
	g.destroy(avatar)
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20, "a face-down creature has no abilities (CR 708.2)")


## Controls: the look-back reads what the creature had AS IT LEFT, so the
## printed trigger still fires without Humility, and once Humility has
## gone again.
func test_personal_incarnation_dying_without_humility_still_halves_the_life() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var avatar := put_battlefield(0, "Personal Incarnation")
		g.destroy(avatar)
		resolve_stack()
		assert_eq(g.players[0].life, 10, "%s: the printed dies trigger" % preset)


func test_personal_incarnation_dying_after_humility_left_halves_the_life() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	var humility := put_battlefield(1, "Humility")
	assert_true(avatar.cur_abilities_silenced)
	g.destroy(humility)
	assert_false(avatar.cur_abilities_silenced, "precondition: its abilities are back")
	g.destroy(avatar)
	resolve_stack()
	assert_eq(g.players[0].life, 10)


func test_a_wrath_without_humility_still_fires_the_dies_trigger() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	put_battlefield(0, "Grizzly Bears")
	var wrath := give_hand(1, "Wrath of God")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.W, 2)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, wrath))
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 10)


# ---------------------------------------------------------- h4-2 / h6-1 --
# CR 614.12: a replacement effect that modifies how a permanent enters is
# judged on the permanent as it would exist on the battlefield, with the
# continuous effects that already exist (Humility). Under Humility a
# creature has no abilities as it enters, so its OWN "enters with
# counters", "as this enters" and "enters as a copy" do not apply.

func test_a_spike_entering_under_humility_gets_no_counters() -> void:
	for preset in PRESETS:
		_fresh(preset)
		put_battlefield(1, "Humility")
		var colony := put_battlefield(0, "Spike Colony")
		assert_true(colony.cur_abilities_silenced, "%s: precondition, humbled" % preset)
		assert_eq(int(colony.counters.get("+1/+1", 0)), 0,
			"%s: 'enters with four +1/+1 counters' is an ability Humility removed" % preset)
		assert_eq([colony.cur_power, colony.cur_toughness], [1, 1], preset)


func test_a_spike_cast_under_humility_enters_without_counters() -> void:
	put_battlefield(1, "Humility")
	advance_to_step(Mtg.Step.MAIN1)
	var feeder := give_hand(0, "Spike Feeder")
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(0, feeder, []))
	resolve_stack()
	assert_eq(feeder.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(feeder.counters.get("+1/+1", 0)), 0)
	assert_eq([feeder.cur_power, feeder.cur_toughness], [1, 1])


func test_a_spike_hatcher_under_humility_is_a_one_one() -> void:
	put_battlefield(1, "Humility")
	var hatcher := put_battlefield(0, "Spike Hatcher")
	assert_eq([hatcher.cur_power, hatcher.cur_toughness], [1, 1])


func test_artifact_creatures_entering_under_humility_get_no_counters() -> void:
	put_battlefield(1, "Humility")
	var trisk := put_battlefield(0, "Triskelion")
	var horse := put_battlefield(0, "Workhorse")
	assert_eq(int(trisk.counters.get("+1/+1", 0)), 0, "Triskelion")
	assert_eq(int(horse.counters.get("+1/+1", 0)), 0, "Workhorse")
	assert_eq([trisk.cur_power, trisk.cur_toughness], [1, 1])
	assert_eq([horse.cur_power, horse.cur_toughness], [1, 1])


func test_krakilin_cast_for_x_under_humility_gets_no_counters() -> void:
	put_battlefield(1, "Humility")
	advance_to_step(Mtg.Step.MAIN1)
	var krakilin := give_hand(0, "Krakilin")
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, krakilin, [], 3))
	resolve_stack()
	assert_eq(krakilin.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(krakilin.counters.get("+1/+1", 0)), 0)
	assert_eq([krakilin.cur_power, krakilin.cur_toughness], [1, 1])


func test_dracoplasm_entering_under_humility_eats_nothing() -> void:
	for preset in PRESETS:
		_fresh(preset)
		put_battlefield(1, "Humility")
		var bear := put_battlefield(0, "Grizzly Bears")
		var plasm := put_battlefield(0, "Dracoplasm")
		assert_true(plasm.cur_abilities_silenced, "%s: precondition, humbled" % preset)
		assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD,
			"%s: its 'As this enters, sacrifice any number of creatures' does not apply" % preset)
		assert_eq([plasm.cur_power, plasm.cur_toughness], [1, 1], preset)


func test_clone_entering_under_humility_copies_nothing() -> void:
	var seat := Seat.new()
	g.set_agent(0, seat)
	seat.prefer = ["Serra Angel"]
	put_battlefield(1, "Humility")
	put_battlefield(1, "Serra Angel")
	var clone := put_battlefield(0, "Clone")
	assert_false(seat.asked.any(func(p: String) -> bool: return p.begins_with("Copy")),
		"Clone has no 'enter as a copy' ability as it would exist (CR 614.12)")
	assert_eq(clone.data.card_name, "Clone")
	assert_eq(clone.zone, Mtg.Zone.BATTLEFIELD, "a 1/1 under Humility, not a 0/0")
	assert_eq([clone.cur_power, clone.cur_toughness], [1, 1])


## Copy Artifact is not a creature, so Humility does not reach it as it
## would exist: it copies. What it copied is then an artifact creature,
## and Humility does reach THAT — the copied "enters with counters" is
## gone (CR 614.12: "taking into account replacement effects that have
## already modified how it enters").
func test_copy_artifact_under_humility_copies_but_a_copied_triskelion_gets_no_counters() -> void:
	var seat := Seat.new()
	g.set_agent(0, seat)
	seat.prefer = ["Triskelion"]
	put_battlefield(1, "Humility")
	put_battlefield(1, "Triskelion")
	var copy := put_battlefield(0, "Copy Artifact")
	assert_true(seat.asked.any(func(p: String) -> bool: return p.begins_with("Copy")),
		"Copy Artifact's own replacement applies")
	assert_eq(copy.data.card_name, "Triskelion")
	assert_true(copy.cur_abilities_silenced, "a humbled artifact creature")
	assert_eq(int(copy.counters.get("+1/+1", 0)), 0)
	assert_eq([copy.cur_power, copy.cur_toughness], [1, 1])


## Controls: no Humility, the counters arrive; a Spike that entered before
## Humility keeps them (counters are not abilities); a Clone copies.
func test_a_spike_entering_without_humility_gets_its_counters() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var colony := put_battlefield(0, "Spike Colony")
		assert_eq(int(colony.counters.get("+1/+1", 0)), 4, preset)


func test_a_spike_already_out_keeps_its_counters_when_humility_arrives() -> void:
	var feeder := put_battlefield(0, "Spike Feeder")
	put_battlefield(1, "Humility")
	assert_eq(int(feeder.counters.get("+1/+1", 0)), 2)
	assert_eq([feeder.cur_power, feeder.cur_toughness], [3, 3])


func test_a_clone_without_humility_copies_a_spike_with_its_counters() -> void:
	var seat := Seat.new()
	g.set_agent(0, seat)
	seat.prefer = ["Spike Feeder"]
	put_battlefield(1, "Spike Feeder")
	var clone := put_battlefield(0, "Clone")
	assert_eq(clone.data.card_name, "Spike Feeder")
	assert_eq(int(clone.counters.get("+1/+1", 0)), 2,
		"the copied 'enters with counters' applies once the copy has (CR 614.12)")


func test_a_spike_entering_after_humility_left_gets_its_counters() -> void:
	var humility := put_battlefield(1, "Humility")
	g.destroy(humility)
	var colony := put_battlefield(0, "Spike Colony")
	assert_eq(int(colony.counters.get("+1/+1", 0)), 4)


## The same reading for a land's own "enters tapped" under Blood Moon: as
## it would exist on the battlefield it is a Mountain with no other
## abilities (CR 305.7), so it enters untapped (CR 614.12).
func test_a_nonbasic_land_that_enters_tapped_enters_untapped_under_blood_moon() -> void:
	for preset in PRESETS:
		_fresh(preset)
		put_battlefield(1, "Blood Moon")
		var ruins := put_battlefield(0, "Dwarven Ruins")
		assert_true(ruins.has_subtype("mountain"), "%s: precondition, a Mountain" % preset)
		assert_false(ruins.tapped, "%s: its own 'enters tapped' is gone (CR 614.12)" % preset)


func test_a_nonbasic_land_that_enters_tapped_still_does_without_blood_moon() -> void:
	var ruins := put_battlefield(0, "Dwarven Ruins")
	assert_true(ruins.tapped)


# ---------------------------------------------------------------- h4-3 --
# "You may choose not to untap" is a static ability of the creature: under
# Humility it has none, so it untaps — and Coffin Queen's raised creature
# is exiled as she untaps.

func test_coffin_queen_under_humility_untaps_and_loses_its_creature() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var queen := put_battlefield(0, "Coffin Queen")
		var dead := _make_instance(1, "Grizzly Bears")
		dead.zone = Mtg.Zone.GRAVEYARD
		g.players[1].graveyard.append(dead)
		advance_to_step(Mtg.Step.MAIN1)
		add_mana(0, Mtg.ManaColor.B, 1)
		add_mana(0, Mtg.ManaColor.C, 2)
		assert_ok(g.activate_ability(0, queen, 0, [TargetRef.card(dead)]))
		resolve_stack()
		assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD, "%s: precondition, raised" % preset)
		assert_true(queen.tapped)
		put_battlefield(1, "Humility")
		assert_true(queen.cur_abilities_silenced, "%s: precondition, humbled" % preset)
		advance_to_next_turn()   # P1
		advance_to_next_turn()   # P0: its untap step has run
		assert_false(queen.tapped,
			"%s: a humbled Coffin Queen has no 'You may choose not to untap'" % preset)
		assert_ne(dead.zone, Mtg.Zone.BATTLEFIELD,
			"%s: the raised creature is exiled as she untaps" % preset)


func test_coffin_queen_without_humility_may_stay_tapped() -> void:
	var queen := put_battlefield(0, "Coffin Queen")
	var dead := _make_instance(1, "Grizzly Bears")
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[1].graveyard.append(dead)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, queen, 0, [TargetRef.card(dead)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(queen.tapped, "the default seat keeps her tapped to keep the creature")
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- h4-4 --
# A grant with NO duration made AFTER Humility (Cocoon's "that creature
# gains flying", Rainbow Knights' protection) is a later layer-6 effect
# than Humility's removal and survives it (CR 613.7, 611.2); one made
# BEFORE it is removed.

func _hatch_cocoon_on(bear: CardInstance) -> CardInstance:
	var cocoon := _enchant_named(0, "Cocoon", bear)
	resolve_stack()   # its enters trigger: three pupa counters
	cocoon.counters.erase("pupa")   # setup: the last counter came off
	return cocoon


func test_cocoons_flying_granted_after_humility_survives() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var bear := put_battlefield(0, "Grizzly Bears")
		var cocoon := _hatch_cocoon_on(bear)
		put_battlefield(1, "Humility")
		advance_to_next_turn()   # P1
		advance_to_next_turn()   # P0's upkeep: Cocoon hatches
		assert_eq(cocoon.zone, Mtg.Zone.GRAVEYARD, "%s: precondition, sacrificed" % preset)
		assert_eq(int(bear.counters.get("+1/+1", 0)), 1, "%s: precondition, the counter" % preset)
		assert_true(bear.has_keyword(Mtg.Keyword.FLYING),
			"%s: flying granted after Humility is the later effect (CR 613.7)" % preset)
		assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "%s: 1/1 plus the counter" % preset)


func test_cocoons_flying_granted_before_humility_is_removed() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var cocoon := _hatch_cocoon_on(bear)
	advance_to_next_turn()
	advance_to_next_turn()   # hatched
	assert_eq(cocoon.zone, Mtg.Zone.GRAVEYARD)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "precondition: it flies")
	put_battlefield(1, "Humility")
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING),
		"Humility is the later effect: the grant is removed")


func test_a_durationless_grant_after_humility_falls_to_a_newer_humility() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Humility")
	g.grant_keyword_permanently(bear, Mtg.Keyword.FLYING)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "the grant is newer")
	put_battlefield(0, "Humility")
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING),
		"a second, newer Humility removes it (the later strip wins)")


func test_rainbow_knights_protection_granted_after_humility_survives() -> void:
	var knights := put_battlefield(0, "Rainbow Knights")
	assert_false(g.stack.is_empty(), "precondition: its arrival trigger waits")
	put_battlefield(1, "Humility")   # in response, so to speak
	resolve_stack()   # the trigger is on the stack, independent of its source
	assert_ne(knights.added_protection, 0, "a colour was chosen")
	assert_eq(knights.cur_protection, knights.added_protection,
		"granted after Humility: the later effect (CR 613.7)")


func test_rainbow_knights_protection_granted_before_humility_is_removed() -> void:
	var knights := put_battlefield(0, "Rainbow Knights")
	resolve_stack()
	assert_ne(knights.cur_protection, 0, "precondition: protected")
	put_battlefield(1, "Humility")
	assert_eq(knights.cur_protection, 0, "Humility is the later effect")
