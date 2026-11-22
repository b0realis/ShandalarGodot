extends GameTest
## Whole-project review 2026-11-21 — the engine's findings, one group each:
## an attacker cannot tap for its own attack tax, a creature is declared as
## an attacker once, a "when it dies this turn" watch runs after the
## departure (and the batch) is complete, redirections keep one destination
## per booking, per-turn ability uses belong to the ability, the AI plans
## before it pays, and the pre-flight skips its probe for a resolution that
## provably asks nothing.

const G := Mtg.ManaColor.G


func _brainwash(host: CardInstance, pid: int) -> CardInstance:
	var aura := _make_instance(pid, "Brainwash")
	g._put_on_battlefield(aura, pid, host)
	g.recalculate()
	return aura


func _bury(pid: int, card_name: String) -> CardInstance:
	var card := _make_instance(pid, card_name)
	card.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(card)
	return card


# ------------------------------------------------------- the attack tax --

func test_an_attacker_cannot_tap_for_its_own_attack_tax() -> void:
	var elves := put_battlefield(0, "Llanowar Elves")
	_brainwash(elves, 1)   # "can't attack unless its controller pays {3}"
	var forests: Array[CardInstance] = []
	for i in 2:
		forests.append(put_battlefield(0, "Forest"))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	# Two Forests and the Elves' own mana make {3} — but the Elves are
	# tapped as an attacker before the cost is paid (CR 508.1f-i).
	assert_refused(g.declare_attackers(0, [elves.id]), "attack cost")
	assert_false(elves.tapped, "a refused declaration taps nothing")
	for forest in forests:
		assert_false(forest.tapped, "and spends nothing")
	forests.append(put_battlefield(0, "Forest"))
	assert_ok(g.declare_attackers(0, [elves.id]))
	assert_true(g.combat.attackers.has(elves.id))
	for forest in forests:
		assert_true(forest.tapped, "the three Forests paid the {3}")
	assert_eq(g.players[0].mana_pool.total(), 0, "and nothing floats")


func test_a_creature_staying_home_may_pay_the_attack_tax() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	_brainwash(angel, 1)
	var elves := put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [angel.id]))
	assert_true(elves.tapped, "the Elves at home tapped for the third mana")


func test_the_barred_payers_are_the_attackers_that_tap() -> void:
	var elves := put_battlefield(0, "Llanowar Elves")
	var angel := put_battlefield(0, "Serra Angel")   # vigilance
	var barred := g.attack_tax_barred_payers(0, [elves, angel])
	assert_true(barred.has(elves.id))
	assert_false(barred.has(angel.id), "a vigilant attacker stays untapped and may pay")


func test_an_attacker_is_declared_once() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id, bear.id]), "twice")
	assert_true(g.awaiting_attackers, "the step is still open")
	assert_ok(g.declare_attackers(0, [bear.id]))


# ---------------------------------------------------- the death watches --

func test_reincarnation_on_a_clone_brings_it_back_copying_anew() -> void:
	put_battlefield(1, "Serra Angel")
	var clone := put_battlefield(0, "Clone")
	assert_eq(clone.data.card_name, "Serra Angel", "the Clone copies the only creature")
	var spell := give_hand(0, "Reincarnation")
	add_mana(0, G, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(clone)]))
	resolve_stack()
	g.destroy(clone)
	g.check_state_based_actions()
	assert_eq(clone.zone, Mtg.Zone.BATTLEFIELD, "raised by the watch")
	assert_eq(clone.data.card_name, "Serra Angel",
		"it entered as a Clone and copied anew — not a bare 0/0 reset under it")
	assert_eq(clone.cur_toughness, 4)
	assert_false(g.players[0].graveyard.has(clone))
	assert_true(g._due_death_watches.is_empty())


