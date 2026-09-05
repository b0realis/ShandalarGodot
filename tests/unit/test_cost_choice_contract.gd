extends GameTest
## COST CHOICES — CR 601.2h, from both sides: the refusal order and the HOLD.
##
## "Sacrifice a creature" as an additional cost (Metamorphosis, Sacrifice),
## "Sacrifice an artifact" in an activation cost (Orcish Mechanics), the same
## in a MANA ability's cost (Ashnod's Altar) and Fellwar Stone's colour are
## the engine's choice call sites OUTSIDE a stack resolution — the four rows
## docs/duel-todo.md §1.3's fall-through table used to carry. A cost is paid
## before its spell reaches the stack, and a mana ability never touches the
## stack at all (CR 605.3a), so the pre-flight has nothing to probe.
##
## TWO THINGS ARE PINNED HERE.
##
## 1. THE REFUSAL ORDER. CR 601.2h says a cost that turns out to be unpayable
##    leaves the game exactly as it was, and the ledger is part of "exactly as
##    it was". A question filed for an action the engine then REFUSED is a
##    phantom: it lands in MtgGame.choice_log, in MtgGame.unanswered_choices,
##    and — for a seat that wanted to be asked — as a `(decided for P0) …`
##    line in the game log, describing a sacrifice that never happened. So
##    every refusal check runs BEFORE the seat is asked.
##
## 2. THE HOLD. Because the question is put where no refusal is left and
##    nothing has been mutated, it needs no rewind point: the duel is held
##    open on MtgGame.awaiting_choice and MtgGame.answer_choice RE-ISSUES the
##    whole action with the answer in the seat's mailbox. Same contract as
##    awaiting_attackers / awaiting_discard — every action refused meanwhile.


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _decided_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for line in g.log_lines:
		if line.begins_with("(decided for "):
			out.append(line)
	return out


# ------------------------------------------------- an additional cost --

func test_a_refused_cast_files_no_cost_choice() -> void:
	# Metamorphosis: "as an additional cost, sacrifice a creature", {G} to
	# cast. A creature to eat, but not a single green mana.
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	put_battlefield(0, "Grizzly Bears")
	var meta := give_hand(0, "Metamorphosis")
	assert_refused(g.cast_spell(0, meta, []), "not enough mana")
	assert_eq(g.choice_log.size(), 0,
		"a cast that was refused never asked anything")
	assert_eq(g.unanswered_choices.size(), 0, "and nothing is on the ledger")
	assert_eq(_decided_lines().size(), 0,
		"and the log does not claim a sacrifice was decided")


func test_a_refused_cast_still_refuses_for_a_missing_body_first() -> void:
	# The legality half of the cost is unchanged: no creature, no cast, and
	# the refusal names the requirement rather than the mana.
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	var meta := give_hand(0, "Metamorphosis")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, meta, []), "creature")
	assert_eq(g.choice_log.size(), 0, "nothing was asked")


func test_an_affordable_cast_holds_the_duel_open_on_the_question() -> void:
	# The positive control: the question is asked when the cost is actually
	# payable — and for a seat that wants to answer its own questions the
	# duel STOPS on it rather than the referee picking a body.
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	var bear := put_battlefield(0, "Grizzly Bears")
	var meta := give_hand(0, "Metamorphosis")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, meta, []))
	assert_not_null(g.awaiting_choice, "the cast is held open on the choice")
	var asked: PlayerChoice = g.awaiting_choice
	assert_true(asked.is_cost, "and it is filed as a COST question")
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_eq(asked.source, "Metamorphosis", "wearing the card that asked")
	assert_eq(asked.prompt, "Select creature to sacrifice.")
	# CR 601.2h — nothing has been paid or moved while the question stands.
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "nothing was sacrificed yet")
	assert_eq(meta.zone, Mtg.Zone.HAND, "and the spell is still in hand")
	assert_eq(g.players[0].mana_pool.total(), 1, "and the mana is unspent")
	assert_eq(g.choice_log.size(), 0, "nothing is on the record yet either")


func test_answering_the_cast_question_replays_the_cast() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	var bear := put_battlefield(0, "Grizzly Bears")
	var meta := give_hand(0, "Metamorphosis")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, meta, []))
	assert_ok(g.answer_choice("Grizzly Bears"))
	assert_null(g.awaiting_choice, "the hold is released")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the additional cost was paid")
	assert_eq(meta.zone, Mtg.Zone.STACK, "and the spell is on the stack")
	assert_eq(g.choice_log.size(), 1, "the choice is on the record ONCE")
	assert_eq(g.choice_log[0].kind, PlayerChoice.Kind.CARD)
	assert_true(g.choice_log[0].answered_by_player, "and it was the player's")
	assert_eq(g.unanswered_choices.size(), 0,
		"so nothing was decided on their behalf")
	assert_eq(_decided_lines().size(), 0, "and the log claims nothing")


