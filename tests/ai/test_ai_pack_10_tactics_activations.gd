extends GameTest
## THE URZA BLOCK'S ACTIVATIONS, READ BY THE FAIR AI (Pack 10;
## [member AiProfile.forecasts_tactics]; engine/ai/urza_tactics.gd, reached
## through engine/ai/mirage_tactics.gd `option` / `respond`).
##
## Each shape is read off the typed effect, the cost's own fields or the
## printed line, never the name:
##  * a gift of itself — Witch Engine never, Goblin Festival only for the
##    point that ends the game;
##  * an Aura sold for a card (Capashen Standard) only when its host is
##    about to go;
##  * Phyrexian Processor's token at the life it was paid;
##  * Elvish Piper with any creature card, Quicksilver Amulet at their end
##    step, Copper Gnomes' artifact; Sneak Attack and Apprentice
##    Necromancer only for an attack that ends the game;
##  * Grim Monolith and Voltaic Key untapping what will not untap itself,
##    with their end step's mana;
##  * Masticore finishing what its pings can pay for; a Phyrexian
##    -N/-N sacrifice killing;
##  * Lurking Evil priced by the half life the engine really takes
##    (MtgGame.ability_life_cost), Yawgmoth's Bargain's floor;
##  * Opal Acrolith's dodge in answer to removal.
## Each has its null arm (gate off: the pilot as before Pack 10); the
## decisions a hidden zone could sway replay with the opponent's hand and
## both libraries changed (docs/fair-play.md).

const UT := preload("res://engine/ai/urza_tactics.gd")
const OPAL := preload("res://cards/sets/usg/_opal.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _lands(pid: int, card_name: String, n: int) -> void:
	for _i in n: put_battlefield(pid, card_name)


## Their end step, seat 0 holding priority, the stack empty.
func _their_end_step() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END \
			and g.priority_player == 0 and g.stack.is_empty()) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.END)


## Act for seat 0 until [param needle] appears in a line or it passes.
func _act_until(ai: AiPlayer, needle: String) -> String:
	for _i in 6:
		var line := ai.act(g)
		if line.contains(needle) or line == "pass" or line == "":
			return line
		resolve_stack()
	return ""


