extends GameTest
## Pack 8, batch B4: the white, blue and black Mirage instants and sorceries
## (cards/sets/mir/_spells.gd). Each card's distinguishing clause is driven
## through the public cast/priority API; choices are answered by a scripted
## seat so both branches of every "you may" and "choose" are pinned.


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


# ------------------------------------------------------------- Afterlife --

func test_afterlife_ignores_regeneration_and_pays_the_creatures_controller() -> void:
	var skeleton := put_battlefield(1, "Drudge Skeletons")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(1, skeleton, 0))
	resolve_stack()
	assert_eq(skeleton.regeneration_shields, 1)
	cast("Afterlife", [TargetRef.card(skeleton)])
	assert_eq(skeleton.zone, Mtg.Zone.GRAVEYARD, "it can't be regenerated")
	var spirits := tokens_of(1, "Spirit")
	assert_eq(spirits.size(), 1, "the creature's controller gets the Spirit")
	assert_eq(tokens_of(0, "Spirit").size(), 0)
	var spirit := spirits[0]
	assert_eq([spirit.cur_power, spirit.cur_toughness], [1, 1])
	assert_true(spirit.has_keyword(Mtg.Keyword.FLYING))
	assert_true(spirit.has_color(Mtg.ManaColor.W))


func test_afterlife_fizzles_with_no_spirit_when_its_target_is_gone() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Afterlife")
	fund(0, spell)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	g.return_to_hand(bear)   # bounced in response
	resolve_stack()
	assert_eq(tokens_of(1, "Spirit").size(), 0)
	assert_eq(tokens_of(0, "Spirit").size(), 0)


func test_afterlife_on_your_own_creature_gives_you_the_spirit() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Afterlife", [TargetRef.card(bear)])
	assert_eq(tokens_of(0, "Spirit").size(), 1)


# ------------------------------------------------------------ Disempower --

func test_disempower_puts_an_artifact_on_top_of_its_owners_library() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	cast("Disempower", [TargetRef.card(ring)])
	assert_eq(ring.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].library.back(), ring)


func test_disempower_refuses_a_creature() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Disempower")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]))


# ---------------------------------------------------------- Illumination --

func test_illumination_counters_an_artifact_and_its_controller_gains_its_mana_value() -> void:
	var tome := give_hand(0, "Jayemdae Tome")
	fund(0, tome)
	assert_ok(g.cast_spell(0, tome, []))
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Illumination")
	fund(1, spell)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(tome)]))
	resolve_stack()
	assert_eq(tome.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 24, "the countered spell's controller gains 4")
	assert_eq(g.players[1].life, 20)


func test_illumination_refuses_a_creature_spell() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	fund(0, bear)
	assert_ok(g.cast_spell(0, bear, []))
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Illumination")
	fund(1, spell)
	assert_refused(g.cast_spell(1, spell, [TargetRef.card(bear)]))


# ----------------------------------------------------------- Ivory Charm --

func test_ivory_charm_shrinks_every_creature() -> void:
	var mine := put_battlefield(0, "Hill Giant")
	var theirs := put_battlefield(1, "Grizzly Bears")
	cast("Ivory Charm", [], 0, 0)
	assert_eq(mine.cur_power, 1)
	assert_eq(theirs.cur_power, 0)
	assert_eq(theirs.cur_toughness, 2)


func test_ivory_charm_taps_target_creature() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Ivory Charm", [TargetRef.card(bear)], 0, 1)
	assert_true(bear.tapped)


func test_ivory_charm_prevents_the_next_point() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	cast("Ivory Charm", [TargetRef.card(giant)], 0, 2)
	cast("Lightning Bolt", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.damage, 2)


## Fifth Edition's damage-prevention window (RulesOptions fork): only the
## prevention mode is one of "the damage prevention fast effects".
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func test_ivory_charm_prevention_mode_is_legal_in_the_1997_window() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, Duelist.new())
	var wurm := put_battlefield(0, "Craw Wurm")
	var charm := give_hand(1, "Ivory Charm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(1, charm, [], 0, 0), "no other kind of fast effects")
	assert_ok(g.cast_spell(1, charm, [TargetRef.player(1)], 0, 2))
	resolve_stack()
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(g.players[1].life, 15, "six from the Wurm, one prevented")


# ---------------------------------------------------- Jabari's Influence --

func test_jabaris_influence_is_only_cast_after_combat() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Jabari's Influence")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]))


func test_jabaris_influence_steals_an_attacker_and_weakens_it() -> void:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var idle := put_battlefield(1, "Hill Giant")
	run_combat([bear.id])
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(1))
	var spell := give_hand(0, "Jabari's Influence")
	fund(0, spell)
	# A creature that did not attack is not a legal target.
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(idle)]), "attacked")
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0)
	assert_eq(bear.cur_power, 1, "a -1/-0 counter")
	assert_eq(bear.cur_toughness, 2)


