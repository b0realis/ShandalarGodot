extends GameTest
## Pack 8 engine package E6 — the COST VOCABULARY the Mirage block prints.
##
## Every capability is pinned on SYNTHETIC cards built in this file, so the
## mechanism is tested apart from any one card script (the card agents'
## own tests quote the oracle text):
##   * N_bounce_cost       — "Return a Forest you control to its owner's
##     hand:" (object-cost op `return`), "Return this enchantment to its
##     owner's hand:" (ActivatedAbility.with_return_cost), and the spell's
##     additional "return X Swamps" (Infernal Harvest);
##   * N_x_object_cost     — a group whose count IS the announced X;
##   * N_exile_object_cost — "Exile a card from your hand:" (chosen) and
##     "Exile the top [creature] card of your graveyard:" (positional,
##     never a choice);
##   * N_hand_cost         — "Discard your hand" and "sacrifice all
##     permanents you control";
##   * N_alt_cost          — CardData.with_alternative_cost, the printed
##     mana cost (and so the mana value) kept, CR 118.9;
##   * N_life_per_target   — "costs 3 life more to cast for each target";
##   * N_mana_per_turn     — ManaAbility.per_turn + a put-a-counter cost;
##   * N_mana_instant_only — ManaAbility.as_instant (Lion's Eye Diamond);
##   * N_cu_custom         — CumulativeUpkeep with a non-mana payment and
##     the "doesn't pay" event.
## CR 601.2b/f/h, 602.2b: costs are announced, validated before anything
## moves, and paid as the spell or ability goes on the stack.

const OC := preload("res://engine/additional_object_costs.gd")
const ALLIANCES_TACTICS := preload("res://engine/ai/alliances_tactics.gd")


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ----------------------------------------------------------------- helpers --

func _card_in(pid: int, data: CardData, zone: int) -> CardInstance:
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.HAND: g.players[pid].hand.append(inst)
		Mtg.Zone.GRAVEYARD: g.players[pid].graveyard.append(inst)
		Mtg.Zone.LIBRARY: g.players[pid].library.append(inst)
	return inst


func _named_in(pid: int, card_name: String, zone: int) -> CardInstance:
	return _card_in(pid, CardRegistry.get_card(card_name), zone)


static func _is_forest(c: CardInstance) -> bool:
	return c.has_subtype("forest")

static func _is_island(c: CardInstance) -> bool:
	return c.has_subtype("island")

static func _is_swamp(c: CardInstance) -> bool:
	return c.has_subtype("swamp")

static func _is_mountain(c: CardInstance) -> bool:
	return c.has_subtype("mountain")

static func _creature_card(c: CardInstance) -> bool:
	return c.data.is_creature()

static func _black_card(c: CardInstance) -> bool:
	return (c.data.color_mask() & Mtg.ManaColor.B) != 0


## Quirion Ranger's shape: "Return a Forest you control to its owner's
## hand: Untap target creature. Activate only once each turn."
func _ranger() -> CardData:
	var ability := ActivatedAbility.new("", false, [UntapEffect.new(TargetSpec.creature())],
		"Return a Forest you control to its owner's hand: Untap target creature.") \
		.with_object_cost(OC.returning("a Forest you control", _is_forest)).per_turn(1)
	return CardData.new("Synthetic Ranger", "{G}", Mtg.CardType.CREATURE).pt(1, 1) \
		.activated(ability).oracle("Return a Forest you control to its owner's hand: Untap target creature. Activate only once each turn.")


## Gossamer Chains' shape: "Return this enchantment to its owner's hand: ..."
func _chains() -> CardData:
	var ability := ActivatedAbility.new("", false, [PumpEffect.new(1, 1)],
		"Return this enchantment to its owner's hand: Target creature gets +1/+1 until end of turn.") \
		.with_return_cost()
	ability.effects[0].target_spec = TargetSpec.creature()
	return CardData.new("Synthetic Chains", "{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ability).oracle("Return this enchantment to its owner's hand: Target creature gets +1/+1 until end of turn.")


## Flooded Shoreline's shape: "{U}{U}, Return two Islands you control to
## their owner's hand: Return target creature to its owner's hand."
func _shoreline() -> CardData:
	var ability := ActivatedAbility.new("{U}{U}", false, [ReturnToHandEffect.new(TargetSpec.creature())],
		"{U}{U}, Return two Islands you control to their owner's hand: Return target creature to its owner's hand.") \
		.with_object_cost(OC.returning("an Island you control", _is_island, 2))
	return CardData.new("Synthetic Shoreline", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.activated(ability).oracle("...")


## Infernal Harvest's shape: "As an additional cost to cast this spell,
## return X Swamps you control to their owner's hand. ~ deals X damage to
## target creature." (one target here; the division is TargetPlan's.)
func _harvest() -> CardData:
	return CardData.new("Synthetic Harvest", "{1}{B}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(0).x_damage().target_creature()) \
		.with_object_cost(OC.times_x(OC.returning("a Swamp you control", _is_swamp))) \
		.oracle("As an additional cost to cast this spell, return X Swamps you control to their owner's hand.")


# ------------------------------------------------------------ N_bounce_cost --

func test_return_cost_is_paid_on_activation_before_the_ability_resolves() -> void:
	var ranger := put_synthetic(0, _ranger())
	var forest := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	bear.tapped = true
	assert_ok(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))
	# CR 602.2b: the Forest is back in hand while the ability is on the stack.
	assert_eq(forest.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(forest))
	assert_eq(g.stack.size(), 1)
	assert_true(bear.tapped, "nothing resolved yet")
	resolve_stack()
	assert_false(bear.tapped)
	# "Activate only once each turn."
	put_battlefield(0, "Forest")
	assert_refused(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]), "once")


