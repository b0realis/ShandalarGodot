extends GameTest
## Pack 10 engine package E3 — TYPE REPLACEMENT (CR 205.1a) and the
## card-type dependency (CR 613.8a).
##
## "It becomes a 2/2 Soldier creature" (the Opal, Veiled, Hidden and
## Lurking enchantments) SETS the card type: the permanent is a creature
## and no longer an enchantment. "This permanent becomes an enchantment"
## (Opal Acrolith, Hidden Stag, Soul Sculptor) is the same the other way,
## and the creature types go with the creature type (205.1a). The engine's
## writers used to ADD types only; [method ContinuousEffects.add_type_change]
## is the one that replaces them, stamped on the layer-4 clock with the
## animations and the type-changing statics (CR 613.7), and Opalescence —
## which decides by card type whom it animates — applies after every one
## of them whatever the timestamps (CR 613.8a-b).

const D := ContinuousEffects.Duration


static func _enchantment(card_name := "Test Opal", cost := "{1}{W}") -> CardData:
	return CardData.new(card_name, cost, Mtg.CardType.ENCHANTMENT)


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


static func _opalescence() -> CardData:
	return CardData.new("Test Opalescence", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_opal_types, "Each other non-Aura enchantment is a creature.") \
			.reading_card_types().part_of(&"opalescence")) \
		.static_ability(StaticAbility.new(_opal_size, "... base power and toughness equal to its mana value.") \
			.setting_base_pt().part_of(&"opalescence"))


static func _any_creature(_g: MtgGame, _s: CardInstance, inst: CardInstance) -> bool:
	return inst.is_creature()


static func _humility() -> CardData:
	return CardData.new("Test Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.removing_all_abilities(_any_creature,
			"All creatures lose all abilities.").part_of(&"humility")) \
		.static_ability(StaticAbility.base_pt_for(_any_creature, 1, 1,
			"All creatures have base power and toughness 1/1.").part_of(&"humility"))


## "It becomes a P/T <subtype> creature" — the Opal family's two halves.
func _becomes_creature(inst: CardInstance, power: int, toughness: int,
		subtypes: Array = ["soldier"]) -> void:
	g.continuous.add_type_change(inst.id,
		{"set_types": Mtg.CardType.CREATURE, "set_subtypes": subtypes})
	g.continuous.add_until_eot_base_pt(inst.id, power, toughness, false, D.INDEFINITE)
	g.recalculate()


func _becomes_enchantment(inst: CardInstance) -> void:
	g.continuous.add_type_change(inst.id, {"set_types": Mtg.CardType.ENCHANTMENT})
	g.recalculate()


func _enchant(pid: int, card_name: String, host: CardInstance) -> CardInstance:
	var aura := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	g._put_on_battlefield(aura, pid, host)
	return aura


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


# --------------------------------------------------- CR 205.1a: replacing --

func test_becomes_a_creature_is_no_longer_an_enchantment() -> void:
	var opal := put_synthetic(0, _enchantment())
	_becomes_creature(opal, 2, 2)
	assert_true(opal.is_creature())
	assert_false(opal.is_type(Mtg.CardType.ENCHANTMENT), "the card type is REPLACED (CR 205.1a)")
	assert_eq(Array(opal.cur_subtypes), ["soldier"])
	assert_eq(_pt(opal), [2, 2])


func test_becomes_an_enchantment_drops_the_creature_and_its_creature_types() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_becomes_enchantment(bear)
	assert_false(bear.is_creature())
	assert_true(bear.is_type(Mtg.CardType.ENCHANTMENT))
	assert_true(bear.cur_subtypes.is_empty(), "its creature types went with the creature type")


func test_a_land_creature_that_becomes_an_enchantment_is_no_land() -> void:
	var factory := put_battlefield(0, "Mishra's Factory")
	g.continuous.add_until_eot_animation(factory.id,
		Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT, 2, 2, ["assembly-worker"])
	g.recalculate()
	_becomes_enchantment(factory)
	assert_eq(factory.cur_types, Mtg.CardType.ENCHANTMENT, "the later effect replaces all three")
	assert_false(factory.has_subtype("assembly-worker"))


