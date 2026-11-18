extends GameTest
## A CARD A PLAYER MADE ([CommunityCard]): the spec checked, built from the
## engine's own pieces and its rules text written from them — then cast,
## activated, triggered and worn in real duels.


func _spec(extra: Dictionary) -> Dictionary:
	var spec := {"format": CommunityCard.FORMAT, "version": 1, "name": "Test Card",
		"cost": "{1}{R}", "types": ["creature"], "power": 2, "toughness": 2,
		"rarity": "common", "abilities": []}
	spec.merge(extra, true)
	return spec


func _card(extra: Dictionary) -> CardData:
	var spec := _spec(extra)
	assert_eq(CommunityCard.problems(spec), [] as Array[String], "the spec is whole")
	return CommunityCard.build(spec)


# ------------------------------------------------------------- checking --

func test_a_whole_card_has_no_problem_and_a_broken_one_says_each() -> void:
	assert_eq(CommunityCard.problems(_spec({})), [] as Array[String])
	var broken := CommunityCard.problems(_spec({"name": "", "cost": "{Q}", "types": ["creature", "wizard"],
		"power": 200, "rarity": "epic", "keywords": ["swimming"],
		"abilities": [{"kind": "spell", "effects": [{"effect": "draw", "amount": 1}]}]}))
	for words in ["The name must be", "mana cost is like", "Unknown card type", "power is a number",
			"rarity is", "Unknown keyword", "only an instant or a sorcery has a spell effect"]:
		assert_true(broken.any(func(line: String) -> bool: return line.contains(words)), words)
	assert_false(CommunityCard.problems("not a card").is_empty())
	assert_false(CommunityCard.problems(_spec({"types": ["instant"], "abilities": []})).is_empty(),
		"an instant needs a spell effect")
	assert_false(CommunityCard.problems(_spec({"types": ["land"], "cost": "{1}"})).is_empty(),
		"a land has no mana cost")
	assert_true(CommunityCard.cost_ok("{2}{W}{W}"))
	assert_false(CommunityCard.cost_ok("{20}{R}"), "at most 16 mana")
	assert_false(CommunityCard.cost_ok("2R"))


# ------------------------------------------------------------- building --

func test_a_creature_is_built_with_everything_it_names() -> void:
	var data := _card({"name": "Ember Hawk", "cost": "{2}{R}", "power": 3, "toughness": 1,
		"subtypes": ["bird"], "supertypes": ["legendary"], "keywords": ["flying", "haste"],
		"protection": ["blue"], "landwalk": ["mountain"], "flavor": "It never lands."})
	assert_eq(data.card_name, "Ember Hawk")
	assert_eq(data.cost.mana_value(), 3)
	assert_true(data.is_type(Mtg.CardType.CREATURE))
	assert_eq([data.power, data.toughness], [3, 1])
	assert_true(data.keywords.has(Mtg.Keyword.FLYING) and data.keywords.has(Mtg.Keyword.HASTE))
	assert_eq(data.protection_from, Mtg.ManaColor.U)
	assert_eq(data.landwalk, ["mountain"] as Array[String])
	assert_true(data.subtypes.has("bird"))
	assert_ne(data.supertypes & Mtg.Supertype.LEGENDARY, 0)
	assert_eq(data.flavor_text, "It never lands.")
	assert_eq(data.oracle_text, "Flying, haste, protection from blue, mountainwalk")


func test_the_rules_text_is_written_from_the_blocks() -> void:
	var spec := _spec({"name": "Sage", "abilities": [
		{"kind": "activated", "cost": "{1}", "tap": true, "effects": [{"effect": "draw", "amount": 1}]},
		{"kind": "trigger", "when": "enters", "effects": [{"effect": "gain_life", "amount": 3},
			{"effect": "damage", "amount": 1, "target": "opponent"}]},
		{"kind": "mana", "color": "green", "amount": 2},
		{"kind": "static", "what": "anthem_others", "power": 1, "toughness": 1, "keywords": ["vigilance"]}]})
	assert_eq(CommunityCard.rules_text(spec), "\n".join([
		"{1}, {T}: Draw a card.",
		"When Sage enters the battlefield, you gain 3 life and Sage deals 1 damage to target opponent.",
		"{T}: Add {G}{G}.",
		"Other creatures you control get +1/+1 and have vigilance."]))
	var spell := _spec({"name": "Double Spark", "types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "damage", "amount": 2, "target": "creature"}, {"effect": "draw", "amount": 2}]}]})
	assert_eq(CommunityCard.rules_text(spell), "Double Spark deals 2 damage to target creature and draw two cards.")


# ------------------------------------------------------------ in a duel --

func test_a_community_instant_burns_the_opponent() -> void:
	var data := _card({"name": "Spark of Will", "cost": "{R}", "types": ["instant"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "damage", "amount": 3, "target": "any"}]}]})
	var spark := give_synthetic(0, data)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, spark, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_an_activated_ability_draws_a_card() -> void:
	var sage := put_synthetic(0, _card({"name": "Library Sage", "abilities": [
		{"kind": "activated", "cost": "{1}", "tap": true, "effects": [{"effect": "draw", "amount": 1}]}]}))
	var before := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, sage, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1)
	assert_true(sage.tapped)


func test_an_enters_trigger_and_a_dies_trigger_fire() -> void:
	put_synthetic(0, _card({"name": "Healer of Ash", "abilities": [
		{"kind": "trigger", "when": "enters", "effects": [{"effect": "gain_life", "amount": 3}]}]}))
	resolve_stack()
	assert_eq(g.players[0].life, 23)
	var egg := put_synthetic(0, _card({"name": "Ash Egg", "abilities": [
		{"kind": "trigger", "when": "dies", "effects": [{"effect": "draw", "amount": 2}]}]}))
	var hand := g.players[0].hand.size()
	g.destroy(egg)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 2)


