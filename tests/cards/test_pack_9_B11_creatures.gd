extends GameTest
## Pack 9 (the Tempest block), batch B11: the Exodus creatures of
## cards/sets/exo/_creatures.gd — each card's distinguishing Oracle clause
## and its edges (illegal targets, the condition the Keepers name, X, the
## source leaving, sorcery timing).

const CLAIMED := ["Cat Burglar", "Entropic Specter", "Ephemeron", "Ertai, Wizard Adept",
	"Furnace Brood", "Keeper of the Beasts", "Keeper of the Dead", "Keeper of the Flame",
	"Keeper of the Light", "Keeper of the Mind", "Killer Whale", "Mage il-Vec",
	"Merfolk Looter", "Ogre Shaman", "Plaguebearer", "Plated Rootwalla",
	"Rootwater Alligator", "Rootwater Mystic", "Shield Mate", "Skyshroud Elite",
	"Skyshroud War Beast", "Thrull Surgeon", "Vampire Hounds", "Wayward Soul",
	"Whiptongue Frog"]

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card

func _hand_of(pid: int, names: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for n in names: out.append(give_hand(pid, n))
	return out

## P0 attacks with [param attacker]; P1 blocks with [param blocker] (or not).
func _combat(attacker: CardInstance, blocker: CardInstance = null) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {} if blocker == null else {blocker.id: attacker.id}))
	resolve_stack()


func test_claimed_cards_are_no_longer_pending() -> void:
	for name in CLAIMED:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)
		assert_false(c.activated_abilities.is_empty() and c.static_abilities.is_empty() and c.triggered_abilities.is_empty(),
			"%s has its rules" % name)


# --- Cat Burglar --------------------------------------------------------------

func test_cat_burglar_makes_target_player_discard_their_choice() -> void:
	var burglar := put_battlefield(0, "Cat Burglar")
	var cards := _hand_of(1, ["Forest", "Craw Wurm"])
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(0, burglar, 0, [TargetRef.player(1)]))
	assert_true(burglar.tapped)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD, "the discarding player's heuristic throws the costliest card")

func test_cat_burglar_activates_only_as_a_sorcery() -> void:
	var burglar := put_battlefield(0, "Cat Burglar")
	_hand_of(1, ["Forest"])
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears))
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.activate_ability(0, burglar, 0, [TargetRef.player(1)]), "sorcery")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.activate_ability(0, burglar, 0, [TargetRef.player(1)]), "sorcery")
	assert_false(burglar.tapped)


# --- Entropic Specter ---------------------------------------------------------

func test_entropic_specter_counts_the_chosen_opponents_hand() -> void:
	_hand_of(1, ["Forest", "Forest", "Forest"])
	_hand_of(0, ["Forest"])
	var specter := put_battlefield(0, "Entropic Specter")
	assert_eq(int(specter.memory.get("chosen_player", -1)), 1, "the opponent was chosen as it entered")
	assert_eq([specter.cur_power, specter.cur_toughness], [3, 3])
	give_hand(1, "Forest")
	g.recalculate()
	assert_eq([specter.cur_power, specter.cur_toughness], [4, 4], "the count is live")
	assert_true(specter.has_keyword(Mtg.Keyword.FLYING))

func test_entropic_specter_dies_against_an_empty_hand() -> void:
	_hand_of(0, ["Forest", "Forest"])
	var specter := put_battlefield(0, "Entropic Specter")
	g.check_state_based_actions()
	assert_eq(specter.zone, Mtg.Zone.GRAVEYARD, "its controller's own hand does not count")

func test_entropic_specter_damage_makes_that_player_discard() -> void:
	var cards := _hand_of(1, ["Forest", "Craw Wurm", "Forest"])
	var specter := put_battlefield(0, "Entropic Specter")
	_combat(specter)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "a 3/3 hit")
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD, "that player discarded a card of their choice")
	assert_eq(g.players[1].hand.size(), 2)
	assert_eq(specter.cur_power, 2, "and the Specter shrank with the hand")


# --- Ephemeron ----------------------------------------------------------------

