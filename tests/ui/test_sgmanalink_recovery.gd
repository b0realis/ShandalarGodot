extends GameTest
## Actual lobby/socket recovery around rules questions, searches and combat.

var server: SgLocalServer
var lobby: SgLobby
var a: SgLocalClient
var b: SgLocalClient
var referee: SgPracticeMatch
var ui: SgDuelView

func before_each() -> void:
	super.before_each()
	server = SgLocalServer.new()
	add_child_autofree(server)
	assert_eq(server.start_local(0), OK)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	lobby = SgLobby.new()
	viewport.add_child(lobby)
	a = lobby.client
	b = SgLocalClient.new()
	add_child_autofree(b)

func after_each() -> void:
	a.forget()
	b.forget()
	server.stop()

func _until(predicate: Callable) -> bool:
	for i in 400:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "Recovery exceeded its frame budget")
	return false

func _command(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action))
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame

func _connect() -> void:
	assert_eq(a.connect_local(server.port, server.access_code), OK)
	assert_eq(b.connect_local(server.port, server.access_code), OK)
	await _until(func() -> bool: return a.online and b.online)
	await _command(a, {"op": "host", "name": "Recovery", "decks": "own", "deck": {}})
	await _command(b, {"op":"join", "room":a.state.room.id})

func _install() -> void:
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	server._rooms[a.state.room.id].match = referee
	server._rooms[a.state.room.id].revision += 1
	ui = SgDuelView.new()
	ui.stops.from_masks(PackedInt32Array([255,255,255,255]))
	lobby.add_child(ui)
	lobby._duel = ui
	ui.action_requested.connect(lobby._send)
	server._publish()
	await _until(func() -> bool: return ui._built)

## A MANA QUESTION THE AUTO-PAYMENT HAS TO WAIT FOR: Grizzly Bears paid
## from a Green Mana Battery with one charge counter, whose tap asks how
## many counters to spend. (Until 2026-11-11 this was a Fellwar Stone's
## colour; an unmarked Stone now makes the colour the plan priced.)
func _color_question() -> CardInstance:
	await _connect()
	advance_to_step(Mtg.Step.MAIN1)
	var bears := give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	var battery := put_battlefield(0, "Green Mana Battery")
	battery.counters["charge"] = 1
	await _install()
	var card := ui.game.find_instance(ui.projection.local_id(referee._handle(0, bears)))
	ui._on_card_clicked(card)
	ui._auto_cast(card)
	await _until(func() -> bool: return g.awaiting_choice != null and not a.busy() and not ui.projection.locked)
	return bears

func test_color_question_lost_ack_reconnect_and_single_cast() -> void:
	var bears := await _color_question()
	var sent: Array = []
	var errors: Array = []
	ui.action_requested.connect(func(action: Dictionary) -> void: sent.append(action.op))
	a.refused.connect(func(reason: String) -> void: errors.append(reason))
	for i in 20: await get_tree().process_frame
	assert_eq(sent, [], "no submission loop while the question is open")
	a.set_process(false)
	ui._on_choice_option(0)   # spend no counter: the Forest and one {G}
	await _until(func() -> bool: return g.awaiting_choice == null)
	a._socket.close(-1)
	a.set_process(true)
	a.reconnect()
	await _until(func() -> bool: return a.online and not a.busy() and g.stack.size() == 1)
	for i in 12: await get_tree().process_frame
	assert_eq(g.stack[0].card, bears)
	assert_eq(sent.count("submit"), 1)
	assert_eq(errors, [])
	var count := ui.game.log_lines.size()
	a.reconnect()
	await _until(func() -> bool: return a.online and not a.busy())
	for i in 12: await get_tree().process_frame
	assert_eq(ui.game.log_lines.size(), count, "reconnect does not duplicate journal entries")

func test_cancel_mana_question_abandons_payment_and_draft() -> void:
	var bears := await _color_question()
	ui._on_cancel()
	await _until(func() -> bool: return not a.busy() and g.awaiting_choice == null)
	for i in 12: await get_tree().process_frame
	assert_true(referee.actions.draft.is_empty())
	assert_true(referee.actions._auto_payment.is_empty())
	assert_true(g.stack.is_empty())
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_null(ui._pending_card)


func _rejoin_question() -> void:
	var question: Dictionary = a.state.room.game.choice.duplicate(true)
	var guest := a.guest
	a.reconnect()
	await _until(func() -> bool: return a.online and not a.busy())
	assert_eq(a.guest, guest)
	assert_eq(int(a.state.room.revision), int(server._rooms[a.state.room.id].revision), "input waits for the resumed snapshot")
	assert_eq(a.state.room.game.choice, question, "pending question survives reconnection")
	assert_true(b.state.room.game.choice.is_empty(), "only the choosing seat receives the options")


func _lose_ack(client: SgLocalClient, action: Dictionary, applied: Callable) -> void:
	var errors: Array = []
	client.refused.connect(func(reason: String) -> void: errors.append(reason))
	client.set_process(false)
	assert_true(client.command(action))
	await _until(applied)
	assert_true(client.busy(), "the applied command has not been acknowledged locally")
	client._socket.close(-1)
	client.set_process(true)
	client.reconnect()
	await _until(func() -> bool: return client.online and not client.busy())
	for i in 8: await get_tree().process_frame
	assert_eq(errors, [], "same command is acknowledged after reconnect, not applied again")


