extends GameTest
## Campaign of 2026-11-22, the rules of a data-built card ([CommunityCard]):
## the spec checks that were too kind, the texts that said less than the
## card did, the computer's reading of an arrival trigger, and the new
## vocabulary — drawbacks on yourself, "you may" and "up to one target",
## color and type filters, graveyard returns, cards and tokens that leave,
## "doesn't untap", and the color-cast and draw-step triggers.


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


func _refused(extra: Dictionary, words: String) -> void:
	var said := CommunityCard.problems(_spec(extra))
	assert_true(said.any(func(line: String) -> bool: return line.contains(words)),
		"refused with \"%s\" (said: %s)" % [words, str(said)])


func _trigger(when: String, effects: Array, more := {}) -> Dictionary:
	var a := {"kind": "trigger", "when": when, "effects": effects}
	a.merge(more, true)
	return a


func _dead(pid: int, card_name: String) -> CardInstance:
	var card := _make_instance(pid, card_name)
	card.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(card)
	return card


# ------------------------------------------------------------ the bugs --

func test_an_x_only_cost_nothing_reads_is_no_cost() -> void:
	_refused({"abilities": [{"kind": "activated", "cost": "{X}",
		"effects": [{"effect": "damage", "amount": 1, "target": "any"}]}]}, "an ability needs a cost")
	# With an effect that reads X, or another cost beside it, it is a price.
	_card({"abilities": [{"kind": "activated", "cost": "{X}",
		"effects": [{"effect": "damage", "x": true, "target": "any"}]}]})
	_card({"abilities": [{"kind": "activated", "cost": "{X}", "tap": true,
		"effects": [{"effect": "damage", "amount": 1, "target": "any"}]}]})


func test_two_cheaper_spell_statics_both_count() -> void:
	put_synthetic(0, _card({"name": "Ash Broker", "abilities": [
		{"kind": "static", "what": "cost_less", "spell_type": "creature", "amount": 2},
		{"kind": "static", "what": "cost_less", "spell_type": "artifact", "amount": 1}]}))
	var giant := give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, giant, []))   # {3}{R} for {1}{R}
	resolve_stack()
	var jugger := give_hand(0, "Juggernaut")
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(0, jugger, []))   # an artifact creature: {4} for {1}
	resolve_stack()
	assert_eq(jugger.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 0, "both discounts were used, neither twice")


func test_a_chosen_discard_says_who_chooses_and_the_other_kind_lets_them() -> void:
	var look := _spec({"name": "Ash Probe", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "discard", "amount": 1, "target": "opponent"}]}]})
	assert_eq(CommunityCard.rules_text(look), "Target opponent reveals their hand and discards a card of your choice.")
	var rot := _card({"name": "Ash Rot", "cost": "{2}{B}", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "discard_own", "amount": 2, "target": "player"}]}]})
	assert_eq(rot.oracle_text, "Target player discards two cards.")
	give_hand(1, "Hill Giant")
	give_hand(1, "Grizzly Bears")
	give_hand(1, "Forest")
	var hand := g.players[1].hand.size()
	var spell := give_synthetic(0, rot)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), hand - 2)


func test_the_computer_reads_a_data_built_arrival_by_what_it_does() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	advance_to_step(Mtg.Step.MAIN1)
	_dead(0, "Hill Giant")
	var digger := give_synthetic(0, _card({"name": "Ash Digger", "abilities": [
		_trigger("enters", [{"effect": "raise", "target": "creature_card"}])]}))
	assert_false(ai._forced_arrival_harm(g, digger), "returning a creature card of ours is no harm")
	var bears := put_battlefield(0, "Grizzly Bears")
	bears.tapped = true
	var waker := give_synthetic(0, _card({"name": "Ash Waker", "abilities": [
		_trigger("enters", [{"effect": "untap", "target": "creature"}])]}))
	assert_false(ai._forced_arrival_harm(g, waker), "untapping ours is no harm")
	# Real harm with only our own creatures to name: the cast is held.
	for effect in [{"effect": "minus_counters", "amount": 2, "target": "creature"},
			{"effect": "pump", "power": -3, "toughness": -3, "target": "creature"},
			{"effect": "destroy", "target": "creature"},
			{"effect": "bounce", "target": "creature"}]:
		var harm := give_synthetic(0, _card({"name": "Ash Harm", "abilities": [_trigger("enters", [effect])]}))
		assert_true(ai._forced_arrival_harm(g, harm), "%s lands on our own" % effect["effect"])
		# The same trigger as "you may" or "up to one target" may be declined.
		for choice in ["may", "up_to"]:
			var soft := give_synthetic(0, _card({"name": "Ash Soft", "abilities": [
				_trigger("enters", [effect], {"choice": choice})]}))
			assert_false(ai._forced_arrival_harm(g, soft), "%s, %s" % [effect["effect"], choice])
	# A second slot is read as well as the first.
	var two := give_synthetic(0, _card({"name": "Ash Pair", "abilities": [_trigger("enters", [
		{"effect": "untap", "target": "creature"}, {"effect": "destroy", "target": "creature"}])]}))
	assert_true(ai._forced_arrival_harm(g, two), "the second target is the harmful one")
	put_battlefield(1, "Hill Giant")
	var killer := give_synthetic(0, _card({"name": "Ash Killer", "abilities": [
		_trigger("enters", [{"effect": "destroy", "target": "creature"}])]}))
	assert_false(ai._forced_arrival_harm(g, killer), "with a creature of theirs there is a target")


func test_a_token_loop_and_uncastable_cards_are_refused() -> void:
	_refused({"abilities": [_trigger("creature_enters", [{"effect": "token", "amount": 1}])]}, "without end")
	_refused({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "counter", "target": "spell"}]}]}, "a sorcery cannot counter")
	_refused({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "destroy", "target": "creature_attacking"}]}]}, "no attacking creature")
	_refused({"abilities": [_trigger("upkeep", [{"effect": "exile", "target": "creature_attacking"}])]},
		"no creature is attacking")
	# The same things where they work.
	_card({"types": ["instant"], "abilities": [{"kind": "spell", "effects": [{"effect": "counter", "target": "spell"}]}]})
	_card({"types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "destroy", "target": "creature_attacking"}]}]})
	_card({"abilities": [_trigger("land_enters", [{"effect": "token", "amount": 1}])]})


func test_two_cards_sharing_a_once_a_turn_ability_give_two_uses() -> void:
	var lord := {"name": "Ash Sliver", "subtypes": ["sliver"], "abilities": [
		{"kind": "activated", "cost": "{1}", "shared": "sliver", "timing": "once",
			"effects": [{"effect": "pump", "power": 1, "toughness": 1, "target": "self"}]}]}
	var one := put_synthetic(0, _card(lord))
	assert_eq(one.cur_activated_abilities.size(), 1)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, one, 0))
	resolve_stack()
	assert_ne(g.activate_ability(0, one, 0), "", "one card: once each turn")
	put_synthetic(0, _card(lord))
	assert_eq(one.cur_activated_abilities.size(), 2)
	var done := 0
	for index in 2:
		if g.activate_ability(0, one, index) == "":
			resolve_stack()
			done += 1
	assert_eq(done, 1, "the second card's copy has its own use; the first is spent")
	assert_eq(one.cur_power, 4)


