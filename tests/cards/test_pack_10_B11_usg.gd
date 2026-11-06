extends GameTest
## Pack 10 (the Urza block), batch B11: the OWN TEXT of the Urza's Saga
## cycling cards (cards/sets/usg/_cycling.gd) — their cycling is pinned by
## test_pack_10_B11_cycling.gd, Fluctuator by test_pack_10_B11_fluctuator.gd.


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## A land that pings ("{T}: 1 damage to any target") — a LAND source.
static func _quarry() -> CardData:
	return CardData.new("Test Quarry", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new("", true, [DamageEffect.new(1).any_target()],
			"{T}: This land deals 1 damage to any target."))


# ------------------------------------------------------------------- white --

func test_clear_destroys_an_enchantment_and_only_an_enchantment() -> void:
	var gloom := put_battlefield(1, "Rune of Protection: Black")
	var bear := put_battlefield(1, "Grizzly Bears")
	var clear := give_hand(0, "Clear")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_refused(g.cast_spell(0, clear, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, clear, [TargetRef.card(gloom)]))
	resolve_stack()
	assert_eq(gloom.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_the_disciples_and_shimmering_barrier_print_their_keywords() -> void:
	var grace := put_battlefield(0, "Disciple of Grace")
	var law := put_battlefield(0, "Disciple of Law")
	var barrier := put_battlefield(0, "Shimmering Barrier")
	assert_true((grace.cur_protection & Mtg.ManaColor.B) != 0)
	assert_eq([grace.cur_power, grace.cur_toughness], [1, 2])
	assert_true((law.cur_protection & Mtg.ManaColor.R) != 0)
	assert_true(barrier.has_keyword(Mtg.Keyword.DEFENDER))
	assert_true(barrier.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq([barrier.cur_power, barrier.cur_toughness], [1, 3])


## P1 acts first (P0 passes its empty-stack priority), then P0 answers
## [param action]'s object on the chain with [param rune]'s {W} shield —
## the moment a Circle-type shield is for: "a source of your choice" is
## named as it resolves, so the source must already be there (CR 608.2).
func _answer_with(rune: CardInstance, action: Callable) -> void:
	if g.priority_player == 0:
		assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	action.call()
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, rune, 0))
	resolve_stack()


func test_a_rune_of_protection_red_stops_a_red_source_answered_on_the_chain() -> void:
	var rune := put_battlefield(0, "Rune of Protection: Red")
	assert_eq(rune.cur_activated_abilities[0].text,
		"{W}: The next time a red source of your choice would deal damage to you this turn, prevent that damage.")
	var bolt := give_hand(1, "Lightning Bolt")
	_answer_with(rune, func() -> void:
		add_mana(1, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)])))
	assert_eq(g.players[0].life, 20, "the red Bolt is prevented")


func test_a_rune_of_protection_red_has_no_colorless_rod_to_name() -> void:
	var rune := put_battlefield(0, "Rune of Protection: Red")
	var rod := put_battlefield(1, "Rod of Ruin")
	_answer_with(rune, func() -> void:
		add_mana(1, Mtg.ManaColor.C, 3)
		assert_ok(g.activate_ability(1, rod, 0, [TargetRef.player(0)])))
	assert_eq(g.players[0].life, 19, "a colorless Rod is no red source")


func test_a_rune_of_protection_artifacts_stops_an_artifact_source() -> void:
	var rune := put_battlefield(0, "Rune of Protection: Artifacts")
	var rod := put_battlefield(1, "Rod of Ruin")
	_answer_with(rune, func() -> void:
		add_mana(1, Mtg.ManaColor.C, 3)
		assert_ok(g.activate_ability(1, rod, 0, [TargetRef.player(0)])))
	assert_eq(g.players[0].life, 20)


func test_a_rune_of_protection_lands_stops_a_land_source() -> void:
	var rune := put_battlefield(0, "Rune of Protection: Lands")
	var quarry := put_synthetic(1, _quarry())
	_answer_with(rune, func() -> void:
		assert_ok(g.activate_ability(1, quarry, 0, [TargetRef.player(0)])))
	assert_eq(g.players[0].life, 20)