func test_a_creature_dying_in_the_same_batch_can_be_raised() -> void:
	var elves := put_battlefield(0, "Llanowar Elves")
	var dragon := put_battlefield(0, "Shivan Dragon")
	var spell := give_hand(0, "Reincarnation")
	add_mana(0, G, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(elves)]))
	resolve_stack()
	# The marked Elves go first, the Dragon a moment later in the same
	# batch: the watch waits for the batch, so the Dragon is in the
	# graveyard to be chosen (the chooser takes their own biggest body).
	g.depart_together([elves, dragon], func(inst: CardInstance) -> void:
		g.destroy(inst))
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "the Dragon came back")
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


func test_a_watch_outside_a_batch_still_runs_at_once() -> void:
	var elves := put_battlefield(0, "Llanowar Elves")
	var seen: Array = []
	g.watch_death(elves, func(_game: MtgGame, dead: CardInstance) -> void:
		seen.append(dead.zone))
	g.destroy(elves)
	assert_eq(seen, [Mtg.Zone.GRAVEYARD], "run once, with the card already buried")


# ------------------------------------------------------- the redirections --

func test_two_monolith_bookings_each_keep_their_own_destination() -> void:
	var wall := put_battlefield(0, "Wall of Stone")
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	wall.book_damage_redirect(0, giant.id)   # seat 0's Monolith, naming the Giant
	wall.book_damage_redirect(1, bear.id)    # seat 1's, naming the Bears
	assert_eq(wall.damage_redirect_to_for(giant.id), 0)
	assert_eq(wall.damage_redirect_to_for(bear.id), 1)
	g.deal_damage(bear, TargetRef.card(wall), 2)
	assert_eq(g.players[1].life, 18, "the Bears' damage went to seat 1")
	assert_eq(g.players[0].life, 20)
	assert_eq(wall.damage_redirects, 1)
	g.deal_damage(giant, TargetRef.card(wall), 3)
	assert_eq(g.players[0].life, 17, "the Giant's damage went to seat 0")
	assert_eq(wall.damage, 0)
	assert_eq(wall.damage_redirects, 0)
	assert_eq(wall.damage_redirect_to, -1)
	assert_true(wall.damage_redirect_tos.is_empty())