func test_an_anthem_and_an_aura_change_creatures() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(0, _card({"name": "Banner of Ash", "cost": "{2}", "types": ["enchantment"],
		"abilities": [{"kind": "static", "what": "anthem", "power": 1, "toughness": 1, "keywords": ["flying"]}]}))
	g.recalculate()
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_eq([theirs.cur_power, theirs.cur_toughness], [2, 2], "only creatures you control")
	var cloak := CardInstance.new(_card({"name": "Cloak of Ash", "cost": "{W}", "types": ["enchantment"],
		"abilities": [{"kind": "enchant", "power": 2, "toughness": 0, "keywords": ["first_strike"]}]}),
		g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[cloak.id] = cloak
	cloak.zone = Mtg.Zone.HAND
	g.players[1].hand.append(cloak)
	g.attach_aura_from_anywhere(cloak, theirs, 1)
	g.recalculate()
	assert_eq([theirs.cur_power, theirs.cur_toughness], [4, 2])
	assert_true(theirs.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_a_mana_creature_and_a_token_maker() -> void:
	var elf := _card({"name": "Ash Elf", "abilities": [{"kind": "mana", "color": "green", "amount": 1}]})
	assert_eq(elf.mana_abilities.size(), 1)
	var call := give_synthetic(0, _card({"name": "Call the Ash", "cost": "{2}", "types": ["sorcery"],
		"abilities": [{"kind": "spell", "effects": [{"effect": "token", "amount": 2, "power": 1,
			"toughness": 1, "color": "red", "subtype": "goblin"}]}]}))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, call, []))
	resolve_stack()
	var goblins := g.all_battlefield().filter(func(i: CardInstance) -> bool: return i.data.subtypes.has("goblin"))
	assert_eq(goblins.size(), 2)
	assert_eq([goblins[0].cur_power, goblins[0].cur_toughness], [1, 1])


# ------------------------------------------- the rules of every set --

func test_card_rules_are_built_and_written() -> void:
	var data := _card({"name": "Old Guard", "cost": "{3}{W}", "power": 3, "toughness": 3,
		"keywords": ["must_attack"],
		"rules": {"echo": "{3}{W}", "rampage": 2, "enters_counters": 1, "enters_tapped": true,
			"cant_be_countered": true, "no_walls": true, "extra_blocks": 1, "extra_life": 2, "cycling": "{2}"}})
	assert_eq(data.rampage, 2)
	assert_true(data.enters_tapped)
	assert_true(data.cant_be_countered)
	assert_eq(data.cant_be_blocked_by, ["wall"] as Array[String])
	assert_eq(data.extra_blocks, 1)
	assert_eq(data.additional_life, 2)
	assert_true(data.keywords.has(Mtg.Keyword.MUST_ATTACK))
	assert_eq(data.triggered_abilities.size(), 1, "echo waits for the upkeep")
	assert_eq(data.oracle_text, "\n".join([
		"Rampage 2",
		"Echo {3}{W}",
		"Cycling {2}",
		"Old Guard attacks each combat if able.",
		"As an additional cost to cast Old Guard, pay 2 life.",
		"Old Guard can't be countered.",
		"Old Guard enters the battlefield tapped.",
		"Old Guard enters the battlefield with a +1/+1 counter on it.",
		"Old Guard can't be blocked by Walls.",
		"Old Guard can block an additional creature each combat."]))
	var wrong := CommunityCard.problems(_spec({"types": ["instant"], "rules": {"echo": "{1}", "rampage": 9},
		"abilities": [{"kind": "spell", "effects": [{"effect": "draw", "amount": 1}]}]}))
	for words in ["Echo is for", "Rampage is for", "Rampage is 1 to 5"]:
		assert_true(wrong.any(func(line: String) -> bool: return line.contains(words)), words)


func test_it_enters_tapped_with_its_counters_and_cannot_block() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var golem := give_synthetic(0, _card({"name": "Stiff Golem", "cost": "{3}", "types": ["artifact", "creature"],
		"rules": {"enters_tapped": true, "enters_counters": 2, "cant_block": true}}))
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, golem, []))
	resolve_stack()
	g.recalculate()
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(golem.tapped, "it enters tapped")
	assert_eq(int(golem.counters.get("+1/+1", 0)), 2)
	assert_eq([golem.cur_power, golem.cur_toughness], [4, 4])
	assert_true(golem.cur_cant_block_filter.is_valid(), "it can't block")


func test_combat_damage_end_step_and_cast_triggers_fire() -> void:
	put_synthetic(0, _card({"name": "Dusk Bell", "cost": "{2}", "types": ["artifact"], "abilities": [
		{"kind": "trigger", "when": "end_step", "effects": [{"effect": "gain_life", "amount": 2}]}]}))
	var raider := put_synthetic(0, _card({"name": "Ash Raider", "abilities": [
		{"kind": "trigger", "when": "combat_damage_player", "effects": [{"effect": "draw", "amount": 1}]}]}))
	advance_to_step(Mtg.Step.MAIN1)
	var hand := g.players[0].hand.size()
	run_combat([raider.id])
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].hand.size(), hand + 1, "it dealt combat damage to a player")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 22, "at the beginning of your end step")


func test_a_spell_cast_and_a_creature_arriving_trigger() -> void:
	put_synthetic(0, _card({"name": "Ash Chorus", "cost": "{2}", "types": ["enchantment"], "abilities": [
		{"kind": "trigger", "when": "you_cast", "effects": [{"effect": "gain_life", "amount": 1}]},
		{"kind": "trigger", "when": "creature_enters", "effects": [{"effect": "gain_life", "amount": 10}]}]}))
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear, []))
	resolve_stack()
	assert_eq(g.players[0].life, 31, "+1 as it was cast, +10 as it arrived")


func test_an_x_spell_a_drain_and_an_extra_turn() -> void:
	assert_false(CommunityCard.problems(_spec({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "damage", "x": true, "target": "any"}]}]})).is_empty(), "X needs {X} in the cost")
	var blast := give_synthetic(0, _card({"name": "Ash Blast", "cost": "{X}{R}", "types": ["sorcery"],
		"abilities": [{"kind": "spell", "effects": [{"effect": "damage", "x": true, "target": "any"}]}]}))
	assert_eq(blast.data.oracle_text, "Ash Blast deals X damage to any target.")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	var drain := give_synthetic(0, _card({"name": "Ash Thirst", "cost": "{B}", "types": ["sorcery"],
		"abilities": [{"kind": "spell", "effects": [{"effect": "drain", "amount": 2, "target": "opponent"},
			{"effect": "extra_turn"}]}]}))
	assert_eq(drain.data.oracle_text,
		"Target opponent loses 2 life and you gain 2 life and take an extra turn after this one.")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq([g.players[0].life, g.players[1].life], [22, 15])
	assert_eq(g.extra_turns.size(), 1)