## P1 casts [param spell] at [param target] and passes: P0 holds priority.
func _aimed_at(target: CardInstance, spell: String, color: int, generic := 1) -> CardInstance:
	if g.priority_player != 1:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(1, spell)
	add_mana(1, color)
	if generic > 0: add_mana(1, Mtg.ManaColor.C, generic)
	assert_ok(g.cast_spell(1, card, [TargetRef.card(target)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


## Shuffle the library of [param pid] into a new order (the hidden zone).
func _restack(pid: int, names: Array) -> void:
	g.players[pid].library.clear()
	for n in names:
		var inst := _make_instance(pid, n)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(inst)


func _option(ai: AiPlayer, inst: CardInstance, index: int, window: String) -> Variant:
	return UT.option(g, ai, inst, index, window)


# --------------------------------------------------------- a gift of itself --

func test_witch_engine_is_never_given_away_for_its_mana() -> void:
	var ai := _ai()
	var engine := put_battlefield(0, "Witch Engine")
	give_hand(0, "Craw Wurm")   # {4}{G}{G}: four black would not cast it anyway
	_lands(0, "Swamp", 2)
	for window in ["MAIN", "SINK", "UPKEEP", "RESPONSE"]:
		assert_eq(_option(ai, engine, 0, window), {}, window)
	assert_ne(_act_until(ai, "Witch Engine"), "activated Witch Engine")
	_their_end_step()
	assert_ne(ai.act(g), "activated Witch Engine")
	assert_eq(engine.controller_id, 0, "the 4/4 stays ours")


func test_the_null_arm_reads_no_gift() -> void:
	var ai := _ai(false)
	var engine := put_battlefield(0, "Witch Engine")
	assert_null(_option(ai, engine, 0, "MAIN"))


func test_goblin_festival_is_not_flipped_away_for_a_point() -> void:
	var ai := _ai()
	var festival := put_battlefield(0, "Goblin Festival")
	_lands(0, "Mountain", 4)
	_their_end_step()
	assert_ne(ai.act(g), "activated Goblin Festival")
	assert_eq(festival.controller_id, 0)


func test_goblin_festival_pings_the_last_point() -> void:
	var ai := _ai()
	put_battlefield(0, "Goblin Festival")
	_lands(0, "Mountain", 2)
	g.players[1].life = 1
	assert_eq(_act_until(ai, "Goblin Festival"), "activated Goblin Festival")
	resolve_stack()
	assert_true(g.game_over)


func test_the_null_arm_flips_the_festival_at_their_end_step() -> void:
	var ai := _ai(false)
	var festival := put_battlefield(0, "Goblin Festival")
	assert_null(_option(ai, festival, 0, "SINK"))


# ------------------------------------------------------- an Aura for a card --

func _standard_on_bears() -> Array:
	var bears := put_battlefield(0, "Grizzly Bears")
	var standard := give_hand(0, "Capashen Standard")
	g.attach_aura_from_anywhere(standard, bears, 0)
	_lands(0, "Plains", 2)
	return [bears, standard]


func test_capashen_standard_is_not_sold_for_its_own_card() -> void:
	var ai := _ai()
	var pair := _standard_on_bears()
	assert_eq(_option(ai, pair[1], 0, "MAIN"), {})
	assert_ne(_act_until(ai, "Capashen Standard"), "activated Capashen Standard")
	assert_eq((pair[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_capashen_standard_draws_as_its_host_is_terrored() -> void:
	var ai := _ai()
	var pair := _standard_on_bears()
	var hand := g.players[0].hand.size()
	_aimed_at(pair[0], "Terror", Mtg.ManaColor.B)
	assert_eq(ai.act(g), "activated Capashen Standard")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "the card it was worth, before it went")


func test_the_standards_answer_ignores_their_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		var pair := _standard_on_bears()
		give_hand(1, filler)
		_restack(1, [filler, "Forest", "Island"])
		_aimed_at(pair[0], "Terror", Mtg.ManaColor.B)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])


func test_the_null_arm_leaves_the_standard_to_the_shared_reader() -> void:
	var ai := _ai(false)
	var pair := _standard_on_bears()
	assert_null(_option(ai, pair[1], 0, "MAIN"))


# --------------------------------------------------------- Phyrexian Processor --

func test_the_processor_makes_its_minion_at_the_life_paid() -> void:
	var ai := _ai()
	var processor := put_battlefield(0, "Phyrexian Processor")
	processor.memory["paid"] = 4
	_lands(0, "Swamp", 4)
	var opt: Variant = _option(ai, processor, 0, "MAIN")
	assert_gt(float(opt["value"]), 3.0, "a 4/4 for {4}")
	assert_eq(_act_until(ai, "Phyrexian Processor"), "activated Phyrexian Processor")
	resolve_stack()
	var minion: CardInstance = null
	for inst in g.players[0].battlefield:
		if inst.is_token: minion = inst
	assert_not_null(minion)
	assert_eq([minion.cur_power, minion.cur_toughness], [4, 4])


func test_a_processor_paid_nothing_makes_nothing() -> void:
	var ai := _ai()
	var processor := put_battlefield(0, "Phyrexian Processor")
	processor.memory["paid"] = 0
	assert_eq(_option(ai, processor, 0, "MAIN"), {})


# --------------------------------------------------- the cards from the hand --

func test_elvish_piper_puts_any_creature_card_onto_the_battlefield() -> void:
	var ai := _ai()
	put_battlefield(0, "Elvish Piper")
	put_battlefield(0, "Forest")
	var dragon := give_hand(0, "Shivan Dragon")
	assert_eq(_act_until(ai, "Elvish Piper"), "activated Elvish Piper")
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "a red creature: the card takes any")


func test_the_null_arm_reads_the_piper_as_green_only() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Elvish Piper")
	put_battlefield(0, "Forest")
	var dragon := give_hand(0, "Shivan Dragon")
	ai.act(g)
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.HAND)


func test_quicksilver_amulet_ambushes_at_their_end_step() -> void:
	var ai := _ai()
	put_battlefield(0, "Quicksilver Amulet")
	_lands(0, "Island", 4)
	var dragon := give_hand(0, "Shivan Dragon")
	_their_end_step()
	assert_eq(ai.act(g), "activated Quicksilver Amulet")
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)


