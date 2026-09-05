extends GameTest
## 2026-09-02 fidelity pass — targets an OPPONENT chooses ("… of an
## opponent's choice": Arena, Preacher, Nova Pentacle, Cuombajj Witches).
## The engine feature: TargetSpec.opponent_chooses marks a spec whose ref
## the activator does not supply; MtgGame._fill_adverse_targets asks the
## opponent as the ability is activated (CR 601.2c), through the cost
## hold, and the answer is a REAL target — legality (shroud, protection),
## the no-legal-target refusal and the fizzle all follow from that.


## Picks the named card when it is on the list, else the first.
class PickByName extends DecisionAgent:
	var wanted := ""

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null if candidates.is_empty() else candidates[0]


## Answers OPTION questions with a fixed label.
class PickByLabel extends DecisionAgent:
	var wanted := ""

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], hint: int) -> int:
		var at := options.find(wanted)
		return at if at >= 0 else hint


func _human_seat(pid: int) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _cloak(inst: CardInstance) -> void:
	# Spectral Cloak: shroud while untapped.
	g.attach_aura_from_anywhere(give_hand(inst.controller_id, "Spectral Cloak"),
		inst, inst.controller_id)
	g.recalculate()
	assert_true(inst.cur_shroud, "the cloak took")


# ----------------------------------------------------------------- Arena --

func test_arena_cannot_be_activated_with_nobody_to_fight() -> void:
	# The champion is a TARGET: no legal one, no activation (CR 601.2c).
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]),
		"no legal target")
	assert_false(mine.tapped)
	assert_eq(g.stack.size(), 0)
	assert_eq(g.players[0].mana_pool.total(), 3, "nothing was paid")


func test_arena_champion_with_shroud_is_not_on_the_list() -> void:
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Hill Giant")
	var cloaked := put_battlefield(1, "Serra Angel")
	_cloak(cloaked)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]),
		"no legal target")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	assert_eq(g.stack[0].targets.size(), 2, "two targets, one per player")
	assert_eq(g.stack[0].targets[1].instance_id, bears.id,
		"the only legal champion")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cloaked.damage, 0)


func test_arena_no_fight_when_the_champion_leaves_in_response() -> void:
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Hill Giant")
	var theirs := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	g.destroy(theirs)
	g.check_state_based_actions()
	resolve_stack()
	assert_true(mine.tapped, "your creature is still tapped (the tap is not the fight)")
	assert_eq(mine.damage, 0, "CR 701.12b: no blow with one side gone")


func test_arena_no_fight_when_your_own_creature_leaves_in_response() -> void:
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Hill Giant")
	var theirs := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	g.destroy(mine)
	g.check_state_based_actions()
	resolve_stack()
	assert_true(theirs.tapped, "the champion is still tapped")
	assert_eq(theirs.damage, 0, "and unhurt")
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)


func test_arena_heuristic_champion_is_the_one_that_wins() -> void:
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Hill Giant")       # 3/3
	var bears := put_battlefield(1, "Grizzly Bears")   # loses
	var angel := put_battlefield(1, "Serra Angel")     # 4/4 kills it and lives
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	assert_eq(g.stack[0].targets[1].instance_id, angel.id)
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "the Giant died")
	assert_eq(angel.damage, 3)
	assert_eq(bears.damage, 0)


func test_arena_heuristic_sends_the_cheapest_when_nobody_can_win() -> void:
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Serra Angel")      # 4/4
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	assert_eq(g.stack[0].targets[1].instance_id, bears.id,
		"a loss either way: the Bears go")
	resolve_stack()
	assert_eq(giant.damage, 0)


func test_arena_ai_opponent_takes_the_ordered_pick_not_its_most_valuable() -> void:
	g.agents[1] = AiPlayer.new(1)
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	assert_eq(g.stack[0].targets[1].instance_id, bears.id)
	var asked: PlayerChoice = g.choice_log[g.choice_log.size() - 1]
	assert_true(asked.adverse, "filed as a choice made against oneself")
	assert_eq(asked.pid, 1)


func test_arena_human_opponent_is_held_on_the_pick_at_activation() -> void:
	var human := _human_seat(1)
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	assert_not_null(g.awaiting_choice, "held for the OPPONENT's pick")
	assert_eq(g.awaiting_choice.pid, 1)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.source, "Arena")
	assert_eq(g.awaiting_choice.prompt, "Select target creature.")   # `@ARENA`
	assert_true(g.awaiting_choice.adverse)
	assert_true(g.awaiting_choice.is_cost, "rides the cost hold")
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_eq(g.stack.size(), 0, "nothing on the stack yet")
	assert_false(arena.tapped, "nothing paid yet")
	assert_refused(g.pass_priority(0), "waiting for a choice")
	assert_ok(g.answer_choice("Serra Angel"))
	assert_null(g.awaiting_choice)
	assert_eq(g.stack.size(), 1, "the activation went through")
	assert_true(arena.tapped)
	assert_eq(g.stack[0].targets[1].instance_id, angel.id, "their own pick")
	resolve_stack()
	assert_eq(angel.damage, 3)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_true(human._parked.is_empty(), "the parked answer was consumed")


