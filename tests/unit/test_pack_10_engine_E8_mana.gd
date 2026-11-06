extends GameTest
## Pack 10 engine package E8 (part 1) — TWO NEW KINDS OF MANA.
##
##  * MANA THAT CAN'T BE SPENT TO CAST SPELLS (Thran Turbine: "you may add
##    {C}{C}. This mana can't be spent to cast spells." — CR 106.6). The
##    pool keeps it under the one INVERSE restriction key,
##    [constant ManaPool.NOT_SPELL]: every payment whose usage keys do not
##    name "spell" may spend it — an activated ability, a mana ability's
##    own mana cost, echo, cumulative upkeep, an "unless pays" — and no
##    spell ever may ([method MtgGame.mana_usage_keys] always names
##    "spell"). It is still mana in the pool: it empties with the step and
##    burns under the mana-burn fork.
##  * A LAND'S MANA OF A FIXED TYPE AND AMOUNT (Contamination: "If a land
##    is tapped for mana, it produces {B} instead of any other type and
##    amount." — CR 106.6, 614.1a, 616.1). A static writes it on each land
##    with [method ManaAbility.replace_land_mana] (colour + amount); the
##    continuous pipeline turns every {T} mana ability of the land into a
##    [method ManaAbility.forcing_color] copy whose output is exactly that
##    many of that colour — a Karoo, a Gaea's Cradle, a Tolarian Academy
##    each make ONE {B}. Triggered extras (Mana Flare, Wild Growth) are
##    separate mana abilities and still add theirs.
## Test-only cards stand in for the real ones (batch B13 builds those).


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ----------------------------------------------------------------- helpers --

static func _your_upkeep(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data.get("player", -1)) == source.controller_id


## Thran Turbine's shape (the optional "may" is the B13 card's business).
static func _turbine() -> CardData:
	return CardData.new("Test Turbine", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _turbine_mana,
			"At the beginning of your upkeep, you may add {C}{C}. This mana can't be spent to cast spells.",
			_your_upkeep)) \
		.oracle("At the beginning of your upkeep, you may add {C}{C}. This mana can't be spent to cast spells.")


static func _turbine_mana(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.players[s.controller_id].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)


static func _engine() -> CardData:
	return CardData.new("Test Engine", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{2}", false, [DrawEffect.new(1)], "{2}: Draw a card.")) \
		.oracle("{2}: Draw a card.")


static func _artifact_spell() -> CardData:
	return CardData.new("Test Trinket", "{2}", Mtg.CardType.ARTIFACT).oracle("")


static func _prism() -> CardData:
	return CardData.new("Test Prism", "{2}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.G, 1).with_mana_cost("{1}")) \
		.oracle("{1}, {T}: Add {G}.")


static func _echo_bear() -> CardData:
	var c := CardData.new("Test Echo Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)
	EchoAbility.attach(c, "{2}")
	return c.oracle("Echo {2}")


static func _aging_wall() -> CardData:
	var c := CardData.new("Test Aging Wall", "{1}", Mtg.CardType.ARTIFACT)
	CumulativeUpkeep.attach(c, "{2}")
	return c.oracle("Cumulative upkeep {2}")


## Contamination's second sentence.
static func _contamination() -> CardData:
	return CardData.new("Test Contamination", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_contaminate,
			"If a land is tapped for mana, it produces {B} instead of any other type and amount.")) \
		.oracle("If a land is tapped for mana, it produces {B} instead of any other type and amount.")


static func _contaminate(g: MtgGame, _s: CardInstance) -> void:
	for land in g.all_battlefield():
		if land.is_land():
			ManaAbility.replace_land_mana(land, Mtg.ManaColor.B, 1)


static func _karoo() -> CardData:
	return CardData.new("Test Karoo", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1).and_also(Mtg.ManaColor.U, 1)) \
		.oracle("{T}: Add {C}{U}.")


static func _cradle() -> CardData:
	return CardData.new("Test Cradle", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.G, 0).with_dynamic_amount(_creatures)) \
		.oracle("{T}: Add {G} for each creature you control.")


static func _creatures(g: MtgGame, s: CardInstance) -> int:
	var n := 0
	for inst in g.players[s.controller_id].battlefield:
		if inst.is_creature(): n += 1
	return n


static func _pump_land() -> CardData:
	return CardData.new("Test Pump Land", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.R, 1).without_tap().with_mana_cost("{1}")) \
		.oracle("{1}: Add {R}.")


func _row_of(inst: CardInstance, pid := 0) -> Array:
	for row in ManaPlanner.sources(g, pid):
		if row[0] == inst:
			return row
	return []


# ------------------------------------------------- mana not for spells --

func test_not_spell_mana_pays_an_activated_ability_first() -> void:
	var engine := put_synthetic(0, _engine())
	add_mana(0, Mtg.ManaColor.C, 1)
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)
	var hand := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, engine, 0, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "the ability resolved")
	assert_eq(g.players[0].mana_pool.restricted_total(ManaPool.NOT_SPELL), 0,
		"the restricted mana went first (it would be wasted otherwise)")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1, "the ordinary mana is left")


