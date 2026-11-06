extends GameTest
## Pack 10 engine package E2 — CYCLING (CR 702.29a): an activated ability
## that functions only from its owner's HAND (CR 113.6), costs mana and
## discarding the card itself (a COST discard, CR 601.2h, 701.8), uses the
## stack (CR 602.2) and draws a card. Pinned on SYNTHETIC cards built with
## the builders card authors use (`CardData.with_cycling`,
## `ActivatedAbility.from_hand` / `with_discard_self_cost` / `as_cycling`),
## and against the real cards it meets: Megrim, Library of Leng, Forbidden
## Crypt, Heartstone, Gloom, Cursed Totem, Null Rod, Elvish Spirit Guide.
##
## Also the "cycling abilities you activate cost {2} less" shape
## (Fluctuator: `with_ability_cost_reduction` reading `is_cycling`), and the
## three routed fixes — Gloom, Cursed Totem and Null Rod read a card in a
## HAND as no permanent (CR 109.2).


func before_all() -> void:
	CardPacks.set_enabled_many(["pack-5", "pack-8", "pack-9"] as Array[String], true)


func after_all() -> void:
	CardPacks.set_enabled_many(["pack-5", "pack-8", "pack-9"] as Array[String], false)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ----------------------------------------------------------------- fixture --

## A white instant with cycling {2} (Clear's shape).
static func _cycler(card_name := "Test Cycler", cost := "{2}") -> CardData:
	return CardData.new(card_name, "{1}{W}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment",
			func(c: CardInstance) -> bool: return c.is_type(Mtg.CardType.ENCHANTMENT)))) \
		.with_cycling(cost) \
		.oracle("Destroy target enchantment.\nCycling %s (%s, Discard this card: Draw a card.)" % [cost, cost])


## A cycling land (Blasted Landscape's shape).
static func _cycling_land() -> CardData:
	return CardData.new("Test Landscape", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)) \
		.with_cycling() \
		.oracle("{T}: Add {C}.\nCycling {2} ({2}, Discard this card: Draw a card.)")


