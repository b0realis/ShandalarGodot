extends GutTest
## THE SHOWCASE — what fills the big card, and the two gestures that fill
## it without playing anything. `docs/duel-todo.md` §2.14 and §2.15.
##
## `Duel.hlp`, topic **Showcase**: *"To the left of the Phase Bar, in the
## center, is a big card… Whenever the mouse cursor pauses long enough over
## a card in play, in a visible hand, or even in a graveyard, that card is
## displayed here. **Cards drawn into your hand are displayed when you draw
## them.**"* — the second sentence is the only time the original fills the
## Showcase unasked, and it is the 1997 answer to the question §2.14 asked
## of s30.
##
## `Duel.hlp`, topics **Hands** and **Territory**, both carry the same
## sentence for §2.15: *"You can also right-click and hold to bring a card
## in your hand to the front for as long as you hold the mouse button."*
## and **Territory** adds *"**Show full card** displays the card in the
## Showcase… You can also double-right-click to perform the same
## function."* — printed as an accelerator in the mini-menu itself,
## `@MENU_SMALLCARD` entry 2 (`Program/UIStrings.txt:937`): `Show full
## card\tR DblClk`.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _put(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	return inst


func _shown() -> String:
	return screen._card_preview._name_label.text


# ---------------------------------------------- §2.14 what fills it alone --

func test_a_drawn_card_lands_in_the_showcase() -> void:
	var g: MtgGame = screen.game
	# The card that will come off the top, named before it moves.
	var next: CardInstance = g.players[0].library[-1]
	g.draw_cards(0, 1)
	assert_eq(_shown(), next.data.card_name,
		"the card you drew is the card in the magnifier")
	assert_false(screen._card_preview._back.visible)


func test_the_opening_deal_leaves_the_showcase_face_down() -> void:
	# Seven cards cannot be shown one at a time, the opening window is over
	# them while they are dealt, and the owner's rule is that the slot
	# starts as a card back. turn_number is 0 until start_duel, which is
	# the gate.
	var fresh: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame
	assert_true(fresh._card_preview._back.visible,
		"dealt seven cards and still face down")


func test_a_hidden_hands_draw_is_not_shown_to_us() -> void:
	# The gate is `hidden_hands`, not "is it a human": at a HOTSEAT both
	# hands are open and each player should see their own draw, while in a
	# duel against the AI its seat is hidden and so is its card.
	var g: MtgGame = screen.game
	screen.hidden_hands = [1]
	g.draw_cards(0, 1)
	var mine := _shown()
	g.draw_cards(1, 1)
	assert_eq(_shown(), mine, "we do not get to read a hidden hand's draw")


func test_leaving_a_card_falls_back_to_the_top_of_the_chain() -> void:
	# s30's hover chain ends with the top stack item (duel.go:1930-1953),
	# so the card currently resolving is always the one in the magnifier.
	var g: MtgGame = screen.game
	var bear := _put(1, "Grizzly Bears")
	g.recalculate()
	screen._card_preview.show_card(bear)
	assert_eq(_shown(), "Grizzly Bears")
	# The seat with priority, not seat 0: the coin toss in `_new_game`
	# decides who opens, so assuming a seat makes the test flaky.
	var caster: int = g.priority_player
	var bolt := CardInstance.new(CardRegistry.get_card("Lightning Bolt"),
		g._next_instance_id, caster)
	g._next_instance_id += 1
	g._instances[bolt.id] = bolt
	bolt.zone = Mtg.Zone.HAND
	g.players[caster].hand.append(bolt)
	g.players[caster].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_eq(g.cast_spell(caster, bolt,
		[TargetRef.player(g.opponent_of(caster))]), "")
	screen._show_top_of_chain()
	assert_eq(_shown(), "Lightning Bolt", "the spell waiting to resolve")


func test_an_empty_chain_leaves_the_last_card_alone() -> void:
	# The docked Showcase's "last examined card persists" rule is the
	# owner's, and it still holds whenever nothing is waiting.
	var bear := _put(0, "Grizzly Bears")
	screen.game.recalculate()
	screen._card_preview.show_card(bear)
	screen._show_top_of_chain()
	assert_eq(_shown(), "Grizzly Bears")


# -------------------------------------------- §2.15 look without touching --

func _right(pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pressed
	return ev


func test_right_pressing_a_card_shows_it_and_never_plays_it() -> void:
	var g: MtgGame = screen.game
	var bear := _put(1, "Grizzly Bears")
	g.recalculate()
	var before := g.stack.size()
	var card := screen._make_card(bear)
	add_child_autofree(card)
	screen._on_card_look(_right(true), card, bear)
	assert_eq(_shown(), "Grizzly Bears", "it is in the Showcase")
	assert_eq(g.stack.size(), before, "and nothing was activated")


func test_a_right_held_card_lifts_clear_of_its_neighbours() -> void:
	# "…to bring a card in your hand to the front for as long as you hold
	# the mouse button." In a stacked hand the cards overlap to their name
	# bands, so "to the front" is literal.
	var bear := _put(0, "Grizzly Bears")
	screen.game.recalculate()
	var card := screen._make_card(bear)
	add_child_autofree(card)
	assert_eq(card.z_index, 0)
	screen._on_card_look(_right(true), card, bear)
	assert_eq(card.z_index, DuelScreen.LIFT_Z, "held to the front")
	screen._on_card_look(_right(false), card, bear)
	assert_eq(card.z_index, 0, "and dropped on release")


func test_a_board_rebuild_drops_a_held_card() -> void:
	# A rebuild frees every widget on the board; the release would arrive
	# at a dead object, so the lift is let go of there too.
	var bear := _put(0, "Grizzly Bears")
	screen.game.recalculate()
	var card := screen._make_card(bear)
	add_child_autofree(card)
	screen._on_card_look(_right(true), card, bear)
	assert_not_null(screen._lifted_card)
	screen._rebuild_field(0)
	assert_null(screen._lifted_card)
	assert_eq(card.z_index, 0)


func test_a_face_down_card_is_not_revealed_by_a_right_press() -> void:
	var g: MtgGame = screen.game
	var hidden := _put(1, "Grizzly Bears")
	g.recalculate()
	screen._card_preview.show_back()
	var card := screen._make_card(hidden)
	# face_down is a property of the WIDGET, not of the instance — it is
	# what the hand rebuild sets for a hidden hand.
	card.face_down = true
	add_child_autofree(card)
	screen._on_card_look(_right(true), card, hidden)
	assert_true(screen._card_preview._back.visible,
		"a face-down card stays face down")