func _pass_until_question() -> void:
	for i in 12:
		if g.awaiting_choice != null: break
		await _command(a if g.priority_player == 0 else b, {"op":"pass"})
	assert_not_null(g.awaiting_choice)


func test_private_search_reconnect_and_lost_answer_ack() -> void:
	await _connect()
	advance_to_step(Mtg.Step.MAIN1)
	var hidden := give_hand(0, "Black Lotus")
	g.put_from_hand_on_top_of_library(hidden)
	var tutor := give_hand(0, "Demonic Tutor")
	add_mana(0, Mtg.ManaColor.B, 2)
	await _install()
	await _command(a, {"op":"play", "card":referee._handle(0, tutor)})
	await _pass_until_question()
	await _rejoin_question()
	assert_false(SgProtocol.encode(b.state).contains("Black Lotus"))
	var index: int = a.state.room.game.choice.options.find("Black Lotus")
	assert_gte(index, 0)
	await _lose_ack(a, {"op":"choice", "picks":[index]}, func() -> bool: return g.awaiting_choice == null)
	assert_eq(hidden.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), 1, "the search resolves once")
	assert_false(SgProtocol.encode(b.state).contains("Black Lotus"), "the found card remains private")


func test_triggered_payment_reconnect_and_lost_answer_ack() -> void:
	await _connect()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Soul Net")
	var land := put_battlefield(0, "Plains")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.destroy(bears, false)
	await _install()
	await _pass_until_question()
	await _rejoin_question()
	assert_string_contains(a.state.room.game.choice.prompt, "Soul Net")
	await _lose_ack(a, {"op":"choice", "picks":[0]}, func() -> bool: return g.awaiting_choice == null)
	assert_eq(g.players[0].life, 21, "trigger payment and life gain happen once")
	assert_true(land.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_divided_combat_damage_survives_reconnect_and_lost_ack() -> void:
	await _connect()
	g.rules.free_damage_assignment = true
	# Pin human decision makers before entering damage, not afterwards in _install.
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	var wurm := put_battlefield(0, "Craw Wurm")
	var first := put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	for i in 8:
		if g.awaiting_blockers: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.declare_blockers(1, {first.id:wurm.id, second.id:wurm.id}))
	for i in 8:
		if g.awaiting_damage_assignment: break
		assert_ok(g.pass_priority(g.priority_player))
	await _install()
	await _until(func() -> bool: return a.state.room.game.mode == "damage")
	var request: Dictionary = a.state.room.game.damage_request.duplicate(true)
	a.reconnect()
	await _until(func() -> bool: return a.online and not a.busy())
	assert_eq(int(a.state.room.revision), int(server._rooms[a.state.room.id].revision), "damage input must use the resumed revision")
	assert_eq(a.state.room.game.damage_request, request)
	assert_true(b.state.room.game.damage_request.is_empty())
	await _lose_ack(a, {"op":"damage", "points":[[referee._handle(0, first), 3],
		[referee._handle(0, second), 3]]}, func() -> bool: return not g.awaiting_damage_assignment)
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 20)

func test_large_combat_crosses_socket_and_accepts_blocks() -> void:
	await _connect()
	var attackers: Array = []
	for i in 24: attackers.append(put_battlefield(0, "Grizzly Bears").id)
	for i in 24: put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attackers))
	await _install()
	await _until(func() -> bool: return not b.state.room.game.is_empty())
	assert_true(b.online)
	assert_true(SgViewProtocol.game(b.state.room.game))
	assert_eq(b.state.room.game.presentation.blockable.size(), 24)
	# Advance the combat priority windows to the actual blocker declaration.
	for i in 8:
		if b.state.room.game.mode == "block": break
		var actor := int(a.state.room.game.actor)
		await _command(a if actor == 0 else b, {"op":"pass"})
	assert_eq(b.state.room.game.mode, "block")
	var pairs: Array = []
	for row in b.state.room.game.presentation.blockable: pairs.append([row[0], row[1][0]])
	await _command(b, {"op":"block", "pairs":pairs})
	assert_eq(g.combat.blocks.size(), 24)
	assert_true(a.online and b.online)


func test_refused_multitarget_payment_refreshes_the_cached_draft() -> void:
	await _connect()
	advance_to_step(Mtg.Step.MAIN1)
	var fireball := give_hand(0, "Fireball")
	add_mana(0, Mtg.ManaColor.R, 3)
	await _install()
	var room: Dictionary = server._rooms[a.state.room.id]
	var sid: int = room.seats[0]
	assert_ok(server._command(sid, {"op":"prepare", "kind":"spell", "index":0,
		"mode":0, "x":2, "card":referee._handle(0, fireball)}, room.revision))
	var before: Dictionary = server._state(sid).room.game
	assert_true(before.presentation.draft.reachable, "one-target X=2 needs only three mana")
	var offered: Array = before.announcement.slots[0].targets
	assert_eq(offered.size(), 2, "both players are legal targets")
	var revision: int = room.revision
	assert_refused(server._command(sid, {"op":"submit", "targets":[[offered[0].id, 1],
		[offered[1].id, 1]]}, revision), "not enough mana")
	assert_eq(referee.actions.draft.count, 2)
	assert_gt(int(room.revision), revision, "the private draft changed despite the refusal")
	assert_false(server._state(sid).room.game.presentation.draft.reachable,
		"cached reachability must include the fourth mana for the extra target")
	assert_true(server._state(int(room.seats[1])).room.game.announcement.is_empty())