func test_return_cost_refuses_without_an_eligible_permanent_and_moves_nothing() -> void:
	var ranger := put_synthetic(0, _ranger())
	var island := put_battlefield(0, "Island")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.stack.is_empty())
	# An OPPONENT's Forest is not "a Forest you control".
	put_battlefield(1, "Forest")
	assert_refused(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))


func test_a_tapped_land_still_pays_a_return_cost() -> void:
	# The Quirion Ranger trick: tap the Forest for {G}, then return it.
	var ranger := put_synthetic(0, _ranger())
	var forest := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.tap_for_mana(0, forest))
	assert_ok(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))
	assert_eq(forest.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)


func test_return_this_permanent_cost_bounces_the_source_and_the_ability_still_resolves() -> void:
	var chains := put_synthetic(0, _chains())
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, chains, 0, [TargetRef.card(bear)]))
	assert_eq(chains.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(chains))
	resolve_stack()
	assert_eq(bear.cur_power, 3)
	# The source left (CR 400.7): it cannot be activated again from hand.
	assert_refused(g.activate_ability(0, chains, 0, [TargetRef.card(bear)]))


func test_return_two_islands_needs_two_distinct_islands() -> void:
	var shore := put_synthetic(0, _shoreline())
	var island := put_battlefield(0, "Island")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, shore, 0, [TargetRef.card(bear)]))
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2, "a refused cost pays nothing")
	var second := put_battlefield(0, "Island")
	assert_ok(g.activate_ability(0, shore, 0, [TargetRef.card(bear)]))
	assert_eq(island.zone, Mtg.Zone.HAND)
	assert_eq(second.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)


func test_a_human_chooses_which_forest_returns_and_nothing_moves_while_asked() -> void:
	var ranger := put_synthetic(0, _ranger())
	var first := put_battlefield(0, "Forest")
	var second := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	bear.tapped = true
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))
	assert_not_null(g.awaiting_choice)
	assert_true(g.awaiting_choice.is_cost)
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(second.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.stack.is_empty())
	assert_ok(g.answer_choice(second.id))
	assert_null(g.awaiting_choice)
	assert_eq(second.zone, Mtg.Zone.HAND)
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 1)


# ---------------------------------------------------------- N_x_object_cost --

func test_x_swamps_returned_as_an_additional_cost() -> void:
	var swamps: Array[CardInstance] = []
	for i in 3:
		swamps.append(put_battlefield(0, "Swamp"))
	var wurm := put_battlefield(1, "Craw Wurm")
	var harvest := _card_in(0, _harvest(), Mtg.Zone.HAND)
	assert_true(harvest.data.cost.has_x, "X is announced although no {X} is printed")
	assert_eq(harvest.data.cost.mana_value(), 2, "the mana value is the printed {1}{B}")
	add_mana(0, Mtg.ManaColor.B, 2)
	# X=4 with three Swamps: refused before a single mana is spent.
	assert_refused(g.cast_spell(0, harvest, [TargetRef.card(wurm)], 4))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 2)
	assert_eq(harvest.zone, Mtg.Zone.HAND)
	assert_ok(g.cast_spell(0, harvest, [TargetRef.card(wurm)], 3))
	for s in swamps:
		assert_eq(s.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq(wurm.damage, 3)


func test_x_zero_returns_nothing() -> void:
	var swamp := put_battlefield(0, "Swamp")
	var bear := put_battlefield(1, "Grizzly Bears")
	var harvest := _card_in(0, _harvest(), Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, harvest, [TargetRef.card(bear)], 0))
	assert_eq(swamp.zone, Mtg.Zone.BATTLEFIELD)


