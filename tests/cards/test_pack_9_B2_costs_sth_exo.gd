extends GameTest
## Pack 9 (the Tempest block), batch B2: the Stronghold and Exodus cost
## cards (cards/sets/sth/_costs.gd, cards/sets/exo/_costs.gd) — Dream
## Halls, Fling, Heartstone, Hidden Retreat, Mask of the Mimic, Scapegoat,
## Aether Tide, Culling the Weak, Hatred, Necrologia, Penance, Sonic Burst
## and Sphere of Resistance: each card's effect, its refused case (a cost
## that cannot be paid changes nothing — CR 601.2h, 602.2b) and the two
## rules presets where the 1997 rules differ (a tapped artifact's static
## stops; mana burn).


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _pool(pid := 0) -> int: return g.players[pid].mana_pool.total()

func _to_library(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

## P1 casts a spell at [param target] and passes: P0 holds priority.
func _their_spell(card_name: String, color: int, mana: int, target: TargetRef) -> CardInstance:
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, card_name)
	add_mana(1, color, mana)
	assert_ok(g.cast_spell(1, spell, [target]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return spell

func _ability_cost(pid: int, inst: CardInstance, index: int) -> int:
	var pay := g.ability_payment(pid, inst, index)
	return (pay["cost"] as ManaCost).mana_value() + int(pay["extra"])

func _spell_cost(pid: int, card_name: String) -> int:
	var pay := g.spell_payment(pid, CardRegistry.get_card(card_name), 0, 1, null, 0)
	return (pay["cost"] as ManaCost).mana_value() + int(pay["extra"])


func test_every_stronghold_and_exodus_cost_card_is_claimed() -> void:
	for card_name in ["Dream Halls", "Fling", "Heartstone", "Hidden Retreat", "Mask of the Mimic",
			"Scapegoat", "Aether Tide", "Culling the Weak", "Hatred", "Necrologia", "Penance",
			"Sonic Burst", "Sphere of Resistance"]:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# --------------------------------------------------------------- Dream Halls --

func test_dream_halls_casts_a_spell_for_a_card_of_its_colour() -> void:
	put_battlefield(0, "Dream Halls")
	var dragon := give_hand(0, "Shivan Dragon")
	var fodder := give_hand(0, "Lightning Bolt")
	var blue := give_hand(0, "Counterspell")
	var rows := g.payment_rows(0, dragon)
	assert_eq(rows.size(), 2, "the printed row, then Dream Halls'")
	assert_ok(g.cast_spell(0, dragon, [], 0, 1))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "the red card paid for it")
	assert_eq(blue.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)

func test_dream_halls_works_for_every_player_and_never_for_colourless() -> void:
	put_battlefield(0, "Dream Halls")
	var bolt := give_hand(1, "Lightning Bolt")
	give_hand(1, "Mountain")
	var other := give_hand(1, "Fireball")
	var icy := give_hand(1, "Icy Manipulator")
	assert_eq(g.payment_rows(1, icy).size(), 1, "a colourless spell shares no colour")
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)], 0, 1))
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD, "a land is colourless; the red card paid")
	resolve_stack()
	assert_eq(g.players[0].life, 17)

func test_dream_halls_keeps_a_buyback_owed_on_top() -> void:
	put_battlefield(0, "Dream Halls")
	var bears := put_battlefield(1, "Grizzly Bears")
	var capsize := give_hand(0, "Capsize")
	var fodder := give_hand(0, "Counterspell")
	var rows := g.payment_rows(0, capsize)
	assert_eq(rows.size(), 4, "printed, buyback, Halls, Halls with buyback")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, capsize, [TargetRef.card(bears)], 0, 3), "not enough mana")
	assert_eq(fodder.zone, Mtg.Zone.HAND, "refused: nothing discarded")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, capsize, [TargetRef.card(bears)], 0, 3))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(capsize.zone, Mtg.Zone.HAND, "the buyback was still paid (ruling)")
	assert_true(g.players[1].hand.has(bears))

