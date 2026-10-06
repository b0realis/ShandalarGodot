extends GameTest
## Pack 9 (the Tempest block), batch B4: the black and red Tempest
## creatures of cards/sets/tmp/_creatures.gd — Bounty Hunter, Carrionette,
## Coffin Queen, Darkling Stalker, Marsh Lurker, Minion of the Wastes, Pit
## Imp, Rats of Rath, Screeching Harpy, Skyshroud Vampire, Souldrinker,
## Canyon Drake, Firefly, Fireslinger, Flowstone Giant, Flowstone Wyvern,
## Mogg Fanatic, Mogg Raider, Mogg Squad, Opportunist, Pallimud, Sandstone
## Warrior, Starke of Rath. Each test drives the card through the public
## API and pins the clause that makes it that card, with its refused case.

const CLAIMED := ["Bounty Hunter", "Carrionette", "Coffin Queen", "Darkling Stalker",
	"Marsh Lurker", "Minion of the Wastes", "Pit Imp", "Rats of Rath", "Screeching Harpy",
	"Skyshroud Vampire", "Souldrinker", "Canyon Drake", "Firefly", "Fireslinger",
	"Flowstone Giant", "Flowstone Wyvern", "Mogg Fanatic", "Mogg Raider", "Mogg Squad",
	"Opportunist", "Pallimud", "Sandstone Warrior", "Starke of Rath"]


## FIFO answers; an empty queue falls back to the caller's hint (and a card
## pick to the first candidate).
class Scripted extends DecisionAgent:
	var options: Array = []
	var answers: Array = []
	var picks: Array = []

	func answer_option(_g: MtgGame, _p: int, _prompt: String, _labels: Array[String], hint: int) -> int:
		return int(options.pop_front()) if not options.is_empty() else hint

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		if not picks.is_empty():
			var want: Variant = picks.pop_front()
			for c in candidates:
				if c == want:
					return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a

## Exactly the mana [param card]'s cost asks for (X paid as colourless).
func fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

func cast_only(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	return card

func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	var card := cast_only(card_name, targets, pid)
	resolve_stack()
	return card

## A card of [param card_name] in [param pid]'s graveyard (it died).
func dead(pid: int, card_name: String) -> CardInstance:
	var inst := put_battlefield(pid, card_name)
	g.sacrifice_permanent(inst)
	assert_eq(inst.zone, Mtg.Zone.GRAVEYARD)
	return inst

## P0 attacks with [param attacker]; P1 is to declare blockers.
func _attack(attacker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Bounty Hunter ----------------------------------------------------------

func test_bounty_hunter_marks_a_nonblack_creature_and_later_collects() -> void:
	var hunter := put_battlefield(0, "Bounty Hunter")
	var bear := put_battlefield(1, "Grizzly Bears")
	var zombie := put_battlefield(1, "Scathe Zombies")
	assert_refused(g.activate_ability(0, hunter, 0, [TargetRef.card(zombie)]))
	assert_refused(g.activate_ability(0, hunter, 1, [TargetRef.card(bear)]), "")
	assert_ok(g.activate_ability(0, hunter, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(int(bear.counters.get("bounty", 0)), 1)
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "a bounty counter is no P/T counter")
	assert_refused(g.activate_ability(0, hunter, 1, [TargetRef.card(bear)]), "")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_ok(g.activate_ability(0, hunter, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# --- Carrionette ------------------------------------------------------------

func test_carrionette_works_only_from_the_graveyard_and_exiles_both() -> void:
	var p1 := seat(1)
	p1.answers = [false]
	var puppet := put_battlefield(0, "Carrionette")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, puppet, 0, [TargetRef.card(giant)]), "zone")
	g.sacrifice_permanent(puppet)
	assert_ok(g.activate_ability(0, puppet, 0, [TargetRef.card(giant)]))
	add_mana(1, Mtg.ManaColor.C, 2)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.EXILE)
	assert_eq(puppet.zone, Mtg.Zone.EXILE)

func test_carrionette_paid_for_spares_both() -> void:
	var p1 := seat(1)
	p1.answers = [true]
	var puppet := dead(0, "Carrionette")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, puppet, 0, [TargetRef.card(giant)]))
	add_mana(1, Mtg.ManaColor.C, 2)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(puppet.zone, Mtg.Zone.GRAVEYARD)

func test_carrionette_without_the_two_mana_cannot_be_paid_off() -> void:
	var puppet := dead(0, "Carrionette")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, puppet, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.EXILE, "P1 had nothing to pay with")
	assert_true(CardRegistry.get_card("Carrionette").activated_abilities[0].effects[0] is ExileEffect)