func test_a_lord_a_steal_an_edict_and_cheaper_creatures() -> void:
	var goblin := put_synthetic(0, _card({"name": "Ash Goblin", "subtypes": ["goblin"], "power": 1, "toughness": 1}))
	var chief := put_synthetic(0, _card({"name": "Ash Chief", "subtypes": ["goblin"], "abilities": [
		{"kind": "static", "what": "lord", "subtype": "goblin", "power": 1, "toughness": 1, "keywords": []},
		{"kind": "static", "what": "cost_less", "spell_type": "creature", "amount": 1}]}))
	assert_eq(chief.data.oracle_text, "Other Goblin creatures you control get +1/+1.\nCreature spells you cast cost {1} less to cast.")
	g.recalculate()
	assert_eq([goblin.cur_power, chief.cur_power], [2, 2], "the other goblins, not itself")
	var pay := g.spell_payment(0, CardRegistry.get_card("Grizzly Bears"), 0, 1, null, 0)
	assert_eq((pay["cost"] as ManaCost).mana_value() + int(pay["extra"]), 1, "creature spells cost {1} less")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var take := give_synthetic(0, _card({"name": "Ash Theft", "cost": "{U}", "types": ["sorcery"],
		"abilities": [{"kind": "spell", "effects": [{"effect": "steal", "target": "creature"}]}]}))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, take, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0, "gain control")
	var lone := put_battlefield(1, "Hill Giant")
	var edict := give_synthetic(0, _card({"name": "Ash Edict", "cost": "{B}", "types": ["sorcery"],
		"abilities": [{"kind": "spell", "effects": [{"effect": "sacrifice", "target": "opponent"}]}]}))
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, edict, [TargetRef.player(1)]))
	resolve_stack()
	assert_ne(lone.zone, Mtg.Zone.BATTLEFIELD, "the opponent sacrificed it")


func test_a_trigger_offers_the_opponent_first_for_harm_and_its_own_side_for_help() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var source := put_synthetic(0, _card({"name": "Ash Eye"}))
	var choices := [TargetRef.card(mine), TargetRef.card(theirs)]
	var harm := CommunityCard._order(false)
	choices.sort_custom(func(a: TargetRef, b: TargetRef) -> bool: return harm.call(g, source, a, b))
	assert_eq(choices[0].instance_id, theirs.id, "damage goes to the opponent's first")
	var help := CommunityCard._order(true)
	choices.sort_custom(func(a: TargetRef, b: TargetRef) -> bool: return help.call(g, source, a, b))
	assert_eq(choices[0].instance_id, mine.id, "a pump to its own first")


func test_every_trigger_static_and_effect_of_the_catalogue_builds() -> void:
	for when in CommunityCard.TRIGGERS:
		var data := _card({"name": "Ash Test", "abilities": [{"kind": "trigger", "when": when,
			"effects": [{"effect": "gain_life", "amount": 1}]}]})
		assert_eq(data.triggered_abilities.size(), 1, when)
		assert_false(data.oracle_text.contains("CARDNAME"), when)
	for what in CommunityCard.STATICS:
		var a := {"kind": "static", "what": what, "power": 1, "toughness": 1, "keywords": [],
			"subtype": "goblin", "spell_type": "creature", "amount": 1}
		var data := _card({"name": "Ash Test", "abilities": [a]})
		assert_ne(data.oracle_text, "", what)
	for id in CommunityCard.EFFECTS:
		var kind := "activated"
		var e := CommunityCard.effect_defaults(id, kind)
		var spec := _spec({"name": "Ash Test", "abilities": [{"kind": kind, "cost": "{1}", "tap": true,
			"effects": [e]}]})
		if id in ["counter", "fog", "extra_turn", "counter_ability", "add_mana"]:
			spec = _spec({"name": "Ash Test", "types": ["instant"], "abilities": [{"kind": "spell",
				"effects": [CommunityCard.effect_defaults(id, "spell")]}]})
		elif id == "animate":
			spec = _spec({"name": "Ash Test", "cost": "{3}", "types": ["artifact"], "abilities": [
				{"kind": kind, "cost": "{1}", "effects": [e]}]})
		assert_eq(CommunityCard.problems(spec), [] as Array[String], id)
		assert_not_null(CommunityCard.effect_of(e), id)
		assert_ne(CommunityCard.rules_text(spec), "", id)


# ------------------------------------------- the bug pass (2026-11-17) --

func test_a_spec_of_the_wrong_shape_is_refused_and_never_crashes() -> void:
	var bad_effect := {"kind": "spell", "effects": [{"effect": "damage", "amount": "abc"}]}
	var cases := [{"version": null}, {"name": 5}, {"cost": null}, {"types": [null]}, {"subtypes": [5]},
		{"rarity": 3}, {"flavor": null}, {"power": "big"}, {"power": INF}, {"keywords": {"a": 1}},
		{"look": {"art": "x"}}, {"look": {"border": 7}}, {"rules": {"echo": 5}}, {"rules": {"rampage": null}},
		{"rules": {"enters_tapped": "yes"}}, {"abilities": [5]}, {"abilities": "boom"},
		{"types": ["instant"], "abilities": [bad_effect]},
		{"abilities": [{"kind": "activated", "cost": "{1}", "tap": "yes", "effects": [{"effect": "draw"}]}]},
		{"abilities": [{"kind": "static", "what": "anthem", "keywords": "flying"}]},
		{"abilities": [{"kind": "static", "what": "anthem", "effects": "boom"}]},
		{"abilities": [{"kind": "trigger", "when": "enters", "effects": [null]}]},
		{"abilities": [{"kind": "activated", "cost": "{X}", "effects": [{"effect": "draw", "x": "yes"}]}]}]
	for extra in cases:
		var spec := _spec(extra)
		var found := CommunityCard.problems(spec)
		assert_false(found.is_empty(), "refused: %s" % str(extra))
	assert_false(CommunityCard.problems(_spec({"rules": {"enters_tapped": false}})).is_empty(),
		"a flag is on or left out")