func test_quicksilver_amulet_does_not_put_a_bear_the_lands_cast() -> void:
	var ai := _ai()
	var amulet := put_battlefield(0, "Quicksilver Amulet")
	_lands(0, "Forest", 6)
	give_hand(0, "Grizzly Bears")
	assert_eq(_option(ai, amulet, 0, "MAIN"), {}, "cast it: {4} buys nothing")


func test_copper_gnomes_put_a_costly_artifact() -> void:
	var ai := _ai()
	put_battlefield(0, "Copper Gnomes")
	_lands(0, "Plains", 4)
	var colossus := give_hand(0, "Phyrexian Colossus")
	assert_eq(_act_until(ai, "Copper Gnomes"), "activated Copper Gnomes")
	resolve_stack()
	assert_eq(colossus.zone, Mtg.Zone.BATTLEFIELD)


func test_sneak_attack_is_not_spent_on_chip_damage() -> void:
	var ai := _ai()
	var sneak := put_battlefield(0, "Sneak Attack")
	put_battlefield(0, "Mountain")
	var dragon := give_hand(0, "Shivan Dragon")
	assert_eq(_option(ai, sneak, 0, "MAIN"), {})
	ai.act(g)
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.HAND, "a card spent for five of twenty")


func test_sneak_attack_brings_in_the_lethal_dragon() -> void:
	var ai := _ai()
	put_battlefield(0, "Sneak Attack")
	put_battlefield(0, "Mountain")
	var dragon := give_hand(0, "Shivan Dragon")
	g.players[1].life = 5
	assert_eq(_act_until(ai, "Sneak Attack"), "activated Sneak Attack")
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(dragon.has_keyword(Mtg.Keyword.HASTE))


func test_sneak_attack_reads_only_its_own_hand() -> void:
	var answers: Array = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		var sneak := put_battlefield(0, "Sneak Attack")
		put_battlefield(0, "Mountain")
		give_hand(0, "Shivan Dragon")
		g.players[1].life = 5
		give_hand(1, filler)
		_restack(1, [filler, "Forest"])
		_restack(0, ["Island", filler])
		answers.append(_option(ai, sneak, 0, "MAIN"))
	assert_eq(answers[0], answers[1])


func test_apprentice_necromancer_does_not_raise_for_one_turn_of_nothing() -> void:
	var ai := _ai()
	var necro := put_battlefield(0, "Apprentice Necromancer")
	put_battlefield(0, "Swamp")
	var wurm := give_hand(0, "Craw Wurm")
	g.discard_cards(0, [wurm])
	assert_eq(_option(ai, necro, 0, "MAIN"), {})
	ai.act(g)
	resolve_stack()
	assert_eq(necro.zone, Mtg.Zone.BATTLEFIELD, "a 6/4 for one turn is no reanimation")


func test_apprentice_necromancer_raises_the_lethal_attacker() -> void:
	var ai := _ai()
	put_battlefield(0, "Apprentice Necromancer")
	put_battlefield(0, "Swamp")
	var wurm := give_hand(0, "Craw Wurm")
	g.discard_cards(0, [wurm])
	g.players[1].life = 6
	assert_eq(_act_until(ai, "Apprentice Necromancer"), "activated Apprentice Necromancer")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------------ the untaps --

func test_grim_monolith_is_untapped_with_their_end_steps_mana() -> void:
	var ai := _ai()
	var mono := put_battlefield(0, "Grim Monolith")
	mono.tapped = true
	_lands(0, "Island", 4)
	assert_eq(_option(ai, mono, 0, "MAIN"), {}, "{4} for {C}{C}{C}: never in our main phase")
	_their_end_step()
	assert_eq(ai.act(g), "activated Grim Monolith")
	resolve_stack()
	assert_false(mono.tapped)


func test_the_null_arm_leaves_the_monolith_tapped() -> void:
	var ai := _ai(false)
	var mono := put_battlefield(0, "Grim Monolith")
	mono.tapped = true
	_lands(0, "Island", 4)
	_their_end_step()
	ai.act(g)
	resolve_stack()
	assert_true(mono.tapped)