# --- Coffin Queen -----------------------------------------------------------

func _raise_with_queen() -> Array:
	var queen := put_battlefield(0, "Coffin Queen")
	var giant := dead(1, "Hill Giant")
	var forest := dead(0, "Forest")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, queen, 0, [TargetRef.card(forest)]))
	assert_ok(g.activate_ability(0, queen, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 0, "under the Queen's controller")
	return [queen, giant]

func test_coffin_queen_keeps_her_creature_while_she_stays_tapped() -> void:
	var pair := _raise_with_queen()
	var queen: CardInstance = pair[0]
	var giant: CardInstance = pair[1]
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_true(queen.tapped, "the default seat chose not to untap her")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	var twiddle := cast_only("Twiddle", [TargetRef.card(queen)])
	resolve_stack()
	assert_eq(twiddle.zone, Mtg.Zone.GRAVEYARD)
	assert_false(queen.tapped)
	assert_eq(giant.zone, Mtg.Zone.EXILE, "she became untapped")

func test_coffin_queen_untapping_in_the_untap_step_exiles_the_creature() -> void:
	var p0 := seat(0)
	p0.options = [0]   # "Untap Coffin Queen."
	var pair := _raise_with_queen()
	var queen: CardInstance = pair[0]
	var giant: CardInstance = pair[1]
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(queen.tapped)
	assert_eq(giant.zone, Mtg.Zone.EXILE)

func test_coffin_queen_leaving_the_battlefield_exiles_the_creature() -> void:
	var pair := _raise_with_queen()
	var queen: CardInstance = pair[0]
	var giant: CardInstance = pair[1]
	g.destroy(queen)
	resolve_stack()
	assert_eq(queen.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.EXILE, "you no longer control her")

func test_coffin_queen_stolen_exiles_the_creature() -> void:
	var pair := _raise_with_queen()
	var queen: CardInstance = pair[0]
	var giant: CardInstance = pair[1]
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	cast("Control Magic", [TargetRef.card(queen)], 1)
	assert_eq(queen.controller_id, 1)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.EXILE)


# --- Darkling Stalker / Screeching Harpy ------------------------------------

func test_darkling_stalker_regenerates_and_pumps_for_b() -> void:
	var stalker := put_battlefield(0, "Darkling Stalker")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, stalker, 1))
	assert_ok(g.activate_ability(0, stalker, 0))
	assert_refused(g.activate_ability(0, stalker, 0), "mana")
	resolve_stack()
	assert_eq([stalker.cur_power, stalker.cur_toughness], [2, 2])
	g.destroy(stalker)
	assert_eq(stalker.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(stalker.tapped, "regenerated")

func test_screeching_harpy_flies_and_regenerates_for_one_b() -> void:
	var harpy := put_battlefield(0, "Screeching Harpy")
	assert_true(harpy.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, harpy, 0), "mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, harpy, 0))
	resolve_stack()
	g.destroy(harpy)
	assert_eq(harpy.zone, Mtg.Zone.BATTLEFIELD)


# --- Marsh Lurker -----------------------------------------------------------

func test_marsh_lurker_eats_a_swamp_for_fear() -> void:
	var lurker := put_battlefield(0, "Marsh Lurker")
	assert_refused(g.activate_ability(0, lurker, 0), "Swamp")
	var swamp := put_battlefield(0, "Swamp")
	assert_ok(g.activate_ability(0, lurker, 0))
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_true(lurker.has_keyword(Mtg.Keyword.FEAR))
	var bear := put_battlefield(1, "Grizzly Bears")
	var zombie := put_battlefield(1, "Scathe Zombies")
	_attack(lurker)
	assert_refused(g.declare_blockers(1, {bear.id: lurker.id}))
	assert_ok(g.declare_blockers(1, {zombie.id: lurker.id}))
	assert_eq(lurker.cur_activated_abilities[0].effects[0].ai_role, &"self_keyword")


# --- Minion of the Wastes ---------------------------------------------------

func test_minion_of_the_wastes_is_as_big_as_the_life_paid() -> void:
	var p0 := seat(0)
	p0.options = [5]
	var minion := cast("Minion of the Wastes")
	assert_eq(minion.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([minion.cur_power, minion.cur_toughness], [5, 5])
	assert_eq(g.players[0].life, 15)
	assert_true(minion.has_keyword(Mtg.Keyword.TRAMPLE))

func test_minion_of_the_wastes_paid_nothing_dies_as_a_zero_zero() -> void:
	var p0 := seat(0)
	p0.options = [0]
	var minion := cast("Minion of the Wastes")
	assert_eq(minion.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


# --- Pit Imp ----------------------------------------------------------------

func test_pit_imp_firebreathes_no_more_than_twice_a_turn() -> void:
	var imp := put_battlefield(0, "Pit Imp")
	assert_true(imp.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(0, imp, 0))
	assert_ok(g.activate_ability(0, imp, 0))
	assert_refused(g.activate_ability(0, imp, 0))
	resolve_stack()
	assert_eq([imp.cur_power, imp.cur_toughness], [2, 1])


# --- Rats of Rath -----------------------------------------------------------

func test_rats_of_rath_destroy_only_your_own_artifact_creature_or_land() -> void:
	var rats := put_battlefield(0, "Rats of Rath")
	var forest := put_battlefield(0, "Forest")
	var crusade := put_battlefield(0, "Crusade")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, rats, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(0, rats, 0, [TargetRef.card(crusade)]))
	assert_ok(g.activate_ability(0, rats, 0, [TargetRef.card(forest)]))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)


# --- Skyshroud Vampire ------------------------------------------------------

func test_skyshroud_vampire_discards_a_creature_card_for_two_two() -> void:
	var vampire := put_battlefield(0, "Skyshroud Vampire")
	var bolt := give_hand(0, "Lightning Bolt")
	assert_refused(g.activate_ability(0, vampire, 0), "creature")
	var bear := give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, vampire, 0))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq([vampire.cur_power, vampire.cur_toughness], [5, 5])


