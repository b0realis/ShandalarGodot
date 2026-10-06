extends GameTest
## Pack 9 (the Tempest block), batch B4: the fourteen vanilla and
## keyword-only Tempest creatures of cards/sets/tmp/_basic.gd. Their whole
## Oracle text is printed characteristics, so each test pins the printed
## body and the one rule its keyword brings to the table — and the refused
## side of it (the blocker that may not block, the spell that may not
## target, the ability that does not exist).

## name -> [power, toughness, keywords, landwalk, artifact]
const BODIES := {
	"Bayou Dragonfly": [1, 1, [Mtg.Keyword.FLYING], ["swamp"], false],
	"Benthic Behemoth": [7, 6, [], ["island"], false],
	"Canopy Spider": [1, 3, [Mtg.Keyword.REACH], [], false],
	"Canyon Wildcat": [2, 1, [], ["mountain"], false],
	"Coiled Tinviper": [2, 1, [Mtg.Keyword.FIRST_STRIKE], [], true],
	"Fighting Drake": [2, 4, [Mtg.Keyword.FLYING], [], false],
	"Heartwood Treefolk": [3, 4, [], ["forest"], false],
	"Lightning Elemental": [4, 1, [Mtg.Keyword.HASTE], [], false],
	"Lowland Giant": [4, 3, [], [], false],
	"Metallic Sliver": [1, 1, [], [], true],
	"Phyrexian Hulk": [5, 4, [], [], true],
	"Rootbreaker Wurm": [6, 6, [Mtg.Keyword.TRAMPLE], [], false],
	"Sky Spirit": [2, 2, [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE], [], false],
	"Trained Armodon": [3, 3, [], [], false],
}


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _pending(c: CardData) -> bool:
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"

## P0 attacks with [param attacker]; leaves the game at the declare
## blockers step, P1 to declare.
func _attack(attacker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_every_basic_name_is_claimed_and_carries_only_its_printed_body() -> void:
	for card_name in BODIES:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_false(_pending(c), "%s is still pending" % card_name)
		assert_eq(c.set_code, "tmp", card_name)
		var row: Array = BODIES[card_name]
		var inst := put_battlefield(0, card_name)
		assert_eq([inst.cur_power, inst.cur_toughness], [row[0], row[1]], card_name)
		for keyword in row[2]:
			assert_true(inst.has_keyword(int(keyword)), "%s has %s" % [card_name, Mtg.Keyword.keys()[keyword]])
		assert_eq(inst.cur_keywords.size(), (row[2] as Array).size(), "%s has no other keyword" % card_name)
		assert_eq(inst.cur_landwalk, (row[3] as Array), card_name)
		assert_eq(inst.is_type(Mtg.CardType.ARTIFACT), bool(row[4]), card_name)
		assert_true(inst.is_creature(), card_name)
		assert_eq(inst.cur_activated_abilities.size(), 0, "%s has no activated ability" % card_name)
		assert_eq(c.triggered_abilities.size(), 0, card_name)
		assert_eq(c.static_abilities.size(), 0, card_name)


func test_a_vanilla_creature_casts_for_its_cost_and_has_nothing_to_activate() -> void:
	var armodon := give_hand(0, "Trained Armodon")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, armodon), "mana")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(0, armodon))
	resolve_stack()
	assert_eq(armodon.zone, Mtg.Zone.BATTLEFIELD)
	var giant := put_battlefield(0, "Lowland Giant")
	assert_refused(g.activate_ability(0, giant, 0), "no such ability")