func test_jabaris_influence_refuses_a_black_attacker() -> void:
	advance_to_next_turn()
	var zombie := put_battlefield(1, "Scathe Zombies")
	run_combat([zombie.id])
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(1))
	var spell := give_hand(0, "Jabari's Influence")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(zombie)]))


# ---------------------------------------------------- Mangara's Blessing --

func test_mangaras_blessing_gains_five() -> void:
	cast("Mangara's Blessing")
	assert_eq(g.players[0].life, 25)


func test_mangaras_blessing_comes_back_when_an_opponent_makes_you_discard_it() -> void:
	advance_to_next_turn()
	var blessing := give_hand(0, "Mangara's Blessing")
	cast("Mind Twist", [TargetRef.player(0)], 1, 0, 1)
	assert_eq(blessing.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 22, "gain 2 when an opponent's spell discards it")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(blessing.zone, Mtg.Zone.HAND, "back at the beginning of the next end step")


func test_mangaras_blessing_stays_gone_if_it_left_the_graveyard() -> void:
	advance_to_next_turn()
	var blessing := give_hand(0, "Mangara's Blessing")
	cast("Mind Twist", [TargetRef.player(0)], 1, 0, 1)
	assert_eq(g.players[0].life, 22)
	g.exile_from_graveyard(blessing)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(blessing.zone, Mtg.Zone.EXILE)


func test_mangaras_blessing_ignores_your_own_discard() -> void:
	var blessing := give_hand(0, "Mangara's Blessing")
	cast("Mind Twist", [TargetRef.player(0)], 1)
	assert_eq(blessing.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(blessing.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------- Dissipate --

func test_dissipate_exiles_the_spell_it_counters() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	fund(0, bear)
	assert_ok(g.cast_spell(0, bear, []))
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Dissipate")
	fund(1, spell)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "exiled instead of going to the graveyard")
	assert_false(g.players[0].graveyard.has(bear))
	assert_eq(spell.zone, Mtg.Zone.GRAVEYARD, "Dissipate itself is not exiled")


func test_dissipate_exiles_a_countered_instant() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	fund(0, bolt)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Dissipate")
	fund(1, spell)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[1].life, 20)


# ------------------------------------------------------------ Dream Cache --

func test_dream_cache_draws_three_and_buries_two() -> void:
	var a := seat(0)
	var before := g.players[0].hand.size()
	var bolt := give_hand(0, "Lightning Bolt")
	var growth := give_hand(0, "Giant Growth")
	a.options = ["bottom"]
	a.picks = [bolt, growth]
	cast("Dream Cache")
	assert_eq(g.players[0].hand.size(), before + 3)
	assert_eq(bolt.zone, Mtg.Zone.LIBRARY)
	assert_eq(growth.zone, Mtg.Zone.LIBRARY)
	var bottom: Array = [g.players[0].library[0], g.players[0].library[1]]
	assert_has(bottom, bolt)
	assert_has(bottom, growth)


func test_dream_cache_can_put_both_on_top() -> void:
	var a := seat(0)
	var before := g.players[0].hand.size()
	var bolt := give_hand(0, "Lightning Bolt")
	a.options = ["top"]
	a.picks = [bolt]
	cast("Dream Cache")
	assert_eq(g.players[0].hand.size(), before + 2)
	var lib := g.players[0].library
	assert_has([lib[lib.size() - 1], lib[lib.size() - 2]], bolt)


# ------------------------------------------------------------- Ether Well --

func test_ether_well_puts_a_creature_on_top() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Ether Well", [TargetRef.card(bear)])
	assert_eq(g.players[1].library.back(), bear)


func test_ether_well_may_bottom_a_red_creature() -> void:
	var a := seat(0)
	a.answers = [true]
	var giant := put_battlefield(1, "Hill Giant")
	cast("Ether Well", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].library[0], giant)


func test_ether_well_red_creature_may_still_go_on_top() -> void:
	var a := seat(0)
	a.answers = [false]
	var giant := put_battlefield(1, "Hill Giant")
	cast("Ether Well", [TargetRef.card(giant)])
	assert_eq(g.players[1].library.back(), giant)


# ------------------------------------------------------------------ Flash --