# ---------------------------------------------------------- the polish --

func test_the_small_texts() -> void:
	var mill := _spec({"name": "Ash Tide", "abilities": [_trigger("enters", [
		{"effect": "shuffle_in", "from": "graveyard", "target": "you"}])]})
	assert_eq(CommunityCard.rules_text(mill),
		"When Ash Tide enters the battlefield, shuffle your graveyard into your library.")
	var wurm := _spec({"name": "Ash Call", "types": ["sorcery"], "abilities": [{"kind": "spell", "effects": [
		{"effect": "token", "amount": 1, "power": 8, "toughness": 8, "color": "green", "subtype": "wurm"}]}]})
	assert_eq(CommunityCard.rules_text(wurm), "Create an 8/8 green Wurm creature token.")
	var land := _spec({"name": "Ash Field", "cost": "", "types": ["land"], "abilities": [
		{"kind": "activated", "cost": "{1}", "effects": [{"effect": "animate", "power": 2, "toughness": 2}]}]})
	assert_eq(CommunityCard.problems(land), [] as Array[String])
	assert_eq(CommunityCard.rules_text(land),
		"{1}: Ash Field becomes a 2/2 creature until end of turn. It's still a land.")
	assert_eq(CommunityCard.build(land).activated_abilities[0].text,
		"{1}: Ash Field becomes a 2/2 creature until end of turn. It's still a land.")


func test_nothing_to_do_and_odd_costs_are_said() -> void:
	_refused({"abilities": [{"kind": "static", "what": "anthem", "power": 0, "toughness": 0}]}, "choose what it does")
	_refused({"types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "pump", "power": 0, "toughness": 0, "target": "creature"}]}]}, "choose what it does")
	_card({"abilities": [{"kind": "static", "what": "anthem", "power": 0, "toughness": 0, "keywords": ["flying"]}]})
	assert_false(CommunityCard.cost_ok("{00}"))
	assert_false(CommunityCard.cost_ok("{07}"))
	assert_true(CommunityCard.cost_ok("{0}") and CommunityCard.cost_ok("{10}") and CommunityCard.cost_ok("{7}{G}"))
	# What still builds but is likely not meant is a warning, never a problem.
	var frail := _spec({"power": 0, "toughness": 0})
	assert_eq(CommunityCard.problems(frail), [] as Array[String])
	assert_true(CommunityCard.warnings(frail)[0].contains("toughness 0"))
	assert_true(CommunityCard.warnings(_spec({"cost": "{X}{R}"}))[0].contains("{X}"))
	assert_true(CommunityCard.warnings(_spec({"abilities": [{"kind": "activated", "cost": "{X}{1}",
		"effects": [{"effect": "draw", "amount": 1}]}]}))[0].contains("Ability 1"))
	assert_eq(CommunityCard.warnings(_spec({})), [] as Array[String])
	assert_eq(CommunityCard.warnings("not a card"), [] as Array[String])


func test_that_player_shares_the_target_before_it() -> void:
	_refused({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "lose_life", "amount": 2, "target": "that_player"}]}]}, "follows an effect")
	var data := _card({"name": "Ash Verdict", "cost": "{2}{B}", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "lose_life", "amount": 2, "target": "opponent"},
			{"effect": "discard_random", "amount": 1, "target": "that_player"},
			{"effect": "sacrifice", "target": "that_player"}]}]})
	assert_eq(data.oracle_text,
		"Target opponent loses 2 life, then that player discards a card at random, then that player sacrifices a creature.")
	var bears := put_battlefield(1, "Grizzly Bears")
	give_hand(1, "Forest")
	var hand := g.players[1].hand.size()
	var spell := give_synthetic(0, data)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))   # one target, asked once
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[1].hand.size(), hand - 1)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	# In a trigger too: one slot, the opponent first.
	put_synthetic(0, _card({"name": "Ash Judge", "abilities": [_trigger("enters", [
		{"effect": "damage", "amount": 1, "target": "opponent"}, {"effect": "mill", "amount": 2, "target": "that_player"}])]}))
	var library := g.players[1].library.size()
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[1].library.size(), library - 2)


# ------------------------------------------------- drawbacks on yourself --

func test_a_card_may_hurt_its_own_controller() -> void:
	var djinn := _spec({"name": "Ash Djinn", "abilities": [
		_trigger("upkeep", [{"effect": "damage", "amount": 1, "target": "you"}]),
		_trigger("enters", [{"effect": "lose_life", "amount": 2, "target": "you"},
			{"effect": "discard_own", "amount": 1, "target": "you"}, {"effect": "sacrifice", "target": "you"}])]})
	assert_eq(CommunityCard.rules_text(djinn), "\n".join([
		"At the beginning of your upkeep, Ash Djinn deals 1 damage to you.",
		"When Ash Djinn enters the battlefield, you lose 2 life, then discard a card, then sacrifice a creature."]))
	var bears := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Forest")
	var hand := g.players[0].hand.size()
	var card := give_synthetic(0, CommunityCard.build(djinn))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, card, []))   # nothing is targeted: it is all "you"
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[0].hand.size(), hand - 1)
	assert_eq(g.players[1].life, 20)
	assert_true(bears.zone == Mtg.Zone.GRAVEYARD or card.zone == Mtg.Zone.GRAVEYARD, "one creature of ours went")
	if card.zone == Mtg.Zone.BATTLEFIELD:
		advance_to_next_turn()
		advance_to_next_turn()
		assert_eq(g.players[0].life, 17, "its upkeep damage is ours")


