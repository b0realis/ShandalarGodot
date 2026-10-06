extends GameTest
## Pack 9 engine package E5 — LAYERS: "loses all abilities" in timestamp
## order (Humility, CR 613.1f / 613.7), base-P/T setting in timestamp order
## (CR 613.4b), and a characteristic-defining P/T that counts an ability
## (Dauthi Warlord, CR 613.4a after layer 6).
##
## Humility is implemented AS PRINTED (owner ruling 2026-10-06): its
## "lose all abilities" is a layer-6 effect at Humility's own timestamp, so
## an ability granted EARLIER (an Aura already on the creature, a Jump cast
## before it entered) is removed and one granted LATER survives; its 1/1 is
## a layer-7b effect at the same timestamp, so a later "becomes 2/2"
## (Mishra's Factory animated afterwards) wins and an earlier one loses.
## A creature's OWN ability never survives Humility, whatever the order:
## removing it changes the existence of that creature's effect, so Humility
## applies first (CR 613.8a dependency) — Talon Sliver entering after
## Humility still grants nothing.
##
## Every Humility here is SYNTHETIC — the card itself is a Pack 9 script
## written against the API this package lands — built from the two
## statics the card prints, which is the shape `docs/` will name.

const W := Mtg.ManaColor.W


# ------------------------------------------------------------ definitions --

static func _creature_filter(_game: MtgGame, _source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.is_creature()


## "All creatures lose all abilities and have base power and toughness 1/1."
static func _humility() -> CardData:
	return CardData.new("Test Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_humble,
			"All creatures lose all abilities.").silencing_abilities()) \
		.static_ability(StaticAbility.new(_one_one,
			"All creatures have base power and toughness 1/1.").setting_base_pt())


static func _humble(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_abilities_silenced = true


static func _one_one(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_power = 1
			inst.cur_toughness = 1


## A creature lord granting a keyword to every OTHER creature (Talon
## Sliver's shape, "All Slivers have first strike", widened to creatures).
static func _keyword_lord() -> CardData:
	return CardData.new("Test Talon Lord", "{1}{W}", Mtg.CardType.CREATURE).pt(2, 2) \
		.static_ability(StaticAbility.new(_grant_first_strike,
			"Other creatures have first strike.").changing_abilities())


static func _grant_first_strike(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.is_creature() \
				and not inst.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE):
			inst.cur_keywords.append(Mtg.Keyword.FIRST_STRIKE)


## A creature lord pumping every creature (Muscle Sliver's shape).
static func _pump_lord() -> CardData:
	return CardData.new("Test Muscle Lord", "{1}{G}", Mtg.CardType.CREATURE).pt(1, 1) \
		.static_ability(StaticAbility.new(_pump_all, "Creatures get +1/+1."))


static func _pump_all(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_power += 1
			inst.cur_toughness += 1


## An Aura granting +1/+5 (Hero's Resolve's shape).
static func _resolve_aura() -> CardData:
	return CardData.new("Test Resolve", "{1}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_resolve_pump, "Enchanted creature gets +1/+5."))


static func _resolve_pump(game: MtgGame, source: CardInstance) -> void:
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power += 1
		host.cur_toughness += 5


## Dauthi Warlord's shape: "This creature's power is equal to the number of
## creatures on the battlefield with <keyword>" — FLYING here, so the test
## does not wait on Pack 9's shadow keyword (package E1).
static func _counting_lord(keyword: int) -> CardData:
	return CardData.new("Test Warlord", "{1}{B}", Mtg.CardType.CREATURE).pt(0, 1) \
		.static_ability(StaticAbility.new(_count_keyword.bind(keyword),
			"Power is the number of creatures with the keyword.") \
			.setting_base_pt().reading_abilities())


static func _count_keyword(game: MtgGame, source: CardInstance, keyword: int) -> void:
	var count := 0
	for inst in game.all_battlefield():
		if inst.is_creature() and inst.has_keyword(keyword):
			count += 1
	source.cur_power = count


func _enchant(pid: int, data: CardData, host: CardInstance) -> CardInstance:
	var aura := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	g._put_on_battlefield(aura, pid, host)
	return aura


func _enchant_named(pid: int, card_name: String, host: CardInstance) -> CardInstance:
	return _enchant(pid, CardRegistry.get_card(card_name), host)


# ----------------------------------------------- printed abilities go away --

func test_humility_removes_printed_keywords_and_sets_one_one() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	put_synthetic(1, _humility())
	assert_true(angel.cur_abilities_silenced)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "flying is printed: gone")
	assert_false(angel.has_keyword(Mtg.Keyword.VIGILANCE), "vigilance too")
	assert_eq([angel.cur_power, angel.cur_toughness], [1, 1])


func test_humility_removes_printed_protection_and_first_strike() -> void:
	var knight := put_battlefield(0, "White Knight")
	assert_ne(knight.cur_protection, 0, "precondition: protection from black")
	put_synthetic(1, _humility())
	assert_eq(knight.cur_protection, 0, "protection is an ability (CR 702.16)")
	assert_false(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_humility_removes_mana_and_activated_abilities() -> void:
	var elves := put_battlefield(0, "Llanowar Elves")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	put_synthetic(1, _humility())
	assert_true(elves.cur_mana_abilities.is_empty(), "no {T}: Add {G}")
	assert_true(sorcerer.cur_activated_abilities.is_empty(), "no ping")


func test_humility_leaving_gives_everything_back() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var humility := put_synthetic(1, _humility())
	g.destroy(humility)
	assert_false(angel.cur_abilities_silenced)
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([angel.cur_power, angel.cur_toughness], [4, 4])


# --------------------------------------- grants: earlier lost, later kept --

func test_an_aura_attached_before_humility_loses_its_grant() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant_named(0, "Flight", bear)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "precondition")
	put_synthetic(1, _humility())
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING),
		"the Flight is the EARLIER layer-6 effect (CR 613.7)")


func test_an_aura_attached_after_humility_keeps_its_grant() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	_enchant_named(0, "Flight", bear)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING),
		"the Flight is the LATER layer-6 effect (CR 613.7)")
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1])