func test_ephemeron_discards_a_card_to_return_to_hand() -> void:
	var ephemeron := put_battlefield(0, "Ephemeron")
	assert_refused(g.activate_ability(0, ephemeron, 0, []))   # an empty hand cannot pay
	var forest := give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, ephemeron, 0, []))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the discard is the cost")
	resolve_stack()
	assert_eq(ephemeron.zone, Mtg.Zone.HAND)
	assert_eq(CardRegistry.get_card("Ephemeron").activated_abilities[0].effects[0].ai_role, &"self_bounce")


# --- Ertai, Wizard Adept ------------------------------------------------------

func test_ertai_counters_target_spell() -> void:
	var ertai := put_battlefield(0, "Ertai, Wizard Adept")
	assert_refused(g.activate_ability(0, ertai, 0, []), "")   # no spell to counter
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears))
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_refused(g.activate_ability(0, ertai, 0, [TargetRef.card(bears)]))   # {2}{U}{U} is four mana
	add_mana(0, Mtg.ManaColor.U, 1)
	assert_ok(g.activate_ability(0, ertai, 0, [TargetRef.card(bears)]))
	assert_true(ertai.tapped)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_ne(CardRegistry.get_card("Ertai, Wizard Adept").supertypes & Mtg.Supertype.LEGENDARY, 0)
	assert_eq(CardRegistry.get_card("Ertai, Wizard Adept").activated_abilities[0].effects[0].ai_role, &"counter_spell")


# --- Furnace Brood --------------------------------------------------------------

func test_furnace_brood_stops_regeneration_this_turn() -> void:
	var brood := put_battlefield(0, "Furnace Brood")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	skeletons.regeneration_shields = 1
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, brood, 0, [TargetRef.card(skeletons)]))
	resolve_stack()
	assert_true(skeletons.regeneration_banned_this_turn)
	g.destroy(skeletons)
	assert_eq(skeletons.zone, Mtg.Zone.GRAVEYARD, "the shield could not save it")

func test_furnace_brood_control_a_shield_works_without_it_and_lands_are_refused() -> void:
	var brood := put_battlefield(0, "Furnace Brood")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	var land := put_battlefield(1, "Forest")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, brood, 0, [TargetRef.card(land)]))
	skeletons.regeneration_shields = 1
	g.destroy(skeletons)
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD, "regenerated")


# --- The Keepers ----------------------------------------------------------------

func test_keeper_of_the_light_needs_an_opponent_with_more_life() -> void:
	var keeper := put_battlefield(0, "Keeper of the Light")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))   # 20 v 20
	assert_refused(g.activate_ability(0, keeper, 0, [TargetRef.player(0)]))   # never yourself
	g.players[0].life = 15
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))
	assert_true(keeper.tapped)
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[1].life, 20)

func test_keeper_of_the_light_judges_the_lives_as_it_is_activated() -> void:
	var keeper := put_battlefield(0, "Keeper of the Light")
	g.players[0].life = 15
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))
	g.adjust_life(0, 10)   # in response: now 25 v 20
	resolve_stack()
	assert_eq(g.players[0].life, 28, "\"as you activate\": the ability still resolves")

func test_keeper_of_the_flame_burns_the_opponent_with_more_life() -> void:
	var keeper := put_battlefield(0, "Keeper of the Flame")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))
	g.players[0].life = 12
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 12)

func test_keeper_of_the_mind_needs_two_more_cards() -> void:
	var keeper := put_battlefield(0, "Keeper of the Mind")
	give_hand(0, "Forest")
	_hand_of(1, ["Forest", "Forest"])
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))   # 2 v 1: one more only
	give_hand(1, "Forest")
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 2, "drew a card")

func test_keeper_of_the_beasts_needs_more_creatures_against_it() -> void:
	var keeper := put_battlefield(0, "Keeper of the Beasts")
	put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))   # 1 v 1 (the Keeper counts)
	put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))
	resolve_stack()
	var beasts := 0
	for i in g.players[0].battlefield:
		if i.is_token and i.has_subtype("beast"):
			beasts += 1
			assert_eq([i.cur_power, i.cur_toughness], [2, 2])
			assert_true(i.has_color(Mtg.ManaColor.G))
	assert_eq(beasts, 1)