func test_x_exile_creature_cards_from_graveyard_and_x_discards() -> void:
	# Haunting Misery: exile X creature cards from your graveyard.
	var misery := CardData.new("Synthetic Misery", "{1}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(0).x_damage().target_player()) \
		.with_object_cost(OC.times_x(OC.exiling(Mtg.Zone.GRAVEYARD, "a creature card", _creature_card))) \
		.oracle("...")
	var a := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var b := _named_in(0, "Craw Wurm", Mtg.Zone.GRAVEYARD)
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	var spell := _card_in(0, misery, Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, spell, [TargetRef.player(1)], 3))
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 2))
	assert_eq(a.zone, Mtg.Zone.EXILE)
	assert_eq(b.zone, Mtg.Zone.EXILE)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	# Firestorm: discard X cards — the spell itself is never one of them.
	var storm := CardData.new("Synthetic Storm", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(0).x_damage().target_player()) \
		.with_object_cost(OC.times_x(OC.discarding("a card"))).oracle("...")
	var fire := _card_in(0, storm, Mtg.Zone.HAND)
	var junk := give_hand(0, "Forest")
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_refused(g.cast_spell(0, fire, [TargetRef.player(1)], 2), "")
	assert_ok(g.cast_spell(0, fire, [TargetRef.player(1)], 1))
	assert_eq(junk.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(fire.zone, Mtg.Zone.STACK)


func test_max_x_reports_the_object_bound() -> void:
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var harvest := _card_in(0, _harvest(), Mtg.Zone.HAND)
	assert_eq(OC.max_x(g, 0, harvest.data.object_costs, harvest), 2)
	assert_eq(OC.max_x(g, 0, [OC.returning("a Swamp", _is_swamp)], harvest), -1,
		"no X group: unbounded")


# ------------------------------------------------------- N_exile_object_cost --

func test_exile_the_top_creature_card_is_positional_and_never_asked() -> void:
	# Necratog / Zombie Scavengers: "Exile the top creature card of your
	# graveyard:" — the TOP one, not a choice.
	var tog := CardData.new("Synthetic Tog", "{1}{B}{B}", Mtg.CardType.CREATURE).pt(1, 2) \
		.activated(ActivatedAbility.new("", false, [PumpEffect.new(2, 2).self_buff()], "...") \
			.with_object_cost(OC.exiling_top("creature card", _creature_card))).oracle("...")
	var creature := put_synthetic(0, tog)
	var lower := _named_in(0, "Craw Wurm", Mtg.Zone.GRAVEYARD)
	var upper := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var top := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.activate_ability(0, creature, 0))
	assert_null(g.awaiting_choice, "a positional cost asks nothing")
	assert_eq(upper.zone, Mtg.Zone.EXILE, "the topmost CREATURE card goes")
	assert_eq(lower.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(top.zone, Mtg.Zone.GRAVEYARD)
	assert_ok(g.activate_ability(0, creature, 0))
	assert_eq(lower.zone, Mtg.Zone.EXILE)
	assert_refused(g.activate_ability(0, creature, 0), "")
	resolve_stack()
	assert_eq(creature.cur_power, 5)


func test_exile_the_top_card_of_your_graveyard_any_type() -> void:
	# Alms / Nature's Kiss: "{1}, Exile the top card of your graveyard:".
	var alms := CardData.new("Synthetic Alms", "{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("{1}", false, [GainLifeEffect.new(1)], "...") \
			.with_object_cost(OC.exiling_top("card"))).oracle("...")
	var source := put_synthetic(0, alms)
	var under := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var top := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	_named_in(1, "Craw Wurm", Mtg.Zone.GRAVEYARD)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, source, 0))
	assert_eq(top.zone, Mtg.Zone.EXILE)
	assert_eq(under.zone, Mtg.Zone.GRAVEYARD)


func test_exile_a_card_from_hand_pays_a_mana_ability() -> void:
	# Cadaverous Bloom: "Exile a card from your hand: Add {B}{B} or {G}{G}."
	var bloom := CardData.new("Synthetic Bloom", "{3}{B}{G}", Mtg.CardType.ENCHANTMENT) \
		.mana(ManaAbility.new(Mtg.ManaColor.B, 2).without_tap() \
			.with_object_cost(OC.exiling(Mtg.Zone.HAND, "a card"))) \
		.oracle("...")
	var source := put_synthetic(0, bloom)
	assert_refused(g.tap_for_mana(0, source, 0), "")
	var card := give_hand(0, "Grizzly Bears")
	assert_ok(g.tap_for_mana(0, source, 0))
	assert_eq(card.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 2)
	# Not an automatic source: the planner never spends a card for mana.
	for row in ManaPlanner.sources(g, 0):
		assert_ne(row[0], source)


# --------------------------------------------------------------- N_hand_cost --

