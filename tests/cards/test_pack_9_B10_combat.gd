extends GameTest
## Pack 9 (the Tempest block), batch B10: the Stronghold combat cards in
## cards/sets/sth/_combat.gd — Dream Prowler, Duct Crawler, Hammerhead
## Shark, Invasion Plans, Mogg Flunkies, Provoke, Rabid Rats, Rolling
## Stones and Wall of Tears.

const CLAIMED := ["Dream Prowler", "Duct Crawler", "Hammerhead Shark", "Invasion Plans",
	"Mogg Flunkies", "Provoke", "Rabid Rats", "Rolling Stones", "Wall of Tears"]

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _respond(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

## P0 attacks with [param ids]; returns in the declare blockers step,
## attack triggers resolved, blockers not yet declared.
func _to_blockers(ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# --------------------------------------------------------------- Dream Prowler --

func test_dream_prowler_attacking_alone_cant_be_blocked() -> void:
	var prowler := put_battlefield(0, "Dream Prowler")
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_blockers([prowler.id])
	assert_true(prowler.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	assert_refused(g.declare_blockers(1, {bear.id: prowler.id}), "can't be blocked")
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 19)

func test_dream_prowler_with_company_can_be_blocked() -> void:
	var prowler := put_battlefield(0, "Dream Prowler")
	var ogre := put_battlefield(0, "Gray Ogre")
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_blockers([prowler.id, ogre.id])
	assert_false(prowler.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	assert_ok(g.declare_blockers(1, {bear.id: prowler.id}))

func test_dream_prowler_is_not_unblockable_at_home() -> void:
	var prowler := put_battlefield(0, "Dream Prowler")
	g.recalculate()
	assert_false(prowler.has_keyword(Mtg.Keyword.UNBLOCKABLE))


# ---------------------------------------------------------------- Duct Crawler --

func test_duct_crawler_stops_one_creature_blocking_it() -> void:
	var crawler := put_battlefield(0, "Duct Crawler")
	var ogre := put_battlefield(0, "Gray Ogre")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, crawler, 0, [TargetRef.card(bear)]))
	resolve_stack()
	_to_blockers([crawler.id, ogre.id])
	assert_refused(g.declare_blockers(1, {bear.id: crawler.id}))
	assert_ok(g.declare_blockers(1, {bear.id: ogre.id}))   # it may still block another creature

func test_duct_crawler_ban_ends_with_the_turn() -> void:
	var crawler := put_battlefield(0, "Duct Crawler")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, crawler, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ne(CombatState.block_illegality(g, bear, crawler, 1), "")
	advance_to_next_turn()
	g.recalculate()
	assert_eq(CombatState.block_illegality(g, bear, crawler, 1), "", "this turn only")

func test_duct_crawler_needs_its_mana() -> void:
	var crawler := put_battlefield(0, "Duct Crawler")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, crawler, 0, [TargetRef.card(bear)]))


# ------------------------------------------------------------- Hammerhead Shark --

func test_hammerhead_shark_attacks_only_into_an_island() -> void:
	var shark := put_battlefield(0, "Hammerhead Shark")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [shark.id]), "Island")
	put_battlefield(1, "Island")
	g.recalculate()
	assert_ok(g.declare_attackers(0, [shark.id]))

func test_hammerhead_shark_may_still_block() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shark := put_battlefield(1, "Hammerhead Shark")
	_to_blockers([bear.id])
	assert_ok(g.declare_blockers(1, {shark.id: bear.id}))


# -------------------------------------------------------------- Invasion Plans --

func test_invasion_plans_the_attacker_declares_every_able_block() -> void:
	put_battlefield(1, "Invasion Plans")
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	g.recalculate()
	assert_true(a.cur_must_block)
	assert_true(bear.cur_must_block, "every creature, the attacker's too")
	_to_blockers([bear.id])
	assert_eq(g.block_chooser(), 0, "the attacking player chooses")
	assert_refused(g.declare_blockers(1, {a.id: bear.id, b.id: bear.id}), "designated")
	assert_refused(g.declare_blockers(0, {a.id: bear.id}), "Llanowar Elves")
	assert_ok(g.declare_blockers(0, {a.id: bear.id, b.id: bear.id}))
	assert_eq(g.combat.blockers_of(bear.id).size(), 2)

func test_invasion_plans_under_the_fifth_edition_preset() -> void:
	g.rules.set_edition("fifth")
	put_battlefield(0, "Invasion Plans")
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	_to_blockers([bear.id])
	assert_refused(g.declare_blockers(0, {}), "Grizzly Bears")
	assert_ok(g.declare_blockers(0, {a.id: bear.id}))