func test_keeper_of_the_dead_destroys_a_nonblack_creature_of_that_player() -> void:
	var keeper := put_battlefield(0, "Keeper of the Dead")
	var bears := put_battlefield(1, "Grizzly Bears")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	var mine := put_battlefield(0, "Hill Giant")
	_to_graveyard(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, keeper, 0, [TargetRef.player(1), TargetRef.card(bears)]))   # 1 v 0
	_to_graveyard(0, "Craw Wurm")
	assert_refused(g.activate_ability(0, keeper, 0, [TargetRef.player(1), TargetRef.card(skeletons)]))   # black
	assert_refused(g.activate_ability(0, keeper, 0, [TargetRef.player(1), TargetRef.card(mine)]))   # not that player's
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.player(1), TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)

func test_keeper_of_the_dead_misses_a_creature_that_changed_hands() -> void:
	var keeper := put_battlefield(0, "Keeper of the Dead")
	var bears := put_battlefield(1, "Grizzly Bears")
	_to_graveyard(0, "Grizzly Bears")
	_to_graveyard(0, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.player(1), TargetRef.card(bears)]))
	g.change_control(bears, 0)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "no longer \"that player's\" creature (CR 608.2b)")


# --- Killer Whale, Whiptongue Frog --------------------------------------------

func test_flying_breaths_last_until_end_of_turn() -> void:
	for name in ["Killer Whale", "Whiptongue Frog"]:
		var body := put_battlefield(0, name)
		assert_false(body.has_keyword(Mtg.Keyword.FLYING), name)
		assert_refused(g.activate_ability(0, body, 0, []))   # no {U}
		add_mana(0, Mtg.ManaColor.U)
		assert_ok(g.activate_ability(0, body, 0, []))
		resolve_stack()
		assert_true(body.has_keyword(Mtg.Keyword.FLYING), name)
		var role: StringName = CardRegistry.get_card(name).activated_abilities[0].effects[0].ai_role
		assert_eq(role, &"self_keyword", name)
	var whale: CardInstance = g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.data.card_name == "Killer Whale")[0]
	advance_to_next_turn()
	assert_false(whale.has_keyword(Mtg.Keyword.FLYING))


# --- Mage il-Vec, Ogre Shaman ---------------------------------------------------

func test_mage_il_vec_pings_after_a_random_discard() -> void:
	var mage := put_battlefield(0, "Mage il-Vec")
	assert_refused(g.activate_ability(0, mage, 0, [TargetRef.player(1)]))   # nothing to discard
	var forest := give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.player(1)]))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "discarded as the cost")
	assert_true(mage.tapped)
	resolve_stack()
	assert_eq(g.players[1].life, 19)

func test_ogre_shaman_needs_two_mana_and_a_card() -> void:
	var shaman := put_battlefield(0, "Ogre Shaman")
	var bears := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Forest")
	assert_refused(g.activate_ability(0, shaman, 0, [TargetRef.card(bears)]))   # no {2}
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, shaman, 0, [TargetRef.card(bears)]))
	assert_false(shaman.tapped, "no {T} in the cost")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


# --- Merfolk Looter -------------------------------------------------------------

func test_merfolk_looter_draws_then_discards() -> void:
	var looter := put_battlefield(0, "Merfolk Looter")
	var library := g.players[0].library.size()
	var graveyard := g.players[0].graveyard.size()
	assert_ok(g.activate_ability(0, looter, 0, []))
	resolve_stack()
	assert_eq(g.players[0].library.size(), library - 1)
	assert_eq(g.players[0].hand.size(), 0)
	assert_eq(g.players[0].graveyard.size(), graveyard + 1)
	assert_refused(g.activate_ability(0, looter, 0, []))   # tapped
	var sick := put_battlefield(0, "Merfolk Looter", true)
	assert_refused(g.activate_ability(0, sick, 0, []))


# --- Plaguebearer ---------------------------------------------------------------