func test_discard_your_hand_and_sacrifice_this_pays_even_with_an_empty_hand() -> void:
	# Lion's Eye Diamond: "Discard your hand, Sacrifice this artifact: Add
	# three mana of any one color. Activate only as an instant."
	var led := CardData.new("Synthetic Diamond", "{0}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.R, 3).without_tap().with_sacrifice() \
			.with_object_cost(OC.discard_hand()).as_instant()).oracle("...")
	var diamond := put_synthetic(0, led)
	var a := give_hand(0, "Grizzly Bears")
	var b := give_hand(0, "Lightning Bolt")
	assert_ok(g.tap_for_mana(0, diamond, 0))
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(diamond.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 3)
	var empty := put_synthetic(0, led)
	assert_true(g.players[0].hand.is_empty())
	assert_ok(g.tap_for_mana(0, empty, 0))   # an empty hand can still be discarded


func test_sacrifice_all_and_discard_hand_as_a_spells_additional_cost() -> void:
	# Kaervek's Spite: the spell itself is never discarded, everything
	# else goes, all of it before the spell is on the stack.
	var spite := CardData.new("Synthetic Spite", "{B}{B}{B}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(5).target_player()) \
		.with_object_cost(OC.sacrifice_all()).with_object_cost(OC.discard_hand()) \
		.oracle("...")
	var swamp := put_battlefield(0, "Swamp")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var keep := give_hand(0, "Lightning Bolt")
	var spell := _card_in(0, spite, Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(keep.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(spell.zone, Mtg.Zone.STACK)
	resolve_stack()
	assert_eq(g.players[1].life, 15)


# ---------------------------------------------------------------- N_alt_cost --

func _fireblast() -> CardData:
	return CardData.new("Synthetic Fireblast", "{4}{R}{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(4).any_target()) \
		.with_alternative_cost("Sacrifice two Mountains",
			{"object_costs": [OC.sacrificing("a Mountain", _is_mountain, 2)]}) \
		.oracle("You may sacrifice two Mountains rather than pay this spell's mana cost.")


func test_alternative_cost_sacrifices_instead_of_mana_and_keeps_the_mana_value() -> void:
	var blast := _card_in(0, _fireblast(), Mtg.Zone.HAND)
	assert_eq(blast.data.cost.mana_value(), 6, "CR 118.9: the mana cost is unchanged")
	assert_eq(blast.data.modes.size(), 2)
	var m1 := put_battlefield(0, "Mountain")
	assert_refused(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 1))
	assert_eq(m1.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(blast.zone, Mtg.Zone.HAND)
	var m2 := put_battlefield(0, "Mountain")
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 1))
	assert_eq(m1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(m2.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 16)


func test_the_printed_cost_row_still_pays_mana_and_sacrifices_nothing() -> void:
	var blast := _card_in(0, _fireblast(), Mtg.Zone.HAND)
	var m1 := put_battlefield(0, "Mountain")
	var m2 := put_battlefield(0, "Mountain")
	assert_refused(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 0), "mana")
	add_mana(0, Mtg.ManaColor.R, 6)
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 0))
	assert_eq(m1.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(m2.zone, Mtg.Zone.BATTLEFIELD)


func test_a_human_picks_the_alternative_costs_mountains() -> void:
	var blast := _card_in(0, _fireblast(), Mtg.Zone.HAND)
	var m1 := put_battlefield(0, "Mountain")
	var m2 := put_battlefield(0, "Mountain")
	var m3 := put_battlefield(0, "Mountain")
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 1))
	assert_not_null(g.awaiting_choice)
	assert_eq(blast.zone, Mtg.Zone.HAND)
	assert_ok(g.answer_choice(m3.id))
	assert_not_null(g.awaiting_choice)
	assert_ok(g.answer_choice(m1.id))
	assert_null(g.awaiting_choice)
	assert_eq(m3.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(m1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(m2.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(blast.zone, Mtg.Zone.STACK)


func test_alternative_cost_exiling_the_top_three_black_cards() -> void:
	# Spinning Darkness: the top THREE BLACK cards, in graveyard order.
	var darkness := CardData.new("Synthetic Darkness", "{4}{B}{B}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(3).target_creature()) \
		.with_alternative_cost("Exile the top three black cards of your graveyard",
			{"object_costs": [OC.exiling_top("black card", _black_card, 3)]}).oracle("...")
	var deep := _named_in(0, "Dark Ritual", Mtg.Zone.GRAVEYARD)
	var b1 := _named_in(0, "Dark Ritual", Mtg.Zone.GRAVEYARD)
	var red := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := _card_in(0, darkness, Mtg.Zone.HAND)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)], 0, 1))
	assert_eq(spell.zone, Mtg.Zone.HAND)
	var b2 := _named_in(0, "Terror", Mtg.Zone.GRAVEYARD)
	var b3 := _named_in(0, "Terror", Mtg.Zone.GRAVEYARD)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)], 0, 1))
	for c in [b1, b2, b3]:
		assert_eq(c.zone, Mtg.Zone.EXILE)
	assert_eq(deep.zone, Mtg.Zone.GRAVEYARD, "only the TOP three black cards")
	assert_eq(red.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- N_life_per_target --

func test_life_per_target_is_paid_for_every_target() -> void:
	# Phyrexian Purge: "This spell costs 3 life more to cast for each target."
	var purge := CardData.new("Synthetic Purge", "{2}{B}{R}", Mtg.CardType.SORCERY) \
		.spell(DestroyEffect.new(TargetSpec.creature()).one_or_more()) \
		.with_life_per_target(3).oracle("...")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Craw Wurm")
	var spell := _card_in(0, purge, Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.R, 2)
	g.players[0].life = 5
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(a), TargetRef.card(b)]), "life")
	assert_eq(g.players[0].life, 5)
	g.players[0].life = 6
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(a), TargetRef.card(b)]))
	assert_eq(g.players[0].life, 0, "CR 119.4: life may be paid down to exactly 0")


