extends GameTest
## BERSERK IS A FINISHER, NEVER A MAIN-PHASE CAST (2026-09-27). The
## playtest: *"inspect beserk play by ai - i noticed ai casts it sometimes
## in first turn."* Reproduced: Berserk's effect is card-local (its X is
## the target's power, read at resolution), so [EffectIntent] called it
## `unknown` — removal-shaped — and [method AiPlayer._try_cast_best] aimed
## it across the table at the opponent's best creature in the AI's own
## main phase. On the AI's turn nothing of theirs has attacked, so the
## end-step doom could never fall: the card was a gift of +X/+0 and
## trample, and on turn one it went to the opponent's first creature.
##
## The effect now declares its shape ([member EffectBase.ai_role]
## `double_power_doomed`). [method AiPlayer._is_reactive] keeps it out of
## every main phase, for every profile, and this suite's place for it is
## the finisher in [method AiPlayer._offensive_combat_response]: once the
## blocks are in, on an attacker of ours whose doubled power — or, if
## blocked, whose trample excess after lethal to each blocker (CR
## 702.19b) — ends the game on this attack. The creature dies at the end
## step; the game is over first. (Its other moment, the removal on THEIR
## attacker, is test_ai_berserk_removal_2026_09_27.)
##
## Every test acts through AiPlayer.act / the public MtgGame API.


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## The Wizard's whole main phase: act until it passes.
func _main_phase_acts(ai: AiPlayer) -> Array:
	var acts: Array = []
	for _i in 6:
		var a := ai.act(g)
		acts.append(a)
		if a == "pass" or a == "":
			break
	return acts


## A Hill Giant of ours attacks; [param blocker] (if any) blocks it; the
## Wizard, holding Berserk with a Forest open, acts with the blocks in.
func _attack_into(ai: AiPlayer, their_life: int, blocker: String) -> Array:
	var giant := put_battlefield(0, "Hill Giant")   # 3/3
	var body: CardInstance = null
	if blocker != "":
		body = put_battlefield(1, blocker)
	g.players[1].life = their_life
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var blocks := {}
	if body != null:
		blocks[body.id] = giant.id
	assert_ok(g.declare_blockers(1, blocks))
	assert_eq(g.priority_player, 0, "the attacker acts first with the blocks in")
	var acts: Array = []
	for _i in 4:
		var a := ai.act(g)
		acts.append(a)
		if a == "pass" or a == "":
			break
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	return acts


# ------------------------------------------------------ never in a main phase --

func test_the_playtest_a_berserk_at_their_first_creature() -> void:
	# The AI's first main phase, the opponent's lone creature across the
	# table, Berserk and a Forest in hand: this used to be "cast Berserk".
	var ai := _wizard()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var berserk := give_hand(0, "Berserk")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_main_phase_acts(ai), ["pass"], "not cast at the enemy's creature")
	assert_eq(berserk.zone, Mtg.Zone.HAND)
	assert_eq(theirs.cur_power, 2, "and nothing of theirs was doubled")


func test_not_on_our_own_creature_in_a_main_phase_either() -> void:
	var ai := _wizard()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var berserk := give_hand(0, "Berserk")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_main_phase_acts(ai), ["pass"])
	assert_eq(berserk.zone, Mtg.Zone.HAND)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(_main_phase_acts(ai), ["pass"], "nor in the second main phase")
	assert_eq(berserk.zone, Mtg.Zone.HAND)


func test_the_effect_declares_its_shape() -> void:
	var data := CardRegistry.get_card("Berserk")
	assert_eq(data.spell_effects.size(), 1)
	assert_eq(data.spell_effects[0].ai_role, &"double_power_doomed")
	assert_true(AiPlayer.new(0, AiProfile.wizard())._is_reactive(data),
		"the response framework's card, not the planner's")


# ------------------------------------------------------------- the finisher --

func test_doubles_an_unblocked_attacker_for_the_win() -> void:
	var ai := _wizard()
	put_battlefield(0, "Forest")
	give_hand(0, "Berserk")
	var acts := _attack_into(ai, 6, "")   # 3 lands; doubled, 6 does
	assert_eq(acts[0], "responded with Berserk")
	assert_eq(g.players[1].life, 0)
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


func test_holds_it_when_the_doubling_falls_short() -> void:
	var ai := _wizard()
	put_battlefield(0, "Forest")
	var berserk := give_hand(0, "Berserk")
	var acts := _attack_into(ai, 7, "")   # 3 lands; doubled, 6 does not
	assert_eq(acts, ["pass"], "a Giant that would die at the end step for nothing")
	assert_eq(berserk.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 4)


func test_tramples_over_a_chump_blocker_for_the_win() -> void:
	var ai := _wizard()
	put_battlefield(0, "Forest")
	give_hand(0, "Berserk")
	# Blocked by a 2/2 at 4 life: doubled to 6, lethal 2 to the Bears,
	# 4 trample over — exactly the game.
	var acts := _attack_into(ai, 4, "Grizzly Bears")
	assert_eq(acts[0], "responded with Berserk")
	assert_eq(g.players[1].life, 0)
	assert_true(g.game_over)


func test_holds_it_when_the_trample_excess_falls_short() -> void:
	var ai := _wizard()
	put_battlefield(0, "Forest")
	var berserk := give_hand(0, "Berserk")
	var acts := _attack_into(ai, 5, "Grizzly Bears")   # 4 over at 5 life
	assert_eq(acts, ["pass"])
	assert_eq(berserk.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 5)


func test_holds_it_at_their_attacker_when_the_life_is_dear() -> void:
	# Berserk on THEIR attacker IS a removal — the doom falls at the end
	# step on a body that attacked (the owner: *"beserk can be removal in
	# certain cases!"*; test_ai_berserk_removal_2026_09_27 reads the
	# cases) — but it doubles what hits us first. At eight life a Giant
	# doubled would leave two: held, three taken.
	var ai := _wizard()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var berserk := give_hand(0, "Berserk")
	var theirs := put_battlefield(1, "Hill Giant")
	g.players[0].life = 8
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [theirs.id]))
	var acts: Array = []
	var guard := 0
	while g.current_step() != Mtg.Step.MAIN2 and not g.game_over and guard < 30:
		if g.awaiting_blockers or g.priority_player == 0:
			# AiPlayer.act declares the (empty) blocks and passes by itself.
			var a := ai.act(g)
			if a != "pass" and a != "" and not a.begins_with("declared"):
				acts.append(a)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_eq(acts, [], "the AI passed through their whole combat")
	assert_eq(berserk.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 5, "three from the Giant, not six")
