extends GameTest
## Wave-42 tests: Arabian Nights and Antiquities remainders — a death
## curse (Abu Ja'far), a life floor (Ali from Cairo), a two-way pinger
## (Cuombajj Witches), a symmetric sweeper anyone can fire (Ifh-Biff
## Efreet), a conditional anthem (Jihad), artifact lifegain and card draw
## (Tablet of Epityr, Urza's Chalice, Urza's Miter), a one-shot cannon
## (Rocket Launcher), a rebuy (Obelisk of Undoing) and the two
## artifact-damage cards (Reverse Polarity, Martyrs of Korlis).


func test_abu_jafar_takes_its_killer_with_it() -> void:
	var abu := put_battlefield(1, "Abu Ja'far")     # 0/1
	var bear := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id], {abu.id: bear.id})
	resolve_stack()
	assert_eq(abu.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "everything it blocked dies too")


func test_ali_from_cairo_holds_you_at_one() -> void:
	put_battlefield(0, "Ali from Cairo")
	var fireball := give_hand(1, "Fireball")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C, 30)
	assert_ok(g.cast_spell(1, fireball, [TargetRef.player(0)], 30))
	resolve_stack()
	assert_eq(g.players[0].life, 1, "damage can't take you below 1")
	assert_false(g.game_over)


func test_cuombajj_witches_shoot_both_ways() -> void:
	var witches := put_battlefield(0, "Cuombajj Witches")
	var theirs := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, witches, 0, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "your ping killed the goblin")
	# Their shot is THEIR target (lifted 2026-09-02): with no kill on offer
	# the heuristic takes your face over a 1/3 that heals at end of turn.
	assert_eq(g.players[0].life, 19, "and theirs came back at you")
	assert_eq(witches.damage, 0)


func test_ifh_biff_efreet_sweeps_the_skies_for_anyone() -> void:
	var efreet := put_battlefield(0, "Ifh-Bíff Efreet")   # 3/3 flier
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, efreet, 0, []))
	resolve_stack()
	assert_eq(angel.damage, 1)
	assert_eq(efreet.damage, 1, "it hits itself too")
	assert_eq(bear.damage, 0, "no flying, no damage")
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[1].life, 19)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(1, efreet, 0, []), )


func test_jihad_arms_white_against_the_chosen_colour() -> void:
	var lions := put_battlefield(0, "Savannah Lions")
	var jihad := give_hand(0, "Jihad")
	put_battlefield(1, "Grizzly Bears")   # a green permanent
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, jihad, []))
	resolve_stack()
	assert_eq(lions.cur_power, 4, "+2/+1 while they hold the chosen colour")
	assert_eq(lions.cur_toughness, 2)


func test_tablet_of_epityr_pays_for_dead_artifacts() -> void:
	put_battlefield(0, "Tablet of Epityr")
	var ring := put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Forest")
	g.destroy(ring, false)
	resolve_stack()
	assert_eq(g.players[0].life, 21)


func test_urzas_chalice_pays_for_artifact_spells() -> void:
	put_battlefield(0, "Urza's Chalice")
	put_battlefield(0, "Forest")
	var ring := give_hand(1, "Sol Ring")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, ring, []))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "either player's artifact spell pays")


func test_urzas_miter_draws_off_destroyed_artifacts() -> void:
	put_battlefield(0, "Urza's Miter")
	var ring := put_battlefield(0, "Sol Ring")
	for i in 3:
		put_battlefield(0, "Forest")
	g.destroy(ring, false)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "{3} paid, a card drawn")


func test_rocket_launcher_fires_then_explodes() -> void:
	var launcher := put_battlefield(0, "Rocket Launcher")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, launcher, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, launcher, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(launcher.zone, Mtg.Zone.GRAVEYARD, "it destroys itself at end of turn")


func test_obelisk_of_undoing_rebuys_your_own() -> void:
	var obelisk := put_battlefield(0, "Obelisk of Undoing")
	var ring := put_battlefield(0, "Sol Ring")
	var theirs := put_battlefield(1, "Icy Manipulator")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_refused(g.activate_ability(0, obelisk, 0, [TargetRef.card(theirs)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, obelisk, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.HAND)


func test_reverse_polarity_pays_back_artifact_damage() -> void:
	var rod := put_battlefield(1, "Rod of Ruin")
	var reverse := give_hand(0, "Reverse Polarity")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, rod, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, reverse, []))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "twice the 1 artifact damage taken")


## A creature that a static has turned INTO an artifact deals artifact
## damage for both cards (CR 611.2 — the type is a live characteristic,
## not the printed one). No card in the pool does exactly this, so the
## static is synthetic.
func _an_artifice() -> CardData:
	return CardData.new("Test Artifice", "{1}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			func(game: MtgGame, _src: CardInstance) -> void:
				for inst in game.all_battlefield():
					if inst.is_creature():
						inst.cur_types |= Mtg.CardType.ARTIFACT,
			"All creatures are artifacts in addition to their other types.") \
			.changing_types())


func test_reverse_polarity_counts_damage_from_a_creature_made_an_artifact() -> void:
	put_synthetic(1, _an_artifice())
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_true(bear.is_type(Mtg.CardType.ARTIFACT))
	var reverse := give_hand(0, "Reverse Polarity")
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(bear, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 18)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, reverse, []))
	resolve_stack()
	assert_eq(g.players[0].life, 22, "twice the 2 artifact damage taken")


func test_martyrs_of_korlis_soak_damage_from_a_creature_made_an_artifact() -> void:
	var martyrs := put_battlefield(0, "Martyrs of Korlis")   # 1/6
	put_synthetic(1, _an_artifice())
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(bear, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 20, "the Martyrs took it")
	assert_eq(martyrs.damage, 2)


func test_martyrs_of_korlis_soaks_artifact_damage() -> void:
	var martyrs := put_battlefield(0, "Martyrs of Korlis")   # 1/6
	var rod := put_battlefield(1, "Rod of Ruin")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, rod, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the Martyrs took it")
	assert_eq(martyrs.damage, 1)