func test_the_cast_sacrifices_the_body_the_player_picked() -> void:
	# The whole point of the hold: with several bodies the heuristic takes
	# the first, and the player takes whichever one they meant.
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(0, "Wall of Stone")
	var meta := give_hand(0, "Metamorphosis")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, meta, []))
	assert_eq((g.awaiting_choice as PlayerChoice).candidates.size(), 2,
		"both bodies are on offer")
	assert_ok(g.answer_choice("Wall of Stone"))
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "the Wall went")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "and the Bears did not")


func test_no_action_is_allowed_while_a_cost_choice_is_held() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	var meta := give_hand(0, "Metamorphosis")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, meta, []))
	assert_refused(g.pass_priority(0), "choice")
	# A mana ability skips _act_precheck (CR 605.3a) and needs its own guard.
	assert_refused(g.tap_for_mana(0, forest), "choice")


func test_a_heuristic_seat_is_not_held_open_at_all() -> void:
	# The AI, the base agent and every headless test resolve exactly as they
	# always did: no hold, the first candidate, and the ledger says so.
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var meta := give_hand(0, "Metamorphosis")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, meta, []))
	assert_null(g.awaiting_choice, "nothing is held")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the cost was paid straight off")
	assert_eq(g.choice_log.size(), 1)
	assert_eq(g.unanswered_choices.size(), 0,
		"and a seat that never wanted asking is not owed anything")


# ------------------------------------------------- an activation cost --

func test_a_refused_activation_files_no_cost_choice() -> void:
	# Orcish Mechanics: "{T}, Sacrifice an artifact: 2 damage to any target."
	# Summoning-sick, so the tap cost is unpayable — and the tap check runs
	# after the sacrifice pick.
	_human_seat(0)
	var mech := put_battlefield(0, "Orcish Mechanics", true)
	put_battlefield(0, "Ornithopter")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, mech, 0, [TargetRef.card(bear)]),
		"summoning sickness")
	assert_eq(g.choice_log.size(), 0,
		"an activation that was refused never asked anything")
	assert_eq(_decided_lines().size(), 0, "and said nothing in the log")


func test_an_activation_refused_for_targets_files_no_cost_choice() -> void:
	# The other side of the same coin: a legal cost, an illegal target.
	_human_seat(0)
	var mech := put_battlefield(0, "Orcish Mechanics")
	put_battlefield(0, "Ornithopter")
	assert_refused(g.activate_ability(0, mech, 0, []))
	assert_eq(g.choice_log.size(), 0, "nothing was asked")
	assert_eq(g.players[0].battlefield.size(), 2,
		"and the artifact is still there")


func test_an_affordable_activation_holds_and_then_sacrifices() -> void:
	_human_seat(0)
	var mech := put_battlefield(0, "Orcish Mechanics")
	var thopter := put_battlefield(0, "Ornithopter")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, mech, 0, [TargetRef.card(bear)]))
	assert_not_null(g.awaiting_choice, "the activation is held open")
	var asked: PlayerChoice = g.awaiting_choice
	assert_true(asked.is_cost)
	assert_eq(asked.source, "Orcish Mechanics")
	assert_eq(asked.prompt, "Select artifact to sacrifice.")
	assert_eq(thopter.zone, Mtg.Zone.BATTLEFIELD, "nothing paid yet")
	assert_false(mech.tapped, "and the {T} is unpaid too")
	assert_ok(g.answer_choice("Ornithopter"))
	assert_eq(thopter.zone, Mtg.Zone.GRAVEYARD, "the cost was paid")
	assert_true(mech.tapped)
	assert_eq(g.stack.size(), 1, "and the ability is on the stack")
	assert_eq(g.choice_log.size(), 1, "the choice is on the record ONCE")
	assert_eq(g.unanswered_choices.size(), 0)


# ------------------------------------------------------ a MANA ability --

