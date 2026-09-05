extends GameTest
## Fidelity lift of 2026-09-02 — the ASTRAL set's random targeting and
## random effects, two rows of docs/simplified-cards.md lifted on one
## engine feature: a "random target" (TargetSpec.at_random) is a TARGET
## the GAME rolls as the spell or ability is put on the stack (CR 601.2c),
## so it is on the stack item for everyone to see and respond to, it
## fizzles if it leaves before resolution (CR 608.2b), and a tapped
## creature can come up for the Polka Band and waste the {R} — exactly
## the printed card. The two random-effect tables are the original's own
## two lists: `@FAERIEDRAGON_MESSAGES` (twenty creature effects, rolled
## onto ONE random creature named at activation — `card_faerie_dragon`,
## 0x4735C0, decompiled) and `@WHIMSY_MESSAGES` (seventeen "fast effects",
## each one aimed at random and fizzling when nothing qualifies — Duel.hlp's
## own clarification).


## Answers every OPTION question with a fixed index and records the asks.
class OptionSeat extends DecisionAgent:
	var index := 0
	var asks: Array = []

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asks.append({"prompt": prompt, "options": options.duplicate(), "hint": hint})
		return index


func _creature_names(refs: Array) -> Array:
	var out: Array = []
	for ref in refs:
		var inst := g.find_instance(ref.instance_id)
		out.append(inst.data.card_name if inst != null else "?")
	return out


func _log_count(pattern: String) -> int:
	var n := 0
	for line in g.log_lines:
		if line.contains(pattern):
			n += 1
	return n


# --------------------------------------------------------- Faerie Dragon --

func _dragon_ready() -> CardInstance:
	var dragon := put_battlefield(0, "Faerie Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	return dragon


func test_faerie_dragon_names_its_random_creature_as_it_is_activated() -> void:
	var dragon := _dragon_ready()
	put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, dragon, 0, []))
	var item: StackItem = g.stack[-1]
	assert_eq(item.targets.size(), 1, "one random creature target, on the stack")
	var names := _creature_names(item.targets)
	assert_true(names[0] == "Grizzly Bears" or names[0] == "Faerie Dragon",
		"any creature can come up, the Dragon itself included: %s" % [names])
	assert_true(_log_count("random target") > 0, "the roll is logged")


func test_faerie_dragon_alone_rolls_itself() -> void:
	var dragon := _dragon_ready()
	assert_ok(g.activate_ability(0, dragon, 0, []))
	assert_eq(_creature_names(g.stack[-1].targets), ["Faerie Dragon"])


func test_faerie_dragon_fizzles_when_its_creature_leaves_in_response() -> void:
	var dragon := _dragon_ready()
	put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, dragon, 0, []))
	var victim := g.find_instance(g.stack[-1].targets[0].instance_id)
	g.destroy(victim, false)
	var before := g.log_lines.size()
	resolve_stack()
	var tail: Array = []
	for i in range(before, g.log_lines.size()):
		tail.append(g.log_lines[i])
	assert_true(_log_count("no legal targets") > 0, "CR 608.2b — its only target is gone: %s" % [tail])
	assert_eq(_log_count(" casts ") + _log_count(" activates ") - _log_count("activates Faerie Dragon"),
		0, "no effect was played")


func test_faerie_dragon_supplied_target_is_refused() -> void:
	var dragon := _dragon_ready()
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, dragon, 0, [TargetRef.card(bears)]),
		"takes 0 target(s)")


func test_faerie_dragon_table_is_the_1997_list_of_twenty() -> void:
	assert_eq(RandomCreatureEffectTable.COUNT, 20)
	assert_eq(RandomCreatureEffectTable.MESSAGES.size(), 20)
	assert_eq(RandomCreatureEffectTable.MESSAGES[0], "casts Berserk!")
	assert_eq(RandomCreatureEffectTable.MESSAGES[1], "activates Tawnos's Wand effect!")
	assert_eq(RandomCreatureEffectTable.MESSAGES[6], "casts Lightning Bolt!")
	assert_eq(RandomCreatureEffectTable.MESSAGES[13], "casts Twiddle!")
	assert_eq(RandomCreatureEffectTable.MESSAGES[19], "casts Orcish Catapult!")