# ------------------------------------------- "you may", "up to one target" --

func test_you_may_asks_and_says_so() -> void:
	var spec := _spec({"name": "Ash Mage", "abilities": [
		_trigger("enters", [{"effect": "damage", "amount": 2, "target": "any"}], {"choice": "may"}),
		_trigger("dies", [{"effect": "draw", "amount": 1}, {"effect": "gain_life", "amount": 2}], {"choice": "may"}),
		_trigger("attacks", [{"effect": "pump", "power": 1, "toughness": 1, "target": "creature"}], {"choice": "may"}),
		_trigger("upkeep", [{"effect": "gain_life", "amount": 1}], {"choice": "may"})]})
	assert_eq(CommunityCard.rules_text(spec), "\n".join([
		"When Ash Mage enters the battlefield, you may have Ash Mage deal 2 damage to any target.",
		"When Ash Mage dies, you may draw a card. If you do, you gain 2 life.",
		"Whenever Ash Mage attacks, you may have target creature get +1/+1 until end of turn.",
		"At the beginning of your upkeep, you may gain 1 life."]))
	_refused({"abilities": [_trigger("enters", [{"effect": "draw", "amount": 1}], {"choice": "sometimes"})]},
		"you may")
	# The sensible answer is yes for a gift ...
	var mage := put_synthetic(0, CommunityCard.build(spec))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "the opponent first, and done")
	var hand := g.players[0].hand.size()
	g.destroy(mage)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(g.players[0].life, 22)
	# ... and no for a price of its own, or for harm that finds only its own.
	var hermit := put_synthetic(0, _card({"name": "Ash Hermit", "abilities": [
		_trigger("enters", [{"effect": "sacrifice_self"}, {"effect": "draw", "amount": 3}], {"choice": "may"})]}))
	resolve_stack()
	assert_eq(hermit.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].hand.size(), hand + 1)
	for mine in g.players[1].battlefield.duplicate():
		g.exile_permanent(mine)
	var wisp := put_synthetic(0, _card({"name": "Ash Wisp", "abilities": [
		_trigger("enters", [{"effect": "bounce", "target": "creature"}], {"choice": "may"})]}))
	resolve_stack()
	assert_eq(hermit.zone, Mtg.Zone.BATTLEFIELD, "no creature of ours was returned")
	assert_eq(wisp.zone, Mtg.Zone.BATTLEFIELD)


func test_up_to_one_target_may_take_none() -> void:
	var spec := _spec({"name": "Ash Tide", "abilities": [
		_trigger("enters", [{"effect": "bounce", "target": "creature"}, {"effect": "gain_life", "amount": 1}],
			{"choice": "up_to"})]})
	assert_eq(CommunityCard.rules_text(spec),
		"When Ash Tide enters the battlefield, return up to one target creature to its owner's hand and you gain 1 life.")
	_refused({"abilities": [_trigger("enters", [{"effect": "draw", "amount": 1}], {"choice": "up_to"})]},
		"exactly one effect with a target")
	_refused({"abilities": [_trigger("enters", [{"effect": "bounce", "target": "creature"},
		{"effect": "tap", "target": "creature"}], {"choice": "up_to"})]}, "exactly one effect with a target")
	var data := CommunityCard.build(spec)
	assert_eq(data.triggered_abilities[0].target_min, 0)
	# Only our own creatures: none is returned, the rest still happens.
	var bears := put_battlefield(0, "Grizzly Bears")
	var tide := put_synthetic(0, data)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(tide.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 21)
	# One of theirs: it goes.
	var giant := put_battlefield(1, "Hill Giant")
	put_synthetic(0, data)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 22)


# ------------------------------------------------ color and type filters --

