extends GutTest
## Campaign 2026-11-26 (bugs3 #1, the deck builder's half): the adventure's
## builder asks its opener before it leaves with a deck slot on show —
## [member AdventureBuilder.can_leave] — so an empty slot is not written
## back as the deck in use without a word.

var builder: AdventureBuilder
var player: AdventurePlayer
var asked: Array = []
var closed := 0
var quit := 0


func before_each() -> void:
	CardRegistry.ensure_loaded()
	asked.clear()
	closed = 0
	quit = 0
	player = AdventurePlayer.new()
	player.gold = 100
	player.difficulty = 1
	for card_name in ["Grizzly Bears", "Grizzly Bears", "Giant Growth", "Forest", "Forest", "Llanowar Elves"]:
		player.cards.append({"card": card_name, "decks": [0]})
	builder = AdventureBuilder.new()
	builder.player = player
	add_child_autofree(builder)
	builder.closed.connect(func() -> void: closed += 1)
	builder.exit_requested.connect(func() -> void: quit += 1)
	await get_tree().process_frame


func _judge(slot: int) -> String:
	asked.append(slot)
	var model := builder.slot_model(slot)
	return "" if model != null and model.total() > 0 else "Deck %d is empty." % (slot + 1)


func _labels(node: Node) -> String:
	var out := ""
	if node is Label:
		out += String((node as Label).text) + "\n"
	for child in node.get_children():
		out += _labels(child)
	return out


func test_without_a_judge_the_builder_leaves_as_before() -> void:
	builder._switch_slot(1)
	builder._exit()
	assert_eq(closed, 1)
	assert_eq(player.current_deck, 1)


func test_a_refusal_is_shown_and_the_builder_stays() -> void:
	builder.can_leave = _judge
	builder._switch_slot(1)
	builder._exit()
	assert_eq(asked, [1], "asked about the slot on show")
	assert_eq(closed, 0, "the builder stays")
	assert_eq(player.current_deck, 0, "nothing written back")
	assert_eq(builder.open_dialogs().size(), 1)
	assert_string_contains(_labels(builder.open_dialogs()[0]), "Deck 2 is empty.")
	# With that window up, Exit game and the window's close say it on the status line.
	builder._quit_game()
	builder._on_window_close_request()
	assert_eq(quit, 0)
	assert_eq(builder.open_dialogs().size(), 1, "one window at a time")
	assert_eq(asked, [1, 1, 1])
	builder.open_dialogs()[0].dismiss()
	await get_tree().process_frame
	# Back on the deck that holds cards, every way out is open.
	builder._switch_slot(0)
	builder._exit()
	assert_eq(closed, 1)
	assert_eq(player.current_deck, 0)
	builder._quit_game()
	assert_eq(quit, 1)


func test_a_builder_that_only_looks_is_never_asked() -> void:
	builder.queue_free()
	builder = AdventureBuilder.new()
	builder.player = player
	builder.looking = true
	builder.can_leave = _judge
	add_child_autofree(builder)
	builder.closed.connect(func() -> void: closed += 1)
	await get_tree().process_frame
	builder._exit()
	assert_eq(asked, [])
	assert_eq(closed, 1)