func test_dragon_entry_lightning_bolt_kills_a_bear() -> void:
	var dragon := put_battlefield(0, "Faerie Dragon")
	var bears := put_battlefield(1, "Grizzly Bears")
	RandomCreatureEffectTable.play(g, dragon, 0, 6, bears)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "3 damage from the Dragon")
	assert_true(_log_count("P0 casts Lightning Bolt!") == 1, "the 1997 line")


func test_dragon_entry_giant_growth_and_berserk_and_bloodlust() -> void:
	var dragon := put_battlefield(0, "Faerie Dragon")
	var bears := put_battlefield(1, "Grizzly Bears")
	RandomCreatureEffectTable.play(g, dragon, 0, 8, bears)   # Giant Growth
	assert_eq(bears.cur_power, 5)
	assert_eq(bears.cur_toughness, 5)
	RandomCreatureEffectTable.play(g, dragon, 0, 0, bears)   # Berserk: +5/+0, trample
	assert_eq(bears.cur_power, 10)
	assert_true(bears.has_keyword(Mtg.Keyword.TRAMPLE))
	var giant := put_battlefield(1, "Hill Giant")   # 3/3
	RandomCreatureEffectTable.play(g, dragon, 0, 2, giant)   # Bloodlust: +4/-(3-1)
	assert_eq(giant.cur_power, 7)
	assert_eq(giant.cur_toughness, 1)


func test_dragon_entry_tawnos_wand_fizzles_on_power_three_or_more() -> void:
	var dragon := put_battlefield(0, "Faerie Dragon")
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	RandomCreatureEffectTable.play(g, dragon, 0, 1, bears)
	assert_true(bears.has_keyword(Mtg.Keyword.UNBLOCKABLE), "power 2: can't be blocked")
	assert_eq(_log_count("P0 activates Tawnos's Wand effect!"), 1)
	RandomCreatureEffectTable.play(g, dragon, 0, 1, giant)
	assert_false(giant.has_keyword(Mtg.Keyword.UNBLOCKABLE), "power 3: the Wand fizzles")
	assert_eq(_log_count("P0 fizzles attempting Tawnos's Wand effect!"), 1)


func test_dragon_entry_laces_recolour_the_creature() -> void:
	var dragon := put_battlefield(0, "Faerie Dragon")
	var wall := put_battlefield(1, "Wall of Stone")   # red
	RandomCreatureEffectTable.play(g, dragon, 0, 3, wall)   # Lifelace
	assert_eq(wall.cur_colors, Mtg.ManaColor.G)
	RandomCreatureEffectTable.play(g, dragon, 0, 11, wall)   # Thoughtlace
	assert_eq(wall.cur_colors, Mtg.ManaColor.U)
	RandomCreatureEffectTable.play(g, dragon, 0, 10, wall)   # Deathlace
	assert_eq(wall.cur_colors, Mtg.ManaColor.B)


func test_dragon_entry_twiddle_asks_the_controller_tap_or_untap() -> void:
	var dragon := put_battlefield(0, "Faerie Dragon")
	var bears := put_battlefield(1, "Grizzly Bears")
	var seat := OptionSeat.new()
	seat.index = 1   # "Untap."
	g.set_agent(0, seat)
	bears.tapped = true
	RandomCreatureEffectTable.play(g, dragon, 0, 13, bears)
	assert_false(bears.tapped, "the seat chose Untap.")
	assert_eq(seat.asks.size(), 1)
	assert_eq(seat.asks[0]["options"], ["Tap.", "Untap."], "`@FAERIEDRAGON_TWIDDLE`")
	assert_eq(seat.asks[0]["hint"], 0, "an opponent's creature: the heuristic taps")
	seat.index = 0   # "Tap."
	RandomCreatureEffectTable.play(g, dragon, 0, 13, bears)
	assert_true(bears.tapped)


