extends GameTest
## Pack 10 (the Urza block), batch B12: the white Opal enchantments of
## cards/sets/usg/_opal.gd and cards/sets/ulg/_opal.gd — Opal Caryatid,
## Opal Gargoyle, Opal Archangel, Opal Titan, Opal Acrolith, Opal Champion,
## Opal Avenger.
##
## "It becomes a 2/2 Soldier creature" REPLACES the card type (CR 205.1a):
## the permanent is a creature and no longer an enchantment, for the rest of
## the game. "If this permanent is an enchantment" is an intervening if
## (CR 603.4): asked as the trigger triggers and again as it resolves.

const W := Mtg.ManaColor.W
const G := Mtg.ManaColor.G


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


## P0 (the active player, the Opal's opponent) casts a creature spell.
func _cast_bears(pid := 0) -> CardInstance:
	var bears := give_hand(pid, "Grizzly Bears")
	add_mana(pid, G, 2)
	assert_ok(g.cast_spell(pid, bears, []))
	return bears


func _is_plain_creature(inst: CardInstance, subtype: String) -> void:
	assert_true(inst.is_creature(), "%s is a creature" % inst.data.card_name)
	assert_false(inst.is_type(Mtg.CardType.ENCHANTMENT), "and no longer an enchantment (CR 205.1a)")
	assert_true(inst.has_subtype(subtype), "a %s" % subtype)


# ------------------------------------------------------------ Opal Caryatid --

func test_caryatid_becomes_a_soldier_when_an_opponent_casts_a_creature() -> void:
	var opal := put_battlefield(1, "Opal Caryatid")
	assert_false(opal.is_creature(), "dormant: an enchantment")
	_cast_bears()
	resolve_stack()
	_is_plain_creature(opal, "soldier")
	assert_eq(_pt(opal), [2, 2])


func test_caryatid_ignores_its_controllers_own_creature_and_noncreature_spells() -> void:
	var opal := put_battlefield(0, "Opal Caryatid")
	_cast_bears(0)
	var crusade := give_hand(0, "Crusade")
	resolve_stack()
	add_mana(0, W, 2)
	assert_ok(g.cast_spell(0, crusade, []))
	resolve_stack()
	assert_false(opal.is_creature(), "only an OPPONENT's creature spell")


func test_the_if_is_asked_again_as_it_resolves() -> void:
	var opal := put_battlefield(1, "Opal Caryatid")
	_cast_bears()   # the trigger waits above the Bears
	# Something else makes it a creature first (another trigger of its own,
	# an Opal Acrolith-like change): no longer an enchantment.
	g.continuous.add_type_change(opal.id, {"set_types": Mtg.CardType.CREATURE,
		"set_subtypes": ["golem"]})
	g.continuous.add_until_eot_base_pt(opal.id, 7, 7, false, ContinuousEffects.Duration.INDEFINITE)
	g.recalculate()
	resolve_stack()
	assert_eq(_pt(opal), [7, 7], "the trigger found it no enchantment and did nothing (CR 603.4)")
	assert_false(opal.has_subtype("soldier"))


func test_a_caryatid_that_left_does_nothing() -> void:
	var opal := put_battlefield(1, "Opal Caryatid")
	_cast_bears()
	g.return_to_hand(opal)
	resolve_stack()
	assert_eq(opal.zone, Mtg.Zone.HAND)
	assert_true(g.continuous._type_changes.is_empty(), "a new object (CR 400.7)")


func test_the_creature_lasts_and_an_aura_for_enchantments_falls_off() -> void:
	var opal := put_battlefield(1, "Opal Caryatid")
	var feedback := CardInstance.new(CardRegistry.get_card("Feedback"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[feedback.id] = feedback
	g._put_on_battlefield(feedback, 0, opal)
	_cast_bears()
	resolve_stack()
	assert_eq(feedback.zone, Mtg.Zone.GRAVEYARD, "enchant enchantment: no longer legal")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(opal.is_creature(), "no duration: it stays a creature")
	assert_eq(_pt(opal), [2, 2])


func test_disenchant_cannot_target_it_once_it_is_a_creature() -> void:
	var opal := put_battlefield(1, "Opal Caryatid")
	_cast_bears()
	resolve_stack()
	var disenchant := give_hand(0, "Disenchant")
	add_mana(0, W, 2)
	assert_refused(g.cast_spell(0, disenchant, [TargetRef.card(opal)]))
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(opal)]))
	resolve_stack()
	assert_eq(opal.zone, Mtg.Zone.GRAVEYARD, "creature removal does")


# ------------------------------------------------------ Gargoyle / Archangel --

func test_gargoyle_becomes_a_flying_two_two() -> void:
	var opal := put_battlefield(1, "Opal Gargoyle")
	_cast_bears()
	resolve_stack()
	_is_plain_creature(opal, "gargoyle")
	assert_eq(_pt(opal), [2, 2])
	assert_true(opal.has_keyword(Mtg.Keyword.FLYING))


func test_archangel_becomes_a_five_five_with_flying_and_vigilance() -> void:
	var opal := put_battlefield(1, "Opal Archangel")
	_cast_bears()
	resolve_stack()
	_is_plain_creature(opal, "angel")
	assert_eq(_pt(opal), [5, 5])
	assert_true(opal.has_keyword(Mtg.Keyword.FLYING))
	assert_true(opal.has_keyword(Mtg.Keyword.VIGILANCE))