## A white enchantment with a battlefield ability AND cycling (a Rune of
## Protection's shape): index 0 works on the battlefield, index 1 in hand.
static func _rune() -> CardData:
	return CardData.new("Test Rune", "{1}{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("{W}", false, [GainLifeEffect.new(1)], "{W}: You gain 1 life.")) \
		.with_cycling() \
		.oracle("{W}: You gain 1 life.\nCycling {2} ({2}, Discard this card: Draw a card.)")


## A creature with cycling (Disciple of Grace's shape) — for Cursed Totem.
static func _cycling_creature() -> CardData:
	return CardData.new("Test Disciple", "{1}{W}", Mtg.CardType.CREATURE).pt(1, 2) \
		.with_cycling()


## An artifact with a battlefield ability and cycling — for Null Rod.
static func _cycling_artifact() -> CardData:
	return CardData.new("Test Gadget", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{1}", false, [GainLifeEffect.new(1)], "{1}: You gain 1 life.")) \
		.with_cycling()


## Fluctuator's shape: "Cycling abilities you activate cost {2} less".
static func _fluctuator() -> CardData:
	return CardData.new("Test Fluctuator", "{2}", Mtg.CardType.ARTIFACT) \
		.with_ability_cost_reduction(2, _cycling_you_activate, 0)


static func _cycling_you_activate(_g: MtgGame, pid: int, _source: CardInstance,
		ability: ActivatedAbility, modifier: CardInstance) -> bool:
	return ability.is_cycling and pid == modifier.controller_id


## "Counter target activated ability." (Stifle's shape, CR 701.5).
static func _stifle() -> CardData:
	return CardData.new("Test Stifle", "{U}", Mtg.CardType.INSTANT) \
		.spell(CounterAbilityEffect.new())


func _cycle_index(inst: CardInstance) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i].is_cycling:
			return i
	return -1


## P0 holds priority in P1's main phase, the stack empty — an instant's moment.
func _opponents_main() -> void:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------------ the builder itself --

func test_with_cycling_builds_a_hand_ability_with_a_self_discard_cost() -> void:
	var data := _rune()
	assert_true(data.has_cycling())
	assert_false(CardData.new("Test Plain", "{W}", Mtg.CardType.INSTANT).has_cycling())
	var ability: ActivatedAbility = data.activated_abilities[1]
	assert_eq(ability.activation_zone, Mtg.Zone.HAND)
	assert_true(ability.discard_self_cost)
	assert_true(ability.is_cycling)
	assert_false(ability.tap_cost)
	assert_eq(ability.cost.text, "{2}")
	assert_eq(ability.text, "Cycling {2} ({2}, Discard this card: Draw a card.)")
	assert_true(ability.effects[0] is DrawEffect)
	# Appended: the printed battlefield ability keeps index 0.
	assert_eq(data.activated_abilities[0].activation_zone, Mtg.Zone.BATTLEFIELD)
	# A copy keeps the markers (Power Artifact-style rewrites copy abilities).
	var copy := ability.shallow_copy()
	assert_true(copy.is_cycling and copy.discard_self_cost)
	assert_eq(copy.activation_zone, Mtg.Zone.HAND)


# --------------------------------------------------------------- cycling --

func test_cycling_at_instant_speed_uses_the_stack_and_draws() -> void:
	_opponents_main()
	var card := give_synthetic(0, _cycler())
	add_mana(0, Mtg.ManaColor.C, 2)
	var hand_before := g.players[0].hand.size()
	assert_eq(g.ability_announce_refusal(0, card, _cycle_index(card)), "")
	assert_ok(g.activate_ability(0, card, _cycle_index(card)))
	# The cost is paid on activation: the card is in the graveyard already
	# and the ability waits on the stack (CR 602.2, 601.2h).
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(card))
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack.back().kind, Mtg.StackKind.ABILITY)
	assert_eq(g.players[0].hand.size(), hand_before - 1)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(g.priority_player, 0, "the activator keeps priority (CR 117.3c)")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand_before, "drew a card")
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)


func test_cycling_is_refused_without_its_mana_and_changes_nothing() -> void:
	var card := give_synthetic(0, _cycler())
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, card, _cycle_index(card)), "not enough mana")
	assert_eq(card.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].mana_pool.total(), 1)


func test_only_the_owner_may_cycle_a_card_in_their_hand() -> void:
	var card := give_synthetic(0, _cycler())
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	add_mana(1, Mtg.ManaColor.C, 2)
	var why := g.ability_announce_refusal(1, card, _cycle_index(card))
	assert_string_contains(why, "owner")
	assert_refused(g.activate_ability(1, card, _cycle_index(card)), "owner")
	assert_eq(card.zone, Mtg.Zone.HAND)


func test_a_cycling_card_on_the_battlefield_or_in_a_graveyard_cannot_cycle() -> void:
	var land := put_synthetic(0, _cycling_land())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, land, _cycle_index(land)), "not available from this zone")
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	var dead := give_synthetic(0, _cycler("Test Buried"))
	g.card_to_graveyard_from_anywhere(dead)
	assert_refused(g.activate_ability(0, dead, _cycle_index(dead)), "not available from this zone")
	assert_eq(g.players[0].mana_pool.total(), 2, "nothing was paid")


func test_a_cycling_land_is_played_or_cycled_and_cycling_spends_no_land_drop() -> void:
	var cycled := give_synthetic(0, _cycling_land())
	var played := give_synthetic(0, _cycling_land())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, cycled, _cycle_index(cycled)))
	resolve_stack()
	assert_eq(cycled.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.land_drop_available(0), "cycling is no land play")
	assert_ok(g.play_land(0, played))
	assert_eq(played.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.land_drop_available(0))


