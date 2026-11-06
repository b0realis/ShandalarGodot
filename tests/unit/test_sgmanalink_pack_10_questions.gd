extends GameTest
## PACK 10'S QUESTIONS REACH A GUEST SEAT. Every question the Urza block
## added is one of the engine's existing kinds (YES_NO, OPTION, COLOR,
## CARD), held for a human seat on an existing pending action, so the
## SGManalink referee (`SgPracticeMatch`) puts it to the seat it is for —
## here seat 1, the guest — with a valid view at both seats; the other
## seat only waits, and is never shown the guest's hidden hand while it
## decides (rule 8). One test per shape, each with the printed card:
##
##  * echo's "pay or sacrifice" (E1, Goblin Patrol) — an upkeep trigger;
##  * the draw step's own question (E11, Island Sanctuary) — turn-based;
##  * Show and Tell's "may" and its card (E10) — the active seat first;
##  * "untap up to N lands" (B9, Snap) — a number, then the lands;
##  * "reveal any number of white cards" (B2, Scent of Jasmine) — a
##    number, then which, the names shown to both afterwards;
##  * Metalworker's reveal to pay (E8) and a mana trigger's colour asked
##    before the tap (E8, Fertile Ground);
##  * Storage Matrix's kind in the untap step (E9) and Damping Engine's
##    special action with its sacrifice (E9);
##  * Defensive Formation: the DEFENDER divides the attacker's damage (E6);
##  * Serra's Hymn's divided total read from its counters (E7).

var referee: SgPracticeMatch


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	referee = null
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


# ---------------------------------------------------------------- fixture --

## Pass (declaring nothing) until a question is held; the question.
func _until_asked() -> PlayerChoice:
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 800:
		_advance_once()
		guard += 1
	return g.awaiting_choice


## Pass until [param ready] says so (a declaration is waiting, say).
func _until(ready: Callable) -> void:
	var guard := 0
	while not bool(ready.call()) and not g.game_over and guard < 800:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1


## The guest's question as both seats' views carry it: seat 1 the
## question, seat 0 only the wait. Both views pass the wire check.
func _guest_sees(prompt_part: String) -> Dictionary:
	var theirs := referee.view(1)
	var mine := referee.view(0)
	assert_true(SgViewProtocol.game(theirs), "the guest's view is valid")
	assert_true(SgViewProtocol.game(mine), "the host seat's view is valid")
	assert_eq(String(theirs.mode), "choice")
	assert_eq(int(theirs.actor), 1, "the guest decides")
	assert_eq(int(mine.actor), 1, "the host seat sees who decides")
	assert_eq(mine.choice, {}, "...and nothing of the question")
	if prompt_part != "":
		assert_string_contains(String(theirs.choice.get("prompt", "")), prompt_part)
	return theirs.choice


## The first line of [param choice] that begins with [param prefix], or -1.
static func _line(choice: Dictionary, prefix: String) -> int:
	var lines: Array = choice.get("options", [])
	for i in lines.size():
		if String(lines[i]).begins_with(prefix):
			return i
	return -1


func _answer(pid: int, prefix: String) -> void:
	var choice: Dictionary = referee.view(pid).choice
	var at := _line(choice, prefix)
	assert_ne(at, -1, "%s is a line of %s" % [prefix, str(choice.get("options", []))])
	assert_ok(referee.act(pid, {"op": "choice", "picks": [maxi(0, at)]}))


## Seat 0 passes, so the guest holds priority in seat 0's main phase.
func _guest_priority() -> void:
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


# ================================================================== echo --

func test_echo_asks_the_guest_to_pay_or_sacrifice() -> void:
	var patrol := put_battlefield(1, "Goblin Patrol")
	var mountain := put_battlefield(1, "Mountain")
	var asked := _until_asked()
	assert_not_null(asked, "held at the guest's upkeep")
	assert_eq(g.active_player, 1)
	var choice := _guest_sees("echo")
	assert_eq(choice.options, ["Yes", "No"])
	_answer(1, "Yes")
	assert_null(g.awaiting_choice)
	assert_eq(patrol.zone, Mtg.Zone.BATTLEFIELD, "paid")
	assert_true(mountain.tapped)


# ============================================================ draw step --

func test_the_draw_steps_question_is_held_for_the_guest() -> void:
	put_battlefield(1, "Island Sanctuary")
	var asked := _until_asked()
	assert_not_null(asked)
	assert_eq(g.current_step(), Mtg.Step.DRAW, "held in the draw step itself")
	assert_eq(asked.source, MtgGame.DRAW_STEP_SOURCE)
	var hand := g.players[1].hand.size()
	var choice := _guest_sees("Select draw potential.")
	assert_eq(choice.options, ["Yes", "No"])
	_answer(1, "Yes")
	assert_null(g.awaiting_choice)
	assert_eq(g.players[1].hand.size(), hand, "the draw was skipped")