func test_the_rule_checks_of_the_bug_pass() -> void:
	assert_false(CommunityCard.problems(_spec({"types": ["land", "artifact", "creature"], "cost": ""})).is_empty(),
		"a land is a land or an artifact land")
	assert_eq(CommunityCard.problems(_spec({"types": ["land", "artifact"], "cost": ""})), [] as Array[String])
	assert_false(CommunityCard.problems(_spec({"types": ["artifact"], "abilities": [{"kind": "activated",
		"cost": "{1}", "effects": [{"effect": "pump", "power": 2, "toughness": 2, "target": "self"}]}]})).is_empty(),
		"an artifact cannot pump itself")
	assert_false(CommunityCard.problems(_spec({"cost": "{X}{R}", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "damage", "x": true, "target": "each_opponent"}]}]})).is_empty(), "X to each opponent")
	assert_false(CommunityCard.problems(_spec({"types": ["land"], "cost": "", "rules": {"extra_life": 2}})).is_empty(),
		"a land is never cast")
	var pump := _card({"cost": "{X}{G}", "types": ["instant"], "abilities": [{"kind": "spell", "effects": [
		{"effect": "pump", "x": true, "power": 0, "toughness": 1, "keywords": ["flying"], "target": "creature"}]}]})
	assert_eq(pump.oracle_text, "Target creature gets +X/+1 and has flying until end of turn.")
	var mill := _card({"types": ["sorcery"], "abilities": [{"kind": "spell", "effects": [
		{"effect": "mill", "amount": 1, "target": "player"}]}]})
	assert_string_contains(mill.oracle_text, "puts the top card of their library")
	assert_false(CommunityCard._helpful({"effect": "pump", "power": -2, "toughness": -2}), "a shrink is harm")
	assert_true(CommunityCard._helpful({"effect": "pump", "power": 2, "toughness": 0}))


func test_a_shrinking_trigger_goes_for_the_opponent_s_creature() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, _card({"name": "Ash Wither", "abilities": [{"kind": "trigger", "when": "enters",
		"effects": [{"effect": "pump", "power": -2, "toughness": -2, "target": "creature"}]}]}))
	resolve_stack()
	g.recalculate()
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "its own bear lives")
	assert_ne(theirs.zone, Mtg.Zone.BATTLEFIELD, "the opponent's bear dies")


func test_a_land_that_cares_for_lands_counts_itself() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var grove := give_synthetic(0, _card({"name": "Ash Grove", "types": ["land"], "cost": "", "abilities": [
		{"kind": "trigger", "when": "land_enters", "effects": [{"effect": "gain_life", "amount": 1}]}]}))
	assert_ok(g.play_land(0, grove))
	resolve_stack()
	assert_eq(g.players[0].life, 21)


# ----------------------------------------- every feature (round 4) --

func test_mana_of_any_color_a_pain_land_and_a_lotus() -> void:
	var land := _card({"name": "Ash Wastes", "types": ["land"], "cost": "", "abilities": [
		{"kind": "mana", "color": "any", "amount": 1, "pain": 1}]})
	assert_eq(land.mana_abilities.size(), 5, "one ability a color")
	assert_eq(land.oracle_text, "{T}: Add one mana of any color. Ash Wastes deals 1 damage to you.")
	var wastes := put_synthetic(0, land)
	assert_ok(g.tap_for_mana(0, wastes, 3))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.R), 1, "red mana made")
	assert_eq(g.players[0].life, 19, "the pain land hurts")
	var lotus := _card({"name": "Ash Lotus", "cost": "{0}", "types": ["artifact"], "abilities": [
		{"kind": "mana", "color": "any", "amount": 3, "sacrifice": true}]})
	assert_eq(lotus.oracle_text, "{T}, Sacrifice Ash Lotus: Add three mana of any one color.")
	var petal := put_synthetic(0, lotus)
	assert_ok(g.tap_for_mana(0, petal, 4))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 3)
	assert_ne(petal.zone, Mtg.Zone.BATTLEFIELD, "sacrificed")
	var filter := _card({"name": "Ash Filter", "types": ["land"], "cost": "", "abilities": [
		{"kind": "mana", "color": "blue", "amount": 2, "cost": "{1}"}]})
	assert_eq(filter.oracle_text, "{1}, {T}: Add {U}{U}.")
	assert_false(CommunityCard.problems(_spec({"types": ["land"], "cost": "", "abilities": [
		{"kind": "mana", "color": "any", "pain": 5}]})).is_empty(), "pain is 0 to 2")


func test_costs_sacrifice_a_creature_discard_and_remove_counters() -> void:
	var fiend := _card({"name": "Ash Fiend", "abilities": [
		{"kind": "activated", "cost": "", "sacrifice_what": "creature", "effects": [
			{"effect": "pump", "power": 2, "toughness": 2, "target": "self"}]},
		{"kind": "activated", "cost": "{1}", "discard": 1, "effects": [{"effect": "draw", "amount": 2}]},
		{"kind": "activated", "cost": "", "remove_counters": 1, "effects": [
			{"effect": "gain_life", "amount": 2}]}], "rules": {"enters_counters": 2}})
	assert_string_contains(fiend.oracle_text, "Sacrifice a creature: Ash Fiend gets +2/+2 until end of turn.")
	assert_string_contains(fiend.oracle_text, "{1}, Discard a card: Draw two cards.")
	assert_string_contains(fiend.oracle_text, "Remove a +1/+1 counter from Ash Fiend: You gain 2 life.")
	assert_eq(fiend.activated_abilities[1].discard_cost, 1)
	assert_eq(fiend.activated_abilities[2].counter_cost_kind, "+1/+1")
	var me := put_synthetic(0, fiend)
	me.counters["+1/+1"] = 2
	g.recalculate()
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, me, 2))
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	assert_eq(int(me.counters.get("+1/+1", 0)), 1, "a counter was the cost")
	assert_false(CommunityCard.problems(_spec({"types": ["artifact"], "cost": "{2}", "abilities": [
		{"kind": "activated", "cost": "", "remove_counters": 1, "effects": [{"effect": "draw", "amount": 1}]}]})).is_empty(),
		"counters are a creature's")


