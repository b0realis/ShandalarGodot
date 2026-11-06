extends GameTest
## Pack 10 (the Urza block), batch B12: Opalescence (cards/sets/uds/_opal.gd)
## and Soul Sculptor (cards/sets/usg/_opal.gd), and the interactions
## INVENTORY.md §7 pins for them.
##
## Opalescence + Humility is the rules' own pair (CR 613.6-613.8): Humility
## older — Humility is a 4/4, every other non-Aura enchantment its mana
## value, every other creature 1/1; Humility newer — every creature 1/1.
## Two Opalescences and a Humility kill nothing. An Opal that has become its
## creature is no enchantment and Opalescence lets it go; a creature Soul
## Sculptor made an enchantment is one, and Opalescence animates it again
## (CR 613.8a) — without abilities — until a creature spell is cast.

const W := Mtg.ManaColor.W
const G := Mtg.ManaColor.G


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


func _cast_bears(pid := 0) -> CardInstance:
	var bears := give_hand(pid, "Grizzly Bears")
	add_mana(pid, G, 2)
	assert_ok(g.cast_spell(pid, bears, []))
	return bears


func _sculpt(sculptor: CardInstance, target: CardInstance) -> void:
	add_mana(sculptor.controller_id, W, 2)
	assert_ok(g.activate_ability(sculptor.controller_id, sculptor, 0, [TargetRef.card(target)]))
	resolve_stack()


# --------------------------------------------------------------- Opalescence --

func test_opalescence_animates_each_other_non_aura_enchantment() -> void:
	var crusade := put_battlefield(1, "Crusade")
	var bear := put_battlefield(1, "Grizzly Bears")
	var flight := CardInstance.new(CardRegistry.get_card("Flight"), g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[flight.id] = flight
	g._put_on_battlefield(flight, 1, bear)
	var opal := put_battlefield(0, "Opalescence")
	assert_true(crusade.is_creature() and crusade.is_type(Mtg.CardType.ENCHANTMENT),
		"both seats' enchantments")
	assert_eq(_pt(crusade), [3, 3], "2 + its own +1/+1 (Crusade is white)")
	assert_false(flight.is_creature(), "non-Aura")
	assert_false(opal.is_creature(), "\"each other\"")


func test_wrath_of_god_takes_the_animated_enchantments() -> void:
	var crusade := put_battlefield(1, "Crusade")
	put_battlefield(0, "Opalescence")
	var wrath := give_hand(0, "Wrath of God")
	add_mana(0, W, 4)
	assert_ok(g.cast_spell(0, wrath, []))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)


func test_humility_older_than_opalescence() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var crusade := put_battlefield(0, "Crusade")
	var humility := put_battlefield(1, "Humility")
	put_battlefield(1, "Opalescence")
	assert_eq(_pt(humility), [4, 4])
	assert_eq(_pt(crusade), [2, 2], "its mana value; its own anthem silenced")
	assert_eq(_pt(angel), [1, 1])
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))


func test_humility_newer_than_opalescence() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var crusade := put_battlefield(0, "Crusade")
	put_battlefield(1, "Opalescence")
	var humility := put_battlefield(1, "Humility")
	for inst in [angel, crusade, humility]:
		assert_eq(_pt(inst), [1, 1], "%s: every creature 1/1" % inst.data.card_name)


func test_two_opalescences_and_humility_kill_nothing() -> void:
	var crusade := put_battlefield(0, "Crusade")
	var first := put_battlefield(0, "Opalescence")
	var second := put_battlefield(1, "Opalescence")
	var humility := put_battlefield(1, "Humility")
	g.check_state_based_actions()
	for inst in [crusade, first, second, humility]:
		assert_eq(inst.zone, Mtg.Zone.BATTLEFIELD, "%s survives" % inst.data.card_name)
		assert_eq(_pt(inst), [1, 1])


func test_opal_archangel_under_opalescence_before_and_after_its_trigger() -> void:
	var archangel := put_battlefield(1, "Opal Archangel")
	put_battlefield(1, "Opalescence")
	assert_true(archangel.is_creature() and archangel.is_type(Mtg.CardType.ENCHANTMENT))
	assert_eq(_pt(archangel), [5, 5], "dormant: its mana value")
	assert_false(archangel.has_keyword(Mtg.Keyword.FLYING))
	_cast_bears()
	resolve_stack()
	assert_false(archangel.is_type(Mtg.CardType.ENCHANTMENT), "still an enchantment when it triggered; not now")
	assert_eq(_pt(archangel), [5, 5])
	assert_true(archangel.has_keyword(Mtg.Keyword.FLYING))