func test_flash_puts_a_creature_in_and_keeps_it_for_the_reduced_cost() -> void:
	var a := seat(0)
	var bear := give_hand(0, "Grizzly Bears")
	var flash := give_hand(0, "Flash")
	fund(0, flash)
	assert_ok(g.cast_spell(0, flash, []))
	add_mana(0, Mtg.ManaColor.G)
	a.answers = [true, true]
	a.picks = [bear]
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 0, "{1}{G} reduced by {2} is {G}")


func test_flash_sacrifices_the_creature_when_not_paid() -> void:
	var a := seat(0)
	var bear := give_hand(0, "Grizzly Bears")
	a.answers = [true, false]
	a.picks = [bear]
	cast("Flash")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_flash_may_put_nothing() -> void:
	var a := seat(0)
	var bear := give_hand(0, "Grizzly Bears")
	a.answers = [false]
	cast("Flash")
	assert_eq(bear.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------------ Jolt --

func test_jolt_taps_and_draws_next_upkeep() -> void:
	var a := seat(0)
	a.options = ["tap"]
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Jolt", [TargetRef.card(bear)])
	assert_true(bear.tapped)
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 1)


func test_jolt_may_leave_the_target_alone() -> void:
	var a := seat(0)
	a.options = ["leave"]
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Jolt", [TargetRef.card(bear)])
	assert_false(bear.tapped)


func test_jolt_untaps_a_land() -> void:
	var a := seat(0)
	a.options = ["untap"]
	var forest := put_battlefield(0, "Forest")
	g.tap_permanent(forest)
	cast("Jolt", [TargetRef.card(forest)])
	assert_false(forest.tapped)


func test_jolt_refuses_an_enchantment() -> void:
	var moon := put_battlefield(1, "Bad Moon")
	var spell := give_hand(0, "Jolt")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(moon)]))


# ----------------------------------------------------------------- Meddle --

func test_meddle_moves_a_single_creature_target() -> void:
	var a := seat(1)
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var growth := give_hand(0, "Giant Growth")
	fund(0, growth)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(mine)]))
	assert_ok(g.pass_priority(0))
	var meddle := give_hand(1, "Meddle")
	fund(1, meddle)
	a.options = ["Hill Giant"]
	assert_ok(g.cast_spell(1, meddle, [TargetRef.card(growth)]))
	resolve_stack()
	assert_eq(theirs.cur_power, 6)
	assert_eq(mine.cur_power, 2)


func test_meddle_does_nothing_to_a_spell_aimed_at_a_player() -> void:
	put_battlefield(1, "Hill Giant")
	var bolt := give_hand(0, "Lightning Bolt")
	fund(0, bolt)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	var meddle := give_hand(1, "Meddle")
	fund(1, meddle)
	assert_ok(g.cast_spell(1, meddle, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)


# -------------------------------------------------------------- Mind Bend --

func test_mind_bend_rewrites_a_protection_colour() -> void:
	var a := seat(0)
	a.options = ["white", "blue"]
	var knight := put_battlefield(1, "Black Knight")
	assert_true((knight.cur_protection & Mtg.ManaColor.W) != 0)
	cast("Mind Bend", [TargetRef.card(knight)])
	assert_eq(knight.cur_protection & Mtg.ManaColor.W, 0)
	assert_true((knight.cur_protection & Mtg.ManaColor.U) != 0)


func test_mind_bend_rewrites_a_landwalk() -> void:
	var a := seat(0)
	a.options = ["swamp", "island"]
	var wraith := put_battlefield(1, "Bog Wraith")
	cast("Mind Bend", [TargetRef.card(wraith)])
	assert_true(wraith.cur_landwalk.has("island"))
	assert_false(wraith.cur_landwalk.has("swamp"))


# ----------------------------------------------------- Political Trickery --

func test_political_trickery_swaps_two_lands() -> void:
	var forest := put_battlefield(0, "Forest")
	var island := put_battlefield(1, "Island")
	cast("Political Trickery", [TargetRef.card(forest), TargetRef.card(island)])
	assert_eq(forest.controller_id, 1)
	assert_eq(island.controller_id, 0)


func test_political_trickery_needs_one_land_from_each_side() -> void:
	var forest := put_battlefield(0, "Forest")
	var other := put_battlefield(0, "Island")
	var spell := give_hand(0, "Political Trickery")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(forest), TargetRef.card(other)]))


# ------------------------------------------------------------- Polymorph --

func test_polymorph_replaces_the_creature_with_the_first_creature_revealed() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := on_top(1, "Hill Giant")
	on_top(1, "Forest")
	on_top(1, "Forest")
	var size := g.players[1].library.size()
	cast("Polymorph", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 1)
	assert_eq(g.players[1].library.size(), size - 1, "the revealed lands are shuffled back")


