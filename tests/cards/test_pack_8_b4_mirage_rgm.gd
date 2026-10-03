extends GameTest
## Pack 8, batch B4: the red, green and gold Mirage instants and sorceries
## (cards/sets/mir/_spells.gd). Same scripted-seat harness as
## test_pack_8_b4_mirage_wub.gd.




class Scripted extends DecisionAgent:
	## FIFO answers; an empty queue falls back to the caller's hint.
	var options: Array = []   # int index or String label (case-insensitive)
	var answers: Array = []   # bool
	var picks: Array = []     # CardInstance, card name, or null (decline)
	var colors: Array = []    # Mtg.ManaColor mask

	func answer_option(_g: MtgGame, _p: int, _prompt: String,
			labels: Array[String], hint: int) -> int:
		if options.is_empty():
			return hint
		var want: Variant = options.pop_front()
		if want is String:
			for i in labels.size():
				if labels[i].to_lower().contains(String(want).to_lower()):
					return i
			return hint
		return int(want)

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		if want == null:
			return null
		for c in candidates:
			if want is CardInstance and c == want:
				return c
			if want is String and c.data.card_name == want:
				return c
		return null if candidates.is_empty() else candidates[0]

	func answer_color(_g: MtgGame, _p: int, _prompt: String, hint: int) -> int:
		return int(colors.pop_front()) if not colors.is_empty() else hint


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a


## Exactly the mana [param card]'s cost asks for (X paid as colourless),
## so nothing floats into a later step.
func fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


func cast(name: String, targets: Array = [], x := 0, mode := 0, pid := 0) -> CardInstance:
	var card := give_hand(pid, name)
	fund(pid, card, x)
	assert_ok(g.cast_spell(pid, card, targets, x, mode))
	resolve_stack()
	return card


func bury(pid: int, name: String) -> CardInstance:
	var inst := put_battlefield(pid, name)
	g.destroy(inst)
	assert_eq(inst.zone, Mtg.Zone.GRAVEYARD)
	return inst


func on_top(pid: int, name: String) -> CardInstance:
	var inst := give_hand(pid, name)
	g.put_from_hand_on_top_of_library(inst)
	return inst


func tokens_of(pid: int, name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.is_token and inst.data.card_name == name:
			out.append(inst)
	return out



# --------------------------------------------------------- Builder's Bane --

func test_builders_bane_burns_each_player_per_artifact_buried() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var tome := put_battlefield(1, "Jayemdae Tome")
	var mine := put_battlefield(0, "Sol Ring")
	cast("Builder's Bane", [TargetRef.card(ring), TargetRef.card(tome), TargetRef.card(mine)], 3)
	for inst in [ring, tome, mine]:
		assert_eq(inst.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 19)


func test_builders_bane_x_zero_does_nothing() -> void:
	put_battlefield(1, "Sol Ring")
	cast("Builder's Bane", [], 0)
	assert_eq(g.players[1].life, 20)


# ------------------------------------------------------------ Chaos Charm --

func test_chaos_charm_destroys_a_wall_only() -> void:
	var wall := put_battlefield(1, "Wall of Stone")
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Chaos Charm")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)], 0, 0))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(wall)], 0, 0))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


func test_chaos_charm_pings_and_hastes() -> void:
	var elf := put_battlefield(1, "Llanowar Elves")
	cast("Chaos Charm", [TargetRef.card(elf)], 0, 1)
	assert_eq(elf.zone, Mtg.Zone.GRAVEYARD)
	var bear := put_battlefield(0, "Grizzly Bears", true)
	cast("Chaos Charm", [TargetRef.card(bear)], 0, 2)
	assert_true(bear.has_keyword(Mtg.Keyword.HASTE))


# ------------------------------------------------------------ Cinder Cloud --

func test_cinder_cloud_white_death_burns_its_controller() -> void:
	var lions := put_battlefield(1, "Savannah Lions")
	cast("Cinder Cloud", [TargetRef.card(lions)])
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)