func test_dragon_entries_that_move_or_shrink_the_creature() -> void:
	var dragon := put_battlefield(0, "Faerie Dragon")
	var bears := put_battlefield(1, "Grizzly Bears")
	RandomCreatureEffectTable.play(g, dragon, 0, 17, bears)   # Sorceress Queen
	assert_eq(bears.cur_power, 0)
	assert_eq(bears.cur_toughness, 2)
	RandomCreatureEffectTable.play(g, dragon, 0, 19, bears)   # Orcish Catapult
	assert_eq(int(bears.counters.get("-0/-1", 0)), 1)
	assert_eq(bears.cur_toughness, 1)
	RandomCreatureEffectTable.play(g, dragon, 0, 14, bears)   # Pradesh Gypsies
	assert_eq(bears.cur_power, -2)
	RandomCreatureEffectTable.play(g, dragon, 0, 12, bears)   # Hurr Jackal
	assert_true(bears.regeneration_banned_this_turn)
	RandomCreatureEffectTable.play(g, dragon, 0, 7, bears)    # Jump
	assert_true(bears.has_keyword(Mtg.Keyword.FLYING))
	RandomCreatureEffectTable.play(g, dragon, 0, 9, bears)    # Helm of Chatzuk
	assert_true(bears.has_keyword(Mtg.Keyword.BANDING))
	RandomCreatureEffectTable.play(g, dragon, 0, 15, bears)   # Unsummon
	assert_eq(bears.zone, Mtg.Zone.HAND)
	var giant := put_battlefield(1, "Hill Giant")
	RandomCreatureEffectTable.play(g, dragon, 0, 18, giant)   # Swords to Plowshares
	assert_eq(giant.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[1].life, 23, "its controller gains its power")
	var ogre := put_battlefield(1, "Gray Ogre")
	RandomCreatureEffectTable.play(g, dragon, 0, 16, ogre)    # Rod of Ruin
	assert_eq(ogre.damage, 1)


func test_faerie_dragon_is_deterministic_under_a_seed() -> void:
	assert_eq(_run_dragon(4242), _run_dragon(4242), "same seed, same roll and target")


func _run_dragon(seed_value: int) -> String:
	var sim := MtgGame.new()
	var filler: Array = []
	for _i in 30:
		filler.append("Forest")
	sim.setup(filler, filler, "P0", "P1", 20, 20, seed_value)
	sim.start(0)
	for name in ["Grizzly Bears", "Hill Giant", "Wall of Stone"]:
		var body := CardInstance.new(CardRegistry.get_card(name), sim._next_instance_id, 1)
		sim._next_instance_id += 1
		sim._instances[body.id] = body
		sim._put_on_battlefield(body, 1)
	var dragon := CardInstance.new(CardRegistry.get_card("Faerie Dragon"),
		sim._next_instance_id, 0)
	sim._next_instance_id += 1
	sim._instances[dragon.id] = dragon
	sim._put_on_battlefield(dragon, 0)
	dragon.summoning_sick = false
	while sim.current_step() != Mtg.Step.MAIN1 and not sim.game_over:
		sim.pass_priority(sim.priority_player)
	sim.players[0].mana_pool.add(Mtg.ManaColor.G, 2)
	sim.players[0].mana_pool.add(Mtg.ManaColor.C, 1)
	sim.activate_ability(0, dragon, 0, [])
	var guard := 0
	while not sim.stack.is_empty() and not sim.game_over and guard < 50:
		sim.pass_priority(sim.priority_player)
		guard += 1
	return "\n".join(sim.log_lines)


# ---------------------------------------------------------------- Whimsy --

func test_whimsy_table_is_the_1997_list_of_seventeen() -> void:
	assert_eq(RandomEffectTable.COUNT, 17)
	assert_eq(RandomEffectTable.MESSAGES.size(), 17)
	assert_eq(RandomEffectTable.MESSAGES[0], "activates Time Elemental effect!")
	assert_eq(RandomEffectTable.MESSAGES[1], "casts Twiddle to untap.")
	assert_eq(RandomEffectTable.MESSAGES[12], "activates Bottle of Suleiman effect!")
	assert_eq(RandomEffectTable.MESSAGES[16], "activates Sindbad effect!")