func test_invasion_plans_gone_the_defender_chooses_again() -> void:
	var plans := put_battlefield(1, "Invasion Plans")
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := put_battlefield(1, "Grizzly Bears")
	g.destroy(plans)
	g.recalculate()
	assert_false(a.cur_must_block)
	_to_blockers([bear.id])
	assert_eq(g.block_chooser(), 1)
	assert_ok(g.declare_blockers(1, {}))

func test_invasion_plans_with_the_ai_choosing_for_the_defender() -> void:
	put_battlefield(1, "Invasion Plans")
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	g.recalculate()
	_to_blockers([bear.id])
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.act(g)
	assert_false(g.awaiting_blockers, "the AI made a legal declaration")
	assert_true(g.combat.blocks.has(a.id))
	assert_true(g.combat.blocks.has(b.id))


# --------------------------------------------------------------- Mogg Flunkies --

func test_mogg_flunkies_cant_attack_alone() -> void:
	var flunkies := put_battlefield(0, "Mogg Flunkies")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [flunkies.id]))
	assert_ok(g.declare_attackers(0, [flunkies.id, bear.id]))

func test_mogg_flunkies_cant_block_alone() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var flunkies := put_battlefield(1, "Mogg Flunkies")
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_blockers([giant.id])
	assert_refused(g.declare_blockers(1, {flunkies.id: giant.id}))
	assert_ok(g.declare_blockers(1, {flunkies.id: giant.id, bear.id: giant.id}))

func test_mogg_flunkies_alone_on_the_table_cant_attack_at_all() -> void:
	var flunkies := put_battlefield(0, "Mogg Flunkies")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ne(CombatState.attack_illegality(g, flunkies, 1), "")


# --------------------------------------------------------------------- Provoke --

func test_provoke_untaps_orders_a_block_and_draws() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.tap_permanent(bear)
	var provoke := give_hand(0, "Provoke")
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, provoke, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.tapped)
	assert_true(bear.must_block_this_turn_any)
	assert_eq(g.players[0].hand.size(), hand, "Provoke left, a card drawn")
	_to_blockers([giant.id])
	assert_refused(g.declare_blockers(1, {}), "Grizzly Bears")
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_provoke_cant_target_your_own_creature() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var provoke := give_hand(0, "Provoke")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, provoke, [TargetRef.card(mine)]), "controller")


# ------------------------------------------------------------------- Rabid Rats --

func test_rabid_rats_shrink_a_blocker() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var rats := put_battlefield(0, "Rabid Rats")
	var ogre := put_battlefield(1, "Gray Ogre")
	_to_blockers([bear.id])
	assert_ok(g.declare_blockers(1, {ogre.id: bear.id}))
	_respond(0)
	assert_ok(g.activate_ability(0, rats, 0, [TargetRef.card(ogre)]))
	resolve_stack()
	assert_eq(_pt(ogre), [1, 1])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the shrunken Ogre deals only 1")

func test_rabid_rats_refuse_a_creature_that_is_not_blocking() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var rats := put_battlefield(0, "Rabid Rats")
	var ogre := put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, rats, 0, [TargetRef.card(ogre)]), "blocking")
	assert_refused(g.activate_ability(0, rats, 0, [TargetRef.card(bear)]), "blocking")


# -------------------------------------------------------------- Rolling Stones --

func test_rolling_stones_lets_walls_attack() -> void:
	var wall := put_battlefield(0, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ne(CombatState.attack_illegality(g, wall, 1), "", "defender, no Stones")
	put_battlefield(1, "Rolling Stones")
	g.recalculate()
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER), "as though it didn't — it still has defender")
	assert_ok(g.declare_attackers(0, [wall.id]))

func test_rolling_stones_does_not_free_a_non_wall_defender() -> void:
	put_battlefield(0, "Rolling Stones")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_false(bear.cur_can_attack_with_defender)


# --------------------------------------------------------------- Wall of Tears --

func test_wall_of_tears_returns_what_it_blocked_at_end_of_combat() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Tears")
	_to_blockers([giant.id])
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "not yet")
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(giant), "its owner's hand")
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)

func test_wall_of_tears_return_does_not_need_the_wall() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Tears")
	_to_blockers([giant.id])
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	resolve_stack()
	g.destroy(wall)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND, "the delayed trigger outlives the Wall (CR 603.7)")

func test_wall_of_tears_unblocked_attackers_stay() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Tears")
	_to_blockers([giant.id, bear.id])
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