func test_cinder_cloud_nonwhite_death_deals_nothing() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	cast("Cinder Cloud", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


# ----------------------------------------------------------- Final Fortune --

func test_final_fortune_takes_a_turn_then_loses() -> void:
	cast("Final Fortune")
	var turn := g.turn_number
	advance_to_next_turn()
	assert_eq(g.active_player, 0, "the extra turn is ours")
	assert_eq(g.turn_number, turn + 1)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(g.players[0].has_lost)


# ----------------------------------------------------------- Goblin Scouts --

func test_goblin_scouts_makes_three_mountainwalkers() -> void:
	cast("Goblin Scouts")
	var scouts := tokens_of(0, "Goblin Scout")
	assert_eq(scouts.size(), 3)
	for s in scouts:
		assert_eq([s.cur_power, s.cur_toughness], [1, 1])
		assert_true(s.cur_landwalk.has("mountain"))
		assert_true(s.has_subtype("goblin"))
		assert_true(s.has_subtype("scout"))
		assert_true(s.has_color(Mtg.ManaColor.R))


# ------------------------------------------------------ Hammer of Bogardan --

func test_hammer_of_bogardan_burns_and_returns_only_in_your_upkeep() -> void:
	var hammer := cast("Hammer of Bogardan", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 17)
	assert_eq(hammer.zone, Mtg.Zone.GRAVEYARD)
	add_mana(0, Mtg.ManaColor.R, 3)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, hammer, 0), "")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0)
	add_mana(0, Mtg.ManaColor.R, 3)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, hammer, 0))
	resolve_stack()
	assert_eq(hammer.zone, Mtg.Zone.HAND)


# --------------------------------------------------------- Reign of Chaos --

func test_reign_of_chaos_plains_and_white_creature() -> void:
	var plains := put_battlefield(1, "Plains")
	var lions := put_battlefield(1, "Savannah Lions")
	cast("Reign of Chaos", [TargetRef.card(plains), TargetRef.card(lions)], 0, 0)
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)


func test_reign_of_chaos_island_and_blue_creature() -> void:
	var island := put_battlefield(1, "Island")
	var merfolk := put_battlefield(1, "Merfolk of the Pearl Trident")
	var spell := give_hand(0, "Reign of Chaos")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(island), TargetRef.card(merfolk)], 0, 0))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(island), TargetRef.card(merfolk)], 0, 1))
	resolve_stack()
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(merfolk.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------- Sirocco --

func test_sirocco_discards_a_blue_instant_unless_four_life_is_paid() -> void:
	var a := seat(1)
	a.answers = [false]
	var counter := give_hand(1, "Counterspell")
	var growth := give_hand(1, "Giant Growth")
	cast("Sirocco", [TargetRef.player(1)])
	assert_eq(counter.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(growth.zone, Mtg.Zone.HAND, "only blue instants")
	assert_eq(g.players[1].life, 20)


func test_sirocco_paying_four_life_keeps_the_card() -> void:
	var a := seat(1)
	a.answers = [true]
	var counter := give_hand(1, "Counterspell")
	cast("Sirocco", [TargetRef.player(1)])
	assert_eq(counter.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 16)


# ---------------------------------------------------- Telim'Tor's Edict --

func test_telimtors_edict_exiles_what_you_own_or_control_and_draws_later() -> void:
	var forest := put_battlefield(0, "Forest")
	cast("Telim'Tor's Edict", [TargetRef.card(forest)])
	assert_eq(forest.zone, Mtg.Zone.EXILE)
	var stolen := put_battlefield(0, "Grizzly Bears")
	g.change_control(stolen, 1)
	cast("Telim'Tor's Edict", [TargetRef.card(stolen)])
	assert_eq(stolen.zone, Mtg.Zone.EXILE, "you still own it")
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 2)


func test_telimtors_edict_refuses_an_opponents_own_permanent() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Telim'Tor's Edict")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]))


# -------------------------------------------------------- Volcanic Geyser --

func test_volcanic_geyser_deals_x() -> void:
	cast("Volcanic Geyser", [TargetRef.player(1)], 4)
	assert_eq(g.players[1].life, 16)


# ---------------------------------------------------------- Early Harvest --

func test_early_harvest_untaps_basic_lands_only() -> void:
	var f1 := put_battlefield(0, "Forest")
	var f2 := put_battlefield(0, "Forest")
	var factory := put_battlefield(0, "Mishra's Factory")
	for land in [f1, f2, factory]:
		g.tap_permanent(land)
	cast("Early Harvest", [TargetRef.player(0)])
	assert_false(f1.tapped)
	assert_false(f2.tapped)
	assert_true(factory.tapped)


# ------------------------------------------------------------ Fallow Earth --

func test_fallow_earth_puts_a_land_on_top_of_its_owners_library() -> void:
	var island := put_battlefield(1, "Island")
	cast("Fallow Earth", [TargetRef.card(island)])
	assert_eq(g.players[1].library.back(), island)


# ------------------------------------------------------------ Lure of Prey --

func test_lure_of_prey_needs_an_opponents_creature_spell_this_turn() -> void:
	var spell := give_hand(0, "Lure of Prey")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, []))