func test_a_filter_narrows_a_target_and_a_sweep() -> void:
	var blast := _card({"name": "Ash Blast", "cost": "{R}", "types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "destroy", "target": "permanent", "only": "white"}]}]})
	assert_eq(blast.oracle_text, "Destroy target white permanent.")
	var knight := put_battlefield(1, "White Knight")
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_synthetic(0, blast)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ne(g.cast_spell(0, spell, [TargetRef.card(giant)]), "", "a red creature is no white permanent")
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)
	# A sweep: "destroy all nonred creatures".
	var perish := _card({"name": "Ash Purge", "cost": "{2}{R}", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "destroy_all", "target": "creatures", "only": "nonred"}]}]})
	assert_eq(perish.oracle_text, "Destroy all nonred creatures.")
	var bears := put_battlefield(1, "Grizzly Bears")
	var own := put_battlefield(0, "Grizzly Bears")
	var purge := give_synthetic(0, perish)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, purge, []))
	resolve_stack()
	assert_eq([bears.zone, own.zone, giant.zone], [Mtg.Zone.GRAVEYARD, Mtg.Zone.GRAVEYARD, Mtg.Zone.BATTLEFIELD])
	# The other shapes, as they read.
	for row in [
			[{"effect": "damage", "amount": 2, "target": "creature", "only": "black"}, "Test Card deals 2 damage to target black creature."],
			[{"effect": "damage", "amount": 1, "target": "each_creature", "only": "nongreen"}, "Test Card deals 1 damage to each nongreen creature."],
			[{"effect": "exile", "target": "permanent", "only": "nonland"}, "Exile target nonland permanent."],
			[{"effect": "bounce", "target": "creature", "only": "nonartifact"}, "Return target nonartifact creature to its owner's hand."],
			[{"effect": "mass_pump", "target": "yours", "only": "white", "power": 1, "toughness": 1}, "White creatures you control get +1/+1 until end of turn."],
			[{"effect": "mass_pump", "target": "all", "only": "artifact", "power": -1, "toughness": 0}, "All artifact creatures get -1/+0 until end of turn."],
			[{"effect": "tap", "target": "creature", "only": "blue"}, "Tap target blue creature."]]:
		var spec := _spec({"types": ["instant"], "abilities": [{"kind": "spell", "effects": [row[0]]}]})
		assert_eq(CommunityCard.problems(spec), [] as Array[String])
		assert_eq(CommunityCard.rules_text(spec), row[1])
		assert_not_null(CommunityCard.build(spec))
	_refused({"types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "destroy", "target": "land", "only": "white"}]}]}, "goes with a creature, a permanent")
	_refused({"types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "destroy", "target": "creature", "only": "nonland"}]}]}, "target permanent")
	_refused({"types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "destroy", "target": "creature", "only": "purple"}]}]}, "no such color or type filter")
	_refused({"types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "regenerate", "target": "creature", "only": "white"}]}]}, "no such color or type filter")


func test_a_filtered_trigger_aims_at_the_opponents_first() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	put_synthetic(0, _card({"name": "Ash Blight", "abilities": [
		_trigger("enters", [{"effect": "destroy", "target": "creature", "only": "green"}])]}))
	resolve_stack()
	assert_eq([mine.zone, theirs.zone, giant.zone],
		[Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD, Mtg.Zone.BATTLEFIELD])
	# A helpful one takes its own side first.
	mine.tapped = true
	giant.tapped = true
	put_synthetic(0, _card({"name": "Ash Dawn", "abilities": [
		_trigger("enters", [{"effect": "untap", "target": "creature", "only": "nonwhite"}])]}))
	resolve_stack()
	assert_eq([mine.tapped, giant.tapped], [false, true])


# ---------------------------------------------- back from the graveyard --

func test_a_creature_card_returns_to_the_battlefield_and_any_card_to_hand() -> void:
	var dead := _dead(0, "Hill Giant")
	var bolt := _dead(0, "Lightning Bolt")
	_dead(1, "Grizzly Bears")
	var raise := _card({"name": "Ash Rite", "cost": "{2}{B}", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "raise", "target": "creature_card_to_battlefield"}]}]})
	assert_eq(raise.oracle_text, "Return target creature card from your graveyard to the battlefield.")
	var rite := give_synthetic(0, raise)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ne(g.cast_spell(0, rite, [TargetRef.card(bolt)]), "", "an instant is no creature card")
	assert_ok(g.cast_spell(0, rite, [TargetRef.card(dead)]))
	resolve_stack()
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dead.controller_id, 0)
	# Any card, to hand — and as an arrival trigger it finds our own card.
	var sage := _card({"name": "Ash Sage", "abilities": [_trigger("enters", [{"effect": "raise", "target": "any_card"}])]})
	assert_eq(sage.oracle_text,
		"When Ash Sage enters the battlefield, return target card from your graveyard to your hand.")
	put_synthetic(0, sage)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(bolt))


# ------------------------------------------------- leaving and not untapping --

func test_a_card_sacrifices_or_exiles_itself() -> void:
	var spec := _spec({"name": "Ash Spark", "power": 6, "toughness": 1, "keywords": ["haste", "trample"],
		"abilities": [_trigger("end_step", [{"effect": "sacrifice_self"}]),
			{"kind": "activated", "cost": "{1}", "effects": [{"effect": "exile_self"}, {"effect": "draw", "amount": 1}]}]})
	assert_eq(CommunityCard.rules_text(spec), "\n".join(["Haste, trample",
		"At the beginning of your end step, sacrifice Ash Spark.",
		"{1}: Exile Ash Spark and draw a card."]))
	_refused({"types": ["sorcery"], "abilities": [{"kind": "spell", "effects": [{"effect": "sacrifice_self"}]}]},
		"for a card on the battlefield")
	var data := CommunityCard.build(spec)
	var spark := put_synthetic(0, data)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(spark.zone, Mtg.Zone.GRAVEYARD, "sacrificed at its controller's end step")
	var second := put_synthetic(0, data)
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ok(g.activate_ability(0, second, 0))
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].hand.size(), hand + 1)


func test_tokens_leave_at_the_next_end_step() -> void:
	var spec := _spec({"name": "Ash Ambush", "cost": "{2}{W}", "types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "token", "amount": 3, "power": 2, "toughness": 2, "color": "white", "subtype": "knight",
			"ends": "exile"}]}]})
	assert_eq(CommunityCard.rules_text(spec),
		"Create three 2/2 white Knight creature tokens and exile them at the beginning of the next end step.")
	var one := _spec({"name": "Ash Flare", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "token", "amount": 1, "power": 3, "toughness": 1, "color": "red", "subtype": "elemental",
			"keywords": ["haste"], "ends": "sacrifice"}]}]})
	assert_eq(CommunityCard.rules_text(one),
		"Create a 3/1 red Elemental creature token with haste and sacrifice it at the beginning of the next end step.")
	_refused({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "token", "amount": 1, "ends": "tomorrow"}]}]}, "sacrificed or exiled at end of turn")
	advance_to_step(Mtg.Step.MAIN1)
	var stays := put_battlefield(0, "Grizzly Bears")
	var ambush := give_synthetic(0, CommunityCard.build(spec))
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, ambush, []))
	resolve_stack()
	var knights := g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.data.card_name == "Knight")
	assert_eq(knights.size(), 3)
	var flare := give_synthetic(0, CommunityCard.build(one))
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, flare, []))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 5)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 1, "the four tokens are gone")
	assert_eq(stays.zone, Mtg.Zone.BATTLEFIELD)
	# A token without the key stays, as it always did.
	var old := _card({"name": "Ash Muster", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "token", "amount": 1}]}]})
	assert_false(old.spell_effects[0] is CommunityCard.EndingTokens)


func test_a_card_that_does_not_untap() -> void:
	var spec := _spec({"name": "Ash Colossus", "power": 9, "toughness": 9, "rules": {"no_untap": true}})
	assert_eq(CommunityCard.rules_text(spec), "Ash Colossus doesn't untap during your untap step.")
	var colossus := put_synthetic(0, CommunityCard.build(spec))
	var bears := put_battlefield(0, "Grizzly Bears")
	colossus.tapped = true
	bears.tapped = true
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_true(colossus.tapped, "it stays tapped through its controller's untap step")
	assert_false(bears.tapped)


# --------------------------------------------------------- new triggers --