func test_a_set_subtype_replaces_only_its_own_kind() -> void:
	var forest := put_battlefield(0, "Forest")
	g.continuous.add_type_change(forest.id, {"set_types": Mtg.CardType.LAND | Mtg.CardType.CREATURE,
		"set_subtypes": ["soldier"]})
	g.recalculate()
	assert_true(forest.has_subtype("forest"), "a land type stays with the land type")
	assert_true(forest.has_subtype("soldier"))
	assert_true(forest.is_land() and forest.is_creature())


func test_retaining_the_old_types_adds() -> void:
	var opal := put_synthetic(0, _enchantment())
	g.continuous.add_type_change(opal.id, {"set_types": Mtg.CardType.CREATURE,
		"set_subtypes": ["spirit"], "retain_types": true})
	g.recalculate()
	assert_true(opal.is_creature() and opal.is_type(Mtg.CardType.ENCHANTMENT),
		"\"in addition to its other types\" (CR 205.1b)")
	assert_true(opal.has_subtype("spirit"))


# ------------------------------------------------------- CR 613.7 clock --

func test_the_later_type_change_wins_and_older_ones_are_pruned() -> void:
	var acrolith := put_synthetic(0, _enchantment("Test Acrolith", "{2}{W}"))
	_becomes_creature(acrolith, 2, 4)
	_becomes_enchantment(acrolith)
	assert_false(acrolith.is_creature(), "{0}: becomes an enchantment")
	assert_false(acrolith.has_subtype("soldier"))
	_becomes_creature(acrolith, 2, 4)
	assert_true(acrolith.is_creature())
	assert_eq(_pt(acrolith), [2, 4])
	var mine := 0
	for change in g.continuous._type_changes:
		if int(change["instance_id"]) == acrolith.id:
			mine += 1
	assert_eq(mine, 1, "an indefinite full set makes every older one moot")


func test_an_animation_newer_than_the_change_adds_on_top() -> void:
	var opal := put_synthetic(0, _enchantment())
	_becomes_creature(opal, 2, 2)
	g.continuous.add_until_eot_animation(opal.id, Mtg.CardType.ARTIFACT, 3, 3)
	g.recalculate()
	assert_true(opal.is_creature() and opal.is_type(Mtg.CardType.ARTIFACT))
	assert_false(opal.is_type(Mtg.CardType.ENCHANTMENT))


func test_an_animation_older_than_the_change_is_overridden() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_animation(bear.id, Mtg.CardType.ARTIFACT, 3, 3)
	g.recalculate()
	_becomes_enchantment(bear)
	assert_eq(bear.cur_types, Mtg.CardType.ENCHANTMENT)


func test_living_lands_and_a_type_change_either_way() -> void:
	var older := put_battlefield(0, "Forest")
	put_battlefield(1, "Living Lands")
	_becomes_enchantment(older)
	var newer := put_battlefield(0, "Forest")
	_becomes_enchantment(newer)
	put_battlefield(1, "Living Lands")
	for forest in [older, newer]:
		assert_eq(forest.cur_types, Mtg.CardType.ENCHANTMENT, "no longer a Forest to animate")
		assert_false(forest.has_subtype("forest"))


func test_humility_and_an_opal_settle_the_size_by_timestamp() -> void:
	var late := put_synthetic(0, _enchantment("Test Late Opal"))
	var early := put_synthetic(0, _enchantment("Test Early Opal"))
	_becomes_creature(early, 3, 3)
	put_synthetic(1, _humility())
	_becomes_creature(late, 3, 3)
	assert_eq(_pt(early), [1, 1], "animated before Humility: its 1/1 is newer")
	assert_eq(_pt(late), [3, 3], "animated after Humility: printed size (CR 613.7)")
	assert_true(late.cur_abilities_silenced, "still a creature that lost its abilities")


# --------------------------------------- CR 613.8a: the card-type reader --