func test_countering_the_cycling_ability_leaves_the_card_discarded() -> void:
	var card := give_synthetic(0, _cycler())
	var stifle := give_synthetic(1, _stifle())
	add_mana(0, Mtg.ManaColor.C, 2)
	var hand_before := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, card, _cycle_index(card)))
	var cycling: StackItem = g.stack.back()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, stifle, [TargetRef.ability(cycling)]))
	resolve_stack()
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "the cost stays paid (CR 602.2, 701.5)")
	assert_eq(g.players[0].hand.size(), hand_before - 1, "no card was drawn")


func test_two_stacked_cycling_activations_each_draw() -> void:
	var first := give_synthetic(0, _cycler("Test First"))
	var second := give_synthetic(0, _cycler("Test Second"))
	add_mana(0, Mtg.ManaColor.C, 4)
	var hand_before := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, first, _cycle_index(first)))
	assert_ok(g.activate_ability(0, second, _cycle_index(second)))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand_before, "two out, two drawn")
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)


func test_cycling_is_refused_in_the_1997_damage_prevention_window() -> void:
	g.rules.set_edition("fifth")
	var card := give_synthetic(0, _cycler())
	add_mana(0, Mtg.ManaColor.C, 2)
	var bolt := give_hand(1, "Lightning Bolt")
	plant_damage_packet(bolt, TargetRef.player(0), 3)
	g.awaiting_damage_prevention = true
	assert_refused(g.activate_ability(0, card, _cycle_index(card)), "damage prevention")
	assert_eq(card.zone, Mtg.Zone.HAND)


func test_the_journal_takes_a_cycling_activation_back() -> void:
	var card := give_synthetic(0, _cycler())
	add_mana(0, Mtg.ManaColor.C, 2)
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, card, _cycle_index(card)))
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(card.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(card))
	assert_false(g.players[0].graveyard.has(card))
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].mana_pool.total(), 2)


# ------------------------------------------------- a COST discard (701.8) --

func test_cycling_is_a_discard_megrim_hears_it_and_its_trigger_waits_above() -> void:
	put_battlefield(1, "Megrim")
	var card := give_synthetic(0, _cycler())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, card, _cycle_index(card)))
	# Megrim's trigger went on the stack ABOVE the ability (CR 603.3).
	assert_eq(g.stack.size(), 2)
	assert_eq(g.stack.back().kind, Mtg.StackKind.TRIGGER)
	resolve_stack()
	assert_eq(g.players[0].life, 18)


func test_the_discard_is_caused_by_no_opponent_and_library_of_leng_has_no_say() -> void:
	# Psychic Purge / Metrognome read who CAUSED the discard: a cost the
	# owner paid is caused by no opponent's spell or ability (-1).
	var seen: Array = []
	var data := _cycler("Test Purge")
	data.on_discarded = func(_game: MtgGame, _inst: CardInstance, _pid: int, by: int) -> void:
		seen.append(by)
	put_battlefield(0, "Library of Leng")
	var card := give_synthetic(0, data)
	var top: CardInstance = g.players[0].library.back()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, card, _cycle_index(card)))
	assert_eq(seen, [-1], "no opponent caused it")
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "a cost discard: Library of Leng has no say")
	assert_eq(g.players[0].library.back(), top)


func test_forbidden_crypt_exiles_the_cycled_card() -> void:
	put_battlefield(0, "Forbidden Crypt")
	var card := give_synthetic(0, _cycler())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, card, _cycle_index(card)))
	assert_eq(card.zone, Mtg.Zone.EXILE, "still a discard; the card is exiled")
	assert_eq(g.stack.size(), 1)


# ------------------------------------------- Fluctuator: "{2} less", 601.2f --

func test_a_fluctuator_makes_cycling_free_and_two_do_not_go_below_zero() -> void:
	put_synthetic(0, _fluctuator())
	var card := give_synthetic(0, _cycler())
	var index := _cycle_index(card)
	var due := g.ability_payment(0, card, index)
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 0, "{2} - {2}")
	put_synthetic(0, _fluctuator())
	due = g.ability_payment(0, card, index)
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 0, "floored at 0")
	assert_ok(g.activate_ability(0, card, index))
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)