func test_voltaic_key_untaps_the_monolith_at_their_end_step() -> void:
	var ai := _ai()
	var key := put_battlefield(0, "Voltaic Key")
	var mono := put_battlefield(0, "Grim Monolith")
	mono.tapped = true
	_lands(0, "Island", 1)
	assert_eq(_option(ai, key, 0, "MAIN"), {})
	_their_end_step()
	assert_eq(ai.act(g), "activated Voltaic Key")
	resolve_stack()
	assert_false(mono.tapped)


func test_voltaic_key_never_untaps_their_artifact() -> void:
	var ai := _ai()
	var key := put_battlefield(0, "Voltaic Key")
	var theirs := put_battlefield(1, "Grim Monolith")
	theirs.tapped = true
	_lands(0, "Island", 1)
	_their_end_step()
	assert_eq(_option(ai, key, 0, "SINK"), {})


func test_a_self_untapping_creature_stands_guard_after_its_attack() -> void:
	var ai := _ai()
	var crab := put_battlefield(0, "Horseshoe Crab")
	put_battlefield(0, "Island")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN2)
	crab.tapped = true
	assert_eq(ai.act(g), "activated Horseshoe Crab")
	resolve_stack()
	assert_false(crab.tapped)


func test_a_self_untapping_creature_does_not_untap_in_the_first_main_phase() -> void:
	var ai := _ai()
	var crab := put_battlefield(0, "Horseshoe Crab")
	put_battlefield(0, "Island")
	put_battlefield(1, "Grizzly Bears")
	crab.tapped = true
	assert_eq(_option(ai, crab, 0, "MAIN"), {})


# ----------------------------------------------------------- pings and shrinks --

func test_masticore_pings_a_four_four_to_death() -> void:
	var ai := _ai()
	put_battlefield(0, "Masticore")
	_lands(0, "Mountain", 8)
	var angel := put_battlefield(1, "Serra Angel")
	for i in 4:
		assert_eq(ai.act(g), "activated Masticore", "ping %d" % i)
		resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


func test_masticore_does_not_start_what_its_mana_cannot_finish() -> void:
	var ai := _ai()
	var masticore := put_battlefield(0, "Masticore")
	_lands(0, "Mountain", 6)
	var angel := put_battlefield(1, "Serra Angel")
	assert_null(_option(ai, masticore, 0, "MAIN"), "three shots for a 4/4: no plan of its own")
	ai.act(g)
	resolve_stack()
	assert_eq(angel.damage, 0)


func test_phyrexian_plaguelord_shrinks_their_angel_to_death() -> void:
	var ai := _ai()
	put_battlefield(0, "Phyrexian Plaguelord")
	var angel := put_battlefield(1, "Serra Angel")
	assert_eq(_act_until(ai, "Phyrexian Plaguelord"), "activated Phyrexian Plaguelord")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_never_shrinks() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Phyrexian Plaguelord")
	var angel := put_battlefield(1, "Serra Angel")
	ai.act(g)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------- the life for a body --

func test_lurking_evil_pays_the_half_it_really_costs() -> void:
	var ai := _ai()
	var evil := put_battlefield(0, "Lurking Evil")
	g.players[0].life = 20
	var a: ActivatedAbility = evil.cur_activated_abilities[0]
	assert_eq(a.life_cost, 0, "the printed field reads nothing")
	assert_eq(g.ability_life_cost(0, evil, a), 10)
	assert_eq(_act_until(ai, "Lurking Evil"), "activated Lurking Evil")
	resolve_stack()
	assert_eq(g.players[0].life, 10)
	assert_true(evil.is_creature())
	assert_eq(_option(ai, evil, 0, "MAIN"), {}, "a creature already: never paid twice")


## Nine life pays five: four left against their Hill Giant's three is under
## the floor — a reading of the printed 0 would have kept nine.
func test_lurking_evil_is_refused_when_the_half_leaves_too_little() -> void:
	var ai := _ai()
	var evil := put_battlefield(0, "Lurking Evil")
	put_battlefield(1, "Hill Giant")
	g.players[0].life = 9
	assert_eq(_option(ai, evil, 0, "MAIN"), {})
	ai.act(g)
	resolve_stack()
	assert_eq(g.players[0].life, 9)
	assert_false(evil.is_creature())