# --- Souldrinker ------------------------------------------------------------

func test_souldrinker_pays_three_life_for_a_counter() -> void:
	var drinker := put_battlefield(0, "Souldrinker")
	assert_ok(g.activate_ability(0, drinker, 0))
	assert_eq(g.players[0].life, 17, "the life is paid on activation")
	resolve_stack()
	assert_eq(int(drinker.counters.get("+1/+1", 0)), 1)
	assert_eq([drinker.cur_power, drinker.cur_toughness], [3, 3])
	g.adjust_life(0, -15)
	assert_eq(g.players[0].life, 2)
	assert_refused(g.activate_ability(0, drinker, 0))


# --- Canyon Drake -----------------------------------------------------------

func test_canyon_drake_needs_a_card_to_throw_away() -> void:
	var drake := put_battlefield(0, "Canyon Drake")
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, drake, 0))
	var card := give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, drake, 0))
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "discarded at random as the cost")
	resolve_stack()
	assert_eq([drake.cur_power, drake.cur_toughness], [3, 2])


# --- Firefly / Sandstone Warrior --------------------------------------------

func test_firefly_and_sandstone_warrior_firebreathe() -> void:
	var fly := put_battlefield(0, "Firefly")
	var warrior := put_battlefield(0, "Sandstone Warrior")
	assert_true(fly.has_keyword(Mtg.Keyword.FLYING))
	assert_true(warrior.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, fly, 0))
	assert_ok(g.activate_ability(0, fly, 0))
	assert_ok(g.activate_ability(0, warrior, 0))
	assert_refused(g.activate_ability(0, warrior, 0), "mana")
	resolve_stack()
	assert_eq([fly.cur_power, fly.cur_toughness], [3, 1])
	assert_eq([warrior.cur_power, warrior.cur_toughness], [2, 3])


# --- Fireslinger ------------------------------------------------------------

func test_fireslinger_hurts_its_controller_too() -> void:
	var slinger := put_battlefield(0, "Fireslinger")
	var sick := put_battlefield(0, "Fireslinger", true)
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.player(1)]))
	assert_ok(g.activate_ability(0, slinger, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 19)


# --- Flowstone Giant / Wyvern -----------------------------------------------

func test_flowstone_giant_trades_toughness_for_power() -> void:
	var giant := put_battlefield(0, "Flowstone Giant")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, giant, 0))
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [5, 1])
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, giant, 0))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "7/-1")

func test_flowstone_wyvern_flies_and_shifts_two() -> void:
	var wyvern := put_battlefield(0, "Flowstone Wyvern")
	assert_true(wyvern.has_keyword(Mtg.Keyword.FLYING))
	assert_refused(g.activate_ability(0, wyvern, 0), "mana")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, wyvern, 0))
	resolve_stack()
	assert_eq([wyvern.cur_power, wyvern.cur_toughness], [5, 1])
	advance_to_next_turn()
	assert_eq([wyvern.cur_power, wyvern.cur_toughness], [3, 3])


# --- Mogg Fanatic / Mogg Raider ---------------------------------------------