func test_not_spell_mana_never_casts_a_spell() -> void:
	var trinket := give_synthetic(0, _artifact_spell())
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)
	assert_false(g.players[0].mana_pool.can_pay(trinket.data.cost, 0, g.mana_usage_keys(trinket.data, trinket)),
		"a spell's usage keys never reach it")
	assert_refused(g.cast_spell(0, trinket, []))
	assert_eq(trinket.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].mana_pool.restricted_total(ManaPool.NOT_SPELL), 2, "nothing was spent")
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.C), 2,
		"but the readout still shows it floating")
	# Ordinary mana casts it and leaves the restricted mana alone.
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, trinket, []))
	assert_eq(g.players[0].mana_pool.restricted_total(ManaPool.NOT_SPELL), 2)


func test_the_planner_counts_it_for_abilities_and_never_for_spells() -> void:
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)
	var two := ManaCost.parse("{2}")
	assert_false(ManaPlanner.plan(g, 0, two, 0, []).is_empty(), "an ability's {2} is covered")
	assert_true(ManaPlanner.plan(g, 0, two, 0, ["spell"]).is_empty(), "a spell's is not")
	assert_true(g.can_afford_cost(0, two))
	assert_false(g.can_afford_cost(0, two, g.mana_usage_keys(_artifact_spell())))
	assert_true(ManaPool.key_usable(ManaPool.NOT_SPELL, ["echo"]))
	assert_false(ManaPool.key_usable(ManaPool.NOT_SPELL, ["spell", "artifact"]))
	assert_true(ManaPool.key_usable("", ["spell"]))
	assert_false(ManaPool.key_usable("artifact", []))


func test_not_spell_mana_pays_a_mana_abilitys_own_mana_cost() -> void:
	var prism := put_synthetic(0, _prism())
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 1, ManaPool.NOT_SPELL)
	assert_ok(g.tap_for_mana(0, prism))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(g.players[0].mana_pool.restricted_total(ManaPool.NOT_SPELL), 0)


func test_not_spell_mana_pays_an_unless_cost() -> void:
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)
	assert_true(EffectBase.unless_paid(g, 0, ManaCost.parse("{2}"), "Pay {2}?"),
		"an \"unless pays\" is no spell")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_not_spell_mana_pays_echo() -> void:
	var bear := put_synthetic(0, _echo_bear())
	var forest := put_battlefield(0, "Forest")
	_next_upkeep_of(0)
	assert_false(g.stack.is_empty(), "the echo trigger waits on the stack")
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "echo was paid")
	assert_false(forest.tapped, "with the restricted mana, not the Forest")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_not_spell_mana_pays_cumulative_upkeep() -> void:
	var wall := put_synthetic(0, _aging_wall())
	_next_upkeep_of(0)
	assert_false(g.stack.is_empty(), "the cumulative upkeep trigger waits")
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "the upkeep was paid")
	assert_eq(int(wall.counters.get("age", 0)), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_turbine_mana_empties_with_the_upkeep_and_burns() -> void:
	g.rules.mana_burn = true
	put_synthetic(0, _turbine())
	_next_upkeep_of(0)
	resolve_stack()
	assert_eq(g.players[0].mana_pool.restricted_total(ManaPool.NOT_SPELL), 2, "{C}{C} floats in the upkeep")
	var life: int = g.players[0].life
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.players[0].mana_pool.total(), 0, "gone when the upkeep ends")
	assert_eq(g.players[0].life, life - 2, "and it burns like any other mana")


func test_not_spell_mana_survives_undo() -> void:
	var engine := put_synthetic(0, _engine())
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, engine, 0, []))
	assert_eq(g.players[0].mana_pool.total(), 0)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[0].mana_pool.restricted_total(ManaPool.NOT_SPELL), 2, "the journal puts it back")


# ------------------------------------------ fixed type AND amount (C5) --

func test_a_karoo_makes_one_black() -> void:
	put_synthetic(0, _contamination())
	var karoo := put_synthetic(0, _karoo())
	g.recalculate()
	assert_ok(g.tap_for_mana(0, karoo))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(g.players[0].mana_pool.total(), 1, "one {B}, not two")


func test_a_cradle_makes_one_black_whatever_it_counts() -> void:
	put_synthetic(0, _contamination())
	var cradle := put_synthetic(0, _cradle())
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_ok(g.tap_for_mana(0, cradle))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(g.players[0].mana_pool.total(), 1, "three creatures, still one {B}")


func test_a_cradle_that_counts_nothing_still_makes_one_black() -> void:
	# "produces {B} instead of any other type and amount": the tap of a land
	# for mana makes {B} — pinned on the literal reading (B13 may revisit).
	put_synthetic(0, _contamination())
	var cradle := put_synthetic(0, _cradle())
	g.recalculate()
	assert_ok(g.tap_for_mana(0, cradle))
	assert_eq(g.players[0].mana_pool.total(), 1)


func test_basic_lands_of_both_players_make_black() -> void:
	put_synthetic(0, _contamination())
	var forest := put_battlefield(0, "Forest")
	var island := put_battlefield(1, "Island")
	g.recalculate()
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.tap_for_mana(1, island))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.B), 1, "the opponent's land too")