func test_whimsy_plays_exactly_x_effects_each_announced() -> void:
	put_battlefield(1, "Grizzly Bears")
	var whimsy := give_hand(0, "Whimsy")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, whimsy, [], 3))
	resolve_stack()
	var announced := 0
	for line in g.log_lines:
		if line.begins_with("P0 casts ") or line.begins_with("P0 activates "):
			if not line.begins_with("P0 casts Whimsy"):
				announced += 1
	assert_eq(announced, 3, "one 1997 line per roll: %s" % ["\n".join(g.log_lines)])
	assert_eq(whimsy.zone, Mtg.Zone.GRAVEYARD)


func test_whimsy_entry_time_elemental_bounces_an_unenchanted_permanent() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	var bears := put_battlefield(1, "Grizzly Bears")
	RandomEffectTable.play(g, whimsy, 0, 0)
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(_log_count("P0 activates Time Elemental effect!"), 1)


func test_whimsy_entry_time_elemental_skips_an_enchanted_permanent() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	var bears := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bears)]))
	resolve_stack()
	RandomEffectTable.play(g, whimsy, 0, 0)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "an enchanted permanent is not a candidate")
	assert_eq(aura.zone, Mtg.Zone.HAND, "the Aura itself was the only one")


func test_whimsy_effect_with_no_valid_target_fizzles() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	RandomEffectTable.play(g, whimsy, 0, 0)   # Time Elemental on an empty board
	assert_eq(_log_count("P0 activates Time Elemental effect!"), 1, "announced")
	assert_eq(_log_count("fizzles"), 1, "Duel.hlp: no valid target — it fizzles")
	RandomEffectTable.play(g, whimsy, 0, 5)   # Crumble with no artifact
	assert_eq(_log_count("fizzles"), 2)


func test_whimsy_entry_twiddles() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	var bears := put_battlefield(1, "Grizzly Bears")
	RandomEffectTable.play(g, whimsy, 0, 2)   # Twiddle to tap
	assert_true(bears.tapped)
	RandomEffectTable.play(g, whimsy, 0, 1)   # Twiddle to untap
	assert_false(bears.tapped)


func test_whimsy_entry_aladdins_ring_hits_a_random_any_target() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	RandomEffectTable.play(g, whimsy, 0, 3)
	assert_eq(g.players[0].life + g.players[1].life, 36, "4 damage landed on a player")
	assert_eq(_log_count("P0 activates Aladdin's Ring effect!"), 1)


func test_whimsy_entry_crumble_pays_the_artifacts_controller() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	var hive := put_battlefield(1, "The Hive")   # {5}
	RandomEffectTable.play(g, whimsy, 0, 5)
	assert_eq(hive.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 25, "life equal to its mana value")


func test_whimsy_entries_that_sweep_and_draw_and_mill() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	var bears := put_battlefield(1, "Grizzly Bears")
	var forest := put_battlefield(1, "Forest")
	var hive := put_battlefield(0, "The Hive")
	RandomEffectTable.play(g, whimsy, 0, 11)   # Nevinyrral's Disk
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(hive.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "lands survive the Disk")
	var hands := g.players[0].hand.size() + g.players[1].hand.size()
	RandomEffectTable.play(g, whimsy, 0, 4)    # Ancestral Recall
	assert_eq(g.players[0].hand.size() + g.players[1].hand.size(), hands + 3)
	var libraries := g.players[0].library.size() + g.players[1].library.size()
	RandomEffectTable.play(g, whimsy, 0, 9)    # Millstone
	assert_eq(g.players[0].library.size() + g.players[1].library.size(), libraries - 2)
	var life := g.players[0].life + g.players[1].life
	RandomEffectTable.play(g, whimsy, 0, 7)    # Healing Salve
	assert_eq(g.players[0].life + g.players[1].life, life + 3)


func test_whimsy_entry_the_hive_gives_the_caster_a_wasp() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	RandomEffectTable.play(g, whimsy, 0, 10)
	assert_eq(g.players[0].battlefield.size(), 1)
	assert_eq(g.players[0].battlefield[0].data.card_name, "Wasp")