func test_plaguebearer_destroys_a_nonblack_creature_of_mana_value_x() -> void:
	var plague := put_battlefield(0, "Plaguebearer")
	var bears := put_battlefield(1, "Grizzly Bears")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	add_mana(0, Mtg.ManaColor.B, 5)
	assert_refused(g.activate_ability(0, plague, 0, [TargetRef.card(bears)], 1))   # mana value 2, X 1
	assert_refused(g.activate_ability(0, plague, 0, [TargetRef.card(skeletons)], 2))   # black
	assert_ok(g.activate_ability(0, plague, 0, [TargetRef.card(bears)], 2))
	assert_eq(g.players[0].mana_pool.total(), 0, "{X}{X}{B} with X = 2 is five mana")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(CardRegistry.get_card("Plaguebearer").activated_abilities[0].effects[0].ai_role, &"exact_mv_removal")

func test_plaguebearer_x_zero_kills_a_nonblack_token() -> void:
	var plague := put_battlefield(0, "Plaguebearer")
	var keeper := put_battlefield(0, "Keeper of the Beasts")
	for n in 3: put_battlefield(1, "Grizzly Bears")   # three against our two
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.player(1)]))
	resolve_stack()
	var beast: CardInstance = null
	for i in g.players[0].battlefield:
		if i.is_token: beast = i
	assert_not_null(beast)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, plague, 0, [TargetRef.card(beast)], 0))   # a token's mana value is 0
	resolve_stack()
	assert_ne(beast.zone, Mtg.Zone.BATTLEFIELD)


# --- Plated Rootwalla -----------------------------------------------------------

func test_plated_rootwalla_pumps_once_each_turn() -> void:
	var walla := put_battlefield(0, "Plated Rootwalla")
	add_mana(0, Mtg.ManaColor.G, 6)
	assert_ok(g.activate_ability(0, walla, 0, []))
	resolve_stack()
	assert_eq([walla.cur_power, walla.cur_toughness], [6, 6])
	assert_refused(g.activate_ability(0, walla, 0, []))


# --- Rootwater Alligator --------------------------------------------------------

func test_rootwater_alligator_sacrifices_a_forest_to_regenerate() -> void:
	var gator := put_battlefield(0, "Rootwater Alligator")
	assert_refused(g.activate_ability(0, gator, 0, []))   # no Forest
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.activate_ability(0, gator, 0, []))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(gator.regeneration_shields, 1)
	g.destroy(gator)
	assert_eq(gator.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(gator.tapped, "regenerated (CR 701.15b)")
	assert_true(CardRegistry.get_card("Rootwater Alligator").activated_abilities[0].effects[0].is_regeneration)


# --- Rootwater Mystic -----------------------------------------------------------

func test_rootwater_mystic_shows_its_activator_the_top_card() -> void:
	var mystic := put_battlefield(0, "Rootwater Mystic")
	var wurm := give_hand(1, "Craw Wurm")
	g.put_from_hand_on_top_of_library(wurm)
	var seen: Array = []
	g.information_revealed.connect(func(viewer: int, _title: String, names: Array) -> void:
		seen.append([viewer, names.duplicate()]))
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.activate_ability(0, mystic, 0, [TargetRef.player(1)]))   # {1}{U} is two mana
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, mystic, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(seen, [[0, ["Craw Wurm"]]], "only the activator is shown")
	assert_eq(g.players[1].library.back(), wurm, "nothing moved")


# --- Shield Mate ----------------------------------------------------------------