func test_becomes_an_enchantment_under_an_older_opalescence() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _opalescence())
	_becomes_enchantment(bear)
	assert_true(bear.is_type(Mtg.CardType.ENCHANTMENT) and bear.is_creature(),
		"Opalescence depends on the type change and applies after it (CR 613.8a)")
	assert_eq(_pt(bear), [2, 2], "its mana value")
	assert_false(bear.has_subtype("bear"))


func test_becomes_an_enchantment_under_a_newer_opalescence() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_becomes_enchantment(bear)
	put_synthetic(1, _opalescence())
	assert_true(bear.is_type(Mtg.CardType.ENCHANTMENT) and bear.is_creature())
	assert_eq(_pt(bear), [2, 2])


func test_an_opal_under_opalescence_before_and_after_it_becomes_a_creature() -> void:
	var opal := put_synthetic(0, _enchantment("Test Archangel", "{4}{W}"))
	put_synthetic(1, _opalescence())
	assert_true(opal.is_creature() and opal.is_type(Mtg.CardType.ENCHANTMENT))
	assert_eq(_pt(opal), [5, 5], "dormant: an enchantment creature, its mana value")
	_becomes_creature(opal, 5, 5, ["angel"])
	assert_false(opal.is_type(Mtg.CardType.ENCHANTMENT), "no longer an enchantment")
	assert_eq(_pt(opal), [5, 5])
	var small := put_synthetic(0, _enchantment("Test Caryatid", "{W}"))
	assert_eq(_pt(small), [1, 1])
	_becomes_creature(small, 2, 2)
	assert_eq(_pt(small), [2, 2], "Opalescence no longer sizes what is not an enchantment")


func test_opalescence_arriving_after_the_change_leaves_the_creature_alone() -> void:
	var opal := put_synthetic(0, _enchantment())
	_becomes_creature(opal, 2, 2)
	put_synthetic(1, _opalescence())
	assert_false(opal.is_type(Mtg.CardType.ENCHANTMENT))
	assert_eq(_pt(opal), [2, 2])


# ------------------------------------------- what reads the new type --

func test_an_aura_for_creatures_falls_off_what_became_an_enchantment() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var flight := _enchant(0, "Flight", bear)
	_becomes_enchantment(bear)
	g.check_state_based_actions()
	assert_eq(flight.zone, Mtg.Zone.GRAVEYARD, "enchant creature: illegal (CR 704.5m)")


func test_an_aura_for_enchantments_falls_off_an_opal_creature() -> void:
	var opal := put_synthetic(0, _enchantment())
	var feedback := _enchant(1, "Feedback", opal)
	assert_eq(feedback.zone, Mtg.Zone.BATTLEFIELD, "precondition")
	_becomes_creature(opal, 2, 2)
	g.check_state_based_actions()
	assert_eq(feedback.zone, Mtg.Zone.GRAVEYARD, "enchant enchantment: illegal now")