func test_lurking_evil_prices_the_life_by_the_total() -> void:
	var ai := _ai()
	var evil := put_battlefield(0, "Lurking Evil")
	g.players[0].life = 20
	var rich: float = float(_option(ai, evil, 0, "MAIN")["value"])
	g.players[0].life = 12
	var poor: float = float(_option(ai, evil, 0, "MAIN")["value"])
	assert_gt(rich, poor, "ten at twenty is cheaper than six at twelve")


func test_yawgmoths_bargain_keeps_a_floor_above_their_board() -> void:
	var ai := _ai()
	var bargain := put_battlefield(0, "Yawgmoth's Bargain")
	put_battlefield(1, "Hill Giant")
	g.players[0].life = 9
	assert_eq(_option(ai, bargain, 0, "MAIN"), {})
	g.players[0].life = 20
	assert_null(_option(ai, bargain, 0, "MAIN"), "above the floor: the shared draw reader")


# ------------------------------------------------------------ the Opal dodge --

func test_opal_acrolith_dodges_a_terror_as_an_enchantment() -> void:
	var ai := _ai()
	var opal := put_battlefield(0, "Opal Acrolith")
	OPAL.make_creature(g, opal, 2, 4, ["soldier"])
	assert_true(opal.is_creature())
	assert_eq(_option(ai, opal, 0, "MAIN"), {}, "the body blocks: never flipped for nothing")
	var terror := _aimed_at(opal, "Terror", Mtg.ManaColor.B)
	assert_eq(ai.act(g), "activated Opal Acrolith: becomes an enchantment out of harm's way")
	resolve_stack()
	assert_eq(opal.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(opal.is_creature())
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_lets_the_terror_land() -> void:
	var ai := _ai(false)
	var opal := put_battlefield(0, "Opal Acrolith")
	OPAL.make_creature(g, opal, 2, 4, ["soldier"])
	_aimed_at(opal, "Terror", Mtg.ManaColor.B)
	ai.act(g)
	resolve_stack()
	assert_eq(opal.zone, Mtg.Zone.GRAVEYARD)


func test_the_dodge_ignores_their_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		var opal := put_battlefield(0, "Opal Acrolith")
		OPAL.make_creature(g, opal, 2, 4, ["soldier"])
		give_hand(1, filler)
		_restack(1, [filler, "Swamp"])
		_aimed_at(opal, "Terror", Mtg.ManaColor.B)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])


# ------------------------------------------- the shots, the toll, the ignore --

func test_elite_archers_shoot_their_attacking_giant() -> void:
	var ai := _ai()
	put_battlefield(0, "Elite Archers")
	var giant := put_battlefield(1, "Hill Giant")
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [giant.id]))
	guard = 0
	while g.priority_player != 0 and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(_act_until(ai, "Elite Archers"), "activated Elite Archers")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_never_shoots_in_combat() -> void:
	var ai := _ai(false)
	var archers := put_battlefield(0, "Elite Archers")
	assert_null(_option(ai, archers, 0, "RESPONSE"))


func test_shivan_gorge_pings_with_their_end_steps_mana() -> void:
	var ai := _ai()
	var gorge := put_battlefield(0, "Shivan Gorge")
	_lands(0, "Mountain", 3)
	assert_eq(_option(ai, gorge, 0, "MAIN"), {}, "our own mana has a use in our turn")
	_their_end_step()
	assert_eq(ai.act(g), "activated Shivan Gorge")
	resolve_stack()
	assert_eq(g.players[1].life, 19)


func test_damping_engine_is_ignored_for_the_dragon_it_stops() -> void:
	var ai := _ai()
	put_battlefield(0, "Damping Engine")
	_lands(0, "Mountain", 6)
	put_battlefield(1, "Forest")
	var dragon := give_hand(0, "Shivan Dragon")
	assert_ne(g.play_banned(0, dragon.data), "", "the Engine stops our dragon")
	var line := ai.act(g)
	assert_true(line.begins_with("ignores Damping Engine"), line)
	assert_eq(_act_until(ai, "Shivan Dragon"), "cast Shivan Dragon")


func test_the_null_arm_stays_damped() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Damping Engine")
	_lands(0, "Mountain", 6)
	put_battlefield(1, "Forest")
	give_hand(0, "Shivan Dragon")
	assert_eq(ai.act(g), "pass")