func test_a_token_with_flying() -> void:
	var data := _card({"name": "Ash Roost", "types": ["sorcery"], "cost": "{2}{W}", "abilities": [
		{"kind": "spell", "effects": [{"effect": "token", "amount": 2, "power": 1, "toughness": 1,
			"color": "white", "subtype": "bird", "keywords": ["flying"]}]}]})
	assert_eq(data.oracle_text, "Create two 1/1 white Bird creature tokens with flying.")
	var roost := give_synthetic(0, data)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, roost))
	resolve_stack()
	var birds := g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.has_subtype("bird"))
	assert_eq(birds.size(), 2)
	assert_true(birds.all(func(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)))


func test_the_new_stock_effects_work_and_say_so() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var wall := _card({"name": "Ash Shrink", "types": ["instant"], "cost": "{U}", "abilities": [
		{"kind": "spell", "effects": [{"effect": "set_pt", "power": 0, "toughness": 1, "target": "creature"},
			{"effect": "lose_keyword", "keywords": ["flying"], "target": "creature"}]}]})
	assert_eq(wall.oracle_text, "Target creature has base power and toughness 0/1 until end of turn and target creature loses flying until end of turn.")
	var shrink := give_synthetic(0, wall)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 1)
	assert_ok(g.cast_spell(0, shrink, [TargetRef.card(bear), TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [0, 1])
	var rot := give_synthetic(0, _card({"name": "Ash Rot", "types": ["instant"], "cost": "{B}", "abilities": [
		{"kind": "spell", "effects": [{"effect": "minus_counters", "amount": 1, "target": "creature"}]}]}))
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_ok(g.cast_spell(0, rot, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ne(bear.zone, Mtg.Zone.BATTLEFIELD, "a 0/1 with a -1/-1 counter dies")
	var golem := put_synthetic(0, _card({"name": "Ash Golem", "types": ["artifact"], "cost": "{3}", "abilities": [
		{"kind": "activated", "cost": "{1}", "effects": [{"effect": "animate", "power": 3, "toughness": 3,
			"subtype": "golem"}]}]}))
	assert_string_contains(golem.data.oracle_text, "{1}: Ash Golem becomes a 3/3 Golem creature until end of turn.")
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.activate_ability(0, golem, 0))
	resolve_stack()
	assert_true(golem.is_creature())
	assert_eq([golem.cur_power, golem.cur_toughness], [3, 3])
	var walker := put_synthetic(0, _card({"name": "Ash Walker", "abilities": [
		{"kind": "activated", "cost": "{G}", "effects": [{"effect": "landwalk", "land": "forest", "target": "self"},
			{"effect": "switch_pt", "target": "self"}]}], "power": 1, "toughness": 3}))
	assert_string_contains(walker.data.oracle_text, "{G}: Ash Walker gains forestwalk until end of turn and switch Ash Walker's power and toughness until end of turn.")
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.activate_ability(0, walker, 0))
	resolve_stack()
	assert_true(walker.cur_landwalk.has("forest"))
	assert_eq([walker.cur_power, walker.cur_toughness], [3, 1])
	for e in [{"effect": "shield", "color": "red"}, {"effect": "draw_later", "amount": 1},
			{"effect": "search", "target": "a_creature"}]:
		var data := _card({"name": "Ash Spell", "types": ["instant"], "cost": "{1}", "abilities": [
			{"kind": "spell", "effects": [e]}]})
		assert_ne(data.oracle_text, "", str(e))
	assert_eq(CommunityCard.effect_text({"effect": "shield", "color": "red"}, "X", "spell"),
		"The next time a red source of your choice would deal damage to you this turn, prevent that damage")


func test_counter_unless_its_controller_pays() -> void:
	var leak := _card({"name": "Ash Leak", "types": ["instant"], "cost": "{1}{U}", "abilities": [
		{"kind": "spell", "effects": [{"effect": "counter", "target": "spell", "unless": 3}]}]})
	assert_eq(leak.oracle_text, "Counter target spell unless its controller pays {3}.")
	assert_true(leak.spell_effects[0] is CounterEffect, "still a counterspell to the computer")
	var bolt := give_hand(1, "Lightning Bolt")
	var mine := give_synthetic(0, leak)
	g.active_player = 1
	g.priority_player = 1
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	g.priority_player = 0
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, mine, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "no mana to pay: the bolt is countered")
	var stop := _card({"name": "Ash Stop", "types": ["instant"], "cost": "{U}", "abilities": [
		{"kind": "spell", "effects": [{"effect": "counter_ability", "target": "ability", "unless": 1}]}]})
	assert_eq(stop.oracle_text, "Counter target activated ability unless its controller pays {1}.")


func test_a_choose_one_spell() -> void:
	var charm := _card({"name": "Ash Charm", "types": ["instant"], "cost": "{R}", "abilities": [
		{"kind": "modal", "modes": [{"effects": [{"effect": "damage", "amount": 2, "target": "any"}]},
			{"effects": [{"effect": "draw", "amount": 1}]}]}]})
	assert_true(charm.is_modal())
	assert_eq(charm.modes.size(), 2)
	assert_eq(charm.oracle_text, "Choose one —\n• Ash Charm deals 2 damage to any target.\n• Draw a card.")
	var inst := give_synthetic(0, charm)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 1)
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, inst, [], 0, 1))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "cast one, drew one")
	assert_eq(CommunityCard._ai_mode(g, 1, "Nothing", []), 0)
	for extra in [{"abilities": [{"kind": "modal", "modes": [{"effects": [{"effect": "draw", "amount": 1}]}]}]},
			{"rules": {"buyback": "{2}"}, "abilities": [{"kind": "modal", "modes": [
				{"effects": [{"effect": "draw", "amount": 1}]}, {"effects": [{"effect": "draw", "amount": 2}]}]}]},
			{"types": ["creature"], "abilities": [{"kind": "modal", "modes": [
				{"effects": [{"effect": "draw", "amount": 1}]}, {"effects": [{"effect": "draw", "amount": 2}]}]}]}]:
		var spec := _spec({"types": ["instant"]})
		spec.merge(extra, true)
		assert_false(CommunityCard.problems(spec).is_empty(), str(extra))


