extends GameTest
## Wave-52 tests: the MULTI-PART ONE-OFFS — cards that need no shared
## system, just their own design pass. Stasis freezes the world, Time Vault
## trades turns, Lich rewrites what life means, and Golgothian Sylex and
## City in a Bottle read a card's own set code to undo their expansions.


func test_registry_loaded_wave52() -> void:
	for name in ["Stasis", "Time Vault", "Lich", "Gaea's Liege",
			"Cyclopean Tomb", "Golgothian Sylex", "City in a Bottle",
			"Transmute Artifact", "Tawnos's Coffin"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------------ Stasis --

func test_stasis_stops_everyone_untapping() -> void:
	put_battlefield(0, "Stasis")
	var mine := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Forest")
	g.tap_permanent(mine)
	g.tap_permanent(theirs)
	advance_to_next_turn()      # their untap step
	assert_true(theirs.tapped, "nobody untaps")
	advance_to_next_turn()      # ours
	assert_true(mine.tapped)


func test_stasis_eats_itself_without_the_rent() -> void:
	var stasis := put_battlefield(0, "Stasis")
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep, no blue mana anywhere
	resolve_stack()
	assert_eq(stasis.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------------- Time Vault --

## Answers "Play this turn." to the Vault's question as the turn begins.
class PlaysOn extends DecisionAgent:
	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			_options: Array[String], _hint: int) -> int:
		return 0


func test_time_vault_enters_tapped_and_stays_tapped() -> void:
	var vault := put_battlefield(0, "Time Vault")
	assert_true(vault.tapped)
	g.set_agent(0, PlaysOn.new())
	advance_to_next_turn()
	advance_to_next_turn()   # our turn 3, played rather than skipped
	resolve_stack()
	assert_eq(g.active_player, 0)
	assert_true(vault.tapped, "it never untaps on its own — only a skipped turn "
		+ "untaps it (tests/cards/test_fidelity_2026_09_02_vault.gd)")


func test_time_vault_buys_an_extra_turn() -> void:
	var vault := put_battlefield(0, "Time Vault")
	vault.tapped = false
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, vault, 0, []))
	resolve_stack()
	assert_eq(g.extra_turns.size(), 1)
	assert_eq(g.extra_turns[0], 0, "the extra turn is queued for us")
	advance_to_next_turn()
	assert_string_contains("\n".join(g.log_lines), "takes an extra turn")


# -------------------------------------------------------------------- Lich --

func test_lich_costs_you_your_life_and_keeps_you_alive() -> void:
	var lich := give_hand(0, "Lich")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 4)
	assert_ok(g.cast_spell(0, lich, []))
	resolve_stack()
	assert_eq(g.players[0].life, 0)
	assert_false(g.game_over, "you don't lose the game for having 0 life")


func test_a_bounced_lich_costs_you_the_enchantment_not_the_game() -> void:
	var lich := give_hand(0, "Lich")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 4)
	assert_ok(g.cast_spell(0, lich, []))
	resolve_stack()
	# The Lich left you at 0, and state-based actions would end the game
	# for THAT the moment its protection goes (CR 704.5a) — so hold the
	# life total up first and watch the trigger alone.
	g.players[0].life = 7
	g.return_to_hand(lich)
	assert_eq(lich.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty(), "no trigger was put on the stack")
	resolve_stack()
	assert_false(g.game_over, "only a Lich put into a GRAVEYARD from the battlefield loses the game")
	assert_eq(g.players[0].life, 7)


func test_a_destroyed_lich_loses_you_the_game_whatever_your_life() -> void:
	var lich := give_hand(0, "Lich")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 4)
	assert_ok(g.cast_spell(0, lich, []))
	resolve_stack()
	g.players[0].life = 7   # so it is the TRIGGER that ends it, not 0 life
	g.destroy(lich)
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 1)


func test_lich_turns_life_gain_into_cards() -> void:
	var lich := give_hand(0, "Lich")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 4)
	assert_ok(g.cast_spell(0, lich, []))
	resolve_stack()
	var hand := g.players[0].hand.size()
	g.adjust_life(0, 3)
	assert_eq(g.players[0].life, 0, "no life was gained")
	assert_eq(g.players[0].hand.size(), hand + 3, "three cards instead")


func test_lich_eats_permanents_when_you_take_damage() -> void:
	var lich := give_hand(0, "Lich")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 4)
	assert_ok(g.cast_spell(0, lich, []))
	resolve_stack()
	var permanents := g.players[0].battlefield.size()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), permanents - 3,
		"three damage, three permanents")


func test_losing_the_lich_loses_the_game() -> void:
	var lich := give_hand(0, "Lich")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 4)
	assert_ok(g.cast_spell(0, lich, []))
	resolve_stack()
	g.destroy(lich)
	g.check_state_based_actions()
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 1)