# ------------------------------------------------- N_mana_per_turn / instant --

func _roots() -> CardData:
	return CardData.new("Synthetic Roots", "{1}{G}", Mtg.CardType.CREATURE).pt(0, 5) \
		.mana(ManaAbility.new(Mtg.ManaColor.G).without_tap() \
			.with_put_counter_cost("-0/-1").per_turn(1)).oracle("...")


func test_once_each_turn_mana_ability_with_a_put_counter_cost() -> void:
	var roots := put_synthetic(0, _roots())
	roots.summoning_sick = true
	assert_ok(g.tap_for_mana(0, roots, 0))   # no {T}: usable while summoning sick
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(int(roots.counters.get("-0/-1", 0)), 1)
	assert_eq(roots.cur_toughness, 4)
	assert_refused(g.tap_for_mana(0, roots, 0), "once")
	assert_false(g.mana_ability_ready(roots, 0))
	for row in ManaPlanner.sources(g, 0):
		assert_ne(row[0], roots, "a spent once-a-turn source is not planned")
	advance_to_next_turn()
	assert_true(g.mana_ability_ready(roots, 0))
	assert_ok(g.tap_for_mana(0, roots, 0))
	assert_eq(roots.cur_toughness, 3)


func test_instant_only_mana_needs_priority_and_is_never_planned() -> void:
	var led := CardData.new("Synthetic Diamond", "{0}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.G, 3).without_tap().with_sacrifice() \
			.with_object_cost(OC.discard_hand()).as_instant()).oracle("...")
	var diamond := put_synthetic(0, led)
	for row in ManaPlanner.sources(g, 0):
		assert_ne(row[0], diamond, "an instant-speed mana ability is never auto-tapped")
	# Without priority (the opponent holds it) it can't be activated.
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	assert_refused(g.tap_for_mana(0, diamond, 0), "instant")
	assert_eq(diamond.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------- N_cu_custom --

func _advance_to_own_upkeep() -> void:
	advance_to_next_turn()
	advance_to_next_turn()


func test_custom_cumulative_upkeep_draws_a_card_per_age_counter() -> void:
	var vortex := CumulativeUpkeep.attach_draw(
		CardData.new("Synthetic Vortex", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT).oracle("..."))
	var source := put_synthetic(0, vortex)
	var hand_before := g.players[0].hand.size()
	_advance_to_own_upkeep()
	assert_eq(source.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(source.counters.get("age", 0)), 1)
	# One for the draw step and one for the upkeep payment.
	assert_eq(g.players[0].hand.size(), hand_before + 2)


func test_custom_cumulative_upkeep_puts_counters_on_itself() -> void:
	var aboroth := CumulativeUpkeep.attach_self_counter(
		CardData.new("Synthetic Aboroth", "{4}{G}{G}", Mtg.CardType.CREATURE).pt(9, 9).oracle("..."),
		"-1/-1")
	var source := put_synthetic(0, aboroth)
	_advance_to_own_upkeep()
	assert_eq(int(source.counters.get("-1/-1", 0)), 1)
	_advance_to_own_upkeep()
	assert_eq(int(source.counters.get("age", 0)), 2)
	assert_eq(int(source.counters.get("-1/-1", 0)), 3, "1 + 2 for two age counters")
	assert_eq(source.cur_toughness, 6)


func test_declining_a_cumulative_upkeep_fires_the_unpaid_event_before_the_sacrifice() -> void:
	# Heart of Bogardan: "When a player doesn't pay this enchantment's
	# cumulative upkeep, ..." — heard through the unpaid event.
	var heard: Array = []
	var trig := TriggeredAbility.new(Mtg.EventType.CUMULATIVE_UPKEEP_UNPAID,
		func(game: MtgGame, _s: CardInstance, event: GameEvent) -> void:
			heard.append(int(event.data.ages))
			game.adjust_life(1 - int(event.data.player), -int(event.data.ages) * 2),
		"When a player doesn't pay this enchantment's cumulative upkeep, ...",
		func(_game: MtgGame, s: CardInstance, event: GameEvent) -> bool:
			return event.data.instance == s)
	var heart := CumulativeUpkeep.attach(
		CardData.new("Synthetic Heart", "{2}{R}{R}", Mtg.CardType.ENCHANTMENT).triggered(trig).oracle("..."),
		"{2}")
	var source := put_synthetic(0, heart)
	_advance_to_own_upkeep()   # nothing to pay {2} with: unpaid
	resolve_stack()
	assert_eq(source.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(heard, [1])
	assert_eq(g.players[1].life, 18)


func test_the_ai_hint_pays_a_self_counter_upkeep_only_while_it_survives() -> void:
	var aboroth := CumulativeUpkeep.attach_self_counter(
		CardData.new("Synthetic Aboroth", "{4}{G}{G}", Mtg.CardType.CREATURE).pt(9, 3).oracle("..."),
		"-1/-1")
	var source := put_synthetic(0, aboroth)
	var payment := CumulativeUpkeep.self_counter_payment("-1/-1")
	assert_true(CumulativeUpkeep.payment_hint(g, source, 0, 2, payment), "3 toughness survives two -1/-1")
	assert_false(CumulativeUpkeep.payment_hint(g, source, 0, 3, payment), "three would kill it")
	var draw := CumulativeUpkeep.draw_payment()
	assert_true(CumulativeUpkeep.payment_hint(g, source, 0, 2, draw))
	g.players[0].library.resize(3)
	assert_false(CumulativeUpkeep.payment_hint(g, source, 0, 2, draw), "a thin library declines")


# ------------------------------------------------------------ AI pricing --

func test_the_ai_prices_every_new_object_cost_operation() -> void:
	var ai := AiPlayer.new(0)
	g.set_agent(0, ai)
	var ranger := put_synthetic(0, _ranger())
	put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Lightning Bolt")
	_named_in(0, "Craw Wurm", Mtg.Zone.GRAVEYARD)
	var returning := ALLIANCES_TACTICS.object_price(g, ai, ranger, [OC.returning("a Forest", _is_forest)])
	assert_true(is_finite(returning) and returning > 0.0)
	var top := ALLIANCES_TACTICS.object_price(g, ai, ranger, [OC.exiling_top("creature card", _creature_card)])
	assert_true(is_finite(top) and top < returning, "a graveyard card is cheap")
	var hand := ALLIANCES_TACTICS.object_price(g, ai, ranger, [OC.discard_hand()])
	assert_gt(hand, 0.0)
	var everything := ALLIANCES_TACTICS.object_price(g, ai, ranger, [OC.sacrifice_all()])
	assert_gt(everything, ai._own_value(g, bear))
	assert_eq(ALLIANCES_TACTICS.object_price(g, ai, ranger,
		[OC.times_x(OC.returning("a Forest", _is_forest))], 2), INF, "one Forest cannot pay X=2")



# --------------------------------------------------------------------- undo --

func test_return_and_exile_costs_round_trip_through_the_search_journal() -> void:
	var ranger := put_synthetic(0, _ranger())
	var forest := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	_named_in(0, "Craw Wurm", Mtg.Zone.GRAVEYARD)
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))
	assert_eq(forest.zone, Mtg.Zone.HAND)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.players[0].battlefield.has(forest))
	assert_false(g.players[0].hand.has(forest))
	assert_true(g.stack.is_empty())
	assert_eq(int(ranger.ability_uses.get(0, 0)), 0)