func test_lure_of_prey_puts_a_green_creature_into_play() -> void:
	var a := seat(0)
	advance_to_next_turn()
	cast("Grizzly Bears", [], 0, 0, 1)
	assert_ok(g.pass_priority(1))
	var elves := give_hand(0, "Llanowar Elves")
	give_hand(0, "Hill Giant")
	a.picks = [elves]
	var lure := give_hand(0, "Lure of Prey")
	fund(0, lure)
	assert_ok(g.cast_spell(0, lure, []))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(elves.controller_id, 0)


# ---------------------------------------------------------- Seedling Charm --

func test_seedling_charm_returns_an_aura_on_a_creature() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var strength := cast("Holy Strength", [TargetRef.card(bear)])
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	cast("Seedling Charm", [TargetRef.card(strength)], 0, 0)
	assert_eq(strength.zone, Mtg.Zone.HAND)
	assert_eq(strength.owner_id, 0)


func test_seedling_charm_regenerates_a_green_creature_only() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var spell := give_hand(0, "Seedling Charm")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(giant)], 0, 1))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)], 0, 1))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bear.tapped)


func test_seedling_charm_grants_trample() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	cast("Seedling Charm", [TargetRef.card(giant)], 0, 2)
	assert_true(giant.has_keyword(Mtg.Keyword.TRAMPLE))


# ------------------------------------------------------ Seeds of Innocence --

func test_seeds_of_innocence_destroys_artifacts_and_refunds_mana_value() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var tome := put_battlefield(0, "Jayemdae Tome")
	cast("Seeds of Innocence")
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(tome.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 21)
	assert_eq(g.players[0].life, 24)


# ------------------------------------------------- Serene Heart / Tranquil --

func test_serene_heart_destroys_auras_only() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var strength := cast("Holy Strength", [TargetRef.card(bear)])
	var moon := put_battlefield(1, "Bad Moon")
	cast("Serene Heart")
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(moon.zone, Mtg.Zone.BATTLEFIELD)