# ------------------------------------------------------------ Gaea's Liege --

func test_gaeas_liege_counts_your_forests() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var liege := put_battlefield(0, "Gaea's Liege")
	assert_eq(liege.cur_power, 3)
	assert_eq(liege.cur_toughness, 3)


func test_gaeas_liege_turns_a_land_into_a_forest() -> void:
	# It needs a Forest or two to have a body at all — its power and
	# toughness ARE the Forest count, and a 0/0 dies on arrival.
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var liege := put_battlefield(0, "Gaea's Liege")
	var island := put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, liege, 0, [TargetRef.card(island)]))
	resolve_stack()
	assert_true(island.has_subtype("forest"))
	assert_ok(g.tap_for_mana(1, island))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	g.destroy(liege)
	g.check_state_based_actions()
	assert_false(island.has_subtype("forest"), "it reverts when the Liege dies")


# --------------------------------------------------------- Cyclopean Tomb --

func test_cyclopean_tomb_mires_a_land() -> void:
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var island := put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(island)]))
	resolve_stack()
	assert_eq(int(island.counters.get("mire", 0)), 1)
	assert_true(island.has_subtype("swamp"))
	assert_ok(g.tap_for_mana(1, island))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.B), 1)


func test_cyclopean_tomb_only_works_in_your_upkeep() -> void:
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var island := put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, tomb, 0, [TargetRef.card(island)]),
		"upkeep")


# ------------------------------------------------------- Golgothian Sylex --

func test_golgothian_sylex_unmakes_antiquities() -> void:
	var sylex := put_battlefield(0, "Golgothian Sylex")
	var atq_card := put_battlefield(1, "Mishra's Workshop")   # atq
	var safe := put_battlefield(1, "Grizzly Bears")           # 2ed
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, sylex, 0, []))
	resolve_stack()
	assert_eq(atq_card.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(sylex.zone, Mtg.Zone.GRAVEYARD, "it unmakes itself too")
	assert_eq(safe.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------- City in a Bottle --

func test_city_in_a_bottle_sweeps_arabia() -> void:
	var arabian := put_battlefield(1, "Jeweled Bird")        # arn
	var safe := put_battlefield(1, "Grizzly Bears")
	var bottle := give_hand(0, "City in a Bottle")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, bottle, []))
	resolve_stack()
	assert_eq(arabian.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(safe.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bottle.zone, Mtg.Zone.BATTLEFIELD, "the Bottle itself survives")


func test_city_in_a_bottle_bans_arabian_spells() -> void:
	put_battlefield(0, "City in a Bottle")
	var arabian := give_hand(1, "Jeweled Bird")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(1, arabian, []), "City in a Bottle")


# ----------------------------------------------------- Transmute Artifact --

func test_transmute_artifact_upgrades_a_rock() -> void:
	var fodder := put_battlefield(0, "Sol Ring")     # mana value 1
	var prize := _make_instance(0, "Black Lotus")    # mana value 0
	prize.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(prize)
	var transmute := give_hand(0, "Transmute Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, transmute, []))
	assert_eq(fodder.zone, Mtg.Zone.BATTLEFIELD,
		"\"Sacrifice an artifact. If you do ...\" happens on RESOLUTION")
	resolve_stack()
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(prize.zone, Mtg.Zone.BATTLEFIELD, "a cheaper artifact comes free")


func test_transmute_artifact_needs_an_artifact() -> void:
	# The sacrifice is part of the RESOLUTION, not an additional cost, so
	# the spell is castable with no artifact at all — it simply does nothing
	# (audit 2026-09; it used to be refused at cast time).
	var transmute := give_hand(0, "Transmute Artifact")
	var prize := _make_instance(0, "Black Lotus")
	prize.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(prize)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, transmute, []))
	resolve_stack()
	assert_eq(prize.zone, Mtg.Zone.LIBRARY, "nothing to sacrifice, nothing found")


# ------------------------------------------------------- Tawnos's Coffin --

func test_tawnos_coffin_buries_a_creature_until_it_untaps() -> void:
	var coffin := put_battlefield(0, "Tawnos's Coffin")
	var victim := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(victim)]))
	resolve_stack()
	assert_eq(victim.zone, Mtg.Zone.EXILE)
	assert_true(coffin.tapped)
	g.untap_permanent(coffin)
	resolve_stack()
	assert_eq(victim.zone, Mtg.Zone.BATTLEFIELD, "untapping releases it")
	assert_true(victim.tapped, "and it comes back tapped")
	assert_eq(victim.controller_id, 1, "under its OWNER's control")


func test_tawnos_coffin_releases_when_destroyed() -> void:
	var coffin := put_battlefield(0, "Tawnos's Coffin")
	var victim := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(victim)]))
	resolve_stack()
	g.destroy(coffin)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(victim.zone, Mtg.Zone.BATTLEFIELD)