func test_polymorph_with_no_creature_left_reveals_everything_and_puts_nothing() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var size := g.players[1].library.size()
	cast("Polymorph", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].library.size(), size)
	assert_eq(g.players[1].creatures().size(), 0)


# -------------------------------------------------------- Prismatic Lace --

func test_prismatic_lace_sets_the_chosen_colours() -> void:
	var a := seat(0)
	a.colors = [Mtg.ManaColor.U | Mtg.ManaColor.R]
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Prismatic Lace", [TargetRef.card(bear)])
	assert_eq(bear.cur_colors, Mtg.ManaColor.U | Mtg.ManaColor.R)


# ------------------------------------------------------- Psychic Transfer --

func test_psychic_transfer_exchanges_close_life_totals() -> void:
	g.adjust_life(0, -5)
	cast("Psychic Transfer", [TargetRef.player(1)])
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 15)


func test_psychic_transfer_does_nothing_beyond_five() -> void:
	g.adjust_life(0, -6)
	cast("Psychic Transfer", [TargetRef.player(1)])
	assert_eq(g.players[0].life, 14)
	assert_eq(g.players[1].life, 20)


# ------------------------------------------------------------- Tidal Wave --

func test_tidal_wave_makes_a_defending_wall_for_one_turn() -> void:
	cast("Tidal Wave")
	var walls := tokens_of(0, "Wall")
	assert_eq(walls.size(), 1)
	var wall := walls[0]
	assert_eq([wall.cur_power, wall.cur_toughness], [5, 5])
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	assert_true(wall.has_color(Mtg.ManaColor.U))
	assert_true(wall.has_subtype("wall"))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(tokens_of(0, "Wall").size(), 0, "sacrificed at the next end step")


# ----------------------------------------------------------- Ashen Powder --

func test_ashen_powder_takes_an_opponents_dead_creature() -> void:
	var bear := bury(1, "Grizzly Bears")
	cast("Ashen Powder", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 0)
	assert_eq(bear.owner_id, 1)


func test_ashen_powder_refuses_your_own_graveyard() -> void:
	var bear := bury(0, "Grizzly Bears")
	var spell := give_hand(0, "Ashen Powder")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]))


# ----------------------------------------------------------- Bone Harvest --

func test_bone_harvest_stacks_creature_cards_and_draws_later() -> void:
	var a := seat(0)
	var bear := bury(0, "Grizzly Bears")
	var giant := bury(0, "Hill Giant")
	a.picks = [giant, bear]
	cast("Bone Harvest", [TargetRef.card(bear), TargetRef.card(giant)])
	var lib := g.players[0].library
	assert_eq(lib[lib.size() - 1], giant)
	assert_eq(lib[lib.size() - 2], bear)
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 1)


func test_bone_harvest_may_take_no_targets() -> void:
	cast("Bone Harvest", [])
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 1)


# ---------------------------------------------------------- Choking Sands --

func test_choking_sands_burns_the_controller_of_a_nonbasic_land() -> void:
	var factory := put_battlefield(1, "Mishra's Factory")
	cast("Choking Sands", [TargetRef.card(factory)])
	assert_eq(factory.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)


func test_choking_sands_basic_land_deals_no_damage() -> void:
	var forest := put_battlefield(1, "Forest")
	cast("Choking Sands", [TargetRef.card(forest)])
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


func test_choking_sands_refuses_a_swamp() -> void:
	var swamp := put_battlefield(1, "Swamp")
	var spell := give_hand(0, "Choking Sands")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(swamp)]))


# ------------------------------------------------------------ Ebony Charm --

func test_ebony_charm_drains_one() -> void:
	cast("Ebony Charm", [TargetRef.player(1)], 0, 0)
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 21)


func test_ebony_charm_exiles_up_to_three_cards_from_one_graveyard() -> void:
	var a := bury(1, "Grizzly Bears")
	var b := bury(1, "Sol Ring")
	var c := bury(1, "Hill Giant")
	cast("Ebony Charm", [TargetRef.card(a), TargetRef.card(b), TargetRef.card(c)], 0, 1)
	for inst in [a, b, c]:
		assert_eq(inst.zone, Mtg.Zone.EXILE)


func test_ebony_charm_refuses_cards_from_two_graveyards() -> void:
	var a := bury(1, "Grizzly Bears")
	var b := bury(0, "Hill Giant")
	var spell := give_hand(0, "Ebony Charm")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(a), TargetRef.card(b)], 0, 1))