# ========================================================= Show and Tell --

func test_show_and_tell_asks_each_seat_in_turn_and_hides_the_guests_hand() -> void:
	var spell := give_hand(0, "Show and Tell")
	var angel := give_hand(0, "Serra Angel")
	var wurm := give_hand(1, "Craw Wurm")
	give_hand(1, "Grizzly Bears")
	give_hand(1, "Giant Growth")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell))
	var asked := _until_asked()
	assert_not_null(asked)
	assert_eq(asked.pid, 0, "the active player chooses first (CR 101.4)")
	var guard := 0
	while g.awaiting_choice != null and g.awaiting_choice.pid == 0 and guard < 8:
		_answer(0, "Serra Angel" if g.awaiting_choice.kind == PlayerChoice.Kind.CARD else "Yes")
		guard += 1
	assert_not_null(g.awaiting_choice, "then the guest")
	var choice := _guest_sees("Show and Tell")
	assert_false(SgProtocol.encode(referee.view(0)).contains("Craw Wurm"),
		"rule 8: the host seat is never shown the guest's hand")
	_answer(1, "Yes")
	choice = _guest_sees("Choose a card to put onto the battlefield")
	assert_ne(_line(choice, "Craw Wurm"), -1)
	assert_ne(_line(choice, "Grizzly Bears"), -1)
	assert_eq(_line(choice, "Giant Growth"), -1, "an instant is no candidate")
	_answer(1, "Craw Wurm")
	assert_null(g.awaiting_choice)
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "the guest's card arrived with the host's")
	assert_eq(wurm.controller_id, 1)


# ================================================= untap up to N lands --

func test_snaps_untap_asks_the_guest_how_many_and_which() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var snap := give_hand(1, "Snap")
	var islands: Array = [put_battlefield(1, "Island"), put_battlefield(1, "Island")]
	for island in islands: island.tapped = true
	add_mana(1, Mtg.ManaColor.U)
	add_mana(1, Mtg.ManaColor.C)
	_guest_priority()
	assert_ok(g.cast_spell(1, snap, [TargetRef.card(bears)]))
	assert_not_null(_until_asked())
	var choice := _guest_sees("untap how many lands")
	assert_eq(choice.options, ["0", "1", "2"])
	_answer(1, "2")
	var guard := 0
	while g.awaiting_choice != null and g.awaiting_choice.pid == 1 and guard < 4:
		_guest_sees("select a land to untap")
		_answer(1, "Island")
		guard += 1
	assert_null(g.awaiting_choice)
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_false(islands[0].tapped or islands[1].tapped, "both untapped")


# ============================================ reveal any number of cards --

func test_scent_of_jasmine_asks_the_guest_how_many_and_which() -> void:
	var scent := give_hand(1, "Scent of Jasmine")
	give_hand(1, "Serra Angel")
	give_hand(1, "Savannah Lions")
	add_mana(1, Mtg.ManaColor.W)
	_guest_priority()
	assert_ok(g.cast_spell(1, scent))
	assert_not_null(_until_asked())
	var choice := _guest_sees("reveal how many white cards")
	assert_eq(choice.options, ["0", "1", "2"])
	assert_false(SgProtocol.encode(referee.view(0)).contains("Savannah Lions"),
		"rule 8: nothing is revealed before the guest says what")
	_answer(1, "1")
	_guest_sees("reveal a white card")
	_answer(1, "Savannah Lions")
	assert_null(g.awaiting_choice)
	assert_eq(g.players[1].life, 22)
	var shown: Array = referee.actions.information[0]
	assert_false(shown.is_empty(), "the host seat is shown the reveal")
	assert_true((shown[-1].cards as Array).has("Savannah Lions"))
	assert_false((shown[-1].cards as Array).has("Serra Angel"), "only the card revealed")


# ============================================================ mana (E8) --

func test_metalworkers_reveal_is_the_guests_question() -> void:
	var worker := put_battlefield(1, "Metalworker")
	give_hand(1, "Sol Ring")
	give_hand(1, "Ornithopter")
	_guest_priority()
	assert_ok(referee.act(1, {"op": "mana", "card": referee._handle(1, worker), "index": 0}))
	var choice := _guest_sees("artifact")
	assert_eq(choice.options, ["0", "1", "2"])
	assert_true(bool(choice.cancel), "the tap may be withdrawn")
	_answer(1, "1")
	_guest_sees("Select artifact card to reveal.")
	_answer(1, "Ornithopter")
	assert_null(g.awaiting_choice)
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.C), 2)
	assert_true((referee.actions.information[0][-1].cards as Array).has("Ornithopter"))