func test_a_mana_abilitys_sacrifice_holds_the_duel_open() -> void:
	# Ashnod's Altar: "Sacrifice a creature: Add {C}{C}". A mana ability never
	# uses the stack (CR 605.3a), so the hold has nothing to do with the
	# pre-flight — tap_for_mana raises it itself.
	_human_seat(0)
	var altar := put_battlefield(0, "Ashnod's Altar")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(0, "Wall of Stone")
	assert_ok(g.tap_for_mana(0, altar))
	assert_not_null(g.awaiting_choice, "the activation is held open")
	var asked: PlayerChoice = g.awaiting_choice
	assert_true(asked.is_cost)
	assert_eq(asked.source, "Ashnod's Altar")
	assert_eq(asked.prompt, "Select creature to sacrifice.")
	assert_eq(g.players[0].mana_pool.total(), 0, "no mana yet")
	assert_ok(g.answer_choice("Wall of Stone"))
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "the Wall went")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "and the Bears did not")
	assert_eq(g.players[0].mana_pool.total(), 2, "and the mana arrived")


func test_a_basic_land_sacrifice_wears_the_1997_lower_case() -> void:
	# `@SACRIFICE_LANDS` (Program/Text.res:2661-2667) spells the five basics
	# in lower case: "Select swamp to sacrifice." Horror of Horrors' cost is
	# described as "Swamp".
	_human_seat(0)
	var horror := put_battlefield(0, "Horror of Horrors")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var zombie := put_battlefield(0, "Scathe Zombies")
	assert_ok(g.activate_ability(0, horror, 0, [TargetRef.card(zombie)]))
	assert_not_null(g.awaiting_choice)
	assert_eq((g.awaiting_choice as PlayerChoice).prompt,
		"Select swamp to sacrifice.")


func test_fellwar_stones_colour_holds_the_duel_open() -> void:
	# The fourth row: the colour is chosen as the mana ability is activated,
	# so the engine asks it (ManaAbility.color_options) rather than the card.
	# `@FELLWAR_STONE`, Program/prompts.txt:372-374.
	_human_seat(0)
	var stone := put_battlefield(0, "Fellwar Stone")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Forest")
	assert_ok(g.tap_for_mana(0, stone))
	assert_not_null(g.awaiting_choice, "the tap is held open on the colour")
	var asked: PlayerChoice = g.awaiting_choice
	assert_true(asked.is_cost)
	assert_eq(asked.kind, PlayerChoice.Kind.COLOR)
	assert_eq(asked.prompt, "Fellwar Stone: What kind of mana?")
	assert_eq(asked.colors, [Mtg.ManaColor.B, Mtg.ManaColor.G] as Array[int],
		"and only the colours the opponent's lands could make are offered")
	assert_eq(DuelScreen.choice_options(asked), ["Black", "Green"],
		"which is what the overlay lists — no line the engine would have to "
		+ "substitute away")
	assert_false(stone.tapped, "and the Stone is not tapped yet")
	assert_ok(g.answer_choice(Mtg.ManaColor.G))
	assert_true(stone.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1,
		"the player's own colour, not the heuristic's first")
	assert_eq(g.players[0].mana_pool.total(), 1, "and only one mana")


func test_fellwar_stone_still_asks_nothing_of_a_heuristic_seat() -> void:
	var stone := put_battlefield(0, "Fellwar Stone")
	put_battlefield(1, "Swamp")
	assert_ok(g.tap_for_mana(0, stone))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(g.choice_log.size(), 1, "asked once, not twice")


# --------------------------------------- the as-enters copy replacement --

func test_the_copy_choice_does_reach_the_player() -> void:
	# docs/duel-todo.md §1.3 lists `_apply_enters_as_copy` (Clone, Copy
	# Artifact, Vesuvan Doppelganger) among the six sites the pre-flight
	# "cannot reach", on the grounds that `_put_on_battlefield` is reached
	# from non-resolution paths too. That is true of the METHOD and false of
	# the CARD: a Clone gets onto the battlefield by RESOLVING, which is
	# inside `_run_item` and therefore inside the probe. So the hold works,
	# and the player picks what the Clone copies.
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Wall of Stone")
	var clone := give_hand(0, "Clone")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, clone, []))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "the Clone's copy choice is held open")
	var asked: PlayerChoice = g.awaiting_choice
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_eq(asked.pid, 0)
	assert_eq(asked.source, "Clone")
	assert_gt(asked.candidates.size(), 1, "both bodies are on offer")
	assert_eq(clone.zone, Mtg.Zone.STACK,
		"and nothing has happened yet — the probe was rewound")


func test_the_copy_choice_is_the_players_and_not_the_heuristics() -> void:
	# Answering it picks that body, not the heuristic's first candidate.
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	var clone := give_hand(0, "Clone")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, clone, []))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice)
	assert_ok(g.answer_choice(wall.data.card_name))
	assert_null(g.awaiting_choice, "the resolution finished")
	assert_eq(clone.data.card_name, "Wall of Stone",
		"the Clone copied what the player chose")
	assert_eq(g.unanswered_choices.size(), 0,
		"and nothing was decided on the player's behalf")


