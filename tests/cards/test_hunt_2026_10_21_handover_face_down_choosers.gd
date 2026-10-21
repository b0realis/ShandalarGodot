extends GameTest
## THE SECOND BUG HUNT (2026-10-21), the handover: four cards that read the
## card under an Illusionary Mask.
##
## A face-down permanent is a 2/2 creature with no name and no mana cost
## (CR 708.2) — mana value 0 — and what it really is stays hidden from the
## other seat (CONTRIBUTING.md rule 8). WAS:
## - Plaguebearer ("destroy target nonblack creature with mana value X")
##   measured X against the printed cost under the mask: a masked Shivan
##   Dragon was a legal target at X = 6 — the one X that kills what nobody
##   showed — and not at X = 0;
## - Apocalypse Chime ("destroy all nontoken permanents with a name
##   originally printed in the Homelands expansion") destroyed a masked
##   Homelands card by the name it does not have;
## - Echo Chamber's chooser order and Crown of the Ages' host ranking —
##   both read by the AI as public facts — weighed the hidden mana value.
## NOW each reads mana value 0 and no name for a face-down permanent.


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	CardRegistry.ensure_loaded()


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _masked(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.put_from_hand_face_down(inst, pid)
	g.recalculate()
	assert_true(inst.face_down, "control: masked")
	return inst


func test_plaguebearer_sees_a_masked_creature_at_mana_value_zero() -> void:
	var plague := put_battlefield(0, "Plaguebearer")
	var dragon := _masked(1, "Shivan Dragon")   # mana value 6 under the mask
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 13)
	# The printed cost is hidden: it has no mana value 6.
	assert_refused(g.activate_ability(0, plague, 0, [TargetRef.card(dragon)], 6), "Illegal target")
	assert_ok(g.activate_ability(0, plague, 0, [TargetRef.card(dragon)], 0))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD, "a nonblack creature with mana value 0")


func test_apocalypse_chime_spares_a_masked_homelands_card() -> void:
	var chime := put_battlefield(0, "Apocalypse Chime")
	var masked := _masked(1, "Ihsan's Shade")     # Homelands, under the mask
	var shown := put_battlefield(1, "Ihsan's Shade")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, chime, 0))
	resolve_stack()
	assert_eq(shown.zone, Mtg.Zone.GRAVEYARD, "control: the face-up Shade is destroyed")
	assert_eq(masked.zone, Mtg.Zone.BATTLEFIELD, "a face-down permanent has no name")


func test_echo_chamber_order_weighs_a_masked_creature_as_shown() -> void:
	var chamber := put_battlefield(0, "Echo Chamber")
	var dragon := _masked(1, "Shivan Dragon")
	var bear := put_battlefield(1, "Grizzly Bears")
	var spec: TargetSpec = chamber.data.activated_abilities[0].effects[0].target_spec
	assert_true(spec.chooser_order.is_valid(), "control: the opponent's order")
	assert_true(bool(spec.chooser_order.call(g, chamber, TargetRef.card(dragon), TargetRef.card(bear))),
		"a 2/2 with mana value 0 is weaker than a 2/2 with mana value 2")
	assert_false(bool(spec.chooser_order.call(g, chamber, TargetRef.card(bear), TargetRef.card(dragon))))


func test_crown_of_the_ages_values_a_masked_host_as_shown() -> void:
	var patterns: GDScript = load("res://cards/sets/ice/_patterns.gd")
	var giant := put_battlefield(0, "Hill Giant")
	var strength := give_hand(0, "Holy Strength")
	g.attach_aura_from_anywhere(strength, giant, 0)
	var dragon := _masked(1, "Shivan Dragon")
	var plain := put_battlefield(1, "Grizzly Bears")
	var masked_worth: float = patterns.crown_value(g, strength, dragon, 0)
	assert_eq(masked_worth, -4.0, "2 + 2 + mana value 0, on their side")
	assert_eq(float(patterns.crown_value(g, strength, plain, 0)), -6.0, "control: 2 + 2 + 2")