# ------------------------------------------------- the journal, field-exact --
# The same differ tests/ai/test_undo_log.gd uses: every mutable field
# GameSnapshot knows, captured, the move made with the journal on, unmade,
# and compared — a field a new path writes without journaling shows up by
# name.

func _capture() -> Array:
	var snap := GameSnapshot.take(g)
	var out: Array = []
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var props: Array = snap._props[i]
		var values: Array = snap._values[i]
		var k := 0
		for group in [props[0], props[1]]:
			for name in group:
				if name != &"undo_log" and name != &"journal":
					out.append([obj, name, _deep(values[k])])
				k += 1
	out.append([g.rng, &"state", g.rng.state])
	snap.restore()
	return out


static func _deep(value: Variant) -> Variant:
	var t := typeof(value)
	if t == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	if t == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if t >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value


func _drift(before: Array) -> Array:
	var bad: Array = []
	for row in before:
		var obj: Object = row[0]
		var name: StringName = row[1]
		if not _same(obj.get(name), row[2]):
			bad.append("%s.%s" % [obj.get_script().get_global_name(), name])
	return bad


static func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	if ta != typeof(b):
		return false
	if ta == TYPE_ARRAY:
		var aa := a as Array
		var bb := b as Array
		if aa.size() != bb.size():
			return false
		for i in aa.size():
			if not _same(aa[i], bb[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY:
		var ad := a as Dictionary
		var bd := b as Dictionary
		if ad.size() != bd.size():
			return false
		for k in ad:
			if not bd.has(k) or not _same(ad[k], bd[k]):
				return false
		return true
	return a == b


func _round_trips(move: Callable, what: String) -> void:
	var before := _capture()
	var mark := g.make_mark()
	move.call()
	var mark_size := g.undo_log.size()
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "%s left state behind" % what)
	assert_gt(mark_size, mark, "%s recorded nothing — is the move happening?" % what)
	g.end_search()


func _resolve_all() -> void:
	while not g.stack.is_empty():
		g._resolve_top()
	g.check_state_based_actions()


func test_every_new_cost_round_trips_field_exact() -> void:
	# Fireblast's alternative cost.
	var blast := _card_in(0, _fireblast(), Mtg.Zone.HAND)
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	_round_trips(func() -> void:
		assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 1))
		_resolve_all(), "alternative cost")
	# Infernal Harvest's X Swamps.
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var bear := put_battlefield(1, "Grizzly Bears")
	var harvest := _card_in(0, _harvest(), Mtg.Zone.HAND)
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.B, 2)
		assert_ok(g.cast_spell(0, harvest, [TargetRef.card(bear)], 2))
		_resolve_all(), "x object cost")
	# Wall of Roots: the once-a-turn count and the counter.
	var roots := put_synthetic(0, _roots())
	_round_trips(func() -> void:
		assert_ok(g.tap_for_mana(0, roots, 0)), "per-turn mana with a counter cost")
	# Lion's Eye Diamond: the hand and the source.
	var led := CardData.new("Synthetic Diamond", "{0}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.R, 3).without_tap().with_sacrifice() \
			.with_object_cost(OC.discard_hand()).as_instant()).oracle("...")
	var diamond := put_synthetic(0, led)
	give_hand(0, "Lightning Bolt")
	_round_trips(func() -> void:
		assert_ok(g.tap_for_mana(0, diamond, 0)), "discard your hand")
	# Gossamer Chains' return-this cost.
	var chains := put_synthetic(0, _chains())
	_round_trips(func() -> void:
		assert_ok(g.activate_ability(0, chains, 0, [TargetRef.card(bear)]))
		_resolve_all(), "return this permanent")
	# Necratog's positional graveyard exile.
	_named_in(0, "Craw Wurm", Mtg.Zone.GRAVEYARD)
	var tog := put_synthetic(0, CardData.new("Synthetic Tog", "{1}{B}{B}", Mtg.CardType.CREATURE).pt(1, 2) \
		.activated(ActivatedAbility.new("", false, [PumpEffect.new(2, 2).self_buff()], "...") \
			.with_object_cost(OC.exiling_top("creature card", _creature_card))).oracle("..."))
	_round_trips(func() -> void:
		assert_ok(g.activate_ability(0, tog, 0))
		_resolve_all(), "top-of-graveyard exile")


func test_kaervek_style_costs_and_purge_life_round_trip() -> void:
	var spite := CardData.new("Synthetic Spite", "{B}{B}{B}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(5).target_player()) \
		.with_object_cost(OC.sacrifice_all()).with_object_cost(OC.discard_hand()).oracle("...")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Lightning Bolt")
	var spell := _card_in(0, spite, Mtg.Zone.HAND)
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.B, 3)
		assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
		_resolve_all(), "sacrifice all + discard hand")
	var purge := CardData.new("Synthetic Purge", "{2}{B}{R}", Mtg.CardType.SORCERY) \
		.spell(DestroyEffect.new(TargetSpec.creature()).one_or_more()) \
		.with_life_per_target(3).oracle("...")
	var a := put_battlefield(1, "Grizzly Bears")
	var p := _card_in(0, purge, Mtg.Zone.HAND)
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.B, 2)
		add_mana(0, Mtg.ManaColor.R, 2)
		assert_ok(g.cast_spell(0, p, [TargetRef.card(a)]))
		_resolve_all(), "life per target")