func test_the_planner_sees_one_black() -> void:
	put_synthetic(0, _contamination())
	var karoo := put_synthetic(0, _karoo())
	g.recalculate()
	var row := _row_of(karoo)
	assert_false(row.is_empty())
	assert_eq(int(row[2]), Mtg.ManaColor.B)
	assert_eq(int(row[3]), 1)
	assert_true(ManaPlanner.plan(g, 0, ManaCost.parse("{1}{U}"), 0).is_empty(), "no {U} any more")


func test_mana_flare_and_wild_growth_still_add_their_mana() -> void:
	put_synthetic(0, _contamination())
	put_battlefield(1, "Mana Flare")
	var forest := put_battlefield(0, "Forest")
	var growth := put_battlefield(0, "Wild Growth")
	g.attach_aura_from_anywhere(growth, forest, 0)
	g.recalculate()
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 2,
		"the land's {B} and Mana Flare's \"type that land produced\"")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1, "and Wild Growth's {G}")


func test_with_deep_water_every_order_makes_one() -> void:
	# CR 616.1: the land's controller orders the two replacements; whichever
	# applies last names the colour, and Contamination's amount stands in
	# either order — so the two variants are {B} and {U}, one each.
	put_synthetic(0, _contamination())
	var karoo := put_synthetic(0, _karoo())
	var deep := put_battlefield(0, "Deep Water")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, deep, 0, []))
	resolve_stack()
	g.recalculate()
	assert_eq(karoo.cur_mana_abilities.size(), 2, "one variant per final colour")
	var colors: Array = []
	for ability in karoo.cur_mana_abilities:
		colors.append(int(ability.produces[0][0]))
		assert_eq(ability.produces.size(), 1)
		assert_eq(int(ability.produces[0][1]), 1)
	assert_true(colors.has(Mtg.ManaColor.B) and colors.has(Mtg.ManaColor.U))
	var blue := colors.find(Mtg.ManaColor.U)
	assert_ok(g.tap_for_mana(0, karoo, blue))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)
	assert_eq(g.players[0].mana_pool.total(), 1)


func test_a_borrowed_land_keeps_the_fixed_amount() -> void:
	# MtgGame.mana_ability_for (the Piracy path): a player who does not
	# control the land loses Deep Water's controller-only variant and is
	# handed the land-wide replacement — with its fixed amount.
	put_synthetic(0, _contamination())
	var karoo := put_synthetic(0, _karoo())
	var deep := put_battlefield(0, "Deep Water")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, deep, 0, []))
	resolve_stack()
	g.recalculate()
	var deep_index := -1
	for i in karoo.cur_mana_abilities.size():
		if karoo.cur_mana_abilities[i].controller_replacement: deep_index = i
	assert_ne(deep_index, -1)
	var pirate := g.mana_ability_for(1, karoo, deep_index)
	assert_eq(pirate.produces, [[Mtg.ManaColor.B, 1]])


func test_a_mana_source_that_is_no_land_is_untouched() -> void:
	put_synthetic(0, _contamination())
	var ring := put_battlefield(0, "Sol Ring")
	var pump := put_synthetic(0, _pump_land())
	g.recalculate()
	assert_ok(g.tap_for_mana(0, ring))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2, "Sol Ring is no land")
	assert_ok(g.tap_for_mana(0, pump))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1,
		"a land ability that does not tap it is not \"tapped for mana\"")


func test_the_replacement_ends_with_its_source() -> void:
	var contamination := put_synthetic(0, _contamination())
	var karoo := put_synthetic(0, _karoo())
	g.recalculate()
	assert_false(karoo.cur_land_mana_fixed.is_empty())
	g.destroy(contamination)
	g.recalculate()
	assert_true(karoo.cur_land_mana_fixed.is_empty(), "derived every recalculation")
	assert_ok(g.tap_for_mana(0, karoo))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)


func test_forcing_color_with_a_fixed_amount_drops_every_amount_rider() -> void:
	var ability := ManaAbility.new(Mtg.ManaColor.G, 0).with_dynamic_amount(_creatures) \
		.with_any_number_of_counters("charge", 1).and_also(Mtg.ManaColor.U, 2)
	var fixed := ability.forcing_color(Mtg.ManaColor.B, false, false, 1)
	assert_eq(fixed.produces, [[Mtg.ManaColor.B, 1]])
	assert_false(fixed.dynamic_amount.is_valid())
	assert_eq(fixed.any_number_counter_kind, "")
	assert_eq(fixed.forced_output_color, Mtg.ManaColor.B)
	assert_eq(fixed.unreplaced_ability, ability)
	var plain := ability.forcing_color(Mtg.ManaColor.B)
	assert_true(plain.dynamic_amount.is_valid(), "without an amount the old copy is unchanged")


# ------------------------------------------------------------------ helpers --

func _next_upkeep_of(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.turn_number > turn and g.active_player == pid \
			and g.current_step() == Mtg.Step.UPKEEP) and not g.game_over and guard < 800:
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")