func test_opal_acrolith_under_opalescence_both_ways() -> void:
	var acrolith := put_battlefield(1, "Opal Acrolith")
	put_battlefield(1, "Opalescence")
	assert_eq(_pt(acrolith), [3, 3], "dormant: an enchantment creature 3/3")
	_cast_bears()
	resolve_stack()
	assert_eq(_pt(acrolith), [2, 4], "a Soldier, no enchantment")
	assert_false(acrolith.is_type(Mtg.CardType.ENCHANTMENT))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, acrolith, 0, []))
	resolve_stack()
	assert_true(acrolith.is_type(Mtg.CardType.ENCHANTMENT) and acrolith.is_creature(),
		"{0} under an older Opalescence: an enchantment creature (CR 613.8a)")
	# The trigger's 2/4 still exists ({0} changes only the type) and is the
	# NEWER layer-7b effect than Opalescence's (CR 613.6, 613.7).
	assert_eq(_pt(acrolith), [2, 4])


func test_an_opalescence_newer_than_the_acroliths_size_sets_it() -> void:
	var acrolith := put_battlefield(1, "Opal Acrolith")
	_cast_bears()
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, acrolith, 0, []))
	resolve_stack()
	assert_false(acrolith.is_creature())
	put_battlefield(1, "Opalescence")
	assert_true(acrolith.is_creature())
	assert_eq(_pt(acrolith), [3, 3], "Opalescence is the newer 7b effect now")


func test_a_one_drop_opal_under_opalescence_is_a_one_one() -> void:
	var dormant := put_battlefield(1, "Opal Caryatid")
	put_battlefield(1, "Opalescence")
	assert_eq(_pt(dormant), [1, 1], "mana value 1")
	assert_eq(dormant.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------------- Soul Sculptor --

func test_sculptor_makes_a_creature_an_enchantment_without_abilities() -> void:
	var sculptor := put_battlefield(0, "Soul Sculptor")
	var angel := put_battlefield(1, "Serra Angel")
	_sculpt(sculptor, angel)
	assert_true(sculptor.tapped)
	assert_false(angel.is_creature())
	assert_true(angel.is_type(Mtg.CardType.ENCHANTMENT))
	assert_true(angel.cur_abilities_silenced)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))


func test_sculptor_needs_a_creature_target() -> void:
	var sculptor := put_battlefield(0, "Soul Sculptor")
	var crusade := put_battlefield(1, "Crusade")
	add_mana(0, W, 2)
	assert_refused(g.activate_ability(0, sculptor, 0, [TargetRef.card(crusade)]))
	assert_false(sculptor.tapped, "refused before anything was paid")


func test_any_creature_spell_ends_it_as_it_is_cast() -> void:
	var sculptor := put_battlefield(0, "Soul Sculptor")
	var angel := put_battlefield(1, "Serra Angel")
	_sculpt(sculptor, angel)
	var bears := _cast_bears(0)
	assert_eq(bears.zone, Mtg.Zone.STACK)
	assert_true(angel.is_creature(), "the Sculptor's own side's creature spell ends it too")
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))


func test_the_effect_outlives_the_sculptor() -> void:
	var sculptor := put_battlefield(0, "Soul Sculptor")
	var angel := put_battlefield(1, "Serra Angel")
	_sculpt(sculptor, angel)
	g.destroy(sculptor)
	advance_to_next_turn()
	assert_false(angel.is_creature(), "no creature spell yet")


func test_a_sculpted_creature_under_opalescence() -> void:
	var sculptor := put_battlefield(0, "Soul Sculptor")
	var angel := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Opalescence")
	_sculpt(sculptor, angel)
	assert_true(angel.is_creature() and angel.is_type(Mtg.CardType.ENCHANTMENT),
		"Opalescence applies after the type change (CR 613.8a)")
	assert_eq(_pt(angel), [5, 5], "its mana value")
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "and no abilities")
	_cast_bears()
	assert_eq(_pt(angel), [4, 4])
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))


func test_sculpting_an_opal_creature_and_its_return() -> void:
	var sculptor := put_battlefield(0, "Soul Sculptor")
	var gargoyle := put_battlefield(1, "Opal Gargoyle")
	_cast_bears()
	resolve_stack()
	assert_true(gargoyle.is_creature())
	_sculpt(sculptor, gargoyle)
	assert_false(gargoyle.is_creature(), "the Sculptor's change is the later one")
	assert_true(gargoyle.cur_abilities_silenced)
	_cast_bears()
	resolve_stack()
	assert_true(gargoyle.is_creature(), "the Opal's own change applies again")
	assert_false(gargoyle.is_type(Mtg.CardType.ENCHANTMENT))
	assert_eq(_pt(gargoyle), [2, 2])
	assert_true(gargoyle.has_keyword(Mtg.Keyword.FLYING))
