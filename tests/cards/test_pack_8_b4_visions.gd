extends GameTest
## Pack 8, batch B4: the Visions instants and sorceries
## (cards/sets/vis/_spells.gd). Same scripted-seat harness as
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



# -------------------------------------------------------------- Hope Charm --

func test_hope_charm_first_strike_and_life() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Hope Charm", [TargetRef.card(bear)], 0, 0)
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	cast("Hope Charm", [TargetRef.player(1)], 0, 1)
	assert_eq(g.players[1].life, 22)


func test_hope_charm_destroys_an_aura_but_not_another_enchantment() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var strength := cast("Holy Strength", [TargetRef.card(bear)])
	var moon := put_battlefield(1, "Bad Moon")
	var spell := give_hand(0, "Hope Charm")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(moon)], 0, 2))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(strength)], 0, 2))
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------- Miraculous Recovery --

func test_miraculous_recovery_returns_a_creature_with_a_counter() -> void:
	var bear := bury(0, "Grizzly Bears")
	cast("Miraculous Recovery", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 0)
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])


func test_miraculous_recovery_refuses_an_opponents_graveyard() -> void:
	var bear := bury(1, "Grizzly Bears")
	var spell := give_hand(0, "Miraculous Recovery")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]))


# ------------------------------------------------ Retribution of the Meek --

func test_retribution_of_the_meek_kills_power_four_and_up() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var angel := put_battlefield(1, "Serra Angel")
	var wurm := put_battlefield(0, "Craw Wurm")
	cast("Retribution of the Meek")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- Warrior's Honor --

func test_warriors_honor_pumps_only_your_creatures() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	cast("Warrior's Honor")
	assert_eq([mine.cur_power, mine.cur_toughness], [3, 3])
	assert_eq([theirs.cur_power, theirs.cur_toughness], [2, 2])


# ------------------------------------------------------------------ Remedy --

func test_remedy_divides_five_prevention_among_targets() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(1, "Remedy")
	fund(1, spell)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(giant, 3), TargetRef.player(1, 2)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(giant)])
	cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(giant.damage, 0, "three prevented on the Giant")
	assert_eq(g.players[1].life, 19, "two of the three prevented on the player")


func test_remedy_refuses_a_division_that_is_not_five() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Remedy")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(giant, 3), TargetRef.player(1, 1)]))


## Fifth Edition's damage-prevention window: Remedy is one of the family.
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func test_remedy_is_legal_in_the_1997_damage_window() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, Duelist.new())
	var wurm := put_battlefield(0, "Craw Wurm")
	var remedy := give_hand(1, "Remedy")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	assert_ok(g.end_damage_prevention(0))
	fund(1, remedy)
	assert_ok(g.cast_spell(1, remedy, [TargetRef.player(1, 5)]))
	resolve_stack()
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(g.players[1].life, 19, "six from the Wurm, five prevented")


# --------------------------------------------------------------- Desertion --

func test_desertion_steals_a_countered_creature_spell() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	fund(0, bear)
	assert_ok(g.cast_spell(0, bear, []))
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Desertion")
	fund(1, spell)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 1)
	assert_eq(bear.owner_id, 0)
	assert_true(bear.summoning_sick)


func test_desertion_steals_an_artifact_spell() -> void:
	var ring := give_hand(0, "Sol Ring")
	fund(0, ring)
	assert_ok(g.cast_spell(0, ring, []))
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Desertion")
	fund(1, spell)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(ring.controller_id, 1)


func test_desertion_sends_any_other_spell_to_the_graveyard() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	fund(0, bolt)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Desertion")
	fund(1, spell)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


# --------------------------------------------------------------- Solfatara --

func test_solfatara_stops_land_drops_this_turn_and_draws_next_upkeep() -> void:
	var forest := give_hand(0, "Forest")
	var hand := g.players[0].hand.size()
	cast("Solfatara", [TargetRef.player(0)])
	assert_refused(g.play_land(0, forest), "Solfatara")
	assert_eq(g.players[0].hand.size(), hand, "nothing drawn yet")
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), hand + 1, "the slow cantrip")


func test_solfatara_ends_with_the_turn_and_spares_the_other_player() -> void:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	var spell := give_hand(0, "Solfatara")
	fund(0, spell)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
	resolve_stack()
	var forest := give_hand(1, "Forest")
	assert_refused(g.play_land(1, forest), "Solfatara")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.play_land(1, forest))


# --------------------------------------------------------------- Foreshadow --

func test_foreshadow_draws_when_the_named_card_is_milled() -> void:
	var a := seat(0)
	a.options = ["Forest"]
	var before := g.players[0].hand.size()
	var lib := g.players[1].library.size()
	cast("Foreshadow", [TargetRef.player(1)])
	assert_eq(g.players[1].library.size(), lib - 1)
	assert_eq(g.players[0].hand.size(), before + 1)
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 2, "and the slow cantrip")


