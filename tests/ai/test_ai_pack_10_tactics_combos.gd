extends GameTest
## PACK 10'S LOOPS IN THE CARD-COMBOS CATALOGUE (engine/ai/card_combos.gd
## `PACK_10_RECIPES`, [member AiProfile.plays_combos]; the loops are played
## by hand in tests/cards/test_pack_10_B9_loops.gd).
##  * Grim Monolith + Power Artifact: the search finds the {C}-a-round loop
##    with no catalogue at all, and the pilot runs it for a lethal X.
##  * Voltaic Key + Time Vault: the Key is the piece that completes the
##    loop beside a Vault, and in our main phase it untaps the tapped Vault
##    (engine/ai/urza_tactics.gd `untap_artifact_option`).
##  * Tolarian Academy + Mind Over Matter, Palinchron + High Tide: kept and
##    defended against, never pushed out of the hand for themselves.
## And the shared life-cost reader the walk now asks: a "pay half your
## life" ability is no free action to it.

const CC := preload("res://engine/ai/card_combos.gd")
const PACKS := ["pack-2", "pack-3", "pack-5", "pack-6", "pack-8", "pack-9", "pack-10"]
const PRESETS := ["modern", "fifth"]


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id in PACKS)


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_preset(preset)


func _wizard(on := true) -> AiProfile:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.plays_combos = on
	return p


func _pilots(on := true) -> AiPlayer:
	var ai := AiPlayer.new(0, _wizard(on))
	g.set_agent(0, ai)
	g.set_agent(1, AiPlayer.new(1, _wizard(false)))
	return ai


func _power(host: CardInstance) -> void:
	var aura := give_hand(0, "Power Artifact")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.attached_to, host.id)


func _play_our_turn(cap := 4000) -> void:
	var a0: AiPlayer = g.agents[0]
	var a1: AiPlayer = g.agents[1]
	var turn := g.turn_number
	var rounds := 0
	while not g.game_over and g.turn_number == turn and rounds < cap:
		var said0 := a0.act(g)
		var said1 := a1.act(g)
		if said0 == "" and said1 == "" and not g.game_over:
			break
		rounds += 1
	assert_lt(rounds, cap, "the turn ran away")


func test_every_pack_10_piece_is_a_card_of_the_pool() -> void:
	for recipe in CC.PACK_10_RECIPES:
		for slot in recipe["slots"]:
			for card_name in slot:
				assert_not_null(CardRegistry.get_card(card_name), "%s: %s" % [recipe["name"], card_name])
	assert_eq(CC.recipes().size(), CC.RECIPES.size() + CC.PACK_10_RECIPES.size())


func test_the_powered_grim_monolith_by_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var mono := put_battlefield(0, "Grim Monolith")
		_power(mono)
		for i in 5:
			assert_ok(g.tap_for_mana(0, mono))
			assert_ok(g.activate_ability(0, mono, 0))
			resolve_stack()
		assert_eq(g.players[0].mana_pool.total(), 5, "%s: {C} a round" % preset)


func test_the_search_finds_the_powered_grim_monolith() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_power(put_battlefield(0, "Grim Monolith"))
		var loop := CC.find_loop(g, 0, {}, 96)
		assert_false(loop.is_empty(), preset)
		if not loop.is_empty():
			assert_gt(int(loop["gains"]["mana"]), 0, preset)


func test_the_powered_grim_monolith_feeds_a_lethal_disintegrate() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_power(put_battlefield(0, "Grim Monolith"))
		_pilots()
		put_battlefield(0, "Mountain")
		give_hand(0, "Disintegrate")
		g.players[1].life = 20
		_play_our_turn()
		assert_eq(g.winner, 0, preset)


func test_voltaic_key_completes_the_vault() -> void:
	var ai := _pilots()
	put_battlefield(0, "Time Vault")
	var key := give_hand(0, "Voltaic Key")
	var choice: Variant = CC.spell_choice(g, ai, key)
	assert_not_null(choice)
	assert_gte(float(choice["value"]), CC.COMPLETE_WORTH)


func test_voltaic_key_untaps_the_vault_in_our_main_phase() -> void:
	var ai := _pilots()
	var vault := put_battlefield(0, "Time Vault")
	vault.tapped = true
	put_battlefield(0, "Voltaic Key")
	put_battlefield(0, "Island")
	assert_eq(ai.act(g), "activated Voltaic Key")
	resolve_stack()
	assert_false(vault.tapped)


func test_mind_over_matter_is_not_pushed_by_the_academy() -> void:
	var ai := _pilots()
	put_battlefield(0, "Tolarian Academy")
	var mom := give_hand(0, "Mind Over Matter")
	assert_null(CC.spell_choice(g, ai, mom))
	assert_gt(CC.keep_value(g, ai, mom), 0.0, "but kept from a discard")


func test_high_tide_is_not_cast_for_the_palinchron() -> void:
	var ai := _pilots()
	put_battlefield(0, "Palinchron")
	var tide := give_hand(0, "High Tide")
	assert_null(CC.spell_choice(g, ai, tide))
	assert_gt(CC.keep_value(g, ai, tide), 0.0)


func test_the_walk_does_not_take_a_life_cost_for_free() -> void:
	_fresh("modern")
	var evil := put_battlefield(0, "Lurking Evil")
	assert_false(CC._ability_tryable(evil, evil.cur_activated_abilities[0]),
		"half the life is paid as it is worked out")