func test_a_spell_of_a_color_and_each_draw_step_trigger() -> void:
	var spec := _spec({"name": "Ash Rod", "cost": "{1}", "types": ["artifact"], "abilities": [
		_trigger("cast_red", [{"effect": "gain_life", "amount": 1}]),
		_trigger("each_draw", [{"effect": "lose_life", "amount": 1, "target": "opponent"}]),
		_trigger("draw_step", [{"effect": "draw", "amount": 1}])]})
	spec.erase("power")
	spec.erase("toughness")
	assert_eq(CommunityCard.problems(spec), [] as Array[String])
	assert_eq(CommunityCard.rules_text(spec), "\n".join([
		"Whenever a player casts a red spell, you gain 1 life.",
		"At the beginning of each player's draw step, target opponent loses 1 life.",
		"At the beginning of your draw step, draw a card."]))
	put_synthetic(0, CommunityCard.build(spec))
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "a red spell of ours")
	var growth := give_hand(0, "Giant Growth")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "a green spell is not red")
	# The opponent's draw step: only the each-player trigger.
	var their_life := g.players[1].life
	advance_to_step(Mtg.Step.END)
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.active_player, 1)
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(g.players[1].life, their_life - 1)
	assert_eq(g.players[0].hand.size(), hand, "not our draw step")
	# Ours: both.
	advance_to_step(Mtg.Step.END)
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.active_player, 0)
	hand = g.players[0].hand.size()
	resolve_stack()
	assert_eq(g.players[1].life, their_life - 2)
	assert_eq(g.players[0].hand.size(), hand + 1)


# ------------------------------------------------------- old cards stay --

func test_an_old_card_reads_and_builds_as_before() -> void:
	# None of the new keys: the same text, effects of the same classes.
	var spec := _spec({"name": "Old Hand", "abilities": [
		_trigger("enters", [{"effect": "destroy", "target": "creature"}, {"effect": "gain_life", "amount": 2}]),
		{"kind": "activated", "cost": "{1}", "tap": true, "effects": [{"effect": "sacrifice", "target": "opponent"}]},
		{"kind": "static", "what": "cost_less", "spell_type": "creature", "amount": 1}]})
	assert_eq(CommunityCard.rules_text(spec), "\n".join([
		"When Old Hand enters the battlefield, destroy target creature and you gain 2 life.",
		"{1}, {T}: Target opponent sacrifices a creature.",
		"Creature spells you cast cost {1} less to cast."]))
	var data := CommunityCard.build(spec)
	var trig: TriggeredAbility = data.triggered_abilities[0]
	assert_eq([trig.target_min, trig.target_max, trig.target_slot_count()], [1, 1, 1])
	assert_true(data.activated_abilities[0].effects[0] is CommunityCard.EdictEffect)
	assert_not_null(data.activated_abilities[0].effects[0].target_spec)
	# Every catalogue entry the screen builds its pickers from has its words.
	for id in CommunityCard.EFFECTS:
		for target in CommunityCard.EFFECTS[id].get("targets", []):
			assert_true(CommunityCard.TARGET_WORDS.has(target), "%s: %s" % [id, target])
		assert_ne(CommunityCard.effect_text(CommunityCard.effect_defaults(id, "activated"), "It", "activated"), "", id)
	for only in CommunityCard.ONLY:
		assert_true(only == "" or CommunityCard._only_filter(only).is_valid(), only)


# ------------------------------------------------ the computer's aiming --

func test_the_computer_aims_the_new_spells_at_the_right_side() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	mine.tapped = true
	theirs.tapped = true
	give_hand(1, "Hill Giant")
	give_hand(0, "Hill Giant")
	_dead(0, "Hill Giant")
	var ai := AiPlayer.new(0, AiProfile.wizard())
	advance_to_step(Mtg.Step.MAIN1)
	# [the effects, the side its first target is on: 1 theirs, 0 ours]
	var rows := [
		[[{"effect": "discard_own", "amount": 1, "target": "player"}], 1],
		[[{"effect": "discard_own", "amount": 1, "target": "opponent"}], 1],
		[[{"effect": "destroy", "target": "creature", "only": "green"}], 1],
		[[{"effect": "destroy", "target": "permanent", "only": "nonland"}], 1],
		[[{"effect": "bounce", "target": "creature", "only": "nonartifact"}], 1],
		[[{"effect": "untap", "target": "creature", "only": "green"}], 0],
		[[{"effect": "lose_life", "amount": 3, "target": "player"},
			{"effect": "discard_random", "amount": 1, "target": "that_player"}], 1],
		[[{"effect": "mill", "amount": 3, "target": "player"}, {"effect": "sacrifice", "target": "that_player"}], 1],
		[[{"effect": "raise", "target": "creature_card_to_battlefield"}], 0],
		[[{"effect": "raise", "target": "any_card"}], 0],
	]
	for row in rows:
		var inst := give_synthetic(0, _card({"name": "Aim Test", "types": ["sorcery"], "cost": "{1}",
			"abilities": [{"kind": "spell", "effects": row[0]}]}))
		var picks: Variant = ai._choose_targets(g, inst, 0)
		var label := str(row[0])
		assert_true(picks is Array and (picks as Array).size() == 1, "one target: " + label)
		if picks is Array and (picks as Array).size() == 1:
			var ref: TargetRef = picks[0]
			var side := ref.player_id
			if not ref.is_player:
				var card := g.find_instance(ref.instance_id)
				side = card.owner_id if card.zone == Mtg.Zone.GRAVEYARD else card.controller_id
			assert_eq(side, row[1], label)
		g.players[0].hand.erase(inst)


# ================================================================ round 2 ==

func _aura_on(pid: int, data: CardData, host: CardInstance) -> CardInstance:
	var aura := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	aura.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(aura)
	g.attach_aura_from_anywhere(aura, host, pid)
	g.recalculate()
	return aura


func _spell(extra: Dictionary, effects: Array) -> CardData:
	var spec := {"types": ["sorcery"], "abilities": [{"kind": "spell", "effects": effects}]}
	spec.merge(extra, true)
	return _card(spec)


func _artifact(extra: Dictionary) -> Dictionary:
	var spec := _spec(extra)
	spec.merge({"types": ["artifact"], "cost": "{2}"}, true)
	spec.erase("power")
	spec.erase("toughness")
	return spec


# ------------------------------------------- "that player" of the event --

func test_that_player_is_the_one_whose_step_it_is() -> void:
	var mine := _artifact({"name": "Ash Mine", "abilities": [
		_trigger("each_draw", [{"effect": "draw", "amount": 1, "target": "that_player"}]),
		_trigger("each_upkeep", [{"effect": "lose_life", "amount": 1, "target": "that_player"}])]})
	assert_eq(CommunityCard.problems(mine), [] as Array[String])
	assert_eq(CommunityCard.rules_text(mine), "\n".join([
		"At the beginning of each player's draw step, that player draws a card.",
		"At the beginning of each upkeep, that player loses 1 life."]))
	_refused({"abilities": [_trigger("enters", [{"effect": "draw", "amount": 1, "target": "that_player"}])]},
		"follows an effect")
	put_synthetic(0, CommunityCard.build(mine))
	advance_to_step(Mtg.Step.END)
	var life := [g.players[0].life, g.players[1].life]
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.active_player, 1)
	assert_eq([g.players[0].life, g.players[1].life], [life[0], life[1] - 1], "their upkeep, their life")
	var hands := [g.players[0].hand.size(), g.players[1].hand.size()]
	resolve_stack()
	assert_eq([g.players[0].hand.size(), g.players[1].hand.size()], [hands[0], hands[1] + 1], "they draw one more")