func test_whimsy_entry_bottle_of_suleiman_asks_the_caster_to_call_the_flip() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	var seat := OptionSeat.new()
	g.set_agent(0, seat)
	RandomEffectTable.play(g, whimsy, 0, 12)
	assert_eq(seat.asks.size(), 1)
	assert_eq(seat.asks[0]["prompt"], "Call the coin flip:", "`@WHIMSY_BOTTLESULEIMAN`")
	assert_eq(seat.asks[0]["options"], ["Heads.", "Tails."])
	var djinns := 0
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Djinn":
			djinns += 1
	if djinns == 1:
		assert_eq(g.players[0].life, 20, "won the call: a 5/5 flier")
	else:
		assert_eq(g.players[0].life, 15, "lost the call: 5 damage to the caster")


func test_whimsy_entry_disrupting_scepter_makes_a_random_player_discard() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	give_hand(0, "Grizzly Bears")
	give_hand(1, "Grizzly Bears")
	RandomEffectTable.play(g, whimsy, 0, 14)
	assert_eq(g.players[0].hand.size() + g.players[1].hand.size(), 1)


func test_whimsy_entry_fog_and_sindbad() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	RandomEffectTable.play(g, whimsy, 0, 15)   # Fog
	assert_true(g.combat_damage_prevented)
	RandomEffectTable.play(g, whimsy, 0, 16)   # Sindbad: the top card is a Forest
	assert_eq(g.players[0].hand.size(), 1, "a land stays in hand")
	assert_eq(_log_count("Sindbad draws..."), 1, "`@WHIMSY_SINDBAD`")


func test_whimsy_entry_fissure_and_disenchant() -> void:
	var whimsy := _make_instance(0, "Whimsy")
	var bears := put_battlefield(1, "Grizzly Bears")
	RandomEffectTable.play(g, whimsy, 0, 8)    # Fissure
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	var hive := put_battlefield(1, "The Hive")
	RandomEffectTable.play(g, whimsy, 0, 6)    # Disenchant
	assert_eq(hive.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------ Goblin Polka Band --

func _band_ready(x: int) -> CardInstance:
	var band := put_battlefield(0, "Goblin Polka Band")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	add_mana(0, Mtg.ManaColor.R, x)
	return band


func test_polka_band_names_its_random_victims_as_it_is_activated() -> void:
	var band := _band_ready(2)
	var wall := put_battlefield(1, "Wall of Stone")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, band, 0, [], 2))
	var item: StackItem = g.stack[-1]
	assert_eq(item.targets.size(), 2, "two random creature targets on the stack")
	assert_false(item.targets[0].same_object(item.targets[1]), "two DIFFERENT ones")
	resolve_stack()
	var tapped := 0
	for inst in [wall, bears]:
		if inst.tapped:
			tapped += 1
	assert_true(tapped >= 1, "at least one of theirs was tapped")
	assert_true(band.tapped)


func test_polka_band_can_roll_its_own_tapped_self_and_waste_the_red() -> void:
	# All three creatures are targets when X is 3 — the Band included: it
	# is untapped when the targets are chosen (CR 601.2c comes before the
	# {T} of 601.2h), and its {R} taps nothing.
	var band := _band_ready(3)
	var wall := put_battlefield(1, "Wall of Stone")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, band, 0, [], 3))
	var names := _creature_names(g.stack[-1].targets)
	names.sort()
	assert_eq(names, ["Goblin Polka Band", "Grizzly Bears", "Wall of Stone"])
	resolve_stack()
	assert_true(wall.tapped)
	assert_true(bears.tapped)
	assert_true(band.tapped)
	assert_false(band.skip_next_untap, "already tapped: the {R} on itself was wasted")


func test_polka_band_x_of_zero_takes_no_target() -> void:
	var band := _band_ready(0)
	put_battlefield(1, "Wall of Stone")
	assert_ok(g.activate_ability(0, band, 0, [], 0))
	assert_eq(g.stack[-1].targets.size(), 0)
	resolve_stack()
	assert_eq(_log_count("fizzles"), 0, "no target chosen is not a fizzle (CR 115.5)")