func test_auras_on_lands_and_artifacts_steal_and_pacify() -> void:
	var magic := _card({"name": "Ash Magic", "types": ["enchantment"], "cost": "{2}{U}{U}", "abilities": [
		{"kind": "enchant", "enchant": "creature", "control": true}]})
	assert_eq(magic.oracle_text, "Enchant creature. You control enchanted creature.")
	assert_true(magic.aura_steals)
	assert_eq(EffectIntent.aura_aim(magic), EffectIntent.Aim.HOSTILE)
	var peace := _card({"name": "Ash Peace", "types": ["enchantment"], "cost": "{1}{W}", "abilities": [
		{"kind": "enchant", "pacify": true}]})
	assert_eq(peace.oracle_text, "Enchant creature. Enchanted creature can't attack or block.")
	assert_eq(EffectIntent.aura_aim(peace), EffectIntent.Aim.HOSTILE, "the computer aims it at the opponent's")
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_synthetic(0, peace)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	g.recalculate()
	assert_true(bear.cur_cant_attack, "it can't attack")
	var freeze := _card({"name": "Ash Freeze", "types": ["enchantment"], "cost": "{U}", "abilities": [
		{"kind": "enchant", "enchant": "land", "frozen": true}]})
	assert_eq(freeze.oracle_text, "Enchant land. Enchanted land doesn't untap during its controller's untap step.")
	assert_true(freeze.aura_target.is_legal(g, TargetRef.card(put_battlefield(1, "Forest")), null))
	var ward := _card({"name": "Ash Ward", "types": ["enchantment"], "cost": "{W}", "abilities": [
		{"kind": "enchant", "protection": "black"}]})
	assert_eq(ward.aura_grants_protection, Mtg.ManaColor.B)
	assert_eq(EffectIntent.aura_aim(ward), EffectIntent.Aim.FRIENDLY)
	for a in [{"kind": "enchant", "enchant": "land", "power": 2, "toughness": 2},
			{"kind": "enchant", "enchant": "creature"}, {"kind": "enchant", "enchant": "player", "frozen": true}]:
		assert_false(CommunityCard.problems(_spec({"types": ["enchantment"], "abilities": [a]})).is_empty(), str(a))


func test_a_sliver_shares_its_ability_with_both_players_slivers() -> void:
	var data := _card({"name": "Ash Sliver", "subtypes": ["sliver"], "power": 1, "toughness": 1, "abilities": [
		{"kind": "activated", "cost": "{2}", "shared": "sliver", "effects": [{"effect": "regenerate", "target": "self"}]}]})
	assert_eq(data.oracle_text, "All Sliver creatures have \"{2}: Regenerate this creature.\"")
	assert_true(data.activated_abilities.is_empty(), "it has the ability as a Sliver, not printed twice")
	var mine := put_synthetic(0, data)
	var theirs := put_synthetic(1, CommunityCard.build(_spec({"name": "Ash Other Sliver", "subtypes": ["sliver"]})))
	var bear := put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_eq(mine.cur_activated_abilities.size(), 1)
	assert_eq(theirs.cur_activated_abilities.size(), 1, "the opponent's Sliver has it too")
	assert_eq(bear.cur_activated_abilities.size(), 0)


func test_pay_or_sacrifice_at_upkeep() -> void:
	var data := _card({"name": "Ash Toll", "types": ["enchantment"], "cost": "{W}", "rules": {"upkeep_cost": "{W}{W}"},
		"abilities": [{"kind": "static", "what": "anthem", "power": 1, "toughness": 1}]})
	assert_string_contains(data.oracle_text, "At the beginning of your upkeep, sacrifice Ash Toll unless you pay {W}{W}.")
	var toll := put_synthetic(0, data)
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_ne(toll.zone, Mtg.Zone.BATTLEFIELD, "nothing to pay with: sacrificed")


# ------------------------------------- the round-4 bug hunt (2026-11-17) --