func test_each_colored_rune_names_its_color() -> void:
	for row in [["Black", "black"], ["Blue", "blue"], ["Green", "green"], ["White", "white"]]:
		var c := CardRegistry.get_card("Rune of Protection: %s" % row[0])
		var shield: ActivatedAbility = c.activated_abilities[0]
		assert_eq(shield.cost.text, "{W}")
		assert_string_contains(shield.text, "a %s source of your choice" % row[1])
		assert_true(shield.effects[0] is PreventDamageShieldEffect)


func test_gloom_taxes_a_runes_shield_but_not_its_cycling() -> void:
	put_battlefield(1, "Gloom")
	var in_hand := give_hand(0, "Rune of Protection: White")
	var cycling := in_hand.cur_activated_abilities.size() - 1
	var due := g.ability_payment(0, in_hand, cycling)
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 2)
	var on_table := put_battlefield(0, "Rune of Protection: White")
	due = g.ability_payment(0, on_table, 0)
	assert_eq(int(due["cost"].mana_value()) + int(due["extra"]), 4, "{W} plus Gloom's {3}")


# -------------------------------------------------------------------- blue --

func test_drifting_djinn_is_sacrificed_at_upkeep_unless_its_upkeep_is_paid() -> void:
	var djinn := put_battlefield(0, "Drifting Djinn")
	assert_true(djinn.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([djinn.cur_power, djinn.cur_toughness], [5, 5])
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(djinn.zone, Mtg.Zone.GRAVEYARD, "no mana to pay {1}{U}")


func test_drifting_djinn_stays_when_its_upkeep_is_paid() -> void:
	var djinn := put_battlefield(0, "Drifting Djinn")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(djinn.zone, Mtg.Zone.BATTLEFIELD, "the seat paid {1}{U}")


func test_lingering_mirage_makes_the_enchanted_land_an_island() -> void:
	var mountain := put_battlefield(1, "Mountain")
	var mirage := give_hand(0, "Lingering Mirage")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, mirage, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_eq(mirage.attached_to, mountain.id)
	assert_true(mountain.has_subtype("island"))
	assert_false(mountain.has_subtype("mountain"))
	assert_ok(g.tap_for_mana(1, mountain))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.U), 1)


func test_pendrell_drake_and_the_sandbar_pair() -> void:
	var drake := put_battlefield(0, "Pendrell Drake")
	assert_true(drake.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([drake.cur_power, drake.cur_toughness], [2, 3])
	var merfolk := put_battlefield(0, "Sandbar Merfolk")
	assert_eq([merfolk.cur_power, merfolk.cur_toughness], [1, 1])
	var serpent := put_battlefield(0, "Sandbar Serpent")
	assert_eq([serpent.cur_power, serpent.cur_toughness], [3, 4])


func test_power_taint_drains_two_unless_the_enchantments_controller_pays() -> void:
	var gloom := put_battlefield(1, "Gloom")
	var taint := give_hand(0, "Power Taint")
	add_mana(0, Mtg.ManaColor.U, 2)
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.cast_spell(0, taint, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, taint, [TargetRef.card(gloom)]))
	resolve_stack()
	assert_eq(taint.attached_to, gloom.id)
	advance_to_next_turn()   # P1's upkeep: no mana, the 2 life go
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 20, "only the enchanted enchantment's controller")


func test_power_taint_is_paid_off_with_two_open_mana() -> void:
	var gloom := put_battlefield(1, "Gloom")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	var taint := give_hand(0, "Power Taint")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, taint, [TargetRef.card(gloom)]))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(g.players[1].life, 20, "paid {2}")


func test_rescind_returns_any_permanent_to_its_owners_hand() -> void:
	var land := put_battlefield(1, "Mountain")
	var rescind := give_hand(0, "Rescind")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, rescind, [TargetRef.card(land)]))
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.HAND)
	assert_true(g.players[1].hand.has(land))


# ------------------------------------------------------------------- black --

