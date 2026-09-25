extends GameTest
## Cross-zone definitions, timing, combat transitions and decisions.

func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func cast(name: String, targets: Array = [], pid := 0, x := 0) -> CardInstance:
	var c := give_hand(pid, name)
	for color in Mtg.WUBRG: add_mana(pid, color, 20)
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(pid, c, targets, x))
	resolve_stack()
	return c

func test_switching_blockers_triggers_new_basilisk_pair() -> void:
	CardPacks.set_enabled("pack-3", true)
	var general := put_battlefield(0, "General Jarkeld")
	var basilisk := put_battlefield(0, "Sylvan Basilisk")
	var bear := put_battlefield(0, "Bear Cub")
	var first := put_battlefield(1, "Wall of Wood")
	var second := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [basilisk.id, bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {first.id: basilisk.id, second.id: bear.id}))
	assert_ok(g.activate_ability(0, general, 0, [TargetRef.card(basilisk), TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD, "the original trigger still resolves")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the new blocking pair also triggers")

func test_characteristic_power_also_works_in_hand_and_graveyard() -> void:
	var yeti := give_hand(0, "Sylvan Yeti")
	var engine := give_hand(0, "Nightstalker Engine")
	g.recalculate()
	assert_eq(yeti.cur_power, g.players[0].hand.size())
	g.discard_cards(0, [engine])
	g.recalculate()
	assert_eq(engine.cur_power, 1)
	assert_eq(yeti.cur_power, g.players[0].hand.size())

func test_becomes_blocked_triggers_once_for_a_gang_and_on_forced_block() -> void:
	var bear := put_battlefield(0, "Razorclaw Bear")
	var wolf := put_battlefield(0, "Norwood Warrior")
	var one := put_battlefield(1, "Wall of Wood")
	var two := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, wolf.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {one.id: bear.id, two.id: bear.id}))
	resolve_stack()
	assert_eq(bear.cur_power, 5)
	g.set_block(one, wolf)
	resolve_stack()
	assert_eq(wolf.cur_power, 3)
	g.set_block(two, wolf)
	resolve_stack()
	assert_eq(wolf.cur_power, 3, "not once per blocker")

func test_early_tap_abilities_cannot_be_used_after_attackers() -> void:
	var veteran := put_battlefield(0, "Alaborn Veteran")
	var bear := put_battlefield(0, "Bear Cub")
	assert_ok(g.activate_ability(0, veteran, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	g.untap_permanent(veteran)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	assert_refused(g.activate_ability(0, veteran, 0, [TargetRef.card(bear)]))

func test_priestess_only_puts_a_green_creature_from_own_hand() -> void:
	var priestess := put_battlefield(0, "Norwood Priestess")
	var bear := give_hand(0, "Bear Cub")
	var enemy := give_hand(1, "Craw Wurm")
	assert_ok(g.activate_ability(0, priestess, 0))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(enemy.zone, Mtg.Zone.HAND)

func test_coastal_wizard_bounces_itself_and_target_but_not_a_new_incarnation() -> void:
	var wizard := put_battlefield(0, "Coastal Wizard")
	var bear := put_battlefield(1, "Bear Cub")
	assert_refused(g.activate_ability(0, wizard, 0, [TargetRef.card(wizard)]))
	assert_ok(g.activate_ability(0, wizard, 0, [TargetRef.card(bear)]))
	g.return_to_hand(wizard)
	g.put_from_hand_into_play(wizard, 0)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(wizard.zone, Mtg.Zone.BATTLEFIELD)

func test_sylvan_basilisk_destroys_its_blocker_before_damage() -> void:
	var basilisk := put_battlefield(0, "Sylvan Basilisk")
	var wall := put_battlefield(1, "Wall of Wood")
	run_combat([basilisk.id], {wall.id: basilisk.id})
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "still blocked")

func test_basilisk_in_band_hears_a_block_declared_against_the_other_member() -> void:
	var basilisk := put_battlefield(0, "Sylvan Basilisk")
	var hero := put_battlefield(0, "Benalish Hero")
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, basilisk.id], [[hero.id, basilisk.id]]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: hero.id}))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)

func test_town_sentry_and_zealot_block_triggers() -> void:
	var bear := put_battlefield(0, "Bear Cub")
	var other := put_battlefield(0, "Bear Cub")
	var sentry := put_battlefield(1, "Town Sentry")
	var zealot := put_battlefield(1, "Alaborn Zealot")
	run_combat([bear.id, other.id], {sentry.id: bear.id, zealot.id: other.id})
	assert_eq(sentry.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(zealot.zone, Mtg.Zone.GRAVEYARD)

func test_nightstalker_trigger_discards_before_damage() -> void:
	var stalker := put_battlefield(0, "Abyssal Nightstalker")
	var card := give_hand(1, "Forest")
	run_combat([stalker.id], {})
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)

func test_goblin_lore_draws_four_then_randomly_discards_three() -> void:
	var count := g.players[0].hand.size()
	cast("Goblin Lore")
	assert_eq(g.players[0].hand.size(), count + 1)
	assert_eq(g.players[0].graveyard.size(), 4)

func test_sleight_takes_one_and_bottoms_the_other_without_shuffling() -> void:
	var before := g.players[0].library.duplicate()
	cast("Sleight of Hand")
	assert_eq(g.players[0].library.size(), before.size() - 1)
	assert_eq(g.players[0].hand.size(), 1)

func test_denizen_returns_only_other_creatures_its_controller_controls() -> void:
	var own := put_battlefield(0, "Bear Cub")
	var theirs := put_battlefield(1, "Bear Cub")
	var denizen := cast("Denizen of the Deep")
	assert_eq(own.zone, Mtg.Zone.HAND)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(denizen.zone, Mtg.Zone.BATTLEFIELD)
