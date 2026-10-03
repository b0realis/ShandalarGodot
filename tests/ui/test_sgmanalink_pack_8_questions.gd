extends GameTest
## PACK 8 QUESTIONS AND WINDOWS AT AN SGMANALINK TABLE — what the Mirage
## block's engine asks a HUMAN seat, put by the referee (`SgDuelActions`'
## private `choice` DTO) and answered on the real networked screen
## (`SgDuelView`). Only the seat being asked ever reads a question.
##
##  * A trigger with two target SLOTS (Goblin Grenadiers) — slot by slot.
##  * The untap/upkeep trigger batch — "Which of your triggered abilities
##    resolves first?" (`MtgGame.TRIGGER_ORDER_PROMPT`).
##  * An "in any order" sequence (Teferi's Puzzle Box,
##    `PlayerChoice.in_order`) ends in one click with the local screen's own
##    `Done — keep this order.` line: the rest go in the order LISTED, which
##    at a networked table is the referee's sorted list.
##  * Ward of Lights' colour, chosen as it enters.
##  * Heat Wave's life tax on blocking: the seat's own screen prices the
##    pencilled blocks and refuses one it cannot pay, as the local one does.
##  * The cleanup step's priority window (CR 514.3a).

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []
var refusals: Array = []
var heard: Array = []


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	refusals.clear()
	heard.clear()
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null


# ---------------------------------------------------------------- fixture --

func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Pack eight", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.action_requested.connect(_act.bind(screen, seat))
	screen.present(_room(seat), true, false)
	return screen


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	commands.append(action.duplicate(true))
	var error := referee.act(seat, action)
	if not error.is_empty():
		refusals.append(error)
		screen.show_notice(error)
	else: revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8: await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


## Pass (declaring nothing) until a question is held or [param until] holds.
func _drive(until: Callable, guard := 400) -> void:
	var n := 0
	while g.awaiting_choice == null and not g.game_over and not bool(until.call()) and n < guard:
		if g.awaiting_attackers: g.declare_attackers(g.active_player, [])
		elif g.awaiting_blockers: g.declare_blockers(g.opponent_of(g.active_player), {})
		else: g.pass_priority(g.priority_player)
		n += 1


static func _index_of(options: Array, prefix: String) -> int:
	for i in options.size():
		if String(options[i]).begins_with(prefix): return i
	return -1


static func _is_self(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s

static func _is_land(i: CardInstance) -> bool:
	return i.is_land()

static func _enemy_first(_g: MtgGame, source: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return a.instance_id != source.id and b.instance_id == source.id


static func _grenade(game: MtgGame, _source: CardInstance, _e: GameEvent) -> void:
	for slot in 2:
		var ref := game.current_trigger_target(slot)
		if ref != null:
			game.destroy(game.find_instance(ref.instance_id))


static func _grenadier() -> CardData:
	return CardData.new("Test Grenadier", "{R}", Mtg.CardType.CREATURE).pt(2, 2) \
		.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _grenade,
			"When this creature enters, destroy target creature and target land.", _is_self)
			.targeting(TargetSpec.creature(), _enemy_first, "Select target creature.")
			.and_targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land),
				_enemy_first, "Select target land."))


static func _choose_ward(game: MtgGame, s: CardInstance, pid: int) -> void:
	game._rec(s, &"memory")
	s.memory["ward_color"] = game.agents[pid].choose_color(game, pid,
		"Test Ward: choose a color", Mtg.ManaColor.R)