func test_expunge_kills_a_nonblack_nonartifact_creature_for_good() -> void:
	var zombies := put_battlefield(1, "Scathe Zombies")
	var bear := put_battlefield(1, "Grizzly Bears")
	var expunge := give_hand(0, "Expunge")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, expunge, [TargetRef.card(zombies)]))
	assert_ok(g.cast_spell(0, expunge, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	var spec: TargetSpec = CardRegistry.get_card("Expunge").spell_effects[0].target_spec
	assert_false((CardRegistry.get_card("Expunge").spell_effects[0] as DestroyEffect).can_regenerate,
		"it can't be regenerated")
	assert_not_null(spec)


func test_sicken_gives_minus_one_minus_one() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var merfolk := put_battlefield(1, "Sandbar Merfolk")
	var first := give_hand(0, "Sicken")
	var second := give_hand(0, "Sicken")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, first, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1])
	assert_ok(g.cast_spell(0, second, [TargetRef.card(merfolk)]))
	resolve_stack()
	assert_eq(merfolk.zone, Mtg.Zone.GRAVEYARD, "a 1/1 dies")


# --------------------------------------------------------------------- red --

func test_brand_takes_back_every_permanent_you_own() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ring := put_battlefield(0, "Sol Ring")
	var theirs := put_battlefield(1, "Hill Giant")
	g.change_control(bear, 1)
	g.change_control(ring, 1)
	assert_eq(bear.controller_id, 1)
	var brand := give_hand(0, "Brand")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, brand))
	resolve_stack()
	assert_eq(bear.controller_id, 0)
	assert_eq(ring.controller_id, 0)
	assert_eq(theirs.controller_id, 1, "not what the opponent owns")


func test_lay_waste_and_scrap_destroy_a_land_and_an_artifact() -> void:
	var land := put_battlefield(1, "Mountain")
	var ring := put_battlefield(1, "Sol Ring")
	var waste := give_hand(0, "Lay Waste")
	var scrap := give_hand(0, "Scrap")
	add_mana(0, Mtg.ManaColor.R, 7)
	assert_refused(g.cast_spell(0, scrap, [TargetRef.card(land)]))
	assert_ok(g.cast_spell(0, waste, [TargetRef.card(land)]))
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_ok(g.cast_spell(0, scrap, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------------- green --

func test_hush_destroys_all_enchantments_and_nothing_else() -> void:
	var gloom := put_battlefield(1, "Gloom")
	var rune := put_battlefield(0, "Rune of Protection: Red")
	var ring := put_battlefield(1, "Sol Ring")
	var hush := give_hand(0, "Hush")
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.cast_spell(0, hush))
	resolve_stack()
	assert_eq(gloom.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(rune.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)


func test_lull_prevents_all_combat_damage_this_turn() -> void:
	var lull := give_hand(0, "Lull")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, lull))
	resolve_stack()
	assert_true(g.combat_damage_prevented)
	var bear := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id])
	assert_eq(g.players[1].life, 20)


func test_rejuvenate_gains_six_life() -> void:
	var rejuvenate := give_hand(0, "Rejuvenate")
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.cast_spell(0, rejuvenate))
	resolve_stack()
	assert_eq(g.players[0].life, 26)


func test_wild_dogs_go_to_the_player_with_the_most_life() -> void:
	var dogs := put_battlefield(0, "Wild Dogs")
	assert_eq([dogs.cur_power, dogs.cur_toughness], [2, 1])
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(dogs.controller_id, 0, "equal life: nothing triggers")
	g.players[1].life = 25
	advance_to_next_turn()
	assert_eq(dogs.controller_id, 0, "only at ITS CONTROLLER's upkeep")
	advance_to_next_turn()
	assert_eq(dogs.controller_id, 1, "the player with the most life")
	g.players[0].life = 30
	advance_to_next_turn()
	assert_eq(dogs.controller_id, 0, "and back again at its new controller's upkeep")


func test_wild_dogs_recheck_the_lives_as_the_trigger_resolves() -> void:
	var dogs := put_battlefield(0, "Wild Dogs")
	g.players[1].life = 25
	advance_to_next_turn()
	# Walk to P0's upkeep, the trigger on the stack.
	var guard := 0
	while not (g.active_player == 0 and g.current_step() == Mtg.Step.UPKEEP \
			and not g.stack.is_empty()) and guard < 200:
		_advance_once()
		guard += 1
	assert_false(g.stack.is_empty(), "the intervening if held as the upkeep began")
	g.players[1].life = 20   # equal again before it resolves (CR 603.4)
	resolve_stack()
	assert_eq(dogs.controller_id, 0)
