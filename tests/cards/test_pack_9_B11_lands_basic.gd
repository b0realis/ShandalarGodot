extends GameTest
## Pack 9 (the Tempest block), batch B11: the Exodus lands and mana of
## cards/sets/exo/_lands_mana.gd (City of Traitors, Workhorse) and the
## keyword-only creatures of cards/sets/exo/_basic.gd (Mirri, Cat Warrior;
## Paladin en-Vec; Sabertooth Wyvern; Standing Troops).

const CLAIMED := ["City of Traitors", "Workhorse", "Mirri, Cat Warrior", "Paladin en-Vec",
	"Sabertooth Wyvern", "Standing Troops"]

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func test_claimed_cards_are_no_longer_pending() -> void:
	for name in CLAIMED:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)


# --- City of Traitors -------------------------------------------------------------

func test_city_of_traitors_taps_for_two_colorless() -> void:
	var city := put_battlefield(0, "City of Traitors")
	assert_ok(g.tap_for_mana(0, city))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)
	assert_true(city.tapped)

func test_city_of_traitors_is_sacrificed_when_you_play_another_land() -> void:
	var city := give_hand(0, "City of Traitors")
	assert_ok(g.play_land(0, city))
	assert_true(g.stack.is_empty(), "playing the City itself is not another land")
	advance_to_next_turn()
	advance_to_next_turn()
	var forest := give_hand(0, "Forest")
	assert_ok(g.play_land(0, forest))
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(city.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)

func test_city_of_traitors_ignores_an_opponents_land_and_a_land_put_onto_the_battlefield() -> void:
	var city := put_battlefield(0, "City of Traitors")
	var put := give_hand(0, "Forest")
	g.put_from_hand_into_play(put, 0)   # put, not played (CR 305.4)
	assert_true(g.stack.is_empty())
	advance_to_next_turn()   # P1's turn
	var theirs := give_hand(1, "Forest")
	assert_ok(g.play_land(1, theirs))
	assert_true(g.stack.is_empty())
	assert_eq(city.zone, Mtg.Zone.BATTLEFIELD)

func test_city_of_traitors_mana_can_be_used_in_response() -> void:
	var city := put_battlefield(0, "City of Traitors")
	var forest := give_hand(0, "Forest")
	assert_ok(g.play_land(0, forest))
	assert_ok(g.tap_for_mana(0, city))   # mana abilities with the trigger waiting
	resolve_stack()
	assert_eq(city.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)


# --- Workhorse ----------------------------------------------------------------------

func test_workhorse_enters_with_four_counters_and_spends_them_for_mana() -> void:
	var horse := put_battlefield(0, "Workhorse", true)
	assert_eq(int(horse.counters.get("+1/+1", 0)), 4)
	assert_eq([horse.cur_power, horse.cur_toughness], [4, 4])
	assert_ok(g.tap_for_mana(0, horse))   # no {T}: summoning sickness does not matter
	assert_false(horse.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)
	assert_eq([horse.cur_power, horse.cur_toughness], [3, 3])
	for n in 3:
		assert_ok(g.tap_for_mana(0, horse))
	g.check_state_based_actions()
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 4)
	assert_eq(horse.zone, Mtg.Zone.GRAVEYARD, "a 0/0 with its counters spent")

func test_workhorse_dies_paying_its_last_counter_and_the_mana_stays() -> void:
	# The engine recalculates after a mana ability's counter cost and checks
	# state-based actions outside a payment (CR 704.3): a 0/0 Workhorse is gone.
	var horse := put_battlefield(0, "Workhorse")
	g.remove_counters(horse, "+1/+1", 3)
	assert_ok(g.tap_for_mana(0, horse))
	assert_eq(horse.zone, Mtg.Zone.GRAVEYARD, "the last counter was its toughness")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)

func test_workhorse_refuses_without_a_counter() -> void:
	var horse := put_battlefield(0, "Workhorse")
	g.remove_counters(horse, "+1/+1", 3)
	g.continuous.add_until_eot_pump(horse.id, 0, 1)
	g.recalculate()
	assert_ok(g.tap_for_mana(0, horse))
	assert_eq(horse.zone, Mtg.Zone.BATTLEFIELD, "the pump keeps it alive with no counter left")
	assert_refused(g.tap_for_mana(0, horse), "counter")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)

func test_workhorse_mana_burns_only_under_the_mana_burn_rules() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		if preset == "fifth": g.rules.set_edition("fifth")
		else: g.rules.set_preset("modern")
		var horse := put_battlefield(0, "Workhorse")
		assert_ok(g.tap_for_mana(0, horse))
		var life := g.players[0].life
		advance_to_step(Mtg.Step.COMBAT_BEGIN)
		advance_to_step(Mtg.Step.END)
		assert_eq(g.players[0].life, life - (1 if preset == "fifth" else 0), preset)


# --- the keyword-only creatures -------------------------------------------------------

func test_paladin_en_vec_first_strike_and_protection_from_black_and_red() -> void:
	var paladin := put_battlefield(1, "Paladin en-Vec")
	assert_true(paladin.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(paladin.cur_protection & (Mtg.ManaColor.B | Mtg.ManaColor.R), Mtg.ManaColor.B | Mtg.ManaColor.R)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(paladin)]))
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(paladin)]))   # green is fine
	resolve_stack()
	assert_eq(paladin.cur_power, 5)

func test_paladin_en_vec_cannot_be_blocked_by_black_creatures() -> void:
	var paladin := put_battlefield(0, "Paladin en-Vec")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [paladin.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {skeletons.id: paladin.id}))

func test_mirri_first_strike_forestwalk_vigilance_and_legendary() -> void:
	var mirri := put_battlefield(0, "Mirri, Cat Warrior")
	var bears := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Forest")
	assert_true(mirri.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_ne(mirri.cur_supertypes & Mtg.Supertype.LEGENDARY, 0)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mirri.id]))
	assert_false(mirri.tapped, "vigilance")
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bears.id: mirri.id}))   # forestwalk
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)

func test_sabertooth_wyvern_and_standing_troops_keywords() -> void:
	var wyvern := put_battlefield(0, "Sabertooth Wyvern")
	var troops := put_battlefield(0, "Standing Troops")
	assert_true(wyvern.has_keyword(Mtg.Keyword.FLYING))
	assert_true(wyvern.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_true(troops.has_keyword(Mtg.Keyword.VIGILANCE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [troops.id]))
	assert_false(troops.tapped)