func test_the_cleanup_discard_holds_rather_than_falling_through() -> void:
	# The sixth row of the same table: the cleanup discard. It is outside a
	# resolution, so no probe reaches it — but it has never needed one,
	# because the turn machine stops on `awaiting_discard` for any seat that
	# says wants_to_choose_discard() (§1.1). Pinned here so the table and
	# the engine cannot drift apart.
	_human_seat(0)
	for i in 9:
		give_hand(0, "Forest")
	advance_to_step(Mtg.Step.END)
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_discard, "the discard phase is held open")
	assert_gt(g.discard_count, 0)
	assert_eq(g.unanswered_choices.size(), 0,
		"nobody discarded on the player's behalf")


# ------------------------------------------- withdrawing a cost question --
#
# The hold is taken BEFORE anything is paid (the block beside
# MtgGame._pending_action), so a player who clicked Ashnod's Altar and saw
# "Select creature to sacrifice." can simply think better of it: the whole
# proposal is retracted (CR 601.2h, CR 728.1) and nothing needs undoing.
# Until 2026-09-02 the engine had no door for that — the only exits were a
# sacrifice or a concede.

func test_a_held_mana_ability_can_be_withdrawn() -> void:
	_human_seat(0)
	var altar := put_battlefield(0, "Ashnod's Altar")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.tap_for_mana(0, altar))
	assert_not_null(g.awaiting_choice, "the activation is held open")
	assert_ok(g.cancel_choice())
	assert_null(g.awaiting_choice, "the question is gone")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "nothing was sacrificed")
	assert_eq(g.players[0].mana_pool.total(), 0, "and no mana arrived")
	assert_false(altar.tapped, "the Altar was never tapped")
	assert_ok(g.pass_priority(g.priority_player))   # the duel plays on


func test_a_withdrawn_action_can_be_issued_again_from_scratch() -> void:
	# The answer count is cleared with the hold: the second activation asks
	# its FIRST question again rather than serving a stale answer.
	_human_seat(0)
	var altar := put_battlefield(0, "Ashnod's Altar")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(0, "Wall of Stone")
	assert_ok(g.tap_for_mana(0, altar))
	assert_ok(g.cancel_choice())
	assert_ok(g.tap_for_mana(0, altar))
	assert_not_null(g.awaiting_choice, "asked afresh")
	assert_eq((g.awaiting_choice as PlayerChoice).prompt,
		"Select creature to sacrifice.")
	assert_ok(g.answer_choice("Wall of Stone"))
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 2)


func test_a_held_additional_cost_can_be_withdrawn() -> void:
	# Metamorphosis' sacrifice: the spell stays in hand, the mana stays in
	# the pool, the creature stays on the battlefield (CR 601.2h: a cost
	# not fully paid leaves the game as it was).
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	var bear := put_battlefield(0, "Grizzly Bears")
	var meta := give_hand(0, "Metamorphosis")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, meta, []))
	assert_not_null(g.awaiting_choice)
	assert_ok(g.cancel_choice())
	assert_null(g.awaiting_choice)
	assert_eq(meta.zone, Mtg.Zone.HAND, "the spell never left the hand")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 1, "the mana is still there")
	assert_eq(g.stack.size(), 0)


func test_a_turn_based_question_cannot_be_withdrawn() -> void:
	# Smoke's untap pick is not a cost — the untap step has to finish.
	put_battlefield(0, "Smoke")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	bears.tapped = true
	giant.tapped = true
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_not_null(g.awaiting_choice, "the untap step held on a question")
	assert_refused(g.cancel_choice(), "must be answered")
	assert_not_null(g.awaiting_choice, "still held")
	assert_ok(g.answer_choice("Hill Giant"))
	assert_null(g.awaiting_choice)


func test_an_adverse_question_cannot_be_withdrawn() -> void:
	# Arena's pick belongs to the OPPONENT: the activator's action is not
	# theirs to retract, and they have no way out of the question.
	_human_seat(1)
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	assert_not_null(g.awaiting_choice)
	assert_true((g.awaiting_choice as PlayerChoice).adverse)
	assert_refused(g.cancel_choice(), "must be answered")
	assert_not_null(g.awaiting_choice, "still held")


func test_nothing_held_means_nothing_to_withdraw() -> void:
	assert_refused(g.cancel_choice(), "nothing is waiting")
