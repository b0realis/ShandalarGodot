extends GameTest
## THE LOOP LIMIT (2026-10-19, [constant MtgGame.LOOP_LIMIT], [QoL]). The
## owner: *"Yes all infinity loops should be accompanied by a message - You
## created and infinity loop - stopping at 1000 steps. And lets stop these
## loops at 1000 steps so no freeze can happen!"*
##
## The universal backstop under every loop — a player's, the computer's,
## and the mandatory kind that needs no input at all:
##  * a MANDATORY trigger loop (two test cards that feed each other) stops
##    at the thousandth trigger with the message, and the game goes on to
##    the next step, whose count starts clean;
##  * a player's Sliver Queen + Heartstone + Ashnod's Altar loop through
##    the engine API is refused at its 1001st step with the reason, and
##    works again in the next step;
##  * the computer's Aluren + Shrieking Drake loop, with the AI's own
##    guard turned off, still ends the turn at the limit with the message;
##  * searches and probes never trip it for real.

const PACKS := ["pack-8", "pack-9"]


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id in PACKS)


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func _said_loop(seat_name: String) -> bool:
	var line := "%s created an infinite loop — stopping at %d steps." % [seat_name, MtgGame.LOOP_LIMIT]
	return Array(g.log_lines).has(line)


## Pass priority round until the stack is empty, with a guard far above the
## limit — the stack this loop builds is the thing under test.
func _settle(cap := 5000) -> int:
	var rounds := 0
	while not g.stack.is_empty() and not g.game_over and rounds < cap:
		assert_ok(g.pass_priority(g.priority_player))
		rounds += 1
	assert_lt(rounds, cap, "the stack never emptied")
	return rounds


# --------------------------------------------- a mandatory trigger loop --

## "Whenever this artifact becomes tapped, untap it."
static func _bellows() -> CardData:
	return CardData.new("Test Bellows", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _untap_it,
			"Whenever this artifact becomes tapped, untap it.", _itself))

## "Whenever another permanent becomes untapped, tap it."
static func _anvil() -> CardData:
	return CardData.new("Test Anvil", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_UNTAPPED, _tap_it,
			"Whenever another permanent becomes untapped, tap it.", _another))

static func _itself(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s

static func _another(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") != s

static func _untap_it(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.untap_permanent(s)

static func _tap_it(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var it: CardInstance = e.data.get("instance")
	if it != null:
		g.tap_permanent(it)


func test_a_mandatory_trigger_loop_stops_at_the_limit_and_the_game_goes_on() -> void:
	var bellows := put_synthetic(0, _bellows())
	put_synthetic(0, _anvil())
	g.tap_permanent(bellows)   # the first push; nobody chooses anything after it
	_settle()
	assert_eq(g.loop_steps, MtgGame.LOOP_LIMIT, "the thousandth trigger, and not one more")
	assert_eq(g.loop_stopped_by, 0)
	assert_true(_said_loop("P0"), "the owner's message is in the log")
	assert_true(g.stack.is_empty())
	assert_false(g.game_over, "a loop cut is no draw (CR 104.4b set aside)")
	var step := g.current_step()
	advance_to_step(Mtg.Step.MAIN2)
	assert_ne(g.current_step(), step, "the game moved on")
	assert_eq(g.loop_steps, 0, "the next step starts clean")
	assert_eq(g.loop_stopped_by, -1)


# ---------------------------------------------- a player's loop by hand --

func test_a_players_loop_is_refused_at_the_limit_and_the_next_step_resets() -> void:
	put_battlefield(0, "Heartstone")
	var queen := put_battlefield(0, "Sliver Queen")
	var altar := put_battlefield(0, "Ashnod's Altar")
	var seat := Seat.new()
	seat.picks = ["Sliver"]
	g.set_agent(0, seat)
	add_mana(0, Mtg.ManaColor.C, 1)
	var rounds := 0
	var refusal := ""
	while rounds < 2 * MtgGame.LOOP_LIMIT:
		refusal = g.activate_ability(0, queen, 0)
		if refusal != "":
			break
		resolve_stack()
		refusal = g.tap_for_mana(0, altar)
		if refusal != "":
			break
		rounds += 1
	assert_eq(rounds, MtgGame.LOOP_LIMIT / 2, "two steps a round: the Queen and the Altar")
	assert_eq(refusal, MtgGame.LOOP_REFUSAL, "the reason is given")
	assert_eq(g.tap_for_mana(0, altar), MtgGame.LOOP_REFUSAL, "a mana ability too")
	assert_true(_said_loop("P0"))
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.loop_steps, 0)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, queen, 0))


## A card ask answered with the first candidate named in [member picks].
class Seat extends DecisionAgent:
	var picks: Array[String] = []
	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		for wanted in picks:
			for c in candidates:
				if c.data.card_name == wanted:
					return c
		return super(game, pid, candidates, prompt)


# ---------------------------------------- the computer's loop, unguarded --

func test_the_computers_loop_ends_at_the_limit_without_its_own_guard() -> void:
	var p := AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	ai.runaway_guard = false   # the AI's own guard off: the engine's limit is under it
	g.set_agent(0, ai)
	var them := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, them)
	put_battlefield(0, "Aluren")
	give_hand(0, "Shrieking Drake")
	var turn := g.turn_number
	var rounds := 0
	while not g.game_over and g.turn_number == turn and rounds < 20000:
		var a := ai.act(g)
		var b := them.act(g)
		if a == "" and b == "":
			break
		rounds += 1
	assert_lt(rounds, 20000, "the turn ended")
	assert_ne(g.turn_number, turn)
	assert_true(_said_loop("P0"), "the computer's loop is named")


# ------------------------------------------------ searches never trip it --

func test_a_search_never_trips_the_limit_for_real() -> void:
	put_battlefield(0, "Heartstone")
	var queen := put_battlefield(0, "Sliver Queen")
	put_battlefield(0, "Ashnod's Altar")
	g.loop_steps = MtgGame.LOOP_LIMIT - 1
	var mark := g.make_mark()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, queen, 0))
	assert_eq(g.loop_stopped_by, 0, "inside the search the limit holds")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.loop_steps, MtgGame.LOOP_LIMIT - 1, "and the search is unwound")
	assert_eq(g.loop_stopped_by, -1)
	assert_false(_said_loop("P0"), "a probe says nothing")