# -------------------------------------- control, re-entry, stacking, rules --

func test_a_stolen_ranger_returns_its_new_controllers_forest() -> void:
	var ranger := put_synthetic(0, _ranger())
	var mine := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Forest")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.change_control(ranger, 1)
	g.priority_player = 1
	assert_ok(g.activate_ability(1, ranger, 0, [TargetRef.card(bear)]))
	assert_eq(theirs.zone, Mtg.Zone.HAND, "\"you control\" is the activator")
	assert_true(g.players[1].hand.has(theirs))
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


func test_a_once_a_turn_mana_source_that_leaves_and_returns_is_a_new_object() -> void:
	var roots := put_synthetic(0, _roots())
	assert_ok(g.tap_for_mana(0, roots, 0))
	assert_false(g.mana_ability_ready(roots, 0))
	g.return_to_hand(roots)
	g.players[0].hand.erase(roots)
	g._put_on_battlefield(roots, 0)
	assert_true(g.mana_ability_ready(roots, 0), "CR 400.7: a new object, a new count")
	assert_eq(int(roots.counters.get("-0/-1", 0)), 0)
	assert_ok(g.tap_for_mana(0, roots, 0))


func test_a_counter_cost_that_kills_still_makes_the_mana_and_is_not_planned() -> void:
	var weak := put_synthetic(0, CardData.new("Synthetic Sprout", "{G}", Mtg.CardType.CREATURE).pt(0, 1) \
		.mana(ManaAbility.new(Mtg.ManaColor.G).without_tap().with_put_counter_cost("-0/-1")).oracle("..."))
	for row in ManaPlanner.sources(g, 0):
		assert_ne(row[0], weak, "the planner never pays a counter that kills its source")
	assert_ok(g.tap_for_mana(0, weak, 0))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(weak.zone, Mtg.Zone.GRAVEYARD)


