extends GameTest
## Engine tests for VARIABLE and DIVIDED targeting (engine/core/target_plan.gd).
##
## Three shapes the 1997 pool needs and the old one-ref-per-effect model
## could not express:
##   "X target creatures"                          (Word of Binding)
##   "any number of target ... cards"              (Drafna's Restoration)
##   "N damage divided as you choose among any number of targets" (Pyrotechnics)
## Everything here goes through the public cast/activate API, so the tests
## also pin the refusal messages the UI shows.


# ------------------------------------------------------- variable counts --

func test_x_targets_demands_exactly_x_refs() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var word := give_hand(0, "Word of Binding")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, word, [TargetRef.card(a)], 2), "needs 2 target")
	assert_ok(g.cast_spell(0, word, [TargetRef.card(a), TargetRef.card(b)], 2))
	resolve_stack()
	assert_true(a.tapped)
	assert_true(b.tapped)


func test_x_targets_takes_as_many_as_exist() -> void:
	# Only one legal creature on the board: X=3 taps the one that's there
	# rather than refusing (documented engine simplification).
	var lone := put_battlefield(1, "Grizzly Bears")
	var word := give_hand(0, "Word of Binding")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, word, [TargetRef.card(lone)], 3))
	resolve_stack()
	assert_true(lone.tapped)


func test_the_same_target_cant_fill_two_slots() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var word := give_hand(0, "Word of Binding")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, word, [TargetRef.card(bear), TargetRef.card(bear)], 2),
		"same target twice")


func test_doubled_x_cost_charges_twice() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var part := give_hand(0, "Part Water")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.cast_spell(0, part, [TargetRef.card(bear)], 1),
		"not enough mana")   # X=1 on {X}{X}{U} needs {2}{U}
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(0, part, [TargetRef.card(bear)], 1))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("island"))


# ------------------------------------------------------ divided amounts --

func test_divided_shares_must_add_up() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var pyro := give_hand(0, "Pyrotechnics")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.cast_spell(0, pyro,
		[TargetRef.card(a, 1), TargetRef.card(b, 1)]), "add up to 4")
	assert_ok(g.cast_spell(0, pyro, [TargetRef.card(a, 2), TargetRef.card(b, 2)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "2/2 took 2")
	assert_eq(b.damage, 2)


func test_every_divided_target_needs_at_least_one() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var pyro := give_hand(0, "Pyrotechnics")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.cast_spell(0, pyro,
		[TargetRef.card(a, 4), TargetRef.card(b, 0)]), "at least 1")


func test_a_lone_divided_target_absorbs_the_whole_total() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var pyro := give_hand(0, "Pyrotechnics")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, pyro, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "3/3 took all 4")


# ------------------------------------------- partial fizzle and legality --

func test_one_dead_target_doesnt_stop_the_rest() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var word := give_hand(0, "Word of Binding")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, word, [TargetRef.card(a), TargetRef.card(b)], 2))
	g.destroy(a)                     # one target leaves in response
	g.check_state_based_actions()
	resolve_stack()
	assert_true(b.tapped, "the surviving target is still tapped (CR 608.2c)")


func test_all_targets_gone_fizzles_the_spell() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var word := give_hand(0, "Word of Binding")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, word, [TargetRef.card(a), TargetRef.card(b)], 2))
	g.destroy(a)
	g.destroy(b)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(word.zone, Mtg.Zone.GRAVEYARD)
	assert_string_contains("\n".join(g.log_lines), "fizzles")


# ---------------------------------------------------- abilities take groups --

func test_ability_x_targets_reads_the_activation_x() -> void:
	var candelabra := put_battlefield(0, "Candelabra of Tawnos")
	var one := put_battlefield(0, "Forest")
	var two := put_battlefield(0, "Forest")
	g.tap_permanent(one)
	g.tap_permanent(two)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, candelabra, 0,
		[TargetRef.card(one), TargetRef.card(two)], 2))
	resolve_stack()
	assert_false(one.tapped)
	assert_false(two.tapped)
	assert_true(candelabra.tapped, "the {T} half of the cost was paid")


# ---------------------------------------------- single targets are untouched --

func test_plain_single_target_spells_still_work() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
