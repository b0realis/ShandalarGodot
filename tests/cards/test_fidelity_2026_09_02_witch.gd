extends GameTest
## Fidelity lift of 2026-09-02: Season of the Witch judges "creatures that
## couldn't attack" AS ATTACKERS WERE DECLARED (CR 508.1a — the only moment
## a creature can attack), not at the end step. The engine now takes a
## per-turn census in declare_attackers (CardInstance.could_attack_this_turn).


func _end_step_reaping() -> void:
	advance_to_step(Mtg.Step.END)
	resolve_stack()


func test_a_creature_tapped_at_declare_attackers_is_spared_even_if_it_untaps() -> void:
	put_battlefield(0, "Season of the Witch")
	var bear := put_battlefield(0, "Grizzly Bears")
	var twiddle := give_hand(0, "Twiddle")
	g.tap_permanent(bear)   # tapped BEFORE attackers are declared
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	advance_to_step(Mtg.Step.MAIN2)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, twiddle, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.tapped, "untapped after combat")
	assert_false(bear.could_attack_this_turn)
	_end_step_reaping()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD,
		"it couldn't attack when attackers were declared, so it is excused")


func test_a_creature_that_could_attack_is_reaped_even_if_it_later_gets_defender() -> void:
	# The census is what counts: an able creature that stayed home is doomed
	# even if a later effect would make attack_illegality excuse it now.
	put_battlefield(0, "Season of the Witch")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	assert_true(bear.could_attack_this_turn)
	advance_to_step(Mtg.Step.MAIN2)
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.DEFENDER])
	g.recalculate()
	assert_ne(CombatState.attack_illegality(g, bear, 1), "",
		"it can't attack NOW, but it could when it mattered")
	_end_step_reaping()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_a_creature_that_arrives_after_combat_is_spared() -> void:
	put_battlefield(0, "Season of the Witch")
	advance_to_step(Mtg.Step.MAIN2)
	var late := put_battlefield(0, "Grizzly Bears")
	late.summoning_sick = false   # even a hasty arrival never had the chance
	_end_step_reaping()
	assert_eq(late.zone, Mtg.Zone.BATTLEFIELD)


func test_the_census_is_taken_when_no_attackers_are_declared() -> void:
	# DECLARED_ATTACKERS is not dispatched for an empty declaration, but
	# the census is a turn-based action of the declaration itself.
	var bear := put_battlefield(0, "Grizzly Bears")
	var sick := put_battlefield(0, "Grizzly Bears", true)
	var wall := put_battlefield(0, "Wall of Wood")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	assert_true(bear.could_attack_this_turn)
	assert_false(sick.could_attack_this_turn, "summoning sickness")
	assert_false(wall.could_attack_this_turn, "defender")
	assert_false(theirs.could_attack_this_turn, "CR 508.1a: not the active player's")


func test_the_census_expires_with_the_turn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_true(bear.could_attack_this_turn)
	advance_to_next_turn()
	assert_false(bear.could_attack_this_turn)