# ------------------------------------------------- what an Aura gives --

func test_an_aura_gives_its_creature_an_ability_and_watches_it() -> void:
	var study := _spec({"name": "Ash Study", "types": ["enchantment"], "cost": "{1}{U}", "abilities": [
		{"kind": "enchant", "enchant": "creature"},
		{"kind": "activated", "cost": "", "tap": true, "enchanted": true,
			"effects": [{"effect": "damage", "amount": 1, "target": "any"}]},
		_trigger("attacks", [{"effect": "gain_life", "amount": 2}], {"enchanted": true}),
		_trigger("to_graveyard", [{"effect": "return_self"}])]})
	study.erase("power")
	study.erase("toughness")
	assert_eq(CommunityCard.problems(study), [] as Array[String])
	assert_eq(CommunityCard.rules_text(study), "\n".join([
		"Enchant creature.",
		"Enchanted creature has \"{T}: This creature deals 1 damage to any target.\"",
		"Whenever enchanted creature attacks, you gain 2 life.",
		"When Ash Study is put into a graveyard from the battlefield, return Ash Study to its owner's hand."]))
	# Not on a card that is no Aura, not for a trigger an Aura cannot watch.
	_refused({"abilities": [{"kind": "activated", "cost": "{1}", "enchanted": true,
		"effects": [{"effect": "draw", "amount": 1}]}]}, "only an Aura")
	var bad := study.duplicate(true)
	bad["abilities"][2]["when"] = "upkeep"
	assert_true(CommunityCard.problems(bad).any(func(l: String) -> bool: return l.contains("is watched for")))
	var bears := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(0, "Hill Giant")
	var aura := _aura_on(0, CommunityCard.build(study), bears)
	assert_eq(bears.cur_activated_abilities.size(), 1)
	assert_eq(other.cur_activated_abilities.size(), 0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, bears, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_true(bears.tapped, "its own {T}")
	bears.tapped = false
	run_combat([bears.id])
	assert_eq(g.players[0].life, 22, "the Aura watched its creature attack")
	g.destroy(bears)
	g.check_state_based_actions()   # the Aura with no creature goes to the graveyard
	assert_ok(g.pass_priority(g.priority_player))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.HAND, "put into the graveyard from the battlefield, it comes back")


# ----------------------------------------------------- X, and divided --

func test_x_on_more_effects() -> void:
	var twist := _spell({"name": "Ash Twist", "cost": "{X}{B}"}, [
		{"effect": "discard_random", "x": true, "target": "opponent"},
		{"effect": "drain", "x": true, "target": "opponent"},
		{"effect": "token", "x": true, "power": 1, "toughness": 1, "color": "black", "subtype": "rat"},
		{"effect": "lose_life", "x": true, "target": "you"}])
	assert_eq(twist.oracle_text, "Target opponent discards X cards at random, then target opponent loses X life "
		+ "and you gain X life, then create X 1/1 black Rat creature tokens, then you lose X life.")
	for n in 3:
		give_hand(1, "Forest")
	var hand := g.players[1].hand.size()
	var spell := give_synthetic(0, twist)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1), TargetRef.player(1)], 2))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), hand - 2)
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 20, "gained two, lost two")
	assert_eq(g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.data.card_name == "Rat").size(), 2)
	# Enters with X counters.
	_refused({"rules": {"enters_x_counters": true}}, "needs {X} in the mana cost")
	var hydra := _spec({"name": "Ash Hydra", "cost": "{X}{R}", "power": 0, "toughness": 0,
		"rules": {"enters_x_counters": true}})
	assert_eq(CommunityCard.rules_text(hydra), "Ash Hydra enters the battlefield with X +1/+1 counters on it.")
	assert_eq(CommunityCard.warnings(hydra), [] as Array[String])
	var body := give_synthetic(0, CommunityCard.build(hydra))
	add_mana(0, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(0, body, [], 3))
	resolve_stack()
	assert_eq(body.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([body.cur_power, body.cur_toughness], [3, 3])


func test_divided_damage() -> void:
	var data := _spell({"name": "Ash Volley", "cost": "{2}{R}"}, [{"effect": "damage", "amount": 4, "target": "divided"}])
	assert_eq(data.oracle_text, "Ash Volley deals 4 damage divided as you choose among any number of targets.")
	_refused({"abilities": [_trigger("enters", [{"effect": "damage", "amount": 2, "target": "divided"}])]},
		"divided damage is a fixed amount")
	var bears := put_battlefield(1, "Grizzly Bears")
	var spell := give_synthetic(0, data)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bears, 2), TargetRef.player(1, 2)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)


# ------------------------------------------------------ counted amounts --