func test_the_rule_fixes_of_the_round_4_hunt() -> void:
	assert_false(CommunityCard.problems(_spec({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "draw", "amount": 1, "keywords": ["swimming"]}]}]})).is_empty(),
		"a keyword on an effect that gives none is refused, never built")
	assert_false(CommunityCard.problems(_spec({"types": ["artifact"], "cost": "{1}", "abilities": [{"kind": "activated",
		"cost": "{0}", "effects": [{"effect": "draw", "amount": 1}]}]})).is_empty(), "{0} is no cost")
	assert_false(CommunityCard.problems(_spec({"types": ["enchantment"], "cost": "{1}", "abilities": [
		{"kind": "enchant", "power": 1, "toughness": 1},
		{"kind": "activated", "cost": "{1}", "effects": [{"effect": "animate", "power": 2, "toughness": 2}]}]})).is_empty(),
		"an Aura never becomes a creature")
	assert_false(CommunityCard.problems(_spec({"types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "pump", "power": 0, "toughness": 0, "keywords": ["defender"], "target": "creature"}]}]})).is_empty(),
		"only defender to give is an Aura's")
	var twin := _card({"name": "Twin Altar", "types": ["artifact"], "cost": "{2}", "abilities": [{"kind": "activated",
		"cost": "", "sacrifice": true, "sacrifice_what": "creature", "effects": [{"effect": "draw", "amount": 2}]}]})
	assert_eq(twin.oracle_text, "Sacrifice Twin Altar, Sacrifice a creature: Draw two cards.", "an artifact sacrifices a creature, not another")
	assert_false(twin.activated_abilities[0].sacrifice_may_be_source, "one body pays one cost")
	var grow := _card({"types": ["instant"], "abilities": [{"kind": "spell", "effects": [
		{"effect": "set_pt", "power": 7, "toughness": 7, "target": "creature"}]}]})
	assert_true(grow.spell_effects[0].ai_helpful, "a big body is a gift")
	var hive := _card({"name": "Hive Caller", "types": ["sorcery"], "abilities": [{"kind": "spell", "effects": [
		{"effect": "token", "amount": 1, "power": 1, "toughness": 1, "subtype": "mindflayer"}]}]})
	assert_string_contains(hive.oracle_text, "Mindflayer creature token")
	assert_true((hive.spell_effects[0] as CreateTokenEffect).token.subtypes.has("mindflayer"), "one word, as a lord reads it")
	var bound := _card({"name": "Bound Knight", "abilities": [{"kind": "static", "what": "anthem", "power": 1,
		"toughness": 0, "keywords": ["must_attack"]}]})
	assert_eq(bound.oracle_text, "Creatures you control get +1/+0 and attack each combat if able.")
	var tap_room := _card({"name": "Tap Room", "abilities": [{"kind": "trigger", "when": "enters",
		"effects": [{"effect": "damage", "amount": 1, "target": "opponent"}]}]})
	assert_string_contains(tap_room.oracle_text, ", Tap Room deals 1 damage", "a name keeps its capital")
	var grove := _card({"name": "Ash Grove", "types": ["land"], "cost": "", "subtypes": ["forest", "island"]})
	assert_eq(grove.mana_abilities.size(), 2, "a land of basic types taps for their colors")
	assert_eq(grove.oracle_text, "({T}: Add {G} or {U}.)")
	var filter := _card({"name": "Ash Filter", "types": ["land"], "cost": "", "abilities": [
		{"kind": "mana", "color": "blue", "amount": 2, "cost": "{1}"}]})
	assert_true(filter.mana_abilities[0].planner_conversion, "the planner may plan through a filter")


func test_the_computer_picks_removal_over_a_life_gain() -> void:
	put_battlefield(1, "Craw Wurm")
	var charm := give_synthetic(1 - 1, _card({"name": "Ash Choice", "types": ["instant"], "cost": "{B}", "abilities": [
		{"kind": "modal", "modes": [{"effects": [{"effect": "gain_life", "amount": 1}]},
			{"effects": [{"effect": "destroy", "target": "creature"}]}]}]}))
	assert_eq(charm.data.ai_mode_picker.call(g, 0), 1, "the Wurm is the aim")


func test_counter_unless_takes_nothing_for_an_uncounterable_spell() -> void:
	var leak := _card({"name": "Ash Leak", "types": ["instant"], "cost": "{1}{U}", "abilities": [
		{"kind": "spell", "effects": [{"effect": "counter", "target": "spell", "unless": 2}]}]})
	var hard := give_synthetic(1, _card({"name": "Ash Hard", "types": ["sorcery"], "cost": "{R}",
		"rules": {"cant_be_countered": true}, "abilities": [{"kind": "spell", "effects": [
			{"effect": "damage", "amount": 2, "target": "opponent"}]}]}))
	g.active_player = 1
	g.priority_player = 1
	advance_to_step(Mtg.Step.MAIN1)
	g.active_player = 1
	g.priority_player = 1
	add_mana(1, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(1, hard, [TargetRef.player(0)]))
	var pool_before := g.players[1].mana_pool.total()
	leak.spell_effects[0].resolve(g, null, 0, TargetRef.card(hard))
	assert_eq(g.players[1].mana_pool.total(), pool_before, "no toll asked for a spell that can't be countered")


func test_the_example_cart_saves_a_hill_giant_from_a_bolt() -> void:
	var rows := CommunityCards.examples()
	assert_eq(rows.size(), 1)
	assert_eq(String(rows[0]["spec"]["set_name"]), "Wheel of Fortune")
	var cart := put_synthetic(0, CommunityCard.build(rows[0]["spec"]))
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, cart, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(cart.tapped, "the cart taps")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 1)
	g.priority_player = 1
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "3 damage less the 1 prevented: the 3/3 lives")
	assert_eq(giant.damage, 2)


# ------------------------------------- the round-5 bug pass (2026-11-17) --

func test_the_rule_fixes_of_the_round_5_pass() -> void:
	# A stolen creature's "dies" trigger is the thief's: its life goes to them.
	var mourner := put_synthetic(1, _card({"name": "Ash Mourner", "abilities": [{"kind": "trigger", "when": "dies",
		"effects": [{"effect": "gain_life", "amount": 5}]}]}))
	g.change_control(mourner, 0)
	g.destroy(mourner)
	resolve_stack()
	assert_eq([g.players[0].life, g.players[1].life], [25, 20], "the controller when it died gains")
	for extra in [{"types": ["artifact"], "cost": "{2}", "abilities": [{"kind": "activated", "cost": "", "tap": true,
				"effects": [{"effect": "add_mana", "amount": 1, "color": "green"}]}]},
			{"rules": {"echo": "{0}"}}, {"rules": {"upkeep_cost": "{0}"}},
			{"types": ["sorcery"], "landwalk": ["island"], "abilities": [{"kind": "spell", "effects": [
				{"effect": "draw", "amount": 1}]}]}]:
		assert_false(CommunityCard.problems(_spec(extra)).is_empty(), str(extra))
	var wake := _card({"types": ["instant"], "abilities": [{"kind": "spell", "effects": [
		{"effect": "lose_keyword", "keywords": ["defender"], "target": "creature"}]}]})
	assert_true(wake.spell_effects[0].ai_helpful, "losing defender is a gift")
	var phase := _card({"name": "Ash Phase", "types": ["enchantment"], "abilities": [{"kind": "enchant",
		"keywords": ["phasing"]}]})
	assert_eq(EffectIntent.aura_aim(phase), EffectIntent.Aim.HOSTILE)
	var ward := _card({"name": "Ash Ward", "types": ["enchantment"], "abilities": [{"kind": "enchant", "protection": "white"}]})
	assert_string_contains(ward.oracle_text, "This effect doesn't remove this Aura.")
	var tutor := _card({"types": ["sorcery"], "abilities": [{"kind": "spell", "effects": [
		{"effect": "search", "target": "a_card"}]}]})
	assert_eq(tutor.oracle_text, "Search your library for a card, put it into your hand, then shuffle.")


func test_a_mode_burns_a_creature_rather_than_a_player() -> void:
	put_battlefield(1, "Grizzly Bears")
	var charm := give_synthetic(0, _card({"name": "Ash Choice", "types": ["instant"], "cost": "{R}", "abilities": [
		{"kind": "modal", "modes": [{"effects": [{"effect": "gain_life", "amount": 1}]},
			{"effects": [{"effect": "damage", "amount": 3, "target": "any"}]}]}]}))
	assert_eq(charm.data.ai_mode_picker.call(g, 0), 1, "the Bears are the aim")


# ------------------------------------------- shuffle in, each player draws --

func test_a_twister_reads_and_plays_as_timetwister() -> void:
	var data := _card({"name": "Zyx Twister", "cost": "{2}{U}", "types": ["sorcery"], "abilities": [
		{"kind": "spell", "effects": [
			{"effect": "shuffle_in", "from": "hand_and_graveyard", "target": "each_player"},
			{"effect": "draw", "amount": 7, "target": "each_player"}]}]})
	assert_eq(data.oracle_text,
		"Each player shuffles their hand and graveyard into their library, then draws seven cards.")
	var twister := give_synthetic(0, data)
	advance_to_step(Mtg.Step.MAIN1)
	for pid in 2:
		for i in 2:
			var gone := give_hand(pid, "Grizzly Bears")
			g.players[pid].hand.erase(gone)
			gone.zone = Mtg.Zone.GRAVEYARD
			g.players[pid].graveyard.append(gone)
	var cards := [0, 0]
	for pid in 2:
		var p := g.players[pid]
		cards[pid] = p.hand.size() + p.graveyard.size() + p.library.size() - (1 if pid == 0 else 0)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, twister, []))
	resolve_stack()
	for pid in 2:
		var p := g.players[pid]
		assert_eq(p.hand.size(), 7, "player %d draws seven" % pid)
		assert_eq(p.hand.size() + p.library.size(), cards[pid], "every card shuffled back in")
	assert_eq(g.players[0].graveyard.size(), 1, "only the twister itself, after it resolved")
	assert_eq(g.players[1].graveyard.size(), 0)


