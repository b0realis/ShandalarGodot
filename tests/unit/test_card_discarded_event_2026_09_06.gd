extends GameTest
## CARD_DISCARDED — one event per card, after the card has moved, from
## every discard path the engine has: the cleanup discard (CR 514.1), an
## effect's chosen discard (Hymn to Tourach's random, Mind Twist's chosen),
## and a whole hand at once. The table's ear for `Discard.wav`
## (`functions.c:14861` plays it INSIDE the discard, once per card), which
## used to sound only for the human's own cleanup discard.


var heard: Array = []


func _listen() -> void:
	heard = []
	g.event_occurred.connect(func(ev: GameEvent) -> void:
		if ev.type == Mtg.EventType.CARD_DISCARDED:
			heard.append(ev.data))


func test_a_chosen_discard_by_an_effect_announces_each_card() -> void:
	var a := give_hand(0, "Grizzly Bears")
	var b := give_hand(0, "Forest")
	give_hand(0, "Plains")
	_listen()
	g.discard_cards(0, [a, b], true)
	assert_eq(heard.size(), 2, "one event per card")
	assert_eq(heard[0]["instance"], a)
	assert_eq(heard[1]["instance"], b)
	assert_eq(heard[0]["player"], 0)
	assert_true(heard[0]["by_effect"])
	assert_false(heard[0]["to_library"])
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "after the move, not before")
	assert_eq(g.players[0].hand.size(), 1)


func test_a_random_discard_announces_too() -> void:
	give_hand(1, "Grizzly Bears")
	give_hand(1, "Forest")
	give_hand(1, "Plains")
	_listen()
	g.discard_random(1, 2, true)
	assert_eq(heard.size(), 2)
	for data in heard:
		assert_eq(data["player"], 1)
		assert_eq((data["instance"] as CardInstance).zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].hand.size(), 1)


func test_the_whole_hand_announces_each_card() -> void:
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Forest")
	_listen()
	g.discard_hand(0)
	assert_eq(heard.size(), 2)
	assert_true(g.players[0].hand.is_empty())


func test_the_cleanup_discard_is_not_by_effect() -> void:
	g.players[0].max_hand_size = 1
	var a := give_hand(0, "Grizzly Bears")
	var b := give_hand(0, "Forest")
	_listen()
	g.awaiting_discard = true
	g.discard_count = 1
	g.active_player = 0
	assert_ok(g.discard_to_hand_size(0, [a]))
	assert_eq(heard.size(), 1, "the one card the phase asked for")
	assert_eq(heard[0]["instance"], a)
	assert_false(heard[0]["by_effect"], "CR 514.1: a turn-based action")
	assert_eq(b.zone, Mtg.Zone.HAND)


func test_no_card_no_event() -> void:
	_listen()
	g.discard_cards(0, [], true)
	g.discard_random(0, 3, true)
	g.discard_hand(0)
	assert_eq(heard.size(), 0, "an empty hand discards nothing")