func test_disenchant_follows_the_live_type() -> void:
	var opal := put_synthetic(1, _enchantment())
	var bear := put_battlefield(1, "Grizzly Bears")
	_becomes_creature(opal, 2, 2)
	_becomes_enchantment(bear)
	advance_to_step(Mtg.Step.MAIN1)
	var first := give_hand(0, "Disenchant")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_refused(g.cast_spell(0, first, [TargetRef.card(opal)]))
	assert_ok(g.cast_spell(0, first, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_a_creature_that_becomes_an_enchantment_leaves_combat() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_true(g.combat.attackers.has(bear.id))
	_becomes_enchantment(bear)
	g.check_state_based_actions()
	assert_false(g.combat.attackers.has(bear.id), "no longer a creature (CR 506.4)")


func test_a_clone_copies_the_printed_enchantment() -> void:
	var opal := put_synthetic(1, _enchantment())
	_becomes_creature(opal, 2, 2)
	var clone := give_hand(0, "Clone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, clone, []))
	resolve_stack()
	assert_eq(clone.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(clone.data.card_name, "Test Opal")
	assert_false(clone.is_creature(), "copiable values are the printed ones (CR 707.2)")
	assert_true(clone.is_type(Mtg.CardType.ENCHANTMENT))


# ---------------------------------------------------------- durations --

func test_cleanup_and_a_control_change_keep_it() -> void:
	var opal := put_synthetic(0, _enchantment())
	_becomes_creature(opal, 2, 2)
	g.continuous.expire_until_eot()
	g.continuous.expire_end_of_combat()
	g.change_control(opal, 1)
	g.recalculate()
	assert_true(opal.is_creature())
	assert_eq(_pt(opal), [2, 2])


func test_leaving_the_battlefield_ends_it() -> void:
	var opal := put_synthetic(0, _enchantment())
	_becomes_creature(opal, 2, 2)
	g.return_to_hand(opal)
	assert_eq(opal.zone, Mtg.Zone.HAND)
	assert_true(opal.is_type(Mtg.CardType.ENCHANTMENT))
	assert_false(opal.is_creature())
	for change in g.continuous._type_changes:
		assert_ne(int(change["instance_id"]), opal.id, "a new object (CR 400.7)")


func test_a_phased_out_permanent_is_not_changed() -> void:
	var opal := put_synthetic(0, _enchantment())
	g.phase_out(opal)
	g.continuous.add_type_change(opal.id, {"set_types": Mtg.CardType.CREATURE})
	assert_true(g.continuous._type_changes.is_empty(), "CR 702.26e")


func test_undo_restores_the_enchantment() -> void:
	var opal := put_synthetic(0, _enchantment())
	var mark := g.make_mark()
	_becomes_creature(opal, 2, 2)
	assert_true(opal.is_creature())
	g.unmake_to(mark)
	g.end_search()
	g.recalculate()
	assert_false(opal.is_creature())
	assert_true(g.continuous._type_changes.is_empty())


func test_the_ai_reader_sees_an_indefinite_creature() -> void:
	var factory := put_battlefield(0, "Mishra's Factory")
	g.continuous.add_until_eot_animation(factory.id,
		Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT, 2, 2, ["assembly-worker"])
	assert_true(g.continuous.creature_until_end_of_turn(factory.id), "regression: an EOT animation")
	var opal := put_synthetic(0, _enchantment())
	_becomes_creature(opal, 2, 2)
	g.continuous.add_until_eot_animation(opal.id, Mtg.CardType.CREATURE, 4, 4)
	assert_false(g.continuous.creature_until_end_of_turn(opal.id),
		"an indefinite type change keeps it a creature after the turn")


func test_the_same_answers_under_the_1997_rules() -> void:
	g.rules.set_edition("fifth")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _opalescence())
	_becomes_enchantment(bear)
	assert_true(bear.is_creature() and bear.is_type(Mtg.CardType.ENCHANTMENT))


# ------------------------- a grant kept in a live field, on the 6 clock --

static func _grounded(game: MtgGame, _source: CardInstance, id: int, stamp: int) -> void:
	var body := game.find_instance(id)
	if body != null and body.zone == Mtg.Zone.BATTLEFIELD \
			and not game.continuous.ability_removed_since(body, stamp):
		body.cur_cant_attack = true


func _ground(inst: CardInstance) -> void:
	var stamp := g.continuous.next_timestamp()
	g.continuous.add_floating_static(inst, StaticAbility.new(_grounded.bind(inst.id, stamp),
		"This creature can't attack."), D.INDEFINITE, -1, false, inst.id)
	g.recalculate()


func test_a_live_field_grant_survives_an_older_humility() -> void:
	var opal := put_synthetic(0, _enchantment())
	put_synthetic(1, _humility())
	_becomes_creature(opal, 4, 4, ["serpent"])
	_ground(opal)
	assert_true(opal.cur_cant_attack, "granted after Humility: kept (CR 613.7)")


func test_a_live_field_grant_falls_to_a_newer_humility() -> void:
	var opal := put_synthetic(0, _enchantment())
	_becomes_creature(opal, 4, 4, ["serpent"])
	_ground(opal)
	assert_true(opal.cur_cant_attack, "precondition")
	put_synthetic(1, _humility())
	assert_false(opal.cur_cant_attack, "Humility is the newer layer-6 effect")