func test_a_jump_before_humility_is_removed() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.FLYING])
	g.recalculate()
	put_synthetic(1, _humility())
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING))


func test_a_jump_after_humility_survives() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.FLYING])
	g.recalculate()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))


func test_a_protection_grant_before_humility_is_removed_and_after_it_kept() -> void:
	var early := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_protection(early.id, Mtg.ManaColor.R)
	put_synthetic(1, _humility())
	var late := put_battlefield(0, "Hill Giant")
	g.continuous.add_until_eot_protection(late.id, Mtg.ManaColor.R)
	g.recalculate()
	assert_eq(early.cur_protection, 0, "granted before: removed")
	assert_eq(late.cur_protection, Mtg.ManaColor.R, "granted after: kept")


func test_a_granted_activated_ability_follows_the_same_clock() -> void:
	var early := put_battlefield(0, "Grizzly Bears")
	var ability := ActivatedAbility.new("{1}", false, [PumpEffect.new(1, 0).self_buff()],
		"{1}: This creature gets +1/+0 until end of turn.")
	g.continuous.add_granted_activated_ability(early.id, ability)
	put_synthetic(1, _humility())
	var late := put_battlefield(0, "Hill Giant")
	g.continuous.add_granted_activated_ability(late.id, ability)
	g.recalculate()
	assert_false(early.cur_activated_abilities.has(ability), "granted before: removed")
	assert_true(late.cur_activated_abilities.has(ability), "granted after: kept")


func test_a_rampage_grant_follows_the_same_clock() -> void:
	var early := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_rampage(early.id, 2)
	put_synthetic(1, _humility())
	var late := put_battlefield(0, "Hill Giant")
	g.continuous.add_until_eot_rampage(late.id, 2)
	g.recalculate()
	assert_eq(early.cur_rampage, 0)
	assert_eq(late.cur_rampage, 2)


# ---------------------------------------- creatures' own effects: never --

func test_a_keyword_lord_before_humility_grants_nothing() -> void:
	put_synthetic(0, _keyword_lord())
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE), "precondition")
	put_synthetic(1, _humility())
	assert_false(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_a_keyword_lord_after_humility_still_grants_nothing() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	var lord := put_synthetic(0, _keyword_lord())
	assert_true(lord.cur_abilities_silenced)
	assert_false(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE),
		"Humility removes the lord's own ability first (CR 613.8a)")