func test_foreshadow_misses_on_another_name() -> void:
	var a := seat(0)
	a.options = ["Forest"]
	var bolt := on_top(1, "Lightning Bolt")
	var before := g.players[0].hand.size()
	cast("Foreshadow", [TargetRef.player(1)])
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), before)


func test_foreshadow_refuses_yourself() -> void:
	var spell := give_hand(0, "Foreshadow")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.player(0)]))


# ------------------------------------------------------------------ Impulse --

func test_impulse_keeps_one_and_bottoms_the_rest() -> void:
	var a := seat(0)
	var cards: Array[CardInstance] = []
	for n in ["Hill Giant", "Lightning Bolt", "Sol Ring", "Giant Growth"]:
		cards.append(on_top(0, n))
	var size := g.players[0].library.size()
	a.picks = [cards[1]]
	cast("Impulse")
	assert_eq(cards[1].zone, Mtg.Zone.HAND)
	var lib := g.players[0].library
	assert_eq(lib.size(), size - 1)
	var bottom: Array = [lib[0], lib[1], lib[2]]
	for i in [0, 2, 3]:
		assert_has(bottom, cards[i])


# -------------------------------------------------------------- Inspiration --

func test_inspiration_target_player_draws_two() -> void:
	var before := g.players[1].hand.size()
	cast("Inspiration", [TargetRef.player(1)])
	assert_eq(g.players[1].hand.size(), before + 2)


# ------------------------------------------------------------ Funeral Charm --

func test_funeral_charm_target_player_discards_their_choice() -> void:
	var a := seat(1)
	var forest := give_hand(1, "Forest")
	var bolt := give_hand(1, "Lightning Bolt")
	a.picks = []
	var before := g.players[1].hand.size()
	cast("Funeral Charm", [TargetRef.player(1)], 0, 0)
	assert_eq(g.players[1].hand.size(), before - 1)
	assert_true(forest.zone == Mtg.Zone.GRAVEYARD or bolt.zone == Mtg.Zone.GRAVEYARD)


func test_funeral_charm_pump_and_swampwalk() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Funeral Charm", [TargetRef.card(bear)], 0, 1)
	assert_eq([bear.cur_power, bear.cur_toughness], [4, 1])
	cast("Funeral Charm", [TargetRef.card(bear)], 0, 2)
	assert_true(bear.cur_landwalk.has("swamp"))


# ------------------------------------------------------------- Hearth Charm --

func test_hearth_charm_destroys_an_artifact_creature_only() -> void:
	var bird := put_battlefield(1, "Ornithopter")
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Hearth Charm")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)], 0, 0))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bird)], 0, 0))
	resolve_stack()
	assert_eq(bird.zone, Mtg.Zone.GRAVEYARD)


func test_hearth_charm_pumps_attackers_only() -> void:
	var attacker := put_battlefield(0, "Grizzly Bears")
	var home := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	cast("Hearth Charm", [], 0, 1)
	assert_eq(attacker.cur_power, 3)
	assert_eq(home.cur_power, 2)


func test_hearth_charm_makes_a_small_creature_unblockable() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var spell := give_hand(0, "Hearth Charm")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(giant)], 0, 2))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)], 0, 2))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.UNBLOCKABLE))


# ------------------------------------------------------------ Creeping Mold --

func test_creeping_mold_hits_artifact_enchantment_or_land_not_creature() -> void:
	var island := put_battlefield(1, "Island")
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Creeping Mold")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(island)]))
	resolve_stack()
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)
	var moon := put_battlefield(1, "Bad Moon")
	cast("Creeping Mold", [TargetRef.card(moon)])
	assert_eq(moon.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------ Emerald Charm --

func test_emerald_charm_untaps_a_permanent() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	g.tap_permanent(ring)
	cast("Emerald Charm", [TargetRef.card(ring)], 0, 0)
	assert_false(ring.tapped)


func test_emerald_charm_destroys_a_non_aura_enchantment() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var strength := cast("Holy Strength", [TargetRef.card(bear)])
	var moon := put_battlefield(1, "Bad Moon")
	var spell := give_hand(0, "Emerald Charm")
	fund(0, spell)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(strength)], 0, 1))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(moon)], 0, 1))
	resolve_stack()
	assert_eq(moon.zone, Mtg.Zone.GRAVEYARD)


func test_emerald_charm_removes_flying_until_end_of_turn() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	cast("Emerald Charm", [TargetRef.card(angel)], 0, 2)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))


# ----------------------------------------------------------- Feral Instinct --

func test_feral_instinct_pumps_and_draws_next_upkeep() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Feral Instinct", [TargetRef.card(bear)])
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 1)


# ------------------------------------------------------------------ Simoon --

func test_simoon_pings_each_creature_the_target_opponent_controls() -> void:
	var elf := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Llanowar Elves")
	cast("Simoon", [TargetRef.player(1)])
	assert_eq(elf.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 1)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(mine.damage, 0)