func test_ebony_charm_grants_fear() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Ebony Charm", [TargetRef.card(bear)], 0, 2)
	assert_true(bear.has_keyword(Mtg.Keyword.FEAR))
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.FEAR))


# ------------------------------------------------------ Infernal Contract --

func test_infernal_contract_draws_four_and_halves_life_rounded_up() -> void:
	g.adjust_life(0, -5)
	var before := g.players[0].hand.size()
	cast("Infernal Contract")
	assert_eq(g.players[0].hand.size(), before + 4)
	assert_eq(g.players[0].life, 7, "15 loses 8")


# ----------------------------------------------------------- Kaervek's Hex --

func test_kaerveks_hex_hits_nonblack_and_green_twice() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var zombie := put_battlefield(1, "Scathe Zombies")
	cast("Kaervek's Hex")
	assert_eq(giant.damage, 1)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "green takes 2")
	assert_eq(zombie.damage, 0, "black creatures are spared")


# --------------------------------------------------------- Nocturnal Raid --

func test_nocturnal_raid_pumps_black_creatures_on_both_sides() -> void:
	var mine := put_battlefield(0, "Scathe Zombies")
	var theirs := put_battlefield(1, "Scathe Zombies")
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Nocturnal Raid")
	assert_eq(mine.cur_power, 4)
	assert_eq(theirs.cur_power, 4)
	assert_eq(bear.cur_power, 2)


# ------------------------------------------------------- Painful Memories --

func test_painful_memories_puts_the_chosen_card_on_top() -> void:
	var a := seat(0)
	var before := g.players[1].hand.size()
	give_hand(1, "Forest")
	var bolt := give_hand(1, "Lightning Bolt")
	a.picks = [bolt]
	cast("Painful Memories", [TargetRef.player(1)])
	assert_eq(bolt.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].library.back(), bolt)
	assert_eq(g.players[1].hand.size(), before + 1)


# -------------------------------------------------------- Reign of Terror --

func test_reign_of_terror_kills_green_without_regeneration_and_costs_life() -> void:
	var a := seat(0)
	a.options = ["green"]
	var b1 := put_battlefield(1, "Grizzly Bears")
	var b2 := put_battlefield(1, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	var giant := put_battlefield(0, "Hill Giant")
	cast("Reign of Terror")
	assert_eq(b1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b2.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lions.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 16)


func test_reign_of_terror_white_branch() -> void:
	var a := seat(0)
	a.options = ["white"]
	var bear := put_battlefield(1, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	cast("Reign of Terror")
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 18)


# ---------------------------------------------------------- Shallow Grave --

func test_shallow_grave_returns_the_top_creature_with_haste_then_exiles_it() -> void:
	var bear := bury(0, "Grizzly Bears")
	var giant := bury(0, "Hill Giant")
	bury(0, "Sol Ring")
	cast("Shallow Grave")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_true(giant.has_keyword(Mtg.Keyword.HASTE))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.EXILE)


func test_shallow_grave_with_no_creature_card_does_nothing() -> void:
	var ring := bury(0, "Sol Ring")
	cast("Shallow Grave")
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].battlefield.size(), 0)


# -------------------------------------------------------------- Soul Rend --

func test_soul_rend_destroys_only_a_white_creature() -> void:
	var lions := put_battlefield(1, "Savannah Lions")
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Soul Rend", [TargetRef.card(lions)])
	cast("Soul Rend", [TargetRef.card(bear)])
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 2, "both draw next upkeep")


# ------------------------------------------------------------- Soulshriek --

func test_soulshriek_pumps_by_creature_cards_and_sacrifices() -> void:
	bury(0, "Grizzly Bears")
	bury(0, "Hill Giant")
	bury(0, "Sol Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Soulshriek", [TargetRef.card(bear)])
	assert_eq(bear.cur_power, 4)
	assert_eq(bear.cur_toughness, 2)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_soulshriek_refuses_an_opponents_creature() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Soulshriek")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]))


# ----------------------------------------------------------------- Stupor --

func test_stupor_discards_one_at_random_then_one_chosen() -> void:
	var before := g.players[1].hand.size()
	give_hand(1, "Forest")
	give_hand(1, "Island")
	give_hand(1, "Swamp")
	cast("Stupor", [TargetRef.player(1)])
	assert_eq(g.players[1].hand.size(), before + 1)
	assert_eq(g.players[1].graveyard.size(), 2)


func test_stupor_refuses_yourself() -> void:
	var spell := give_hand(0, "Stupor")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.player(0)]))