func test_tranquil_domain_destroys_non_aura_enchantments_only() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var strength := cast("Holy Strength", [TargetRef.card(bear)])
	var moon := put_battlefield(1, "Bad Moon")
	cast("Tranquil Domain")
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(moon.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------- Superior Numbers --

func test_superior_numbers_deals_the_creature_surplus() -> void:
	for i in 3:
		put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	cast("Superior Numbers", [TargetRef.card(giant), TargetRef.player(1)])
	assert_eq(giant.damage, 2)


func test_superior_numbers_without_a_surplus_deals_nothing() -> void:
	put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	cast("Superior Numbers", [TargetRef.card(giant), TargetRef.player(1)])
	assert_eq(giant.damage, 0)


# ---------------------------------------------------------- Tropical Storm --

func test_tropical_storm_hits_flyers_for_x_and_blue_for_one_more() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var merfolk := put_battlefield(1, "Merfolk of the Pearl Trident")
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Tropical Storm", [], 2)
	assert_eq(angel.damage, 2)
	assert_eq(djinn.damage, 3)
	assert_eq(merfolk.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.damage, 0)


# -------------------------------------------------------- Unyaro Bee Sting --

func test_unyaro_bee_sting_deals_two() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Unyaro Bee Sting", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------- Waiting in the Weeds --

func test_waiting_in_the_weeds_counts_each_players_untapped_forests() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var tapped := put_battlefield(0, "Forest")
	g.tap_permanent(tapped)
	put_battlefield(1, "Forest")
	put_battlefield(1, "Island")
	cast("Waiting in the Weeds")
	var cats := tokens_of(0, "Cat")
	assert_eq(cats.size(), 2)
	assert_eq(tokens_of(1, "Cat").size(), 1)
	assert_true(cats[0].has_color(Mtg.ManaColor.G))
	assert_eq([cats[0].cur_power, cats[0].cur_toughness], [1, 1])


# ------------------------------------------------------------- Energy Bolt --

func test_energy_bolt_damages_or_heals_a_player() -> void:
	cast("Energy Bolt", [TargetRef.player(1)], 3, 0)
	assert_eq(g.players[1].life, 17)
	cast("Energy Bolt", [TargetRef.player(0)], 3, 1)
	assert_eq(g.players[0].life, 23)


# --------------------------------------------------------- Kaervek's Purge --

func test_kaerveks_purge_needs_mana_value_x_and_burns_the_controller() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Kaervek's Purge")
	fund(0, spell, 3)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)], 3))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)], 2))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)


func test_kaerveks_purge_regenerated_creature_deals_no_damage() -> void:
	var skeleton := put_battlefield(1, "Drudge Skeletons")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(1, skeleton, 0))
	resolve_stack()
	cast("Kaervek's Purge", [TargetRef.card(skeleton)], 2)
	assert_eq(skeleton.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20)


# --------------------------------------------------------- Prismatic Boon --

func test_prismatic_boon_protects_x_creatures_from_the_chosen_colour() -> void:
	var a := seat(0)
	a.colors = [Mtg.ManaColor.R]
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	cast("Prismatic Boon", [TargetRef.card(bear), TargetRef.card(giant)], 2)
	assert_true((bear.cur_protection & Mtg.ManaColor.R) != 0)
	assert_true((giant.cur_protection & Mtg.ManaColor.R) != 0)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(bear)]))


# ---------------------------------------------------------- Savage Twister --

func test_savage_twister_hits_every_creature() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	cast("Savage Twister", [], 2)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(theirs.damage, 2)


# ------------------------------------------------------------- Sealed Fate --

func test_sealed_fate_exiles_one_of_the_top_x_and_keeps_the_rest_on_top() -> void:
	var a := seat(0)
	var giant := on_top(1, "Hill Giant")
	var bolt := on_top(1, "Lightning Bolt")
	var ring := on_top(1, "Sol Ring")
	var size := g.players[1].library.size()
	a.picks = [giant]
	cast("Sealed Fate", [TargetRef.player(1)], 3)
	assert_eq(giant.zone, Mtg.Zone.EXILE)
	var lib := g.players[1].library
	assert_eq(lib.size(), size - 1)
	assert_has([lib[lib.size() - 1], lib[lib.size() - 2]], bolt)
	assert_has([lib[lib.size() - 1], lib[lib.size() - 2]], ring)


func test_sealed_fate_for_zero_looks_at_nothing() -> void:
	var ring := on_top(1, "Sol Ring")
	var size := g.players[1].library.size()
	cast("Sealed Fate", [TargetRef.player(1)], 0)
	assert_eq(g.players[1].library.size(), size)
	assert_eq(g.players[1].library.back(), ring)


# ---------------------------------------------------- Vitalizing Cascade --

func test_vitalizing_cascade_gains_x_plus_three() -> void:
	cast("Vitalizing Cascade", [], 4)
	assert_eq(g.players[0].life, 27)
	cast("Vitalizing Cascade", [], 0)
	assert_eq(g.players[0].life, 30)
