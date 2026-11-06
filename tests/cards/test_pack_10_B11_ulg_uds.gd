extends GameTest
## Pack 10 (the Urza block), batch B11: the OWN TEXT of the Urza's Legacy
## and Urza's Destiny cycling cards (cards/sets/ulg/_cycling.gd,
## uds/_cycling.gd) — their cycling is pinned by test_pack_10_B11_cycling.gd.


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.card_to_graveyard_from_anywhere(inst)
	return inst


# --------------------------------------------------------------- Legacy --

func test_iron_will_gives_plus_zero_plus_four() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var will := give_hand(0, "Iron Will")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, will, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 6])


func test_radiants_judgment_reads_live_power() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	var judgment := give_hand(0, "Radiant's Judgment")
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_refused(g.cast_spell(0, judgment, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, judgment, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	# A pumped Bear is a legal target.
	g.continuous.add_until_eot_pump(bear.id, 2, 0)
	g.recalculate()
	var second := give_hand(0, "Radiant's Judgment")
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, second, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_cloud_of_faeries_untaps_up_to_two_lands_as_it_enters() -> void:
	var lands: Array[CardInstance] = []
	for i in 3:
		var island := put_battlefield(0, "Island")
		island.tapped = true
		lands.append(island)
	var cloud := give_hand(0, "Cloud of Faeries")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, cloud))
	resolve_stack()
	assert_eq(cloud.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(cloud.has_keyword(Mtg.Keyword.FLYING))
	var untapped := lands.filter(func(l: CardInstance) -> bool: return not l.tapped).size()
	assert_eq(untapped, 2, "up to two, and the seat takes two")


func test_miscalculation_counters_unless_two_is_paid() -> void:
	var bear := give_hand(1, "Grizzly Bears")
	advance_to_next_turn()   # P1's main phase
	assert_eq(g.active_player, 1)
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(1, bear))
	assert_ok(g.pass_priority(1))
	var misc := give_hand(0, "Miscalculation")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, misc, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "no {2} to pay: countered")


func test_rebuild_returns_every_artifact_to_its_owners_hand() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var rod := put_battlefield(0, "Rod of Ruin")
	var bear := put_battlefield(1, "Grizzly Bears")
	var rebuild := give_hand(0, "Rebuild")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, rebuild))
	resolve_stack()
	assert_true(g.players[1].hand.has(ring))
	assert_true(g.players[0].hand.has(rod))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_swat_destroys_a_creature_with_power_two_or_less() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var swat := give_hand(0, "Swat")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, swat, [TargetRef.card(giant)]))
	assert_ok(g.cast_spell(0, swat, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_unearth_returns_a_small_creature_card_from_your_graveyard() -> void:
	var bear := _in_graveyard(0, "Grizzly Bears")
	var wurm := _in_graveyard(0, "Craw Wurm")
	var theirs := _in_graveyard(1, "Hill Giant")
	var unearth := give_hand(0, "Unearth")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(0, unearth, [TargetRef.card(wurm)]), "")
	assert_refused(g.cast_spell(0, unearth, [TargetRef.card(theirs)]), "")
	assert_ok(g.cast_spell(0, unearth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 0)


func test_the_toad_and_the_elves_have_protection() -> void:
	var toad := put_battlefield(0, "Bloated Toad")
	var elves := put_battlefield(0, "Darkwatch Elves")
	assert_true((toad.cur_protection & Mtg.ManaColor.U) != 0)
	assert_true((elves.cur_protection & Mtg.ManaColor.B) != 0)
	assert_eq([toad.cur_power, toad.cur_toughness], [2, 2])


func test_repopulate_shuffles_a_players_creature_cards_into_their_library() -> void:
	var bear := _in_graveyard(1, "Grizzly Bears")
	var giant := _in_graveyard(1, "Hill Giant")
	var bolt := _in_graveyard(1, "Lightning Bolt")
	var mine := _in_graveyard(0, "Craw Wurm")
	var library_before := g.players[1].library.size()
	var repopulate := give_hand(0, "Repopulate")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, repopulate, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(giant.zone, Mtg.Zone.LIBRARY)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "creature cards only")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "only the target player's graveyard")
	assert_eq(g.players[1].library.size(), library_before + 2)


# -------------------------------------------------------------- Destiny --

func test_fend_off_prevents_the_combat_damage_its_target_would_deal() -> void:
	var fended := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(0, "Grizzly Bears")
	var fend := give_hand(0, "Fend Off")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, fend, [TargetRef.card(fended)]))
	resolve_stack()
	run_combat([fended.id, other.id])
	assert_eq(g.players[1].life, 18, "only the other Bear's two")


func test_rapid_decay_exiles_up_to_three_cards_from_one_graveyard() -> void:
	var a := _in_graveyard(1, "Grizzly Bears")
	var b := _in_graveyard(1, "Hill Giant")
	var mine := _in_graveyard(0, "Craw Wurm")
	var decay := give_hand(0, "Rapid Decay")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, decay, [TargetRef.card(a), TargetRef.card(mine)]))
	assert_ok(g.cast_spell(0, decay, [TargetRef.card(a), TargetRef.card(b)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.EXILE)
	assert_eq(b.zone, Mtg.Zone.EXILE)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	# Zero targets is legal.
	var empty := give_hand(0, "Rapid Decay")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, empty, []))
	resolve_stack()


func test_flame_jet_deals_three_to_a_player_and_cannot_hit_a_creature() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var jet := give_hand(0, "Flame Jet")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, jet, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, jet, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