# -------------------------------------------------------------- Preacher --

func test_preacher_takes_no_target_of_the_activators_own() -> void:
	var preacher := put_battlefield(0, "Preacher")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, preacher, 0, [TargetRef.player(1)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, preacher, 0, []))
	assert_eq(g.stack[0].targets.size(), 1, "the creature IS the target")
	assert_eq(g.stack[0].targets[0].instance_id, bear.id)
	resolve_stack()
	assert_eq(bear.controller_id, 0)


func test_preacher_cannot_be_activated_with_no_creature_to_take() -> void:
	var preacher := put_battlefield(0, "Preacher")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, preacher, 0, []), "no legal target")
	assert_false(preacher.tapped)


func test_preacher_cannot_reach_a_creature_with_protection_from_white() -> void:
	var preacher := put_battlefield(0, "Preacher")
	var knight := put_battlefield(1, "Black Knight")   # pro-white
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, preacher, 0, []), "no legal target")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, preacher, 0, []))
	resolve_stack()
	assert_eq(bear.controller_id, 0)
	assert_eq(knight.controller_id, 1)


func test_preacher_fizzles_when_the_chosen_creature_leaves() -> void:
	var preacher := put_battlefield(0, "Preacher")
	var bear := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, preacher, 0, []))
	assert_eq(g.stack[0].targets[0].instance_id, bear.id, "they hand over the Bears")
	g.destroy(bear)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(angel.controller_id, 1, "no second choice: the ability fizzled")
	assert_true(preacher.tapped)


func test_preacher_untapped_in_response_takes_nothing() -> void:
	# CR 611.2b: "for as long as it remains tapped" already over.
	var preacher := put_battlefield(0, "Preacher")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, preacher, 0, []))
	g.untap_permanent(preacher)
	resolve_stack()
	assert_eq(bear.controller_id, 1)


func test_preacher_victim_ai_hands_over_the_cheapest() -> void:
	g.agents[1] = AiPlayer.new(1)
	var preacher := put_battlefield(0, "Preacher")
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, preacher, 0, []))
	resolve_stack()
	assert_eq(bear.controller_id, 0, "the AI gives up its cheapest body")
	assert_eq(angel.controller_id, 1)


func test_preacher_human_victim_chooses_at_activation() -> void:
	_human_seat(1)
	var preacher := put_battlefield(0, "Preacher")
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, preacher, 0, []))
	assert_not_null(g.awaiting_choice)
	assert_eq(g.awaiting_choice.pid, 1)
	assert_eq(g.awaiting_choice.source, "Preacher")
	assert_eq(g.awaiting_choice.candidates[0], bear, "offered worst-first")
	assert_ok(g.answer_choice("Serra Angel"))
	resolve_stack()
	assert_eq(angel.controller_id, 0, "their call, even a bad one")
	assert_eq(bear.controller_id, 1)


# --------------------------------------------------------- Nova Pentacle --

func _bolt_your_face_then_activate(pentacle: CardInstance) -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, pentacle, 0))


func test_nova_pentacle_cannot_be_activated_with_no_creature_anywhere() -> void:
	var pentacle := put_battlefield(0, "Nova Pentacle")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, pentacle, 0), "no legal target")
	assert_false(pentacle.tapped)


func test_nova_pentacle_target_is_chosen_at_activation_and_fizzles_if_gone() -> void:
	var seat := PickByName.new()
	seat.wanted = "Lightning Bolt"
	g.set_agent(0, seat)
	var pentacle := put_battlefield(0, "Nova Pentacle")
	var bear := put_battlefield(1, "Grizzly Bears")
	_bolt_your_face_then_activate(pentacle)
	assert_eq(g.stack[1].targets.size(), 1)
	assert_eq(g.stack[1].targets[0].instance_id, bear.id, "their creature, their pick")
	g.destroy(bear)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the ability fizzled; the Bolt landed on you")


func test_nova_pentacle_opponent_may_name_one_of_your_creatures() -> void:
	# "target creature of an opponent's choice" — not "they control".
	var seat := PickByName.new()
	seat.wanted = "Lightning Bolt"
	g.set_agent(0, seat)
	var pentacle := put_battlefield(0, "Nova Pentacle")
	var mine := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	_bolt_your_face_then_activate(pentacle)
	assert_eq(g.stack[1].targets[0].instance_id, mine.id,
		"their heuristic aims the damage at YOUR creature")
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "your Bears ate the Bolt")


