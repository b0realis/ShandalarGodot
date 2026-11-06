extends GameTest
## Pack 10 engine package E3 — OPALESCENCE AND HUMILITY: CR 613.6 (an
## effect that started to apply keeps applying in later layers after its
## source loses its abilities) and CR 613.7 (layer 7b in timestamp order).
##
## The rules' own pair. Opalescence makes Humility a 4/4 creature in layer 4;
## Humility then removes every creature's abilities in layer 6, its own
## included, but its effect has started, so its 1/1 still applies in 7b
## (CR 613.6). In 7b the two setters apply in timestamp order:
## - Humility OLDER: every creature 1/1, then Opalescence makes each other
##   non-Aura enchantment MV/MV — Humility 4/4, the rest 1/1;
## - Opalescence OLDER: every creature, Humility included, is 1/1.
## Two Opalescences and a Humility: each Opalescence is a creature (the
## other made it one) and loses its abilities, yet both keep sizing what
## they animated — before Pack 10 every animated enchantment died a 0/0.
##
## The synthetic Opalescence and Humility print the two statics the cards
## print, keyed with [method StaticAbility.part_of]; the shipped Humility
## (Pack 9, cards/sets/tmp/_misc.gd) is pinned at the end.

const OPAL_KEY := &"opalescence"


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


# ------------------------------------------------------------ definitions --

static func _animated_by(source: CardInstance, inst: CardInstance) -> bool:
	return inst != source and not inst.phased_out \
		and inst.is_type(Mtg.CardType.ENCHANTMENT) and not inst.has_subtype("aura")


