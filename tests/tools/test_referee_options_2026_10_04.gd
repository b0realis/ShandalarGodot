extends GameTest
## THE REFEREE'S CASTING LINES (2026-10-04, the MCP play-through): what
## `DeckLab/referee.gd` accepts on top of the wire's strict actions, and
## what it says when a paid-for cast is refused.
##
##  * A line may leave out what has an obvious value — `kind` "spell",
##    `index` 0, `x` 0, `mode` 0, `excluded` [], `count` 1, `targets` [] —
##    and the referee fills it in before the wire's exact-key check
##    (SgProtocol keeps its strict keys). `autoprepare` refused `{op, card,
##    kind, index}` until now.
##  * `autoprepare` with `targets` is the three in one AGENTS.md promised:
##    the announcement is read first with nothing paid, a target that is not
##    among its candidates is refused with NOTHING TAPPED, and then the
##    wire's autoprepare and submit. A target is a slot token, a card handle
##    (`c7`) or `player:0`/`player:1` — what `presentation.targets` says each
##    token stands for; a `submit` takes the same.
##  * A refused prepare/autopay/submit that leaves mana in the pool says so
##    (`floating`), the announcement stays open and `cancel` is offered.
##  * The lead's case end to end: a used Knight of Valor's ability forced
##    through `autoprepare` is refused in the engine's words, nothing tapped,
##    nothing floating — and it is not in the decision's options at all.

const REFEREE := "res://DeckLab/referee.gd"

var referee: SgPracticeMatch
var _lines: Array = []
var _queue: Array = []


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	_lines.clear()
	_queue.clear()


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-8", false)


func _referee():
	var ref = autofree(load(REFEREE).new())
	ref.writer = func(line: String) -> void: _lines.append(JSON.parse_string(line))
	ref.reader = func() -> Variant: return _queue.pop_front() if not _queue.is_empty() else null
	return ref


## One decision for seat 0, answered by [param lines] (JSON objects).
## Returns what `_ask` returned: "" once a line was applied.
func _ask(ref, lines: Array) -> String:
	for line in lines: _queue.append(JSON.stringify(line))
	return ref._ask(0, "priority", func() -> Dictionary: return referee.view(0),
		func(action: Dictionary) -> String: return referee.act(0, action), func() -> void: pass)


func _of(type: String) -> Array:
	return _lines.filter(func(line: Variant) -> bool: return line is Dictionary and line.get("type", "") == type)


func _h(card: CardInstance) -> String:
	return referee._handle(0, card)


# ================================================== the keys left out --

func test_a_casting_line_may_leave_out_what_has_an_obvious_value() -> void:
	var ref = _referee()
	var parse := func(text: String) -> Dictionary: return ref._parse_action(text, 0)
	var auto: Dictionary = parse.call('{"op": "autoprepare", "card": "c5"}')
	assert_false(auto.has("refusal"), str(auto.get("refusal", "")))
	assert_eq(auto.action, {"op": "autoprepare", "card": "c5", "kind": "spell", "index": 0, "mode": 0,
		"excluded": [], "count": 1})
	var ability: Dictionary = parse.call('{"op": "autoprepare", "card": "c5", "kind": "ability", "index": 1}')
	assert_eq(ability.action.kind, "ability")
	assert_eq(int(ability.action.index), 1)
	assert_eq(parse.call('{"op": "prepare", "card": "c3"}').action,
		{"op": "prepare", "card": "c3", "kind": "spell", "index": 0, "x": 0, "mode": 0})
	assert_eq(parse.call('{"op": "autopay"}').action, {"op": "autopay", "excluded": [], "count": 1})
	assert_eq(parse.call('{"op": "submit"}').action, {"op": "submit", "targets": []})
	var pairs: Array = parse.call('{"op": "submit", "targets": ["c9", ["player:1", 2]]}').action.targets
	assert_eq(pairs.size(), 2)
	assert_eq([pairs[0][0], int(pairs[0][1])], ["c9", 0], "a bare target is a pair with amount 0")
	assert_eq([pairs[1][0], int(pairs[1][1])], ["player:1", 2])
	# The three in one: targets ride beside the wire action, and the
	# payment counts them unless the line said a count.
	var three: Dictionary = parse.call('{"op": "autoprepare", "card": "c5", "targets": ["c7", ["player:1", 0]]}')
	assert_false(three.has("refusal"), str(three.get("refusal", "")))
	assert_false(three.action.has("targets"), "never a wire key")
	assert_eq(three.targets.map(func(pair: Array) -> String: return "%s/%d" % [pair[0], int(pair[1])]), ["c7/0", "player:1/0"])
	assert_eq(int(three.action.count), 2)
	assert_eq(int(parse.call('{"op": "autoprepare", "card": "c5", "count": 1, "targets": ["c7", "c8"]}').action.count), 1)
	assert_true(String(parse.call('{"op": "autoprepare", "card": "c5", "targets": [5]}').refusal).contains("autoprepare's targets"))
	assert_true(String(parse.call('{"op": "autoprepare", "card": "c5", "bogus": 1}').refusal).contains("targets"),
		"the refusal names every key it takes")
	assert_true(String(parse.call('{"op": "play"}').refusal).contains("takes exactly the keys op, card"),
		"an op without defaults keeps its strict keys")