func test_a_pump_lord_under_humility_leaves_one_ones() -> void:
	var lord := put_synthetic(0, _pump_lord())
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1])
	assert_eq([lord.cur_power, lord.cur_toughness], [1, 1])


func test_a_characteristic_defining_creature_is_one_one_without_flying() -> void:
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var nightmare := put_battlefield(0, "Nightmare")
	assert_eq(nightmare.cur_power, 2, "precondition: two Swamps")
	put_synthetic(1, _humility())
	assert_eq([nightmare.cur_power, nightmare.cur_toughness], [1, 1])
	assert_false(nightmare.has_keyword(Mtg.Keyword.FLYING))


# --------------------------------------------- other layers still apply --

func test_an_aura_pump_still_applies_after_the_one_one() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	_enchant(0, _resolve_aura(), bear)
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 6], "Hero's Resolve: 2/6")


func test_an_aura_pump_older_than_humility_also_applies() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, _resolve_aura(), bear)
	put_synthetic(1, _humility())
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 6],
		"layer 7c follows 7b whatever the timestamps")


func test_an_anthem_and_counters_still_apply() -> void:
	var knight := put_battlefield(0, "White Knight")
	put_battlefield(0, "Crusade")
	put_synthetic(1, _humility())
	g.add_counters(knight, "+1/+1")
	assert_eq([knight.cur_power, knight.cur_toughness], [3, 3], "1/1 +1/+1 +1/+1")


# ------------------------------------------------- layer 7b by timestamp --

func test_a_factory_animated_after_humility_is_two_two_without_abilities() -> void:
	var factory := put_battlefield(0, "Mishra's Factory")
	put_synthetic(1, _humility())
	g.continuous.add_until_eot_animation(factory.id,
		Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT, 2, 2, ["assembly-worker"])
	g.recalculate()
	assert_true(factory.is_creature())
	assert_eq([factory.cur_power, factory.cur_toughness], [2, 2],
		"the animation is the later 7b effect")
	assert_true(factory.cur_mana_abilities.is_empty(), "a creature: no mana ability")
	assert_true(factory.cur_activated_abilities.is_empty())


func test_a_factory_animated_before_humility_is_one_one() -> void:
	var factory := put_battlefield(0, "Mishra's Factory")
	g.continuous.add_until_eot_animation(factory.id,
		Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT, 2, 2, ["assembly-worker"])
	g.recalculate()
	put_synthetic(1, _humility())
	assert_eq([factory.cur_power, factory.cur_toughness], [1, 1])


func test_a_base_pt_set_after_humility_wins() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	g.continuous.add_until_eot_base_pt(bear.id, 0, 2)   # Sorceress Queen
	g.recalculate()
	assert_eq([bear.cur_power, bear.cur_toughness], [0, 2])


func test_a_base_pt_set_before_humility_loses() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_base_pt(bear.id, 0, 2)
	g.recalculate()
	assert_eq([bear.cur_power, bear.cur_toughness], [0, 2], "precondition")
	put_synthetic(1, _humility())
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1], "Humility is the later 7b")


# ------------------------------- creatures made by layer 4 are humbled too --

func test_living_lands_forests_lose_their_mana_ability() -> void:
	var forest := put_battlefield(0, "Forest")
	put_battlefield(1, "Living Lands")
	assert_true(forest.is_creature(), "precondition")
	assert_false(forest.cur_mana_abilities.is_empty(), "precondition: taps for {G}")
	put_synthetic(1, _humility())
	assert_true(forest.cur_abilities_silenced, "a creature after layer 4 (CR 613.1d)")
	assert_true(forest.cur_mana_abilities.is_empty())
	assert_eq([forest.cur_power, forest.cur_toughness], [1, 1])


func test_a_noncreature_is_untouched() -> void:
	var forest := put_battlefield(0, "Forest")
	var ring := put_battlefield(0, "Sol Ring")
	put_synthetic(1, _humility())
	assert_false(forest.cur_abilities_silenced)
	assert_false(ring.cur_abilities_silenced)
	assert_false(ring.cur_mana_abilities.is_empty())


# --------------------------------------------------------- both presets --

