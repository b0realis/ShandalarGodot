extends GameTest
## Two lured attackers at once (CR 509.1c): a blocker obeys as many block
## requirements as it CAN. Found by the all-packs engine sweep of
## 2026-09-25 — two Elvish Bards attacking together refused every
## declaration, the empty one included, so the AI conceded and a human
## seat could never have left the declare-blockers step.


func _lured_pair() -> Array:
	var first := put_battlefield(0, "Grizzly Bears")
	var second := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	for attacker in [first, second]:
		var lure := give_hand(0, "Lure")
		add_mana(0, Mtg.ManaColor.G, 2)
		add_mana(0, Mtg.ManaColor.C)
		assert_ok(g.cast_spell(0, lure, [TargetRef.card(attacker)]))
		resolve_stack()
		assert_true(attacker.cur_must_be_blocked)
	return [first, second]


func test_one_blocker_each_satisfies_two_lures_however_they_are_dealt() -> void:
	var lured := _lured_pair()
	var wall := put_battlefield(1, "Wall of Wood")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lured[0].id, lured[1].id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "must block")
	assert_refused(g.declare_blockers(1, {wall.id: lured[0].id}), "Savannah Lions must block")
	assert_ok(g.declare_blockers(1, {wall.id: lured[0].id, lions.id: lured[1].id}))
	assert_eq(g.combat.blockers_of(lured[0].id), [wall.id])
	assert_eq(g.combat.blockers_of(lured[1].id), [lions.id])


func test_both_blockers_on_one_lure_leaves_the_other_unblocked_legally() -> void:
	var lured := _lured_pair()
	var wall := put_battlefield(1, "Wall of Wood")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lured[0].id, lured[1].id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: lured[1].id, lions.id: lured[1].id}))
	assert_eq(g.combat.blockers_of(lured[0].id), [])
	assert_eq(g.combat.blockers_of(lured[1].id).size(), 2)


func test_a_block_on_a_bystander_still_breaks_the_requirement() -> void:
	var lured := _lured_pair()
	var bystander := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Wood")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lured[0].id, lured[1].id, bystander.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: lured[0].id, lions.id: bystander.id}),
		"Savannah Lions must block")
	assert_ok(g.declare_blockers(1, {wall.id: lured[0].id, lions.id: lured[1].id}))


func test_a_creature_that_may_block_two_must_take_both_lures() -> void:
	var lured := _lured_pair()
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lured[0].id, lured[1].id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {giant.id: lured[0].id}), "must block")
	assert_ok(g.declare_blockers(1, {giant.id: [lured[0].id, lured[1].id]}))
	assert_eq(g.combat.blockers_of(lured[0].id), [giant.id])
	assert_eq(g.combat.blockers_of(lured[1].id), [giant.id])


func test_the_ai_declares_against_two_lures_instead_of_conceding() -> void:
	var lured := _lured_pair()
	put_battlefield(1, "Wall of Wood")
	put_battlefield(1, "Savannah Lions")
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lured[0].id, lured[1].id]))
	var guard := 0
	while g.awaiting_blockers == false and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_blockers)
	assert_string_contains(ai.act(g), "declared 2 block(s)")
	assert_false(g.game_over, "no concession")
	assert_eq(g.combat.blockers_of(lured[0].id).size() + g.combat.blockers_of(lured[1].id).size(), 2)