# ======================================================= the three in one --

func test_autoprepare_with_targets_casts_in_one_line() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mountain := put_battlefield(0, "Mountain")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	var ref = _referee()
	referee.view(0)
	assert_eq(_ask(ref, [{"op": "autoprepare", "card": _h(bolt), "targets": [_h(bear)]}]), "")
	assert_eq(_of("refused"), [])
	assert_true(mountain.tapped)
	assert_eq(g.stack.size(), 1, "prepared, paid and cast")
	assert_true(referee.actions.draft.is_empty())
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_autoprepare_at_a_player_by_seat() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Mountain")
	var bolt := give_hand(0, "Lightning Bolt")
	var ref = _referee()
	assert_eq(_ask(ref, [{"op": "autoprepare", "card": _h(bolt), "targets": ["player:1"]}]), "")
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_a_target_not_among_the_candidates_is_refused_with_nothing_tapped() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mountain := put_battlefield(0, "Mountain")
	var bolt := give_hand(0, "Lightning Bolt")
	var ref = _referee()
	assert_eq(_ask(ref, [{"op": "autoprepare", "card": _h(bolt), "targets": ["c999"]}]), "eof")
	var refused := _of("refused")
	assert_eq(refused.size(), 1)
	assert_true(String(refused[0].reason).contains("target c999 is not among the announcement's candidates"))
	assert_true(String(refused[0].reason).contains("player:1"), "the refusal names the candidates")
	assert_eq(refused[0].action.targets[0][0], "c999", "the line is echoed with its targets")
	assert_false(refused[0].has("floating"), "nothing was paid")
	assert_false(mountain.tapped, "NOTHING TAPPED")
	assert_true(referee.actions.draft.is_empty(), "the announcement was withdrawn")
	var again: Dictionary = _of("decision").back()
	assert_false(again.options.has("announcement"))


func test_a_submit_may_name_card_handles_and_players() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Mountain")
	var bolt := give_hand(0, "Lightning Bolt")
	assert_ok(referee.act(0, {"op": "prepare", "card": _h(bolt), "kind": "spell", "index": 0, "x": 0, "mode": 0}))
	assert_ok(referee.act(0, {"op": "autopay", "excluded": [], "count": 1}))
	var ref = _referee()
	assert_eq(_ask(ref, [{"op": "submit", "targets": [["player:1", 0]]}]), "")
	resolve_stack()
	assert_eq(g.players[1].life, 17)


# ===================================================== paid and refused --

func test_a_refused_submit_says_what_mana_floats_and_offers_cancel() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Mountain")
	var bolt := give_hand(0, "Lightning Bolt")
	assert_ok(referee.act(0, {"op": "prepare", "card": _h(bolt), "kind": "spell", "index": 0, "x": 0, "mode": 0}))
	assert_ok(referee.act(0, {"op": "autopay", "excluded": [], "count": 1}))
	var ref = _referee()
	_ask(ref, [{"op": "submit", "targets": [["t99", 0]]}])
	var refused := _of("refused")
	assert_eq(refused.size(), 1)
	assert_eq(refused[0].reason, "Target unavailable.")
	var floating: Dictionary = refused[0].get("floating", {})
	assert_eq(floating.keys().size(), 2, "total and the one colour: %s" % floating)
	assert_eq(int(floating.get("total", 0)), 1, "the paid {R} is said, not left to burn silently")
	assert_eq(int(floating.get("R", 0)), 1)
	var again: Dictionary = _of("decision").back()
	assert_true(again.options.has("cancel"), "the announcement stays open; cancel withdraws it")
	assert_true(again.options.has("submit"))


# ============================================= the lead's case, end to end --

func test_a_used_knight_forced_through_autoprepare_is_refused_before_paying() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var knight := put_battlefield(0, "Knight of Valor")
	var plains: Array = []
	for i in 4: plains.append(put_battlefield(0, "Plains"))
	var ref = _referee()
	assert_eq(_ask(ref, [{"op": "autoprepare", "card": _h(knight), "kind": "ability", "targets": []}]), "",
		"the three in one: prepared, paid and activated")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	_lines.clear()
	assert_eq(_ask(ref, [{"op": "autoprepare", "card": _h(knight), "kind": "ability", "index": 0}]), "eof")
	var decisions := _of("decision")
	assert_eq(decisions[0].options.prepare.abilities, [], "the used ability is not offered")
	assert_false(bool(decisions[0].options.respond))
	var refused := _of("refused")
	assert_eq(refused.size(), 1)
	assert_true(String(refused[0].reason).contains("activate only once each turn"), refused[0].reason)
	assert_false(refused[0].has("floating"), "nothing floats")
	var untapped := plains.filter(func(land: CardInstance) -> bool: return not land.tapped)
	assert_eq(untapped.size(), 2, "the two Plains the first use left are still untapped")
	assert_eq(g.players[0].mana_pool.total(), 0)