func test_shield_mate_sacrifices_itself_for_four_toughness() -> void:
	var mate := put_battlefield(0, "Shield Mate")
	var bears := put_battlefield(0, "Grizzly Bears")
	var land := put_battlefield(0, "Forest")
	assert_refused(g.activate_ability(0, mate, 0, [TargetRef.card(land)]))   # a creature only
	assert_eq(mate.zone, Mtg.Zone.BATTLEFIELD, "a refused activation pays nothing")
	assert_ok(g.activate_ability(0, mate, 0, [TargetRef.card(bears)]))
	assert_eq(mate.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is the cost")
	resolve_stack()
	assert_eq([bears.cur_power, bears.cur_toughness], [2, 6])
	advance_to_next_turn()
	assert_eq(bears.cur_toughness, 2)


# --- Skyshroud Elite, Skyshroud War Beast -------------------------------------

func test_skyshroud_elite_grows_against_an_opposing_nonbasic_land() -> void:
	var elite := put_battlefield(0, "Skyshroud Elite")
	put_battlefield(0, "City of Traitors")
	put_battlefield(1, "Forest")
	g.recalculate()
	assert_eq([elite.cur_power, elite.cur_toughness], [1, 1], "its own nonbasic land and a basic do not count")
	var city := put_battlefield(1, "City of Traitors")
	g.recalculate()
	assert_eq([elite.cur_power, elite.cur_toughness], [2, 3])
	g.destroy(city)
	g.recalculate()
	assert_eq([elite.cur_power, elite.cur_toughness], [1, 1])

func test_skyshroud_war_beast_counts_the_chosen_players_nonbasic_lands() -> void:
	put_battlefield(1, "City of Traitors")
	put_battlefield(1, "City of Traitors")
	put_battlefield(1, "Forest")
	put_battlefield(0, "City of Traitors")
	var beast := put_battlefield(0, "Skyshroud War Beast")
	assert_eq(int(beast.memory.get("chosen_player", -1)), 1)
	assert_eq([beast.cur_power, beast.cur_toughness], [2, 2])
	assert_true(beast.has_keyword(Mtg.Keyword.TRAMPLE))

func test_skyshroud_war_beast_dies_with_no_nonbasic_land_against_it() -> void:
	put_battlefield(1, "Forest")
	var beast := put_battlefield(0, "Skyshroud War Beast")
	g.check_state_based_actions()
	assert_eq(beast.zone, Mtg.Zone.GRAVEYARD)


# --- Thrull Surgeon ---------------------------------------------------------------

func test_thrull_surgeon_looks_and_chooses_the_discard() -> void:
	var surgeon := put_battlefield(0, "Thrull Surgeon")
	var cards := _hand_of(1, ["Lightning Bolt", "Craw Wurm"])
	var seen: Array = []
	g.information_revealed.connect(func(viewer: int, _title: String, names: Array) -> void:
		seen.append([viewer, names.duplicate()]))
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, surgeon, 0, [TargetRef.player(1)]))
	assert_eq(surgeon.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(seen, [[0, ["Lightning Bolt", "Craw Wurm"]]], "the hand is shown to the activator only")
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD, "the activator's heuristic takes the costliest card")
	assert_eq(cards[0].zone, Mtg.Zone.HAND)

func test_thrull_surgeon_activates_only_as_a_sorcery() -> void:
	var surgeon := put_battlefield(0, "Thrull Surgeon")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.activate_ability(0, surgeon, 0, [TargetRef.player(1)]), "sorcery")
	assert_eq(surgeon.zone, Mtg.Zone.BATTLEFIELD)


# --- Vampire Hounds ---------------------------------------------------------------

func test_vampire_hounds_discard_only_a_creature_card() -> void:
	var hounds := put_battlefield(0, "Vampire Hounds")
	var forest := give_hand(0, "Forest")
	assert_refused(g.activate_ability(0, hounds, 0, []))   # a land is not a creature card
	var bears := give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, hounds, 0, []))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq([hounds.cur_power, hounds.cur_toughness], [4, 4])


# --- Wayward Soul -------------------------------------------------------------------

func test_wayward_soul_goes_on_top_of_its_owners_library() -> void:
	var soul := put_battlefield(0, "Wayward Soul")
	assert_refused(g.activate_ability(0, soul, 0, []))   # no {U}
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, soul, 0, []))
	resolve_stack()
	assert_eq(soul.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), soul)

func test_wayward_soul_a_stolen_soul_goes_to_its_owners_library() -> void:
	var soul := put_battlefield(1, "Wayward Soul")
	g.change_control(soul, 0)
	soul.summoning_sick = false
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, soul, 0, []))
	resolve_stack()
	assert_eq(g.players[1].library.back(), soul)