func test_an_amount_for_each_and_a_body_that_counts() -> void:
	for row in [
			[{"effect": "damage", "amount": 1, "target": "any", "per": "swamp_you"},
				"Test Card deals 1 damage to any target for each Swamp you control."],
			[{"effect": "gain_life", "amount": 2, "per": "creature_all"}, "You gain 2 life for each creature on the battlefield."],
			[{"effect": "pump", "power": 1, "toughness": 1, "target": "creature", "per": "land_opponent"},
				"Target creature gets +1/+1 until end of turn for each land your opponents control."],
			[{"effect": "draw", "amount": 1, "per": "artifact_you"}, "Draw a card for each artifact you control."],
			[{"effect": "token", "amount": 1, "per": "hand_opponent"},
				"Create a 1/1 colorless Soldier creature token for each card in your opponents' hands."],
			[{"effect": "lose_life", "amount": 1, "target": "opponent", "per": "graveyard_you"},
				"Target opponent loses 1 life for each card in your graveyard."]]:
		assert_eq(_spell({}, [row[0]]).oracle_text, row[1])
	_refused({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "destroy", "target": "creature", "per": "swamp_you"}]}]}, "no such \"for each\"")
	_refused({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "draw", "amount": 1, "per": "goblins"}]}]}, "no such \"for each\"")
	assert_eq(CommunityCard.counts().size(), 30)
	assert_eq(CommunityCard.count_labels()["forest_you"], "for each Forest you control")
	for n in 3:
		put_battlefield(0, "Swamp")
	put_battlefield(1, "Swamp")
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	assert_eq(CommunityCard.count_of(g, 0, "swamp_you"), 3)
	assert_eq(CommunityCard.count_of(g, 0, "swamp_opponent"), 1)
	assert_eq(CommunityCard.count_of(g, 0, "land_all"), 4)
	assert_eq(CommunityCard.count_of(g, 1, "creature_you"), 1)
	advance_to_step(Mtg.Step.MAIN1)
	var corrupt := give_synthetic(0, _spell({"name": "Ash Rot", "cost": "{B}"}, [
		{"effect": "damage", "amount": 1, "target": "any", "per": "swamp_you"},
		{"effect": "pump", "power": 1, "toughness": 2, "target": "creature", "per": "creature_all"}]))
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_ok(g.cast_spell(0, corrupt, [TargetRef.player(1), TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq([bears.cur_power, bears.cur_toughness], [4, 6])
	# Nightmare's body.
	var mare := _spec({"name": "Ash Mare", "power": 0, "toughness": 0, "rules": {"pt_count": "swamp_you"}})
	assert_eq(CommunityCard.rules_text(mare),
		"Ash Mare's power and toughness are each equal to the number of Swamps you control.")
	assert_eq(CommunityCard.warnings(mare), [] as Array[String])
	_refused({"rules": {"pt_count": "many"}}, "choose what it counts")
	var horse := put_synthetic(0, CommunityCard.build(mare))
	g.recalculate()
	assert_eq([horse.cur_power, horse.cur_toughness], [3, 3])
	put_battlefield(0, "Swamp")
	g.recalculate()
	assert_eq([horse.cur_power, horse.cur_toughness], [4, 4])


# ------------------------------------------- damage and mana triggers --

func test_triggers_on_its_own_damage() -> void:
	var spec := _spec({"name": "Ash Asp", "power": 1, "toughness": 4, "abilities": [
		_trigger("deals_damage", [{"effect": "gain_life", "amount": 1}]),
		_trigger("damage_player", [{"effect": "discard_own", "amount": 1, "target": "that_player"}]),
		_trigger("damage_creature", [{"effect": "destroy", "target": "that_creature"}])]})
	assert_eq(CommunityCard.rules_text(spec), "\n".join([
		"Whenever Ash Asp deals damage, you gain 1 life.",
		"Whenever Ash Asp deals damage to a player, that player discards a card.",
		"Whenever Ash Asp deals damage to a creature, destroy that creature."]))
	_refused({"abilities": [_trigger("deals_damage", [{"effect": "damage", "amount": 1, "target": "any"}])]},
		"without end")
	_refused({"abilities": [_trigger("enters", [{"effect": "destroy", "target": "that_creature"}])]},
		"the one dealt damage")
	var asp := put_synthetic(0, CommunityCard.build(spec))
	asp.summoning_sick = false
	give_hand(1, "Forest")
	var hand := g.players[1].hand.size()
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(asp, TargetRef.card(giant), 1)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the creature it dealt damage to")
	assert_eq(g.players[0].life, 21)
	g.deal_damage(asp, TargetRef.player(1), 1)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), hand - 1)
	assert_eq(g.players[0].life, 22)


func test_a_land_tapped_for_mana() -> void:
	var barbs := _spec({"name": "Ash Barbs", "types": ["enchantment"], "cost": "{3}{R}", "abilities": [
		_trigger("land_tapped", [{"effect": "damage", "amount": 1, "target": "that_player"}])]})
	barbs.erase("power")
	barbs.erase("toughness")
	assert_eq(CommunityCard.rules_text(barbs),
		"Whenever a player taps a land for mana, Ash Barbs deals 1 damage to that player.")
	var flare := barbs.duplicate(true)
	flare["name"] = "Ash Flare"
	flare["abilities"] = [_trigger("land_tapped", [{"effect": "extra_mana"}])]
	assert_eq(CommunityCard.problems(flare), [] as Array[String])
	assert_eq(CommunityCard.rules_text(flare),
		"Whenever a player taps a land for mana, that player adds one additional mana of any type that land produced.")
	var loop := barbs.duplicate(true)
	loop["abilities"] = [_trigger("land_tapped", [{"effect": "untap", "target": "land"}])]
	assert_true(CommunityCard.problems(loop).any(func(l: String) -> bool: return l.contains("without end")))
	loop["abilities"] = [_trigger("land_tapped", [{"effect": "extra_mana"}, {"effect": "draw", "amount": 1}])]
	assert_true(CommunityCard.problems(loop).any(func(l: String) -> bool: return l.contains("the whole ability")))
	_refused({"abilities": [_trigger("enters", [{"effect": "extra_mana"}])]}, "taps a land for mana")
	put_synthetic(0, CommunityCard.build(barbs))
	var mountain := put_battlefield(1, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(1, mountain))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "the one who tapped it")
	assert_eq(g.players[0].life, 20)
	put_synthetic(0, CommunityCard.build(flare))
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 2, "one more of the type it made")
	resolve_stack()


# ---------------------------------------- shroud, taxes, a borrowed body --