func test_fighting_drake_flies_over_ground_and_canopy_spider_reaches_it() -> void:
	var drake := put_battlefield(0, "Fighting Drake")
	var bear := put_battlefield(1, "Grizzly Bears")
	var spider := put_battlefield(1, "Canopy Spider")
	_attack(drake)
	assert_refused(g.declare_blockers(1, {bear.id: drake.id}))
	assert_ok(g.declare_blockers(1, {spider.id: drake.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(spider.damage, 2, "the 1/3 Spider took the Drake's 2 and lived")
	assert_eq(spider.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20)


func test_bayou_dragonfly_swampwalks_past_even_a_reach_blocker() -> void:
	var fly := put_battlefield(0, "Bayou Dragonfly")
	var spider := put_battlefield(1, "Canopy Spider")
	put_battlefield(1, "Swamp")
	_attack(fly)
	assert_refused(g.declare_blockers(1, {spider.id: fly.id}))
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 19)


func test_bayou_dragonfly_can_be_reached_with_no_swamp_around() -> void:
	var fly := put_battlefield(0, "Bayou Dragonfly")
	var spider := put_battlefield(1, "Canopy Spider")
	_attack(fly)
	assert_ok(g.declare_blockers(1, {spider.id: fly.id}))


func test_the_three_landwalkers_need_the_defenders_land() -> void:
	for pair in [["Benthic Behemoth", "Island"], ["Canyon Wildcat", "Mountain"], ["Heartwood Treefolk", "Forest"]]:
		before_each()
		var walker := put_battlefield(0, pair[0])
		var wall := put_battlefield(1, "Wall of Wood")
		put_battlefield(1, pair[1])
		_attack(walker)
		assert_refused(g.declare_blockers(1, {wall.id: walker.id}), "")
		before_each()
		walker = put_battlefield(0, pair[0])
		wall = put_battlefield(1, "Wall of Wood")
		put_battlefield(1, "Plains")
		_attack(walker)
		assert_ok(g.declare_blockers(1, {wall.id: walker.id}))


func test_lightning_elemental_attacks_the_turn_it_arrives_and_a_giant_cannot() -> void:
	var elemental := put_battlefield(0, "Lightning Elemental", true)
	var giant := put_battlefield(0, "Lowland Giant", true)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [giant.id]))
	assert_ok(g.declare_attackers(0, [elemental.id]))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 16)


func test_coiled_tinviper_strikes_first_and_is_an_artifact() -> void:
	var viper := put_battlefield(0, "Coiled Tinviper")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack(viper)
	assert_ok(g.declare_blockers(1, {bear.id: viper.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(viper.zone, Mtg.Zone.BATTLEFIELD, "the Bears died before they could strike back")
	advance_to_step(Mtg.Step.MAIN2)
	var shatter := give_hand(0, "Shatter")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, shatter, [TargetRef.card(viper)]))
	resolve_stack()
	assert_eq(viper.zone, Mtg.Zone.GRAVEYARD)


func test_phyrexian_hulk_and_metallic_sliver_are_artifact_creatures() -> void:
	var hulk := put_battlefield(1, "Phyrexian Hulk")
	var sliver := put_battlefield(1, "Metallic Sliver")
	assert_true(sliver.has_subtype("sliver"))
	assert_true(hulk.has_subtype("golem") and hulk.has_subtype("phyrexian"))
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(hulk)]))
	var shatter := give_hand(0, "Shatter")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, shatter, [TargetRef.card(sliver)]))
	resolve_stack()
	assert_eq(sliver.zone, Mtg.Zone.GRAVEYARD)


func test_rootbreaker_wurm_tramples_over_a_chump() -> void:
	var wurm := put_battlefield(0, "Rootbreaker Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack(wurm)
	assert_ok(g.declare_blockers(1, {bear.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 16, "four of six trample over the 2/2")


func test_sky_spirit_flies_and_strikes_first() -> void:
	var spirit := put_battlefield(0, "Sky Spirit")
	var bear := put_battlefield(1, "Grizzly Bears")
	var spider := put_battlefield(1, "Canopy Spider")
	_attack(spirit)
	assert_refused(g.declare_blockers(1, {bear.id: spirit.id}))
	assert_ok(g.declare_blockers(1, {spider.id: spirit.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(spider.damage, 2)
	assert_eq(spirit.damage, 1)
	assert_eq(spirit.zone, Mtg.Zone.BATTLEFIELD)