func test_polka_band_victim_that_leaves_in_response_is_skipped() -> void:
	var band := _band_ready(2)
	var wall := put_battlefield(1, "Wall of Stone")
	assert_ok(g.activate_ability(0, band, 0, [], 2))
	assert_eq(g.stack[-1].targets.size(), 2, "the Band and the Wall")
	g.destroy(wall, false)
	resolve_stack()
	assert_eq(_log_count("is illegal — skipped"), 1, "CR 608.2b — the rest still resolves")


func test_polka_band_goblin_rolled_stays_down() -> void:
	var band := _band_ready(2)
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	assert_ok(g.activate_ability(0, band, 0, [], 2))
	resolve_stack()
	assert_true(goblin.tapped)
	assert_true(goblin.skip_next_untap)


func test_polka_band_supplied_target_is_refused() -> void:
	var band := _band_ready(1)
	var wall := put_battlefield(1, "Wall of Stone")
	assert_refused(g.activate_ability(0, band, 0, [TargetRef.card(wall)], 1),
		"takes 0 target(s)")


# --------------------------------------------------------- Orcish Catapult --

func _catapult_ready(x: int) -> CardInstance:
	var catapult := give_hand(0, "Orcish Catapult")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, x)
	return catapult


func test_orcish_catapult_names_victims_and_shares_as_it_is_cast() -> void:
	var catapult := _catapult_ready(4)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Wall of Stone")
	assert_ok(g.cast_spell(0, catapult, [], 4))
	var item: StackItem = g.stack[-1]
	assert_true(item.targets.size() >= 1 and item.targets.size() <= 3,
		"a random number of random creatures: %d" % item.targets.size())
	var total := 0
	for ref in item.targets:
		assert_true(ref.amount >= 1, "each target gets at least one (CR 601.2d)")
		total += ref.amount
	assert_eq(total, 4, "the X counters are divided as the spell is cast")
	var shares := {}
	for ref in item.targets:
		shares[ref.instance_id] = ref.amount
	resolve_stack()
	for id in shares:
		var inst := g.find_instance(id)
		if inst.zone == Mtg.Zone.BATTLEFIELD:
			assert_eq(int(inst.counters.get("-0/-1", 0)), int(shares[id]),
				"%s got exactly its share" % inst.data.card_name)
		else:
			# Counters vanish with the card (CR 122.2); it died of its share.
			assert_true(int(shares[id]) >= inst.data.toughness,
				"%s died of its share" % inst.data.card_name)


func test_orcish_catapult_x_of_zero_has_no_targets_and_no_counters() -> void:
	var catapult := _catapult_ready(0)
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.cast_spell(0, catapult, [], 0))
	assert_eq(g.stack[-1].targets.size(), 0)
	resolve_stack()
	assert_eq(int(bears.counters.get("-0/-1", 0)), 0)
	assert_eq(catapult.zone, Mtg.Zone.GRAVEYARD)


func test_orcish_catapult_needs_a_creature_when_x_is_positive() -> void:
	var catapult := _catapult_ready(2)
	assert_refused(g.cast_spell(0, catapult, [], 2), "no legal target")
	assert_eq(catapult.zone, Mtg.Zone.HAND)


func test_orcish_catapult_frozen_share_is_lost_with_its_target() -> void:
	var catapult := _catapult_ready(3)
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	assert_ok(g.cast_spell(0, catapult, [], 3))
	var item: StackItem = g.stack[-1]
	var first := g.find_instance(item.targets[0].instance_id)
	var expected := {}
	for ref in item.targets:
		expected[ref.instance_id] = ref.amount
	g.destroy(first, false)
	resolve_stack()
	for inst in [bears, giant]:
		if inst == first:
			continue
		assert_eq(int(inst.counters.get("-0/-1", 0)), int(expected.get(inst.id, 0)),
			"%s keeps its frozen share; the dead target's is not redistributed" % inst.data.card_name)


func test_orcish_catapult_supplied_target_is_refused() -> void:
	var catapult := _catapult_ready(2)
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.cast_spell(0, catapult, [TargetRef.card(bears)], 2),
		"takes 0 target(s)")
