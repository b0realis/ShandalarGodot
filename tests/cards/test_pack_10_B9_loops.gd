extends GameTest
## Pack 10 (the Urza block), batch B9: the rules-faithful loops the block's
## untap cards make with older cards, pinned so the engine's answer is known
## and every single action stays finite:
##  * Voltaic Key + Time Vault (2ed): one Key activation untaps the Vault
##    once, one Vault activation is one extra turn — and the Key, tapped,
##    cannot go again until it untaps in that extra turn;
##  * Grim Monolith + Power Artifact (atq): the {4} untap costs {2}, the
##    Monolith makes {C}{C}{C} — exactly one more mana per cycle, and the
##    loop limit (MtgGame.LOOP_LIMIT, two steps a cycle) ends a runaway;
##  * Palinchron + High Tide (Pack 2's fem): seven Islands make fourteen,
##    Palinchron costs seven, untaps seven and returns for four — three more
##    blue mana per cycle, each cycle ten steps, and the limit ends it.

## Plays every turn it is asked about (Time Vault's skip question).
class PlaysOn extends DecisionAgent:
	func answer_option(_g: MtgGame, _p: int, prompt: String, _labels: Array[String], hint: int) -> int:
		return 0 if prompt.begins_with("Skip this turn to untap") else hint


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	CardPacks.set_enabled("pack-2", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func pool(color: int) -> int:
	return g.players[0].mana_pool.amount_of(color)

func said_loop() -> bool:
	var line := "%s created an infinite loop — stopping at %d steps." % [g.players[0].player_name, MtgGame.LOOP_LIMIT]
	return Array(g.log_lines).has(line)


# --- Voltaic Key + Time Vault ------------------------------------------------

func test_voltaic_key_and_time_vault_give_one_extra_turn_per_key_activation() -> void:
	g.set_agent(0, PlaysOn.new())
	var vault := put_battlefield(0, "Time Vault")
	assert_true(vault.tapped, "the Vault enters tapped")
	var key := put_battlefield(0, "Voltaic Key")
	for r in 3:
		add_mana(0, Mtg.ManaColor.C)
		assert_ok(g.activate_ability(0, key, 0, [TargetRef.card(vault)]))
		resolve_stack()
		assert_false(vault.tapped, "round %d: the Key untapped the Vault" % r)
		assert_ok(g.activate_ability(0, vault, 0))
		resolve_stack()
		assert_eq(g.extra_turns, [0] as Array[int], "round %d: one activation, one extra turn" % r)
		add_mana(0, Mtg.ManaColor.C)
		assert_refused(g.activate_ability(0, key, 0, [TargetRef.card(vault)]), "tapped")
		assert_refused(g.activate_ability(0, vault, 0), "tapped")
		var turn := g.turn_number
		advance_to_next_turn()
		assert_eq(g.active_player, 0, "round %d: the extra turn is ours" % r)
		assert_eq(g.turn_number, turn + 1)
		assert_true(g.extra_turns.is_empty())
		assert_true(vault.tapped, "the Vault does not untap in its untap step")
		assert_false(key.tapped, "the Key does — so it may go once more")

func test_voltaic_key_alone_on_a_tapped_vault_untaps_it_and_nothing_more() -> void:
	g.set_agent(0, PlaysOn.new())
	var vault := put_battlefield(0, "Time Vault")
	var key := put_battlefield(0, "Voltaic Key")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, key, 0, [TargetRef.card(vault)]))
	resolve_stack()
	assert_true(g.extra_turns.is_empty(), "untapping the Vault takes no turn by itself")
	advance_to_next_turn()
	assert_eq(g.active_player, 1, "the Vault was never tapped for a turn")


# --- Grim Monolith + Power Artifact -------------------------------------------

func test_grim_monolith_with_power_artifact_nets_one_mana_a_cycle_until_the_limit() -> void:
	var monolith := put_battlefield(0, "Grim Monolith")
	var artifact := give_hand(0, "Power Artifact")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, artifact, [TargetRef.card(monolith)]))
	resolve_stack()
	assert_eq(artifact.attached_to, monolith.id)
	var untap: ActivatedAbility = monolith.cur_activated_abilities[0]
	assert_eq(untap.cost.mana_value(), 2, "{4} less {2}")
	for cycle in 4:
		var before := pool(Mtg.ManaColor.C)
		assert_ok(g.tap_for_mana(0, monolith))
		assert_ok(g.activate_ability(0, monolith, 0))
		resolve_stack()
		assert_false(monolith.tapped)
		assert_eq(pool(Mtg.ManaColor.C), before + 1, "cycle %d: three in, two out" % cycle)
	var start := g.loop_steps
	var rounds := 0
	var refusal := ""
	while rounds < MtgGame.LOOP_LIMIT:
		refusal = g.tap_for_mana(0, monolith)
		if refusal != "": break
		refusal = g.activate_ability(0, monolith, 0)
		if refusal != "": break
		resolve_stack()
		rounds += 1
	assert_eq(rounds, (MtgGame.LOOP_LIMIT - start) / 2, "two steps a cycle")
	assert_eq(refusal, MtgGame.LOOP_REFUSAL)
	assert_true(said_loop())
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.loop_steps, 0, "the next step starts clean")

func test_grim_monolith_alone_cannot_loop() -> void:
	var monolith := put_battlefield(0, "Grim Monolith")
	assert_ok(g.tap_for_mana(0, monolith))
	assert_refused(g.activate_ability(0, monolith, 0), "mana")
	assert_true(monolith.tapped, "three made, four needed")


# --- Palinchron + High Tide -----------------------------------------------------

func test_palinchron_and_high_tide_net_three_blue_a_cycle_until_the_limit() -> void:
	var islands: Array[CardInstance] = []
	for i in 7: islands.append(put_battlefield(0, "Island"))
	var tide := give_hand(0, "High Tide")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, tide))
	resolve_stack()
	for island in islands: assert_ok(g.tap_for_mana(0, island))
	assert_eq(pool(Mtg.ManaColor.U), 14, "two from each Island under High Tide")
	var palinchron := give_hand(0, "Palinchron")
	var cycles := 0
	var refusal := ""
	while cycles < 300:
		var before := pool(Mtg.ManaColor.U)
		refusal = g.cast_spell(0, palinchron)
		if refusal != "": break
		resolve_stack()   # Palinchron, then "untap up to seven lands"
		for island in islands:
			if island.tapped: continue
			refusal = g.tap_for_mana(0, island)
			if refusal != "": break
		if refusal != "": break
		refusal = g.activate_ability(0, palinchron, 0)
		if refusal != "": break
		resolve_stack()
		assert_eq(palinchron.zone, Mtg.Zone.HAND)
		cycles += 1
		if cycles <= 3:
			assert_eq(pool(Mtg.ManaColor.U), before + 3, "cycle %d: -7, +14, -4" % cycles)
	assert_gt(cycles, 3)
	assert_lt(cycles, 300, "the loop limit ends it, not the guard")
	assert_eq(refusal, MtgGame.LOOP_REFUSAL)
	assert_true(said_loop())
	assert_false(g.game_over)
