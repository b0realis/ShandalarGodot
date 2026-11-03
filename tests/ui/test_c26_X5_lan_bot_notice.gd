extends GameTest
## The 0.60.9 opponent-spell notice at a LAN table with a bot seat (0.60.13
## bug campaign, h4-1): the seat's view names the bot's new spell and its
## target and shows it in the docked Showcase, and the host holds the bot's
## next step for the same reading pause a local duel has.

class ScriptedBot extends AiPlayer:
	var acted := 0
	## The first act, when set (a cast); every later one passes.
	var opening := Callable()

	func _init(seat := 1) -> void:
		super(seat, AiProfile.wizard())

	func act(game: MtgGame) -> String:
		acted += 1
		if opening.is_valid():
			var first := opening
			opening = Callable()
			return first.call()
		return game.pass_priority(pid)


var referee: SgPracticeMatch
var revision := 1
var bots: Array = [{}, {}]


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	bots = [{}, {}]


# ------------------------------------------------------------ the seat's view

func _room(seat: int) -> Dictionary:
	var names := ["Wizard bot" if not bots[0].is_empty() else "Azure Fox",
		"Wizard bot" if not bots[1].is_empty() else "Amber Owl"]
	var room := {"id": "r1", "name": "Computer duel", "seat": seat,
		"names": names, "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}
	if bots != [{}, {}]:
		room.bots = bots.duplicate(true)
	return room


func _screen(seat: int) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	viewport.add_child(screen)
	screen.present(_room(seat), true, false)
	return screen


func _pump() -> void:
	for i in 8: await get_tree().process_frame


## The bot seat's main phase, its Swords to Plowshares ready for the
## human seat's Grizzly Bears.
func _swords_ready(bot: int) -> Array[CardInstance]:
	if bot == 1: advance_to_next_turn()
	else: advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1 - bot, "Grizzly Bears")
	var swords := give_hand(bot, "Swords to Plowshares")
	add_mana(bot, Mtg.ManaColor.W)
	return [bear, swords]


func test_the_bots_new_spell_and_target_are_named_on_the_seats_bar(seat = use_parameters([0, 1])) -> void:
	var bot: int = 1 - seat
	bots[bot] = SgBotPlayer.defaults()
	var cards := _swords_ready(bot)
	var screen := _screen(seat)
	await _pump()
	assert_ok(g.cast_spell(bot, cards[1], [TargetRef.card(cards[0])]))
	revision += 1
	screen.present(_room(seat), true, false)
	await _pump()
	assert_true(screen._computer_seat(1), "the room's bot seat is the view's opponent")
	assert_false(screen._computer_seat(0))
	var message := screen._phase_status_message()
	assert_string_contains(message, "Wizard bot casts Swords to Plowshares")
	assert_string_contains(message, "targeting Grizzly Bears")
	assert_false(message.contains("Spell"), "not the referee's row kind")
	assert_false(message.contains("\n"), "one line, the targets in brackets")


func test_the_docked_showcase_shows_the_bots_new_spell_once() -> void:
	bots[1] = SgBotPlayer.defaults()
	var cards := _swords_ready(1)
	var screen := _screen(0)
	await _pump()
	screen._card_preview.docked = true
	assert_ok(g.cast_spell(1, cards[1], [TargetRef.card(cards[0])]))
	revision += 1
	screen.present(_room(0), true, false)
	await _pump()
	assert_eq(screen._card_preview._name_label.text, "Swords to Plowshares")
	# A later table with the same spell still on the chain is no new action:
	# what the player hovers since stays.
	var bear: CardInstance = screen.game.players[0].battlefield[0]
	screen._card_preview.show_card(bear)
	revision += 1
	screen.present(_room(0), true, false)
	await _pump()
	assert_eq(screen._card_preview._name_label.text, "Grizzly Bears")


func test_a_remote_human_is_not_a_computer_seat() -> void:
	var cards := _swords_ready(1)
	var screen := _screen(0)
	await _pump()
	assert_ok(g.cast_spell(1, cards[1], [TargetRef.card(cards[0])]))
	revision += 1
	screen.present(_room(0), true, false)
	await _pump()
	assert_false(screen._computer_seat(1))
	assert_false(screen._phase_status_message().contains("casts"))
	assert_true(screen._pace_chain_ids.is_empty())


# ------------------------------------------------------------ the host

var server: SgLocalServer
var pilot: ScriptedBot