func test_dream_halls_x_is_zero() -> void:
	put_battlefield(0, "Dream Halls")
	var fireball := give_hand(0, "Fireball")
	give_hand(0, "Lightning Bolt")
	assert_refused(g.cast_spell(0, fireball, [TargetRef.player(1)], 3, 1), "X")
	assert_eq(fireball.zone, Mtg.Zone.HAND)


# --------------------------------------------------------------------- Fling --

func test_fling_deals_the_sacrificed_creatures_power() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(giant)]))
	resolve_stack()
	var fling := give_hand(0, "Fling")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, fling, [TargetRef.player(1)]))
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "sacrificed as it is cast")
	resolve_stack()
	assert_eq(g.players[1].life, 14, "6 power as it last existed (ruling)")

func test_fling_needs_a_creature() -> void:
	var fling := give_hand(0, "Fling")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, fling, [TargetRef.player(1)]))
	assert_eq(_pool(), 2)


# ---------------------------------------------------------------- Heartstone --

func test_heartstone_takes_one_off_creature_abilities_down_to_one_mana() -> void:
	var feeder := put_battlefield(0, "Spike Feeder")
	var troll := put_battlefield(0, "Uthden Troll")
	var icy := put_battlefield(0, "Icy Manipulator")
	assert_eq(_ability_cost(0, feeder, 0), 2)
	put_battlefield(1, "Heartstone")
	assert_eq(_ability_cost(0, feeder, 0), 1, "{2} becomes {1} — anyone's Heartstone")
	assert_eq(_ability_cost(0, feeder, 1), 0, "no mana: it never adds {1}")
	assert_eq(_ability_cost(0, troll, 0), 1, "{R} stays {R}: never a pip")
	assert_eq(_ability_cost(0, icy, 0), 1, "an artifact's ability is no creature's")
	put_battlefield(0, "Heartstone")
	assert_eq(_ability_cost(0, feeder, 0), 1, "two Heartstones: never below one mana")

func test_heartstone_pays_the_reduced_cost_and_a_tapped_one_stops_under_1997_rules() -> void:
	var feeder := put_battlefield(0, "Spike Feeder")
	var stone := put_battlefield(0, "Heartstone")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, feeder, 0, [TargetRef.card(feeder)]))
	assert_eq(_pool(), 0)
	resolve_stack()
	g.tap_permanent(stone)
	g.rules.set_preset("fifth")
	g.recalculate()
	assert_eq(_ability_cost(0, feeder, 0), 2, "fifth: a tapped artifact's static stops")
	g.rules.set_preset("modern_mana_burn")
	g.recalculate()
	assert_eq(_ability_cost(0, feeder, 0), 1)


# ------------------------------------------------------------ Hidden Retreat --

func test_hidden_retreat_prevents_all_damage_from_a_spell() -> void:
	var retreat := put_battlefield(0, "Hidden Retreat")
	var card := give_hand(0, "Forest")
	var bolt := _their_spell("Lightning Bolt", Mtg.ManaColor.R, 1, TargetRef.player(0))
	assert_ok(g.activate_ability(0, retreat, 0, [TargetRef.card(bolt)]))
	assert_eq(card.zone, Mtg.Zone.LIBRARY, "the cost: a card from the hand on top of the library")
	assert_eq(g.players[0].library.back(), card)
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	assert_true(retreat.data.activated_abilities[0].effects[0].is_damage_prevention)

func test_hidden_retreat_needs_a_card_and_an_instant_or_sorcery() -> void:
	var retreat := put_battlefield(0, "Hidden Retreat")
	var bolt := _their_spell("Lightning Bolt", Mtg.ManaColor.R, 1, TargetRef.player(0))
	assert_refused(g.activate_ability(0, retreat, 0, [TargetRef.card(bolt)]))
	give_hand(0, "Forest")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, retreat, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)