func test_the_clock_is_the_same_under_the_1997_rules() -> void:
	g.rules.set_edition("fifth")
	var early := put_battlefield(0, "Grizzly Bears")
	_enchant_named(0, "Flight", early)
	put_synthetic(1, _humility())
	var late := put_battlefield(0, "Hill Giant")
	_enchant_named(0, "Flight", late)
	assert_false(early.has_keyword(Mtg.Keyword.FLYING))
	assert_true(late.has_keyword(Mtg.Keyword.FLYING))


# ------------------------------------------ CDA after layer 6 (Warlord) --

func test_a_cda_counting_an_ability_sees_a_granted_one() -> void:
	var warlord := put_synthetic(0, _counting_lord(Mtg.Keyword.FLYING))
	put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(warlord.cur_power, 1, "the printed flyer")
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.FLYING])
	g.recalculate()
	assert_eq(warlord.cur_power, 2, "a creature that gained flying this turn counts")


func test_a_cda_counting_an_ability_sees_a_static_grant_and_a_loss() -> void:
	var warlord := put_synthetic(0, _counting_lord(Mtg.Keyword.FLYING))
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant_named(0, "Flight", bear)
	assert_eq(warlord.cur_power, 2, "the Aura's flying counts")
	g.continuous.add_until_eot_loss(angel.id, [Mtg.Keyword.FLYING])
	g.recalculate()
	assert_eq(warlord.cur_power, 1, "a flyer that lost flying does not")


func test_a_later_base_pt_set_still_beats_the_cda() -> void:
	var warlord := put_synthetic(0, _counting_lord(Mtg.Keyword.FLYING))
	put_battlefield(1, "Serra Angel")
	g.continuous.add_until_eot_base_pt(warlord.id, 0, 2)
	g.recalculate()
	assert_eq([warlord.cur_power, warlord.cur_toughness], [0, 2],
		"7b after 7a: the Sorceress Queen effect wins")


func test_the_cda_creature_under_humility_is_one_one() -> void:
	var warlord := put_synthetic(0, _counting_lord(Mtg.Keyword.FLYING))
	put_battlefield(1, "Serra Angel")
	put_synthetic(1, _humility())
	assert_eq([warlord.cur_power, warlord.cur_toughness], [1, 1])


# ------------------------------------------- the ready-made statics --

## The two-line Humility the card script uses (StaticAbility's E5 helpers).
static func _humility_from_helpers() -> CardData:
	return CardData.new("Test Helper Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.removing_all_abilities(_creature_filter,
			"All creatures lose all abilities.")) \
		.static_ability(StaticAbility.base_pt_for(_creature_filter, 1, 1,
			"All creatures have base power and toughness 1/1."))


func test_the_ready_made_statics_build_humility() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var ring := put_battlefield(0, "Sol Ring")
	put_synthetic(1, _humility_from_helpers())
	assert_true(angel.cur_abilities_silenced)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([angel.cur_power, angel.cur_toughness], [1, 1])
	assert_false(ring.cur_abilities_silenced, "not a creature")
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant_named(0, "Flight", bear)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "the later grant survives")
	var statics := CardData.new("x").static_ability(
		StaticAbility.removing_all_abilities(_creature_filter, "")).static_abilities
	assert_true(statics[0].silences_abilities)
	assert_false(statics[0].changes_types, "a pure silencer: after layer 4")


# ------------------------------------- two silencers: the later one counts --

func test_a_grant_between_two_silencers_is_removed_by_the_later() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	_enchant_named(0, "Flight", bear)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "after the first: kept")
	put_synthetic(0, _humility())
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING),
		"the second Humility is later than the Flight")


func test_a_kormus_bell_swamp_under_humility_taps_for_nothing() -> void:
	var swamp := put_battlefield(0, "Swamp")
	put_battlefield(1, "Kormus Bell")
	put_synthetic(1, _humility())
	assert_true(swamp.is_creature())
	assert_true(swamp.cur_mana_abilities.is_empty())
	assert_eq([swamp.cur_power, swamp.cur_toughness], [1, 1])


# ------------------------------------------------------------ undo --

func test_undo_restores_the_humbled_board() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var humility := put_synthetic(1, _humility())
	var mark := g.make_mark()
	g.destroy(humility)
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))
	g.unmake_to(mark)
	g.end_search()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([angel.cur_power, angel.cur_toughness], [1, 1])