func test_a_fluctuator_cuts_only_generic_mana_of_a_bigger_cycling_cost() -> void:
	put_synthetic(0, _fluctuator())
	var card := give_synthetic(0, _cycler("Test Costly", "{3}{W}"))
	var due := g.ability_payment(0, card, _cycle_index(card))
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 2, "{3}{W} - {2}: {1}{W}")


func test_the_opponents_fluctuator_and_a_non_cycling_ability_get_nothing() -> void:
	put_synthetic(1, _fluctuator())
	var card := give_synthetic(0, _cycler())
	var due := g.ability_payment(0, card, _cycle_index(card))
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 2, "only abilities ITS controller activates")
	put_synthetic(0, _fluctuator())
	var rune := put_synthetic(0, _rune())
	due = g.ability_payment(0, rune, 0)
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 1, "{W} is no cycling ability")


func test_a_tapped_fluctuator_does_nothing_under_the_1997_rule() -> void:
	g.rules.set_edition("fifth")
	var fluctuator := put_synthetic(0, _fluctuator())
	var card := give_synthetic(0, _cycler())
	fluctuator.tapped = true
	g.recalculate()
	var due := g.ability_payment(0, card, _cycle_index(card))
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 2)


func test_heartstone_does_not_reduce_cycling_a_creature_card_in_hand() -> void:
	put_battlefield(0, "Heartstone")
	var card := give_synthetic(0, _cycling_creature())
	var due := g.ability_payment(0, card, _cycle_index(card))
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 2,
		"a creature card in a hand is no creature (CR 109.2)")


# --------------------------------------- routed fixes: hand is not play --

func test_gloom_taxes_a_white_enchantment_on_the_battlefield_not_one_in_hand() -> void:
	put_battlefield(1, "Gloom")
	var in_hand := give_synthetic(0, _rune())
	var due := g.ability_payment(0, in_hand, _cycle_index(in_hand))
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 2, "cycling a Rune pays no Gloom tax")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, in_hand, _cycle_index(in_hand)))
	var on_table := put_synthetic(0, _rune())
	due = g.ability_payment(0, on_table, 0)
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 4, "{W} plus Gloom's {3}")


func test_cursed_totem_bans_creatures_abilities_not_a_creature_card_in_hand() -> void:
	put_battlefield(1, "Cursed Totem")
	var disciple := give_synthetic(0, _cycling_creature())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, disciple, _cycle_index(disciple)))
	assert_eq(disciple.zone, Mtg.Zone.GRAVEYARD)
	# A creature on the battlefield is still banned.
	var pinger := put_synthetic(0, CardData.new("Test Pinger", "{R}", Mtg.CardType.CREATURE).pt(1, 1) \
		.activated(ActivatedAbility.new("", true, [DamageEffect.new(1).any_target()], "{T}: 1 damage.")))
	assert_refused(g.activate_ability(0, pinger, 0, [TargetRef.player(1)]), "Cursed Totem")


func test_cursed_totem_lets_elvish_spirit_guide_make_mana_from_the_hand() -> void:
	put_battlefield(1, "Cursed Totem")
	var guide := give_hand(0, "Elvish Spirit Guide")
	assert_ok(g.tap_for_mana(0, guide, 0))
	assert_eq(g.players[0].mana_pool.total(), 1)
	assert_eq(guide.zone, Mtg.Zone.EXILE)


func test_null_rod_bans_artifacts_abilities_not_an_artifact_card_in_hand() -> void:
	put_battlefield(1, "Null Rod")
	var in_hand := give_synthetic(0, _cycling_artifact())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, in_hand, _cycle_index(in_hand)))
	assert_eq(in_hand.zone, Mtg.Zone.GRAVEYARD)
	var on_table := put_synthetic(0, _cycling_artifact())
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, on_table, 0), "Null Rod")