static func _ward() -> CardData:
	return CardData.new("Test Ward", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.grants_host_protection_from_chosen("ward_color",
			"Enchanted creature has protection from the chosen color.") \
		.as_it_enters(_choose_ward)


static func _nonblue(blocker: CardInstance) -> bool:
	return not blocker.has_color(Mtg.ManaColor.U)


static func _heat(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if not inst.is_creature():
			continue
		inst.cur_block_restrictions.append({"desc": "nonblue creatures", "filter": _nonblue})
		CombatState.add_block_life_tax(inst, source, 1, _nonblue, "pay 1 life")


static func _heat_wave() -> CardData:
	return CardData.new("Test Heat Wave", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_heat, "Nonblue creatures can't block creatures you control unless their controller pays 1 life for each blocking creature they control."))


static func _bear(card_name := "Test Bear") -> CardData:
	return CardData.new(card_name, "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


class BoxEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x := 0) -> void:
		var left: Array[CardInstance] = game.players[controller].hand.duplicate()
		var n := left.size()
		while not left.is_empty():
			var pick: CardInstance = left[0]
			if left.size() > 1:
				var answer: CardInstance = game.agents[controller].choose_card_in_order(game, controller, left,
					"Test Box: put a card on the bottom of your library (each goes beneath the last)")
				if answer != null and left.has(answer):
					pick = answer
			left.erase(pick)
			game.put_on_bottom_of_library(pick)
		game.draw_cards(controller, n)
	func describe() -> String:
		return "put your hand on the bottom of your library in any order, then draw that many"


# ============================================ a trigger with two targets --

func test_a_two_slot_trigger_is_answered_slot_by_slot_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var their_bear := put_synthetic(1, _bear("Their Bear"))
	var their_land := put_battlefield(1, "Forest")
	var my_land := put_battlefield(0, "Mountain")
	var grenadier := give_synthetic(0, _grenadier())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, grenadier))
	_drive(func() -> bool: return g.stack.is_empty())
	assert_not_null(g.awaiting_choice, "the first slot is held for the seat")
	if g.awaiting_choice == null: return
	assert_eq(referee.view(1).choice, {}, "the other seat is not shown the question")
	var screen := _screen()
	await _pump()
	var first: Dictionary = screen.projection.view.choice
	assert_eq(first.prompt, "Select target creature.")
	var pick := _index_of(first.options, "Their Bear")
	assert_gte(pick, 0)
	screen._on_choice_option(pick)
	await _pump()
	assert_eq(refusals, [])
	var second: Dictionary = screen.projection.view.choice
	assert_eq(second.get("prompt"), "Select target land.")
	assert_gte(_index_of(second.get("options", []), "Mountain"), 0, "every legal land is offered")
	screen._on_choice_option(_index_of(second.get("options", []), "Forest"))
	await _pump()
	assert_eq(refusals, [])
	assert_null(g.awaiting_choice)
	assert_eq(g.stack.size(), 1, "the trigger is on the chain")
	resolve_stack()
	assert_eq(their_bear.zone, Mtg.Zone.GRAVEYARD, "slot 1's pick")
	assert_eq(their_land.zone, Mtg.Zone.GRAVEYARD, "slot 2's pick")
	assert_eq(my_land.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.unanswered_choices.size(), 0)


# ===================================== the untap/upkeep trigger batch --

## The resolutions, as they happen — never the referee's pre-flight probe
## of them (a HumanAgent seat is probed before it is asked).
func _note_in(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	if not game.is_probing(): heard.append("in")


func _note_upkeep(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	if not game.is_probing(): heard.append("upkeep")


func _two_triggers(pid: int) -> CardInstance:
	var c := CardData.new("Test Wurm", "{1}{U}", Mtg.CardType.CREATURE).pt(1, 1)
	c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_IN,
		_note_in,
		"Whenever this creature phases in, note it.", _is_self))
	c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		_note_upkeep,
		"At the beginning of your upkeep, note it.",
		func(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
			return int(event.data.get("player", -1)) == source.controller_id))
	return put_synthetic(pid, c)