func test_nova_pentacle_opponent_gives_up_their_cheapest_when_only_theirs_qualify() -> void:
	var seat := PickByName.new()
	seat.wanted = "Lightning Bolt"
	g.set_agent(0, seat)
	var pentacle := put_battlefield(0, "Nova Pentacle")
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	_bolt_your_face_then_activate(pentacle)
	assert_eq(g.stack[1].targets[0].instance_id, bear.id)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.damage, 0)


func test_nova_pentacle_shrouded_creature_is_not_on_the_list() -> void:
	var seat := PickByName.new()
	seat.wanted = "Lightning Bolt"
	g.set_agent(0, seat)
	var pentacle := put_battlefield(0, "Nova Pentacle")
	var cloaked := put_battlefield(1, "Grizzly Bears")
	_cloak(cloaked)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, pentacle, 0), "no legal target")


func test_nova_pentacle_source_may_be_your_own() -> void:
	# "a source OF YOUR CHOICE": your own Pestilence counts.
	var seat := PickByName.new()
	seat.wanted = "Pestilence"
	g.set_agent(0, seat)
	var pentacle := put_battlefield(0, "Nova Pentacle")
	var pestilence := put_battlefield(0, "Pestilence")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, pentacle, 0))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, pestilence, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "your share went to their Bears")
	assert_eq(g.players[1].life, 19)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "1 of its own plus yours: dead")


# ------------------------------------------------------ Cuombajj Witches --

func test_cuombajj_witches_opponent_may_aim_at_your_face() -> void:
	var witches := put_battlefield(0, "Cuombajj Witches")
	var theirs := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, witches, 0, [TargetRef.card(theirs)]))
	assert_eq(g.stack[0].targets.size(), 2)
	assert_true(g.stack[0].targets[1].is_player, "no kill on offer: your face")
	assert_eq(g.stack[0].targets[1].player_id, 0)
	resolve_stack()
	assert_eq(theirs.damage, 1)
	assert_eq(g.players[0].life, 19)
	assert_eq(witches.damage, 0)


func test_cuombajj_witches_opponent_prefers_a_kill() -> void:
	var witches := put_battlefield(0, "Cuombajj Witches")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")   # 1/1
	var theirs := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, witches, 0, [TargetRef.card(theirs)]))
	assert_eq(g.stack[0].targets[1].instance_id, raiders.id)
	resolve_stack()
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


func test_cuombajj_witches_return_shot_is_a_target_that_fizzles_alone() -> void:
	var witches := put_battlefield(0, "Cuombajj Witches")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	var theirs := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, witches, 0, [TargetRef.card(theirs)]))
	g.destroy(raiders)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "your shot still lands")
	assert_eq(g.players[0].life, 20, "theirs had nowhere else to go")


func test_cuombajj_witches_human_opponent_is_held_on_an_option_list() -> void:
	_human_seat(1)
	var witches := put_battlefield(0, "Cuombajj Witches")
	var theirs := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, witches, 0, [TargetRef.card(theirs)]))
	assert_not_null(g.awaiting_choice)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION,
		"players are on the list, so it is an OPTION question")
	assert_eq(g.awaiting_choice.pid, 1)
	assert_eq(g.awaiting_choice.prompt, "Select target creature or player.")
	assert_eq(g.awaiting_choice.source, "Cuombajj Witches")
	var labels: Array[String] = g.awaiting_choice.options
	assert_eq(labels[0], "P0", "the activator's face leads (no kill on offer)")
	assert_has(labels, "Cuombajj Witches")
	assert_has(labels, "Hill Giant")
	assert_has(labels, "P1")
	assert_eq(g.stack.size(), 0)
	assert_ok(g.answer_choice(labels.find("Cuombajj Witches")))
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(witches.damage, 1, "their own pick")
	assert_eq(g.players[0].life, 20)


func test_cuombajj_witches_opponent_may_double_up_on_your_target() -> void:
	# CR 601.2c: one object may be chosen once per instance of "target".
	var seat := PickByLabel.new()
	seat.wanted = "Grizzly Bears"
	g.set_agent(1, seat)
	var witches := put_battlefield(0, "Cuombajj Witches")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, witches, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "1 + 1 on a 2/2")


func test_cuombajj_witches_cannot_reach_a_shrouded_return_target() -> void:
	# Only a shrouded creature on the activator's side and the players:
	# the creature is on nobody's list.
	var witches := put_battlefield(0, "Cuombajj Witches")
	_cloak(witches)
	var theirs := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, witches, 0, [TargetRef.card(theirs)]))
	var offered: PlayerChoice = g.choice_log[g.choice_log.size() - 1]
	assert_eq(offered.kind, PlayerChoice.Kind.OPTION)
	assert_does_not_have(offered.options, "Cuombajj Witches")