func test_mogg_fanatic_sacrifices_itself_to_ping() -> void:
	var fanatic := put_battlefield(0, "Mogg Fanatic", true)
	var elves := put_battlefield(1, "Llanowar Elves")
	assert_ok(g.activate_ability(0, fanatic, 0, [TargetRef.card(elves)]))
	assert_eq(fanatic.zone, Mtg.Zone.GRAVEYARD, "no {T}: even a fresh Fanatic may")
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_refused(g.activate_ability(0, fanatic, 0, [TargetRef.player(1)]))

func test_mogg_raider_sacrifices_a_goblin_itself_included() -> void:
	var p0 := seat(0)
	var raider := put_battlefield(0, "Mogg Raider")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	var bear := put_battlefield(0, "Grizzly Bears")
	p0.picks = [raiders]
	assert_ok(g.activate_ability(0, raider, 0, [TargetRef.card(bear)]))
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(raider.zone, Mtg.Zone.BATTLEFIELD)
	p0.picks = [raider]
	assert_ok(g.activate_ability(0, raider, 0, [TargetRef.card(bear)]))
	assert_eq(raider.zone, Mtg.Zone.GRAVEYARD, "the Raider is a Goblin too")
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [4, 4])
	assert_refused(g.activate_ability(0, raider, 0, [TargetRef.card(bear)]))


# --- Mogg Squad -------------------------------------------------------------

func test_mogg_squad_shrinks_for_every_other_creature() -> void:
	var squad := put_battlefield(0, "Mogg Squad")
	assert_eq([squad.cur_power, squad.cur_toughness], [3, 3])
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	put_battlefield(1, "Forest")
	assert_eq([squad.cur_power, squad.cur_toughness], [1, 1], "creatures on both sides, lands not")
	put_battlefield(1, "Grizzly Bears")
	g.check_state_based_actions()
	assert_eq(squad.zone, Mtg.Zone.GRAVEYARD)


# --- Opportunist ------------------------------------------------------------

func test_opportunist_finishes_only_a_creature_already_hurt_this_turn() -> void:
	var opportunist := put_battlefield(0, "Opportunist")
	var slinger := put_battlefield(0, "Fireslinger")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, opportunist, 0, [TargetRef.card(giant)]))
	assert_refused(g.activate_ability(0, opportunist, 0, [TargetRef.player(1)]))
	assert_ok(g.activate_ability(0, slinger, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.damage, 1)
	assert_ok(g.activate_ability(0, opportunist, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.damage, 2)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_refused(g.activate_ability(0, opportunist, 0, [TargetRef.card(giant)]), "")


# --- Pallimud ---------------------------------------------------------------

func test_pallimud_counts_the_chosen_players_tapped_lands() -> void:
	var lands: Array[CardInstance] = []
	for i in 3: lands.append(put_battlefield(1, "Forest"))
	put_battlefield(0, "Mountain")
	var mud := cast("Pallimud")
	assert_eq(int(mud.memory.get("chosen_player", -1)), 1)
	assert_eq([mud.cur_power, mud.cur_toughness], [0, 3])
	g.tap_permanent(lands[0])
	g.tap_permanent(lands[1])
	assert_eq(mud.cur_power, 2)
	g.untap_permanent(lands[0])
	assert_eq(mud.cur_power, 1)
	assert_eq(CardRegistry.get_card("Pallimud").power, 0, "0 outside the battlefield (no chosen player)")


# --- Starke of Rath ---------------------------------------------------------

func test_starke_of_rath_destroys_and_changes_hands() -> void:
	var starke := put_battlefield(0, "Starke of Rath")
	var bear := put_battlefield(1, "Grizzly Bears")
	var forest := put_battlefield(1, "Forest")
	assert_refused(g.activate_ability(0, starke, 0, [TargetRef.card(forest)]))
	assert_ok(g.activate_ability(0, starke, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(starke.controller_id, 1, "the destroyed permanent's controller takes Starke")
	advance_to_next_turn()
	assert_eq(starke.controller_id, 1, "indefinitely")

func test_starke_aimed_at_your_own_creature_stays_home() -> void:
	var starke := put_battlefield(0, "Starke of Rath")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, starke, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(starke.controller_id, 0)

func test_starke_changes_hands_even_when_the_target_regenerates() -> void:
	var starke := put_battlefield(0, "Starke of Rath")
	var skeleton := put_battlefield(1, "Drudge Skeletons")
	assert_ok(g.activate_ability(0, starke, 0, [TargetRef.card(skeleton)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(1, skeleton, 0))
	resolve_stack()
	assert_eq(skeleton.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(starke.controller_id, 1)