func test_shuffle_a_graveyard_or_a_hand_and_each_player_draws_x() -> void:
	var cane := _card({"name": "Zyx Cane", "cost": "{1}", "types": ["artifact"], "abilities": [
		{"kind": "activated", "cost": "", "tap": true, "effects": [
			{"effect": "shuffle_in", "from": "graveyard", "target": "you"}]}]})
	assert_eq(cane.oracle_text, "{T}: Shuffle your graveyard into your library.")
	var staff := put_synthetic(0, cane)
	var gone := give_hand(0, "Grizzly Bears")
	g.players[0].hand.erase(gone)
	gone.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(gone)
	var hand := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, staff, 0))
	resolve_stack()
	assert_eq(g.players[0].graveyard.size(), 0, "the graveyard went back")
	assert_eq(g.players[0].hand.size(), hand, "the hand stayed")
	var winds := _card({"name": "Zyx Winds", "cost": "{X}{U}", "types": ["sorcery"], "abilities": [
		{"kind": "spell", "effects": [
			{"effect": "shuffle_in", "from": "hand", "target": "player"},
			{"effect": "draw", "x": true, "target": "each_player"}]}]})
	assert_eq(winds.oracle_text,
		"Target player shuffles their hand into their library and each player draws X cards.")
	var spell := give_synthetic(0, winds)
	advance_to_step(Mtg.Step.MAIN1)
	var mine := g.players[0].hand.size() - 1
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 2))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 2, "their hand went back, then they drew two")
	assert_eq(g.players[0].hand.size(), mine + 2, "and so did the caster draw two")
	assert_false(CommunityCard.problems(_spec({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "shuffle_in", "from": "library", "target": "you"}]}]})).is_empty(),
		"only the hand and graveyard, the graveyard or the hand")


# --------------------------------------- search: how many, what, and where --

func test_a_search_for_up_to_two_creature_cards_and_for_x_cards() -> void:
	var one := _card({"name": "Zyx Tutor", "cost": "{1}{B}", "types": ["sorcery"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "search", "target": "a_creature"}]}]})
	assert_eq(one.oracle_text, "Search your library for a creature card, put it into your hand, then shuffle.",
		"one card off the library reads as it always did")
	var two := _card({"name": "Zyx Hunt", "cost": "{2}{G}", "types": ["sorcery"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "search", "target": "a_creature", "amount": 2, "where": "library"}]}]})
	assert_eq(two.oracle_text,
		"Search your library for up to two creature cards, put them into your hand, then shuffle.")
	var x := _card({"name": "Zyx Gather", "cost": "{X}{G}", "types": ["sorcery"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "search", "target": "a_card", "x": true}]}]})
	assert_eq(x.oracle_text, "Search your library for up to X cards, put them into your hand, then shuffle.")
	var bear := _make_instance(0, "Grizzly Bears")
	bear.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(bear)
	var hunt := give_synthetic(0, two)
	advance_to_step(Mtg.Step.MAIN1)
	var hand := g.players[0].hand.size() - 1
	var library := g.players[0].library.size()
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.cast_spell(0, hunt, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "the one creature found; the second search finds none")
	assert_true(g.players[0].hand.has(bear))
	assert_eq(g.players[0].library.size(), library - 1)


func test_a_certain_card_from_the_graveyard_or_the_library() -> void:
	var back := _card({"name": "Zyx Recall", "cost": "{1}{G}", "types": ["sorcery"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "search", "target": "a_named", "named": "Grizzly Bears",
			"amount": 2, "where": "graveyard"}]}]})
	assert_eq(back.oracle_text, "Return up to two cards named Grizzly Bears from your graveyard to your hand.")
	for card_name in ["Grizzly Bears", "Grizzly Bears", "Forest"]:
		var gone := give_hand(0, card_name)
		g.players[0].hand.erase(gone)
		gone.zone = Mtg.Zone.GRAVEYARD
		g.players[0].graveyard.append(gone)
	var spell := give_synthetic(0, back)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	var names: Array = g.players[0].hand.map(func(i: CardInstance) -> String: return i.data.card_name)
	assert_eq(names.count("Grizzly Bears"), 2, "both Bears back")
	assert_eq(g.players[0].graveyard.map(func(i: CardInstance) -> String: return i.data.card_name),
		["Forest", "Zyx Recall"], "the Forest stays")
	var named := _card({"name": "Zyx Seek", "cost": "{B}", "types": ["instant"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "search", "target": "a_named", "named": "Shivan Dragon"}]}]})
	assert_eq(named.oracle_text,
		"Search your library for a card named Shivan Dragon, put it into your hand, then shuffle.")
	assert_true(named.spell_effects[0] is SearchLibraryEffect,
		"one card off the library: the duel's own library picker")
	for bad in [{"target": "a_named"}, {"target": "a_named", "named": "Bad{name}"},
			{"target": "a_card", "where": "exile"}]:
		var e := {"effect": "search"}
		e.merge(bad)
		assert_false(CommunityCard.problems(_spec({"types": ["sorcery"], "abilities": [{"kind": "spell",
			"effects": [e]}]})).is_empty(), str(bad))