# -------------------------------------------------------------- Opal Titan --

func test_titan_gets_protection_from_the_spells_colors() -> void:
	var opal := put_battlefield(1, "Opal Titan")
	_cast_bears()
	resolve_stack()
	_is_plain_creature(opal, "giant")
	assert_eq(_pt(opal), [4, 4])
	assert_eq(opal.cur_protection, G, "protection from green, the Bears' colour")


func test_titan_gets_no_protection_from_a_colorless_spell() -> void:
	var opal := put_battlefield(1, "Opal Titan")
	var thopter := give_hand(0, "Ornithopter")
	assert_ok(g.cast_spell(0, thopter, []))
	resolve_stack()
	assert_true(opal.is_creature())
	assert_eq(opal.cur_protection, 0)


# ------------------------------------------------------------ Opal Acrolith --

func test_acrolith_becomes_a_two_four_and_back_and_again() -> void:
	var opal := put_battlefield(1, "Opal Acrolith")
	_cast_bears()
	resolve_stack()
	_is_plain_creature(opal, "soldier")
	assert_eq(_pt(opal), [2, 4])
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, opal, 0, []))
	resolve_stack()
	assert_false(opal.is_creature(), "{0}: becomes an enchantment")
	assert_true(opal.is_type(Mtg.CardType.ENCHANTMENT))
	assert_false(opal.has_subtype("soldier"))
	_cast_bears()
	resolve_stack()
	assert_true(opal.is_creature(), "\"Whenever\": it triggers again as an enchantment")
	assert_eq(_pt(opal), [2, 4])


func test_acrolith_dodges_a_terror_in_response() -> void:
	var opal := put_battlefield(1, "Opal Acrolith")
	_cast_bears()
	resolve_stack()
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(opal)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, opal, 0, []))
	resolve_stack()
	assert_eq(opal.zone, Mtg.Zone.BATTLEFIELD, "no longer a creature: the Terror fizzles (CR 608.2b)")


# ------------------------------------------------------- Opal Champion --

func test_champion_becomes_a_three_three_first_striker() -> void:
	var opal := put_battlefield(1, "Opal Champion")
	_cast_bears()
	resolve_stack()
	_is_plain_creature(opal, "knight")
	assert_eq(_pt(opal), [3, 3])
	assert_true(opal.has_keyword(Mtg.Keyword.FIRST_STRIKE))


# -------------------------------------------------------- Opal Avenger --

func test_avenger_waits_for_ten_or_less_life() -> void:
	var opal := put_battlefield(1, "Opal Avenger")
	g.adjust_life(1, -9)
	resolve_stack()
	assert_false(opal.is_creature(), "11 life: not yet")
	g.adjust_life(1, -1)
	resolve_stack()
	_is_plain_creature(opal, "soldier")
	assert_eq(_pt(opal), [3, 5])


func test_avenger_arriving_at_low_life_triggers_at_once() -> void:
	g.players[1].life = 4
	var opal := put_battlefield(1, "Opal Avenger")
	g.check_state_based_actions()
	g.check_state_based_actions()
	resolve_stack()
	assert_true(opal.is_creature(), "a state trigger (CR 603.8)")
	assert_eq(_pt(opal), [3, 5])


func test_avenger_ignores_the_opponents_life() -> void:
	var opal := put_battlefield(1, "Opal Avenger")
	g.adjust_life(0, -15)
	resolve_stack()
	assert_false(opal.is_creature())


# ------------------------------------------------------------ the claims --

func test_every_b12_card_is_claimed() -> void:
	for card_name in ["Opal Acrolith", "Opal Archangel", "Opal Caryatid", "Opal Gargoyle",
			"Opal Titan", "Soul Sculptor", "Veil of Birds", "Veiled Apparition",
			"Veiled Crocodile", "Veiled Sentry", "Veiled Serpent", "Lurking Evil",
			"Hidden Ancients", "Hidden Guerrillas", "Hidden Herd", "Hidden Predators",
			"Hidden Spider", "Hidden Stag", "Opal Avenger", "Opal Champion",
			"Lurking Skirge", "Hidden Gibbons", "Opalescence", "Lurking Jackals"]:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s carries no pending guard" % card_name)


# --------------------------------------------------------------- Humility --

func test_an_opal_animated_after_humility_keeps_its_printed_size() -> void:
	CardPacks.set_enabled("pack-9", true)
	var early := put_battlefield(1, "Opal Champion")
	_cast_bears()
	resolve_stack()
	put_battlefield(1, "Humility")
	var late := put_battlefield(1, "Opal Archangel")
	_cast_bears()
	resolve_stack()
	assert_eq(_pt(early), [1, 1], "animated before Humility: 1/1")
	assert_false(early.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(_pt(late), [5, 5], "animated after it: the later 7b effect (CR 613.7)")
	assert_true(late.has_keyword(Mtg.Keyword.FLYING), "a grant made after Humility stays")


func test_a_dormant_opal_under_humility_still_triggers() -> void:
	CardPacks.set_enabled("pack-9", true)
	put_battlefield(1, "Humility")
	var opal := put_battlefield(1, "Opal Caryatid")
	assert_false(opal.cur_abilities_silenced, "an enchantment: Humility does not reach it")
	_cast_bears()
	resolve_stack()
	assert_true(opal.is_creature())
	assert_true(opal.cur_abilities_silenced, "a creature now")