## A running table at a host: the human's session 1 in seat 0 (a live
## connection, no socket to write to), the bot's session 2 in seat 1.
func _host_table(second_bot := false) -> Dictionary:
	server = SgLocalServer.new()
	add_child_autofree(server)
	server.set_process(false)
	server._sessions[1] = {"peer": 7, "room": "r1", "seq": 0, "acks": {}, "nickname": "Fox",
		"disconnected_at": 0, "token_hash": ""}
	if second_bot:
		server._sessions[1].peer = 0
		server._sessions[1].bot = SgBotPlayer.defaults()
	server._sessions[2] = {"peer": 0, "room": "r1", "seq": 0, "acks": {}, "nickname": "Wizard bot",
		"disconnected_at": 0, "token_hash": "", "bot": SgBotPlayer.defaults()}
	pilot = ScriptedBot.new()
	referee.bots[1] = pilot
	referee.bot_options[1] = SgBotPlayer.defaults()
	if second_bot:
		referee.bots[0] = ScriptedBot.new(0)
		referee.bot_options[0] = SgBotPlayer.defaults()
	var room := {"id": "r1", "name": "Computer duel", "seats": [1, 2], "ready": [true, true],
		"revision": 1, "match": referee, "decks": [{}, {}], "fixed": {}, "rules": SgTableRules.normalize({})}
	if second_bot:
		room.t_pair = 0   # a tournament's table of two bots outlives its humans
	server._rooms["r1"] = room
	return room


func test_the_host_holds_the_bot_for_the_reading_pause_after_its_new_spell() -> void:
	assert_eq(SgLocalServer.BOT_READING_MS, int(DuelScreen.OPPONENT_ACTION_SECONDS * 1000.0),
		"the host's pause is the local screen's")
	var cards := _swords_ready(1)
	_host_table()
	pilot.opening = func() -> String: return g.cast_spell(1, cards[1], [TargetRef.card(cards[0])])
	server._poll_bots(10000)
	assert_eq(pilot.acted, 1)
	assert_eq(cards[1].zone, Mtg.Zone.STACK)
	# The bot's pace (350 ms) has passed; the spell has not stood 2 s yet.
	server._poll_bots(10400)
	server._poll_bots(11999)
	assert_eq(pilot.acted, 1, "the bot still holds its spell on the chain")
	assert_eq(g.priority_player, 1)
	assert_eq(cards[0].zone, Mtg.Zone.BATTLEFIELD, "its target is still there to see")
	server._poll_bots(12000)
	assert_eq(pilot.acted, 2, "then it passes, and the human seat answers")
	assert_eq(g.priority_player, 0)
	assert_eq(cards[1].zone, Mtg.Zone.STACK)
	await get_tree().process_frame   # the host's deferred publish
	server.stop()
	assert_true(server._bot_reading.is_empty())


func test_the_human_seats_own_spell_does_not_slow_the_bots_answer() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	_host_table()
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	server._poll_bots(10000)
	assert_eq(pilot.acted, 1, "an empty reading list adds no pause")
	await get_tree().process_frame


func test_a_table_of_two_bots_keeps_its_pace() -> void:
	var cards := _swords_ready(1)
	_host_table(true)
	pilot.opening = func() -> String: return g.cast_spell(1, cards[1], [TargetRef.card(cards[0])])
	server._poll_bots(10000)
	server._poll_bots(10400)
	assert_eq(pilot.acted, 2, "nobody at a table of two bots to read it")
	await get_tree().process_frame


func test_the_network_tests_zero_pace_keeps_its_speed() -> void:
	var cards := _swords_ready(1)
	_host_table()
	server.bot_pace_override = 0
	pilot.opening = func() -> String: return g.cast_spell(1, cards[1], [TargetRef.card(cards[0])])
	server._poll_bots(10000)
	server._poll_bots(10000)
	assert_eq(pilot.acted, 2)
	await get_tree().process_frame


func test_the_reading_list_goes_with_its_room() -> void:
	var cards := _swords_ready(1)
	var room := _host_table()
	pilot.opening = func() -> String: return g.cast_spell(1, cards[1], [TargetRef.card(cards[0])])
	server._poll_bots(10000)
	assert_eq(server._bot_reading.get("r1", {}).size(), 1)
	room.seats[0] = 0   # the human left: the bot-only room closes
	server._poll_bots(10100)
	assert_false(server._rooms.has("r1"))
	assert_false(server._bot_reading.has("r1"))
	await get_tree().process_frame
