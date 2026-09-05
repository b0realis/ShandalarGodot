class_name GameTest
extends GutTest
## Base class for all engine and card tests: a tiny DSL that lets a test
## read like a description of a game.
##
## Philosophy (inherited from mage-go's gametest package): a card test
## should state a SITUATION and an ASSERTION, not walk the engine's plumbing.
## The helpers here bend the rules only for SETUP (putting cards places,
## granting mana); every action under test goes through the same public
## MtgGame API the UI and AI will use, so tests prove the real path.
##
## Typical shape:
## [codeblock]
## func test_bolt_kills_bears() -> void:
##     var bear := put_battlefield(1, "Grizzly Bears")
##     var bolt := give_hand(0, "Lightning Bolt")
##     add_mana(0, Mtg.ManaColor.R)
##     assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
##     resolve_stack()
##     assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
## [/codeblock]

## The game under test. Recreated fresh for every test in before_each.
var g: MtgGame


func before_each() -> void:
	g = MtgGame.new()
	# Empty decks by default: tests place cards explicitly. 30 filler cards
	# per library prevent accidental draw-out losses during turn cycling.
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	g.start(0)   # no opening hands — tests hand out exactly what they need


# ------------------------------------------------------------ setup helpers --

## Put a fresh copy of [param card_name] directly onto [param pid]'s
## battlefield (setup shortcut — bypasses casting). Summoning sickness is
## cleared unless [param sick] is true, so it can act immediately.
func put_battlefield(pid: int, card_name: String, sick := false) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g._put_on_battlefield(inst, pid)
	# Sickness applies to EVERY permanent now (animated lands, CR 302.6) —
	# pass sick=true to keep it, e.g. for a just-played Mishra's Factory.
	inst.summoning_sick = sick
	return inst


## Put a SYNTHETIC permanent — one built from a [CardData] the test wrote
## rather than a card in the registry — onto [param pid]'s battlefield.
##
## For ENGINE tests that pin a mechanism rather than a card: a hook is
## easier to trust when the thing exercising it is three lines long and
## visible in the test file. Unlike [method MtgGame.create_token] the
## result is a real card, so it can be anted, bounced into a hand and
## raised from a graveyard like any other permanent.
func put_synthetic(pid: int, data: CardData) -> CardInstance:
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


## Put a fresh copy of [param card_name] into [param pid]'s hand.
func give_hand(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


## Add [param amount] mana of [param color] to [param pid]'s pool.
## NOTE: pools empty at step boundaries (CR 500.4) — add mana in the same
## step you spend it, exactly like a real game.
func add_mana(pid: int, color: int, amount := 1) -> void:
	g.players[pid].mana_pool.add(color, amount)


## Put a damage packet straight into the prevention window's queue
## (docs/duel-todo.md §6.8) without a source actually dealing it — SETUP
## ONLY, for tests about what the queue does rather than about how damage
## gets into it.
func plant_damage_packet(source: CardInstance, target: TargetRef,
		amount: int) -> DamagePacket:
	var packet := g._plan_damage(source, target, amount, false)
	g.damage_pending.append(packet)
	return packet


func _make_instance(pid: int, card_name: String) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "unknown card in test: %s" % card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	return inst


# ----------------------------------------------------------- action helpers --

## Assert an engine action succeeded (engine actions return "" on success,
## a refusal reason otherwise — this prints the reason on failure).
func assert_ok(result: String) -> void:
	assert_eq(result, "", "engine refused the action: '%s'" % result)


## Assert an engine action was refused (optionally matching the reason).
func assert_refused(result: String, reason_contains := "") -> void:
	assert_ne(result, "", "expected the engine to refuse, but it allowed the action")
	if reason_contains != "":
		assert_string_contains(result, reason_contains)


## Both players pass until the stack is empty (resolving everything).
func resolve_stack() -> void:
	var guard := 0
	while not g.stack.is_empty() and not g.game_over and guard < 100:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 100, "resolve_stack did not converge")


## Pass priority (declaring nothing in combat) until the game reaches
## [param step] of some later moment. Guards against infinite loops.
func advance_to_step(step: int) -> void:
	var guard := 0
	while g.current_step() != step and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "advance_to_step(%s) did not converge" % Mtg.step_name(step))


## Advance to the next turn's first main phase.
func advance_to_next_turn() -> void:
	var turn := g.turn_number
	var guard := 0
	while (g.turn_number == turn or g.current_step() != Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "advance_to_next_turn did not converge")


func _advance_once() -> void:
	if g.awaiting_attackers:
		assert_ok(g.declare_attackers(g.active_player, []))
	elif g.awaiting_blockers:
		assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
	else:
		assert_ok(g.pass_priority(g.priority_player))


## Run one full combat: [param attacker_ids] attack, [param block_map]
## blocks (blocker id -> attacker id), damage resolves, combat ends.
## Call with the game anywhere before/at declare-attackers of the active
## player's turn.
func run_combat(attacker_ids: Array, block_map: Dictionary = {}) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(g.active_player, attacker_ids))
	resolve_stack()   # attack triggers, if any
	if not attacker_ids.is_empty():
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(g.opponent_of(g.active_player), block_map))
		advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	advance_to_step(Mtg.Step.COMBAT_END)