func test_shroud_and_spells_that_cost_more() -> void:
	var spec := _spec({"name": "Ash Ghost", "keywords": ["flying"], "rules": {"shroud": true}})
	assert_eq(CommunityCard.rules_text(spec), "Flying, shroud")
	var ghost := put_synthetic(1, CommunityCard.build(spec))
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ne(g.cast_spell(0, bolt, [TargetRef.card(ghost)]), "", "it can't be the target of spells")
	# Spells that cost more.
	for row in [
			[{"spell_type": "creature", "amount": 1}, "Creature spells cost {1} more to cast."],
			[{"spell_type": "any", "amount": 2, "who": "opponents"}, "Spells your opponents cast cost {2} more to cast."],
			[{"spell_type": "instant", "spell_color": "red", "amount": 1}, "Red instant spells cost {1} more to cast."],
			[{"spell_type": "any", "spell_color": "black", "amount": 3, "who": "opponents"},
				"Black spells your opponents cast cost {3} more to cast."]]:
		var a := {"kind": "static", "what": "cost_more"}
		a.merge(row[0])
		assert_eq(CommunityCard.rules_text(_artifact({"abilities": [a]})), row[1])
	_refused({"abilities": [{"kind": "static", "what": "cost_more", "spell_type": "creature", "who": "nobody"}]},
		"everyone's spells or your opponents'")
	_refused({"abilities": [{"kind": "static", "what": "cost_less", "spell_type": "any"}]}, "choose the spell type")
	put_synthetic(1, CommunityCard.build(_artifact({"name": "Ash Toll", "abilities": [
		{"kind": "static", "what": "cost_more", "spell_type": "instant", "spell_color": "red", "amount": 2,
			"who": "opponents"}]})))
	g.players[0].mana_pool.clear()
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ne(g.cast_spell(0, bolt, [TargetRef.player(1)]), "", "{R} and {2} more: two is not enough")
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].mana_pool.total(), 0)
	# A red sorcery and a green instant are not taxed.
	var growth := give_hand(0, "Giant Growth")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bears)]))
	resolve_stack()


func test_an_attack_tax() -> void:
	var spec := _artifact({"name": "Ash Wall", "abilities": [{"kind": "static", "what": "attack_tax", "amount": 2}]})
	assert_eq(CommunityCard.problems(spec), [] as Array[String])
	assert_eq(CommunityCard.rules_text(spec), "Creatures can't attack you unless their controller pays {2} "
		+ "for each creature they control that's attacking you.")
	put_synthetic(1, CommunityCard.build(spec))
	var bears := put_battlefield(0, "Grizzly Bears")
	var own := put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_eq(bears.cur_attack_costs.size(), 1)
	assert_eq(int(bears.cur_attack_costs[0]["generic_mana"]), 2)
	assert_eq(own.cur_attack_costs.size(), 0, "its controller's own creatures attack freely")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ne(g.declare_attackers(0, [bears.id]), "", "no mana, no attack")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.declare_attackers(0, [bears.id]))
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_creature_borrowed_for_the_turn() -> void:
	var ray := _card({"name": "Ash Ray", "cost": "{3}{U}", "types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "borrow", "target": "creature"}]}]})
	assert_eq(ray.oracle_text, "Untap target creature and gain control of it until end of turn. "
		+ "It gains haste until end of turn. When you lose control of it, tap it.")
	var giant := put_battlefield(1, "Hill Giant")
	giant.tapped = true
	var spell := give_synthetic(0, ray)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.controller_id, 0)
	assert_false(giant.tapped)
	assert_true(giant.has_keyword(Mtg.Keyword.HASTE))
	advance_to_next_turn()
	assert_eq(giant.controller_id, 1, "back at end of turn")
	assert_false(giant.has_keyword(Mtg.Keyword.HASTE))


func test_the_top_of_the_library() -> void:
	var bolt := _dead(0, "Lightning Bolt")
	var giant := _dead(0, "Hill Giant")
	var recall := _spell({"name": "Ash Recall", "cost": "{G}"}, [{"effect": "raise", "target": "any_card_to_top"},
		{"effect": "raise", "target": "creature_card_to_top"}])
	assert_eq(recall.oracle_text, "Put target card from your graveyard on top of your library and "
		+ "put target creature card from your graveyard on top of your library.")
	var spell := give_synthetic(0, recall)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bolt), TargetRef.card(giant)]))
	resolve_stack()
	assert_eq([bolt.zone, giant.zone], [Mtg.Zone.LIBRARY, Mtg.Zone.LIBRARY])
	var before := g.players[0].hand.size()
	g.draw_cards(0, 2)
	assert_true(g.players[0].hand.has(bolt) and g.players[0].hand.has(giant), "the top two cards")
	assert_eq(g.players[0].hand.size(), before + 2)
	# A tutor that puts the card on top.
	var tutor := _spell({"name": "Ash Tutor", "cost": "{B}"}, [
		{"effect": "search", "amount": 1, "where": "library_top", "target": "a_named", "named": "Hill Giant"}])
	assert_eq(tutor.oracle_text, "Search your library for a card named Hill Giant, then shuffle and put that card on top.")
	_refused({"types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "search", "amount": 2, "where": "library_top", "target": "a_card"}]}]}, "one card goes on top")
	var wanted := _make_instance(0, "Hill Giant")
	wanted.zone = Mtg.Zone.LIBRARY
	g.players[0].library.insert(g.players[0].library.size() / 2, wanted)
	var search := give_synthetic(0, tutor)
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_ok(g.cast_spell(0, search, []))
	resolve_stack()
	g.draw_cards(0, 1)
	assert_true(g.players[0].hand.has(wanted), "it was put on top")


func test_the_computer_aims_the_second_round() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	give_hand(1, "Hill Giant")
	_dead(0, "Hill Giant")
	var ai := AiPlayer.new(0, AiProfile.wizard())
	advance_to_step(Mtg.Step.MAIN1)
	var rows := [
		[{"effect": "borrow", "target": "creature"}, 1],
		[{"effect": "damage", "amount": 1, "target": "any", "per": "swamp_you"}, 1],
		[{"effect": "lose_life", "amount": 1, "target": "player", "per": "swamp_you"}, 1],
		[{"effect": "pump", "power": 1, "toughness": 1, "target": "creature", "per": "swamp_you"}, 0],
		[{"effect": "counters", "amount": 1, "target": "creature", "per": "swamp_you"}, 0],
		[{"effect": "raise", "target": "any_card_to_top"}, 0],
	]
	for row in rows:
		var inst := give_synthetic(0, _card({"name": "Aim Test", "types": ["sorcery"], "cost": "{1}",
			"abilities": [{"kind": "spell", "effects": [row[0]]}]}))
		var picks: Variant = ai._choose_targets(g, inst, 0)
		var label := str(row[0])
		assert_true(picks is Array and (picks as Array).size() == 1, "one target: " + label)
		if picks is Array and (picks as Array).size() == 1:
			var ref: TargetRef = picks[0]
			var side := ref.player_id
			if not ref.is_player:
				var card := g.find_instance(ref.instance_id)
				side = card.owner_id if card.zone == Mtg.Zone.GRAVEYARD else card.controller_id
			assert_eq(side, row[1], label)
		g.players[0].hand.erase(inst)
	assert_true(mine.zone == Mtg.Zone.BATTLEFIELD)