func test_the_trigger_order_question_is_put_to_its_seat_over_the_network() -> void:
	var wurm := _two_triggers(0)
	assert_true(g.phase_out(wurm))
	_drive(func() -> bool: return false)
	assert_not_null(g.awaiting_choice, "the mixed batch is ordered by its controller")
	if g.awaiting_choice == null: return
	assert_eq(g.turn_number, 3)
	assert_eq(referee.view(1).choice, {}, "the other seat only waits")
	var screen := _screen()
	await _pump()
	var question: Dictionary = screen.projection.view.choice
	assert_eq(question.prompt, MtgGame.TRIGGER_ORDER_PROMPT)
	assert_eq(question.options.size(), 2)
	var upkeep := -1
	for i in question.options.size():
		if String(question.options[i]).contains("upkeep"): upkeep = i
	assert_gte(upkeep, 0)
	screen._on_choice_option(upkeep)
	await _pump()
	assert_eq(refusals, [])
	assert_null(g.awaiting_choice)
	resolve_stack()
	assert_eq(heard, ["upkeep", "in"], "the upkeep trigger first, as the seat asked")


# ============================================= "in any order", one click --

func test_keep_this_order_finishes_the_sequence_in_the_order_listed() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var box := give_synthetic(0, CardData.new("Test Box", "{0}", Mtg.CardType.INSTANT).spell(BoxEffect.new()))
	var cards: Array = []
	for card_name in ["Card C", "Card A", "Card E", "Card B", "Card D"]:
		cards.append(give_synthetic(0, CardData.new(card_name, "{1}", Mtg.CardType.ARTIFACT)))
	assert_ok(g.cast_spell(0, box))
	_drive(func() -> bool: return g.stack.is_empty())
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	var screen := _screen()
	await _pump()
	var first: Dictionary = screen.projection.view.choice
	assert_eq(first.options, ["Card A", "Card B", "Card C", "Card D", "Card E", DuelScreen.KEEP_ORDER_LINE])
	screen._on_choice_option(first.options.find("Card D"))
	await _pump()
	var second: Dictionary = screen.projection.view.choice
	assert_eq(second.get("options"), ["Card A", "Card B", "Card C", "Card E", DuelScreen.KEEP_ORDER_LINE])
	screen._on_choice_option(4)
	await _pump()
	assert_eq(refusals, [])
	assert_null(g.awaiting_choice, "no further question")
	assert_true(g.stack.is_empty(), "the box resolved")
	var lib: Array = g.players[0].library
	var order := ["Card D", "Card A", "Card B", "Card C", "Card E"]
	for i in range(1, order.size()):
		var above := -1
		var below := -1
		for at in lib.size():
			if lib[at].data.card_name == order[i - 1]: above = at
			if lib[at].data.card_name == order[i]: below = at
		assert_lt(below, above, "%s lies beneath %s" % [order[i], order[i - 1]])
	assert_eq(g.unanswered_choices.size(), 0, "nothing decided on the player's behalf")


func test_a_question_outside_such_a_sequence_never_offers_the_line() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var their_bear := put_synthetic(1, _bear("Their Bear"))
	put_battlefield(1, "Forest")
	give_synthetic(0, _grenadier())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, g.players[0].hand[0]))
	_drive(func() -> bool: return g.stack.is_empty())
	assert_not_null(g.awaiting_choice)
	assert_false(referee.view(0).choice.get("options", []).has(DuelScreen.KEEP_ORDER_LINE))
	assert_not_null(their_bear)


# ===================================================== Ward of Lights --

func test_ward_of_lights_asks_its_colour_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_synthetic(0, _bear())
	var ward := give_synthetic(0, _ward())
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	_drive(func() -> bool: return g.stack.is_empty())
	assert_not_null(g.awaiting_choice, "the resolution is held for the colour")
	if g.awaiting_choice == null: return
	assert_eq(referee.view(1).choice, {})
	var screen := _screen()
	await _pump()
	var question: Dictionary = screen.projection.view.choice
	assert_eq(question.options, ["White", "Blue", "Black", "Red", "Green"])
	assert_false(question.cancel, "a resolution's question must be answered")
	screen._on_choice_option(2)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(ward.memory.get("ward_color", 0)), Mtg.ManaColor.B)
	var shown := 0
	for face in referee.view(1).players[0].battlefield:
		if face.name == "Test Bear": shown = int(face.protection)
	assert_true(shown & Mtg.ManaColor.B != 0, "both seats read the protection")