func test_two_stacked_return_costs_each_pay_their_own_island_pair() -> void:
	var shore := put_synthetic(0, _shoreline())
	var islands: Array[CardInstance] = []
	for i in 4:
		islands.append(put_battlefield(0, "Island"))
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.activate_ability(0, shore, 0, [TargetRef.card(a)]))
	assert_ok(g.activate_ability(0, shore, 0, [TargetRef.card(b)]))
	assert_eq(g.stack.size(), 2)
	for island in islands:
		assert_eq(island.zone, Mtg.Zone.HAND)
	assert_refused(g.activate_ability(0, shore, 0, [TargetRef.card(a)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.HAND)
	assert_eq(b.zone, Mtg.Zone.HAND)


func test_the_x_object_bound_holds_under_both_rules_profiles() -> void:
	for preset in ["modern", "fifth"]:
		g.rules.set_preset(preset)
		var swamp := put_battlefield(0, "Swamp")
		var bear := put_battlefield(1, "Llanowar Elves")
		var harvest := _card_in(0, _harvest(), Mtg.Zone.HAND)
		add_mana(0, Mtg.ManaColor.B, 2)
		assert_refused(g.cast_spell(0, harvest, [TargetRef.card(bear)], 2))
		assert_ok(g.cast_spell(0, harvest, [TargetRef.card(bear)], 1))
		assert_eq(swamp.zone, Mtg.Zone.HAND, preset)
		resolve_stack()
		assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, preset)


func test_the_ai_pays_a_board_wiping_cost_only_for_the_win() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.profile.develops_late = false
	g.set_agent(0, ai)
	for i in 3:
		put_battlefield(0, "Swamp")
	var hill := put_battlefield(0, "Hill Giant")
	# A sorcery-speed Kaervek's Spite, so the main-phase planner weighs it.
	var spite := CardData.new("Synthetic Spite", "{B}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(5).target_player()) \
		.with_object_cost(OC.sacrifice_all()).with_object_cost(OC.discard_hand()).oracle("...")
	var spell := _card_in(0, spite, Mtg.Zone.HAND)
	var price := ALLIANCES_TACTICS.object_price(g, ai, spell, g.spell_object_costs(spell.data, 0))
	assert_gt(price, ai._own_value(g, hill), "the whole board is the price")
	g.players[1].life = 20
	ai._try_cast_best(g)
	assert_eq(spell.zone, Mtg.Zone.HAND, "five life is not worth the board")
	assert_eq(hill.zone, Mtg.Zone.BATTLEFIELD)
	g.players[1].life = 5
	ai._try_cast_best(g)
	assert_eq(spell.zone, Mtg.Zone.STACK, "for the win it is")
	assert_eq(hill.zone, Mtg.Zone.GRAVEYARD)


func test_the_ai_sizes_x_from_the_objects_it_can_pay() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.profile.develops_late = false
	ai.profile.holds_x_burn = 0   # the turn-one hold is a policy, not this test's
	g.set_agent(0, ai)
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	assert_eq(OC.max_x(g, 0, _harvest().object_costs, null), 3, "three Swamps bound X")
	put_battlefield(0, "Plains")
	var hill := put_battlefield(1, "Hill Giant")
	var harvest := _card_in(0, _harvest(), Mtg.Zone.HAND)
	ai._try_cast_best(g)
	assert_eq(harvest.zone, Mtg.Zone.STACK, "X is paid in Swamps, not mana")
	assert_eq(g.stack.back().x_value, 3)
	resolve_stack()
	assert_eq(hill.zone, Mtg.Zone.GRAVEYARD)


func test_a_cost_is_not_a_target_protection_does_not_stop_it() -> void:
	# CR 702.16: protection stops TARGETING; a cost names no target. The
	# ranger's own target still obeys it.
	var ranger := put_synthetic(0, _ranger())   # green source
	var warded := put_synthetic(0, CardData.new("Synthetic Warded Forest", "", Mtg.CardType.LAND) \
		.with_subtypes(["forest"]).with_protection_from(Mtg.ManaColor.G).oracle("..."))
	var shielded := put_synthetic(1, CardData.new("Synthetic Knight", "{W}{W}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_protection_from(Mtg.ManaColor.G).oracle("..."))
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, ranger, 0, [TargetRef.card(shielded)]))
	assert_eq(warded.zone, Mtg.Zone.BATTLEFIELD, "a refused target pays nothing")
	assert_ok(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))
	assert_eq(warded.zone, Mtg.Zone.HAND, "the protected Forest still pays the cost")