func test_hidden_retreat_covers_a_creature_victim_too() -> void:
	var retreat := put_battlefield(0, "Hidden Retreat")
	give_hand(0, "Forest")
	var bears := put_battlefield(0, "Grizzly Bears")
	var bolt := _their_spell("Lightning Bolt", Mtg.ManaColor.R, 1, TargetRef.card(bears))
	assert_ok(g.activate_ability(0, retreat, 0, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "a creature victim too (ruling)")
	assert_eq(bears.damage, 0)


# --------------------------------------------------------- Mask of the Mimic --

func test_mask_of_the_mimic_fetches_a_namesake_onto_the_battlefield() -> void:
	var fodder := put_battlefield(0, "Llanowar Elves")
	var model := put_battlefield(1, "Serra Angel")
	var copy := _to_library(0, "Serra Angel")
	var mask := give_hand(0, "Mask of the Mimic")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, mask, [TargetRef.card(model)]))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(copy.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(copy.controller_id, 0)

func test_mask_of_the_mimic_refuses_a_token_and_needs_a_sacrifice() -> void:
	var rat := g.create_token(1, CardData.new("Rat", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	var mask := give_hand(0, "Mask of the Mimic")
	var fodder := put_battlefield(0, "Llanowar Elves")
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, mask, [TargetRef.card(rat)]))
	assert_eq(fodder.zone, Mtg.Zone.BATTLEFIELD)
	g.exile_permanent(fodder)
	var model := put_battlefield(1, "Serra Angel")
	assert_refused(g.cast_spell(0, mask, [TargetRef.card(model)]))
	assert_eq(_pool(), 1)

func test_mask_of_the_mimic_finds_nothing_without_a_namesake() -> void:
	put_battlefield(0, "Llanowar Elves")
	var model := put_battlefield(1, "Serra Angel")
	var mask := give_hand(0, "Mask of the Mimic")
	add_mana(0, Mtg.ManaColor.U)
	var library := g.players[0].library.size()
	assert_ok(g.cast_spell(0, mask, [TargetRef.card(model)]))
	resolve_stack()
	assert_eq(g.players[0].library.size(), library)
	assert_eq(mask.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------------- Scapegoat --

func test_scapegoat_returns_any_number_of_your_creatures() -> void:
	var fodder := put_battlefield(0, "Llanowar Elves")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var goat := give_hand(0, "Scapegoat")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, goat, [TargetRef.card(bears), TargetRef.card(giant)]))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_true(g.players[0].hand.has(bears))
	assert_true(g.players[0].hand.has(giant))

func test_scapegoat_refuses_their_creatures_and_may_target_none() -> void:
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var goat := give_hand(0, "Scapegoat")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, goat, [TargetRef.card(theirs)]))
	assert_ok(g.cast_spell(0, goat, []))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Aether Tide --

func test_aether_tide_discards_x_creature_cards_to_bounce_x_creatures() -> void:
	var a := put_battlefield(1, "Hill Giant")
	var b := put_battlefield(1, "Serra Angel")
	var cards: Array = [give_hand(0, "Grizzly Bears"), give_hand(0, "Craw Wurm")]
	var tide := give_hand(0, "Aether Tide")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, tide, [TargetRef.card(a), TargetRef.card(b)], 2))
	for card in cards:
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_true(g.players[1].hand.has(a))
	assert_true(g.players[1].hand.has(b))

func test_aether_tide_counts_creature_cards_only() -> void:
	var a := put_battlefield(1, "Hill Giant")
	give_hand(0, "Forest")
	var tide := give_hand(0, "Aether Tide")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, tide, [TargetRef.card(a)], 1))
	assert_eq(_pool(), 2)


# ---------------------------------------------------------- Culling the Weak --

func test_culling_the_weak_turns_a_creature_into_four_black() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var bears := put_battlefield(0, "Grizzly Bears")
		var culling := give_hand(0, "Culling the Weak")
		add_mana(0, Mtg.ManaColor.B)
		assert_ok(g.cast_spell(0, culling))
		assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, preset)
		resolve_stack()
		assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 4, preset)
		var vampire := give_hand(0, "Sengir Vampire")
		assert_refused(g.cast_spell(0, vampire), "not enough mana")
		var specter := give_hand(0, "Hypnotic Specter")
		assert_ok(g.cast_spell(0, specter))
		resolve_stack()
		assert_eq(specter.zone, Mtg.Zone.BATTLEFIELD, preset)

func test_culling_the_weak_needs_a_creature() -> void:
	var culling := give_hand(0, "Culling the Weak")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(0, culling))
	assert_eq(_pool(), 1)


# --------------------------------------------------------------------- Hatred --