func test_jade_monolith_books_its_controller() -> void:
	var monolith := put_battlefield(0, "Jade Monolith")
	var wall := put_battlefield(0, "Wall of Stone")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, G, 1)
	assert_ok(g.activate_ability(0, monolith, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.damage_redirects, 1)
	assert_eq(wall.damage_redirect_tos, [0] as Array[int])
	var named: int = wall.damage_redirect_sources[0]
	g.deal_damage(g.find_instance(named), TargetRef.card(wall), 2)
	assert_eq(g.players[0].life, 18)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


func test_point_redirects_go_to_the_seat_that_booked_them() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.add_point_redirect(giant, 0, 1)
	g.add_point_redirect(giant, 1, 1)
	assert_eq(giant.damage_point_redirects, 2)
	g.deal_damage(bear, TargetRef.card(giant), 2)
	assert_eq(g.players[0].life, 19, "one point to the first booking's seat")
	assert_eq(g.players[1].life, 19, "one to the second's")
	assert_eq(giant.damage, 0)
	assert_eq(giant.damage_point_redirects, 0)
	assert_eq(giant.damage_point_redirect_to, -1)
	assert_true(giant.damage_point_redirect_rows.is_empty())


func test_points_written_without_a_row_still_move() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	giant.damage_point_redirect_to = 0
	giant.damage_point_redirects = 1
	g.deal_damage(bear, TargetRef.card(giant), 2)
	assert_eq(g.players[0].life, 19)
	assert_eq(giant.damage, 1)
	assert_eq(giant.damage_point_redirects, 0)


# ------------------------------------------------- per-turn ability uses --

func test_ability_uses_follow_the_ability_not_its_position() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var first := ActivatedAbility.new("{0}", false, [], "First granted ability.")
	first.grantor_id = 901
	var second := ActivatedAbility.new("{0}", false, [], "Second granted ability.")
	second.grantor_id = 902
	bear.cur_activated_abilities.append(first)
	bear.cur_activated_abilities.append(second)
	var key: Variant = bear.ability_use_key(0)
	bear.ability_uses[key] = 1
	assert_eq(bear.ability_uses_at(0), 1)
	assert_eq(bear.ability_uses_at(1), 0)
	# The first grant ends: the second slides into its place.
	bear.cur_activated_abilities.remove_at(0)
	assert_eq(bear.ability_uses_at(0), 0, "it does not inherit the other's use")


func test_a_printed_ability_keeps_its_printed_position_as_key() -> void:
	var monolith := put_battlefield(0, "Jade Monolith")
	assert_eq(monolith.ability_use_key(0), 0)
	var wall := put_battlefield(0, "Wall of Stone")
	put_battlefield(1, "Hill Giant")
	add_mana(0, G, 1)
	assert_ok(g.activate_ability(0, monolith, 0, [TargetRef.card(wall)]))
	assert_eq(int(monolith.ability_uses.get(0, 0)), 1)
	assert_eq(monolith.ability_uses_at(0), 1)


# ------------------------------------------------- the AI plans, then pays --

func test_the_ai_plans_a_payment_with_mana_it_is_about_to_buy() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	put_battlefield(0, "Forest")
	var cost := ManaCost.parse("{2}{G}")
	assert_false(ai._plan_covers_with_floating(g, cost, 0, [], 1),
		"a Forest and one bought mana do not make {2}{G}")
	assert_true(ai._plan_covers_with_floating(g, cost, 0, [], 2))
	assert_false(ai._plan_covers_with_floating(g, ManaCost.parse("{G}{G}"), 0, [], 5),
		"bought mana is colorless: it pays no second green")
	assert_eq(g.players[0].life, 20, "asking pays nothing")
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_false(g.players[0].battlefield[0].tapped)


# ------------------------------------------------------- the pre-flight --

func _human(pid := 0) -> HumanAgent:
	advance_to_step(Mtg.Step.MAIN1)
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func test_a_plain_creature_spell_resolves_without_a_probe() -> void:
	_human(0)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_true(g._resolution_asks_nothing(g.stack[-1]))
	# What is skipped is exactly a probe that finds nothing and changes
	# nothing: run it by hand and compare.
	var lines := g.log_lines.size()
	var rng_state := g.rng.state
	assert_null(g._preflight_probe(), "the probe would have asked nothing")
	assert_eq(g.stack.size(), 1, "and left the spell where it was")
	assert_eq(bear.zone, Mtg.Zone.STACK)
	assert_eq(g.log_lines.size(), lines)
	assert_eq(g.rng.state, rng_state)
	var skips := g.preflight_skips
	resolve_stack()
	assert_eq(g.preflight_skips, skips + 1, "the real resolution skipped it")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_null(g.awaiting_choice)


func test_a_spell_that_asks_is_still_probed_and_held() -> void:
	_human(0)
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Hill Giant")
	var clone := give_hand(0, "Clone")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, clone))
	assert_false(g._resolution_asks_nothing(g.stack[-1]), "it chooses what to copy")
	var skips := g.preflight_skips
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.preflight_skips, skips, "no skip")
	assert_not_null(g.awaiting_choice, "the resolution is held on the copy question")


func test_a_board_that_can_react_keeps_the_probe() -> void:
	_human(0)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	var host := put_battlefield(1, "Hill Giant")
	_brainwash(host, 0)   # any static ability on the board
	assert_ok(g.cast_spell(0, bear))
	assert_false(g._resolution_asks_nothing(g.stack[-1]))
	var skips := g.preflight_skips
	resolve_stack()
	assert_eq(g.preflight_skips, skips)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "and it resolves as it always did")


func test_the_shapes_that_are_never_skipped() -> void:
	_human(0)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_false(g._resolution_asks_nothing(g.stack[-1]), "not a permanent spell")
	resolve_stack()
	assert_eq(g.players[1].life, 17)