static func _opal_types(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if _animated_by(source, inst):
			inst.cur_types |= Mtg.CardType.CREATURE


static func _opal_size(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if _animated_by(source, inst):
			var mv := inst.data.cost.mana_value()
			inst.cur_power = mv
			inst.cur_toughness = mv


## "Each other non-Aura enchantment is a creature in addition to its other
## types and has base power and base toughness each equal to its mana value."
static func _opalescence(keyed := true) -> CardData:
	var types := StaticAbility.new(_opal_types,
		"Each other non-Aura enchantment is a creature in addition to its other types.") \
		.reading_card_types()
	var size := StaticAbility.new(_opal_size,
		"Each other non-Aura enchantment has base power and base toughness each equal to its mana value.") \
		.setting_base_pt()
	if keyed:
		types.part_of(OPAL_KEY)
		size.part_of(OPAL_KEY)
	return CardData.new("Test Opalescence", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(types).static_ability(size)


static func _any_creature(_g: MtgGame, _s: CardInstance, inst: CardInstance) -> bool:
	return inst.is_creature()


## "All creatures lose all abilities and have base power and toughness 1/1."
static func _humility(keyed := true) -> CardData:
	var silence := StaticAbility.removing_all_abilities(_any_creature,
		"All creatures lose all abilities.")
	var size := StaticAbility.base_pt_for(_any_creature, 1, 1,
		"All creatures have base power and toughness 1/1.")
	if keyed:
		silence.part_of(&"humility")
		size.part_of(&"humility")
	return CardData.new("Test Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(silence).static_ability(size)


## A plain enchantment of mana value [param mv] with nothing to say.
static func _enchantment(mv: int) -> CardData:
	return CardData.new("Test Enchantment %d" % mv, "{%d}" % mv if mv > 0 else "{0}",
		Mtg.CardType.ENCHANTMENT)


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


# ------------------------------------------------------- Opalescence alone --

func test_opalescence_animates_each_other_non_aura_enchantment() -> void:
	var sphere := put_synthetic(0, _enchantment(3))
	var opal := put_synthetic(0, _opalescence())
	assert_true(sphere.is_creature() and sphere.is_type(Mtg.CardType.ENCHANTMENT),
		"an enchantment creature (in addition to its other types)")
	assert_eq(_pt(sphere), [3, 3], "its mana value")
	assert_false(opal.is_creature(), "\"each OTHER\"")


func test_an_aura_is_not_animated() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var flight := CardInstance.new(CardRegistry.get_card("Flight"), g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[flight.id] = flight
	g._put_on_battlefield(flight, 1, bear)
	put_synthetic(0, _opalescence())
	assert_false(flight.is_creature(), "non-Aura")
	assert_eq(flight.zone, Mtg.Zone.BATTLEFIELD)


func test_a_zero_mana_value_enchantment_is_a_zero_zero_and_dies() -> void:
	var nothing := put_synthetic(0, _enchantment(0))
	put_synthetic(0, _opalescence())
	g.check_state_based_actions()
	assert_eq(nothing.zone, Mtg.Zone.GRAVEYARD, "a 0/0 creature (CR 704.5f)")


func test_two_opalescences_animate_each_other() -> void:
	var first := put_synthetic(0, _opalescence())
	var second := put_synthetic(1, _opalescence())
	assert_true(first.is_creature() and second.is_creature())
	assert_eq(_pt(first), [4, 4])
	assert_eq(_pt(second), [4, 4])


# --------------------------------------- CR 613.6 / 613.7: with Humility --

func test_humility_older_than_opalescence() -> void:
	var bear := put_battlefield(0, "Serra Angel")
	var sphere := put_synthetic(0, _enchantment(3))
	var humility := put_synthetic(1, _humility())
	var opal := put_synthetic(1, _opalescence())
	assert_true(humility.is_creature(), "Opalescence made Humility a creature (layer 4)")
	assert_true(humility.cur_abilities_silenced, "and Humility humbled itself (layer 6)")
	assert_eq(_pt(humility), [4, 4], "7b: Humility's 1/1, then Opalescence's 4/4")
	assert_eq(_pt(sphere), [3, 3], "the other enchantment: its mana value")
	assert_eq(_pt(bear), [1, 1], "an ordinary creature: Humility's 1/1 still applies (CR 613.6)")
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_false(opal.is_creature())


func test_opalescence_older_than_humility() -> void:
	var bear := put_battlefield(0, "Serra Angel")
	var sphere := put_synthetic(0, _enchantment(3))
	put_synthetic(1, _opalescence())
	var humility := put_synthetic(1, _humility())
	assert_eq(_pt(humility), [1, 1], "every creature 1/1, Humility included")
	assert_eq(_pt(sphere), [1, 1])
	assert_eq(_pt(bear), [1, 1])
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING))


func test_two_opalescences_then_humility_nothing_dies() -> void:
	var sphere := put_synthetic(0, _enchantment(3))
	var bear := put_battlefield(0, "Grizzly Bears")
	var first := put_synthetic(0, _opalescence())
	var second := put_synthetic(1, _opalescence())
	var humility := put_synthetic(1, _humility())
	g.check_state_based_actions()
	for inst in [sphere, bear, first, second, humility]:
		assert_eq(inst.zone, Mtg.Zone.BATTLEFIELD, "%s survives" % inst.data.card_name)
		assert_eq(_pt(inst), [1, 1], "%s: Humility is the newest 7b effect" % inst.data.card_name)
	assert_true(first.cur_abilities_silenced and second.cur_abilities_silenced)


func test_humility_then_two_opalescences() -> void:
	var sphere := put_synthetic(0, _enchantment(3))
	var bear := put_battlefield(0, "Grizzly Bears")
	var humility := put_synthetic(1, _humility())
	var first := put_synthetic(0, _opalescence())
	var second := put_synthetic(1, _opalescence())
	g.check_state_based_actions()
	assert_eq(_pt(humility), [4, 4])
	assert_eq(_pt(first), [4, 4], "the second Opalescence sizes the first (CR 613.6)")
	assert_eq(_pt(second), [4, 4], "and the first the second")
	assert_eq(_pt(sphere), [3, 3])
	assert_eq(_pt(bear), [1, 1])


func test_humility_between_two_opalescences() -> void:
	var sphere := put_synthetic(0, _enchantment(3))
	var bear := put_battlefield(0, "Grizzly Bears")
	var first := put_synthetic(0, _opalescence())
	var humility := put_synthetic(1, _humility())
	var second := put_synthetic(1, _opalescence())
	assert_eq(_pt(first), [4, 4], "sized by the newer Opalescence")
	assert_eq(_pt(humility), [4, 4])
	assert_eq(_pt(sphere), [3, 3])
	assert_eq(_pt(second), [1, 1], "only the older Opalescence sized it, before Humility")
	assert_eq(_pt(bear), [1, 1])


func test_a_static_without_a_key_on_a_silenced_source_stays_off() -> void:
	# The pre-Pack-10 answer for an UNKEYED pair, kept for any card that
	# does not declare its halves: a silenced source's 7b static is skipped.
	var sphere := put_synthetic(0, _enchantment(3))
	var humility := put_synthetic(1, _humility(false))
	put_synthetic(1, _opalescence(false))
	assert_eq(_pt(humility), [4, 4])
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(_pt(bear), [2, 2], "Humility's unkeyed 1/1 never started in 7b")
	assert_eq(_pt(sphere), [3, 3])


func test_leaving_and_undo_round_trip() -> void:
	var bear := put_battlefield(0, "Serra Angel")
	put_synthetic(1, _opalescence())
	var humility := put_synthetic(1, _humility())
	var mark := g.make_mark()
	g.destroy(humility)
	assert_eq(_pt(bear), [4, 4])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	g.unmake_to(mark)
	g.end_search()
	g.recalculate()
	assert_eq(_pt(bear), [1, 1])
	assert_eq(_pt(humility), [1, 1])


func test_the_same_answers_under_the_1997_rules() -> void:
	g.rules.set_edition("fifth")
	var bear := put_battlefield(0, "Grizzly Bears")
	var humility := put_synthetic(1, _humility())
	put_synthetic(1, _opalescence())
	assert_eq(_pt(humility), [4, 4])
	assert_eq(_pt(bear), [1, 1])


# ---------------------------------------------- the shipped Humility card --

func test_the_pack_9_humility_older_than_opalescence() -> void:
	CardPacks.set_enabled("pack-9", true)
	var bear := put_battlefield(0, "Grizzly Bears")
	var humility := put_battlefield(1, "Humility")
	put_synthetic(1, _opalescence())
	assert_eq(_pt(humility), [4, 4])
	assert_eq(_pt(bear), [1, 1], "its 1/1 continues after it humbled itself (CR 613.6)")


func test_the_pack_9_humility_newer_than_opalescence() -> void:
	CardPacks.set_enabled("pack-9", true)
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _opalescence())
	var humility := put_battlefield(1, "Humility")
	assert_eq(_pt(humility), [1, 1])
	assert_eq(_pt(bear), [1, 1])