func test_hatred_pays_x_life_for_plus_x_power() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var hatred := give_hand(0, "Hatred")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, hatred, [TargetRef.card(bears)], 6))
	assert_eq(g.players[0].life, 14, "paid as it is cast")
	assert_eq(_pool(), 0, "X is life, not mana")
	resolve_stack()
	assert_eq([bears.cur_power, bears.cur_toughness], [8, 2])

func test_hatred_cannot_pay_more_life_than_it_has_and_the_life_is_lost_if_countered() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var hatred := give_hand(0, "Hatred")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, hatred, [TargetRef.card(bears)], 21))
	assert_eq(g.players[0].life, 20)
	assert_ok(g.cast_spell(0, hatred, [TargetRef.card(bears)], 3))
	assert_ok(g.pass_priority(0))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(hatred)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "a cost stays paid (ruling)")
	assert_eq(bears.cur_power, 2)


# ----------------------------------------------------------------- Necrologia --

func test_necrologia_draws_x_for_x_life_in_your_end_step() -> void:
	var necrologia := give_hand(0, "Necrologia")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, necrologia, [], 2), "end step")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, necrologia, [], 3))
	assert_eq(g.players[0].life, 17)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand - 1 + 3)

func test_necrologia_refuses_the_opponents_end_step() -> void:
	var necrologia := give_hand(0, "Necrologia")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, necrologia, [], 1), "your end step")


# -------------------------------------------------------------------- Penance --

func test_penance_shields_against_a_red_source() -> void:
	var penance := put_battlefield(0, "Penance")
	var card := give_hand(0, "Forest")
	var bolt := _their_spell("Lightning Bolt", Mtg.ManaColor.R, 1, TargetRef.player(0))
	assert_ok(g.activate_ability(0, penance, 0))
	assert_eq(card.zone, Mtg.Zone.LIBRARY)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)
	assert_true(penance.data.activated_abilities[0].effects[0].is_damage_prevention)

func test_penance_cannot_name_a_blue_source() -> void:
	var penance := put_battlefield(0, "Penance")
	give_hand(0, "Forest")
	_their_spell("Psionic Blast", Mtg.ManaColor.U, 3, TargetRef.player(0))
	assert_ok(g.activate_ability(0, penance, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 16, "a blue source is not black or red")

func test_penance_needs_a_card_in_hand() -> void:
	var penance := put_battlefield(0, "Penance")
	assert_refused(g.activate_ability(0, penance, 0))


# ---------------------------------------------------------------- Sonic Burst --

func test_sonic_burst_discards_at_random_and_deals_four() -> void:
	var giant := put_battlefield(1, "Serra Angel")
	var spare := give_hand(0, "Forest")
	var burst := give_hand(0, "Sonic Burst")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, burst, [TargetRef.card(giant)]))
	assert_eq(spare.zone, Mtg.Zone.GRAVEYARD, "the only other card")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)

func test_sonic_burst_needs_another_card() -> void:
	var burst := give_hand(0, "Sonic Burst")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, burst, [TargetRef.player(1)]))
	assert_eq(_pool(), 2)
	assert_eq(burst.zone, Mtg.Zone.HAND)


# ------------------------------------------------------- Sphere of Resistance --

func test_sphere_of_resistance_taxes_every_spell_of_every_player() -> void:
	put_battlefield(1, "Sphere of Resistance")
	assert_eq(_spell_cost(0, "Lightning Bolt"), 2)
	assert_eq(_spell_cost(1, "Lightning Bolt"), 2, "its controller's too")
	put_battlefield(0, "Sphere of Resistance")
	assert_eq(_spell_cost(0, "Grizzly Bears"), 4)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "not enough mana")

func test_a_tapped_sphere_stops_under_the_1997_rules_only() -> void:
	var sphere := put_battlefield(0, "Sphere of Resistance")
	g.tap_permanent(sphere)
	g.rules.set_preset("modern_mana_burn")
	g.recalculate()
	assert_eq(_spell_cost(0, "Lightning Bolt"), 2)
	g.rules.set_preset("fifth")
	g.recalculate()
	assert_eq(_spell_cost(0, "Lightning Bolt"), 1)