# ================================================ a life tax to block --

func _their_attack_into_blocks(my_life: int, blockers: int) -> Array:
	put_synthetic(1, _heat_wave())
	var ogre := put_battlefield(1, "Gray Ogre")
	var mine: Array = []
	for i in blockers: mine.append(put_synthetic(0, _bear("Test Bear %d" % i)))
	g._probing = true
	g.players[0].life = my_life
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	g.awaiting_attackers = true
	g._probing = false
	assert_ok(g.declare_attackers(1, [ogre.id]))
	_drive(func() -> bool: return g.awaiting_blockers)
	assert_true(g.awaiting_blockers)
	return [ogre, mine]


func test_heat_waves_tax_is_shown_and_paid_with_the_network_declaration() -> void:
	var setup := _their_attack_into_blocks(20, 1)
	var ogre: CardInstance = setup[0]
	var bear: CardInstance = setup[1][0]
	var screen := _screen()
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.BLOCKERS)
	screen._pick_block(_local(screen, bear))
	screen._pick_block(_local(screen, ogre))
	assert_string_contains(screen._prompt_label.text, "(Blocking costs 1 life.)")
	screen._on_confirm()
	await _pump()
	if g.awaiting_blockers:
		screen._on_confirm()
		await _pump()
	assert_eq(refusals, [])
	assert_false(g.awaiting_blockers, "declared")
	assert_eq(g.combat.blocks.get(bear.id), ogre.id)
	assert_eq(g.players[0].life, 19, "one life for the one blocking creature")


func test_a_block_the_seat_cannot_pay_for_is_refused_as_it_is_pencilled() -> void:
	var setup := _their_attack_into_blocks(1, 2)
	var ogre: CardInstance = setup[0]
	var bears: Array = setup[1]
	var screen := _screen()
	await _pump()
	var local_ogre := _local(screen, ogre)
	screen._pick_block(_local(screen, bears[0]))
	screen._pick_block(local_ogre)
	assert_true(screen._block_map.has(_local(screen, bears[0]).id), "1 life pays for one blocker")
	screen._pick_block(_local(screen, bears[1]))
	screen._pick_block(local_ogre)
	assert_false(screen._block_map.has(_local(screen, bears[1]).id), "a second would cost 2 life")
	assert_string_contains(screen._prompt_label.text,
		"not enough life for all blocking costs (2 life)")
	var view := referee.view(1)
	assert_true(SgViewProtocol.game(view), "the watching seat's view stays valid")


# ========================================= the cleanup step's window --

static func _gain_one(game: MtgGame) -> void:
	game.adjust_life(0, 1)


func test_a_cleanup_trigger_holds_a_priority_window_at_the_networked_table() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var source := put_synthetic(0, _bear())
	g.schedule_cleanup_action(_gain_one, source, 0, "Gain 1 life.")
	_drive(func() -> bool: return g.current_step() == Mtg.Step.CLEANUP and not g.stack.is_empty())
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	assert_eq(g.stack.size(), 1, "the trigger waits on the stack (CR 514.3a)")
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	assert_eq(view.mode, "priority")
	assert_eq(view.step, "CLEANUP")
	var screen := _screen()
	await _pump()
	assert_eq(screen.game.current_step(), Mtg.Step.CLEANUP)
	assert_eq(screen.game.stack.size(), 1)
	assert_eq(screen.game.priority_player, 0, "the active player holds priority")
	assert_false(screen._pass_button.disabled, "Done answers the window")
	assert_ok(referee.act(0, {"op": "pass"}))
	assert_ok(referee.act(1, {"op": "pass"}))
	assert_eq(g.players[0].life, 21, "resolved in the cleanup step")