func test_fertile_grounds_colour_is_asked_of_the_guest_before_the_tap() -> void:
	var forest := put_battlefield(1, "Forest")
	var ground := give_hand(1, "Fertile Ground")
	g.attach_aura_from_anywhere(ground, forest, 1)
	g.recalculate()
	_guest_priority()
	assert_ok(referee.act(1, {"op": "tap", "card": referee._handle(1, forest)}))
	var choice := _guest_sees("Fertile Ground")
	assert_eq(choice.options, ["White", "Blue", "Black", "Red", "Green"])
	_answer(1, "Red")
	assert_null(g.awaiting_choice)
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.R), 1)


# ===================================================== untap step (E9) --

func test_storage_matrixs_kind_is_the_guests_in_their_untap_step() -> void:
	put_battlefield(0, "Storage Matrix")
	var forest := put_battlefield(1, "Forest")
	var bears := put_battlefield(1, "Grizzly Bears")
	forest.tapped = true
	bears.tapped = true
	var asked := _until_asked()
	assert_not_null(asked)
	assert_eq(asked.pid, 1)
	assert_eq(g.current_step(), Mtg.Step.UNTAP)
	var choice := _guest_sees("Untap only artifacts, creatures, or lands this step?")
	assert_eq(choice.options, ["Artifact", "Creature", "Land"])
	assert_false(bool(choice.cancel), "a turn-based question must be answered")
	_answer(1, "Creature")
	assert_null(g.awaiting_choice)
	assert_false(bears.tapped)
	assert_true(forest.tapped)


func test_damping_engines_ignore_is_the_guests_special_action() -> void:
	var engine := put_battlefield(0, "Damping Engine")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	_guest_priority()
	var label := "Sacrifice a permanent: ignore Damping Engine this turn"
	var view := referee.view(1)
	var at: int = (view.specials as Array).find(label)
	assert_ne(at, -1, "the guest is offered the special action")
	assert_eq(String(view.presentation.special_rows[maxi(0, at)][0]), "ignore_effect")
	assert_eq((referee.view(0).specials as Array).find(label), -1, "never the other seat")
	assert_ok(referee.act(1, {"op": "special", "index": at}))
	var choice := _guest_sees("Select permanent to sacrifice.")
	assert_true(bool(choice.cancel), "the sacrifice is a cost: it may be withdrawn")
	_answer(1, "Grizzly Bears")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.effect_ignored_by(engine, 1))


# ========================================================= combat (E6) --

func test_defensive_formation_hands_the_division_to_the_defending_guest() -> void:
	put_battlefield(1, "Defensive Formation")
	var wurm := put_battlefield(0, "Craw Wurm")
	var left := put_battlefield(1, "Grizzly Bears")
	var right := put_battlefield(1, "Grizzly Bears")
	_until(func() -> bool: return g.awaiting_attackers)
	assert_ok(referee.act(0, {"op": "attack", "cards": [referee._handle(0, wurm)]}))
	_until(func() -> bool: return g.awaiting_blockers)
	var w := referee._handle(1, wurm)
	assert_ok(referee.act(1, {"op": "block", "pairs": [[referee._handle(1, left), w],
		[referee._handle(1, right), w]]}))
	_until(func() -> bool: return g.awaiting_damage_assignment)
	var theirs := referee.view(1)
	var mine := referee.view(0)
	assert_true(SgViewProtocol.game(theirs))
	assert_true(SgViewProtocol.game(mine))
	assert_eq(String(theirs.mode), "damage")
	assert_eq(int(theirs.actor), 1, "the defender assigns the Wurm's damage")
	assert_false(theirs.damage_request.is_empty(), "with the division's targets")
	assert_eq(int(theirs.damage_request.amount), 6)
	assert_eq(mine.damage_request, {}, "the attacker only watches")
	assert_refused(referee.act(0, {"op": "damage", "points": []}), "Wait for your decision")
	assert_ok(referee.act(1, {"op": "damage", "points": [[referee._handle(1, left), 6],
		[referee._handle(1, right), 0]]}))
	_until(func() -> bool: return g.current_step() == Mtg.Step.COMBAT_END or g.current_step() == Mtg.Step.MAIN2)
	assert_eq(left.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(right.zone, Mtg.Zone.BATTLEFIELD, "the guest's division stood")


# ====================================================== divided X (E7) --

func test_serras_hymns_divided_total_reaches_the_guests_announcement() -> void:
	var hymn := put_battlefield(1, "Serra's Hymn")
	g.add_counters(hymn, "verse", 3)
	_guest_priority()
	assert_ok(referee.act(1, {"op": "prepare", "card": referee._handle(1, hymn),
		"kind": "ability", "index": 0, "x": 0, "mode": 0}))
	var view := referee.view(1)
	assert_true(SgViewProtocol.game(view))
	assert_eq(view.announcement.slots.size(), 1)
	assert_eq(int(view.announcement.slots[0].divided), 3, "X read from its verse counters")
	assert_eq(referee.view(0).announcement, {}, "the host seat sees no announcement of the guest's")
