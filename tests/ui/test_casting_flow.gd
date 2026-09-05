extends GutTest
## THE 1997 CASTING FLOW — click the spell, THEN draw the mana; or
## double-click and let the game draw it for you.
##
## The owner's playtest, 2026-09-03, two defects with one answer:
##  4. *"If you click on a spell you should be able to tap lands also
##     AFTER, to cast it — not just before, to the mana pool where a spell
##     picks mana up."*
##  5. *"If you double-click a spell with a yellow name that can be cast,
##     suitable lands should auto-tap and the card is cast quickly."*
##
## Both are 1997's own behaviour, from the shipped help file.
## `Duel.hlp`, topic **Spells**: *"Any card you can cast is highlighted.
## Click on it to cast it. You're prompted to provide mana to pay the
## casting cost. At this point, you can draw from your mana pool, directly
## from land, or from any other source you have. Any X cost is defined by
## the amount of mana you tap now. Alternatively, you can DOUBLE-CLICK on a
## card in your hand to AUTO-CAST it. The casting cost is taken from your
## available mana sources automatically. If there is an X in the cost, all
## of your available mana is funneled into the spell."*
##
## Before the fix the first click was answered with *"not enough mana for
## Grizzly Bears ({1}{G})"* and the whole cast was thrown away — the mana
## had to be floated BEFORE the spell was picked, which is the order the
## owner is complaining about.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


## A clean main phase for seat 0: one spell in hand, [param lands] Forests
## on the table, nothing floating.
func _stage(card_name := "Grizzly Bears", lands := 2) -> CardInstance:
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g.players[0].hand.clear()
	g.players[0].mana_pool.clear()
	g.players[0].battlefield.clear()
	screen.mode = DuelScreen.Mode.NORMAL
	var inst := CardInstance.new(CardRegistry.get_card(card_name), 93001, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	for i in lands:
		var forest := CardInstance.new(CardRegistry.get_card("Forest"),
			93010 + i, 0)
		g._instances[forest.id] = forest
		g._put_on_battlefield(forest, 0)
	screen._refresh()
	return inst


# =============================================== 4: tap AFTER the click --

func test_clicking_a_spell_holds_it_open_for_its_mana() -> void:
	var bears := _stage()
	screen._on_card_clicked(bears)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING,
		"the cast is in progress, not refused")
	assert_eq(screen._pending_card, bears)
	assert_eq(screen._prompt_label.text, "Tap Grizzly Bears",
		"@PROMPT_GRABMANA entry 1, verbatim (UIStrings.txt:1090)")


func test_tapping_lands_afterwards_casts_the_spell() -> void:
	var g: MtgGame = screen.game
	var bears := _stage()
	screen._on_card_clicked(bears)
	for land in g.players[0].battlefield.duplicate():
		screen._on_card_clicked(land)
	assert_eq(g.stack.size(), 1, "the spell went on the chain")
	assert_eq(g.stack[0].card, bears)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "and the screen let go")
	assert_eq(screen._pending_card, null)


func test_the_sources_light_up_while_the_cast_waits() -> void:
	var g: MtgGame = screen.game
	var bears := _stage()
	screen._on_card_clicked(bears)
	for land in g.players[0].battlefield:
		assert_eq(screen._highlight_for(land), MiniCard.Highlight.OPTIONAL,
			"an untapped source is where the mana is coming from")


func test_done_cannot_pass_priority_out_from_under_a_waiting_cast() -> void:
	var g: MtgGame = screen.game
	var bears := _stage()
	screen._on_card_clicked(bears)
	assert_false(screen._done_applies(), "Done has nothing to do here")
	assert_true(screen._can_cancel(), "...but Cancel does")
	screen._on_done()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "still waiting")
	assert_eq(g.priority_player, 0, "and priority never moved")


func test_cancel_drops_the_waiting_cast_and_leaves_the_mana() -> void:
	var g: MtgGame = screen.game
	var bears := _stage()
	screen._on_card_clicked(bears)
	screen._on_card_clicked(g.players[0].battlefield[0])   # one Forest
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "one short")
	screen._on_cancel()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_eq(screen._pending_card, null)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 1,
		"the mana already drawn stays in the pool (CR 500.4 empties it)")
	assert_eq(g.stack.size(), 0)


func test_a_real_refusal_is_still_a_refusal() -> void:
	# Only "not enough mana" holds the cast open. A spell cast at the
	# wrong time is refused exactly as it always was.
	var g: MtgGame = screen.game
	var bears := _stage()
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	screen._on_card_clicked(bears)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "the cast was dropped")
	assert_eq(screen._pending_card, null)
	assert_string_contains(screen._prompt_label.text, "main phase")


func test_a_spell_already_paid_for_needs_no_paying_step() -> void:
	# Floating the mana first still works — this adds a door, it does not
	# close one.
	var g: MtgGame = screen.game
	var bears := _stage()
	for land in g.players[0].battlefield.duplicate():
		screen._on_card_clicked(land)
	screen._on_card_clicked(bears)
	assert_eq(g.stack.size(), 1)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


# ================================================ 5: the auto-cast --

func test_the_yellow_name_means_the_lands_you_could_tap() -> void:
	# `Duel.hlp`, topic Hands: "you must have enough mana available …
	# a card in your hand is useable, and therefore will be highlighted as
	# such." Before the fix the hint priced against the FLOATING pool
	# only, so a castable spell over two untapped Forests read white.
	var bears := _stage()
	assert_eq(screen._highlight_for(bears), MiniCard.Highlight.OPTIONAL,
		"two untapped Forests are {1}{G}")
	assert_eq(MiniCard.Highlight.CASTABLE, MiniCard.Highlight.OPTIONAL,
		"...and CASTABLE is what turns the name yellow (card_pile.gd)")


func test_a_spell_out_of_reach_is_not_yellow() -> void:
	var bears := _stage("Grizzly Bears", 1)
	assert_eq(screen._highlight_for(bears), MiniCard.Highlight.NONE)


func test_double_click_auto_taps_and_casts() -> void:
	var g: MtgGame = screen.game
	var bears := _stage()
	screen._on_card_clicked(bears)     # the first click of the pair
	screen._auto_cast(bears)           # the second
	assert_eq(g.stack.size(), 1, "on the chain, in one gesture")
	var tapped := 0
	for land in g.players[0].battlefield:
		if land.tapped:
			tapped += 1
	assert_eq(tapped, 2, "the suitable lands tapped themselves")


func test_the_auto_cast_leaves_locked_lands_alone() -> void:
	# `@MENU_SMALLCARD` entry 4 / `Duel.hlp`, topic Territory: "Don't Auto
	# Tap marks a land to be ignored — not tapped for mana — when you
	# auto-cast any spell or effect."
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", 3)
	var locked: CardInstance = g.players[0].battlefield[0]
	screen._no_auto_tap[locked.id] = true
	screen._on_card_clicked(bears)
	screen._auto_cast(bears)
	assert_eq(g.stack.size(), 1, "the other two paid for it")
	assert_false(locked.tapped, "the locked land was not touched")


func test_a_locked_land_can_still_be_tapped_by_hand() -> void:
	# "The only way to tap a locked land is manually, by clicking on it."
	var g: MtgGame = screen.game
	var bears := _stage()
	var locked: CardInstance = g.players[0].battlefield[0]
	screen._no_auto_tap[locked.id] = true
	assert_false(g.could_afford(0, bears.data, screen._no_auto_tap),
		"the auto-tapper cannot reach {1}{G} any more")
	screen._on_card_clicked(bears)
	for land in g.players[0].battlefield.duplicate():
		screen._on_card_clicked(land)
	assert_eq(g.stack.size(), 1, "clicking it by hand still works")


func test_the_auto_cast_funnels_everything_into_an_x_spell() -> void:
	# "If you double-click to auto-cast an X spell, ALL of the mana you
	# have available in your pool and from land sources will be put into
	# that spell."
	if CardRegistry.get_card("Fireball") == null:
		pass_test("Fireball not in the pool")
		return
	var g: MtgGame = screen.game
	var fireball := _stage("Fireball", 0)
	for i in 4:
		var mountain := CardInstance.new(CardRegistry.get_card("Mountain"),
			93100 + i, 0)
		g._instances[mountain.id] = mountain
		g._put_on_battlefield(mountain, 0)
	screen._refresh()
	screen._on_card_clicked(fireball)      # opens the X question
	screen._auto_cast(fireball)            # ...which the gesture answers
	assert_eq(screen._pending_x, 3,
		"four Mountains: one buys the {R}, three go into X")
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING,
		"the mana is the only thing the gesture takes over — "
		+ "'if the spell is a targeted one, you need to choose a target'")


func test_double_clicking_a_land_is_the_same_as_clicking_it() -> void:
	# "If you have a land in your hand, click on it to put it into play.
	# You can also double-click, but the effect is the same."
	var g: MtgGame = screen.game
	_stage()
	var forest := CardInstance.new(CardRegistry.get_card("Forest"), 93200, 0)
	forest.zone = Mtg.Zone.HAND
	g._instances[forest.id] = forest
	g.players[0].hand.append(forest)
	screen._on_card_clicked(forest)
	var before: int = g.players[0].battlefield.size()
	screen._auto_cast(forest)
	assert_eq(g.players[0].battlefield.size(), before,
		"the second click plays no second land")


func test_the_auto_cast_ignores_a_card_that_is_not_yours() -> void:
	var g: MtgGame = screen.game
	_stage()
	var theirs := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
		93300, 1)
	theirs.zone = Mtg.Zone.HAND
	g._instances[theirs.id] = theirs
	g.players[1].hand.append(theirs)
	screen._auto_cast(theirs)
	assert_eq(screen._pending_card, null)
	assert_eq(g.stack.size(), 0)


# ============ 5b: AND THE GESTURE HAS TO REACH THE CARD (2026-09-04) --
#
# The owner, on the build that already contained all of the above:
# *"I cannot double-click a castable card and lands do not automatically
# auto-tap."*
#
# `test_double_click_auto_taps_and_casts` above calls `_on_card_clicked`
# and then `_auto_cast` by hand, so it passed the whole time the gesture
# was unreachable. [method DuelScreen._auto_cast] had exactly one caller,
# `_on_card_look`, which is connected to a [MiniCard]'s own `gui_input` by
# `_make_card` — that is the battlefield and the FAN hand. The default
# hand is the original's STACK window, and a [StackHand] is a [CardPile]
# whose rows are holder `Button`s carrying `pressed` and nothing else, so
# no node between the pointer and the card ever looked at `double_click`.
#
# Measured under Xvfb with real press/release/press/release on the row
# (a throwaway probe, deleted). Before: the row's `pressed` fired twice,
# `_pending_card` was the spell and `mode` was PAYING, with `tapped=0` and
# `stack=0`. After: `tapped=2`, `stack=1`, `mode` back to NORMAL.
#
# What a headless suite CAN pin is the wiring, which is the part that was
# missing, plus the gesture driven through the row widget the player
# actually presses rather than through the screen's internals.


## The player's hand window, or null when this build wears the fan.
func _hand_window() -> StackHand:
	var hand: Control = screen._hand_rows[1]
	return hand as StackHand


## The hand window's row for [param inst] — the holder `Button`, the only
## node in a pile that takes the mouse.
func _hand_row(inst: CardInstance) -> Button:
	var window := _hand_window()
	if window == null:
		return null
	for pile in window.get_children():
		if not (pile is CardPile):
			continue
		for holder in (pile as CardPile).get_children():
			if not (holder is Button):
				continue
			for face in holder.get_children():
				if face is MiniCard and (face as MiniCard).instance == inst:
					return holder
	return null


func _press(double: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = double
	return ev


func test_every_row_of_the_hand_window_carries_the_double_click() -> void:
	# THE DEFECT, pinned as an invariant: a hand row with no `gui_input`
	# connection is a card that cannot be auto-cast, whatever `_auto_cast`
	# itself does.
	var bears := _stage()
	var window := _hand_window()
	if window == null:
		pass_test("this build wears the fan hand, whose cards are "
			+ "MiniCards and already carry _on_card_look")
		return
	var row := _hand_row(bears)
	assert_not_null(row, "the window draws a row per card in hand")
	assert_gt(row.gui_input.get_connections().size(), 0,
		"and that row listens for the second press")
	assert_gt(row.pressed.get_connections().size(), 0,
		"while the single click it always had is untouched")


func test_the_arming_survives_a_rebuild_and_a_collapse() -> void:
	# The first click REBUILDS the board, which frees the very row the
	# second click is about to land on — and `StackHand.toggle_collapsed`
	# re-populates without going through `_rebuild_hand` at all. Both are
	# why the arming hangs on the pile's `child_entered_tree`.
	var bears := _stage()
	var window := _hand_window()
	if window == null:
		pass_test("fan hand")
		return
	screen._refresh()
	assert_gt(_hand_row(bears).gui_input.get_connections().size(), 0,
		"still armed after a rebuild")
	window.toggle_collapsed()
	window.toggle_collapsed()
	assert_gt(_hand_row(bears).gui_input.get_connections().size(), 0,
		"and after the window folded and unfolded itself")


func test_a_double_click_ON_THE_ROW_auto_taps_and_casts() -> void:
	# The gesture as the player makes it: press, release (the row's own
	# `pressed`, which begins the cast), then the second press carrying
	# Godot's `double_click`.
	var g: MtgGame = screen.game
	var bears := _stage()
	if _hand_window() == null:
		pass_test("fan hand")
		return
	var row := _hand_row(bears)
	row.gui_input.emit(_press(false))
	assert_null(screen._pending_card,
		"a bare press starts nothing — the row's `pressed` does that")
	row.pressed.emit()                      # the release
	assert_eq(screen._pending_card, bears, "the first click began the cast")
	assert_eq(screen.mode, DuelScreen.Mode.PAYING,
		"...and it is waiting for mana, which is where the owner was stuck")
	# The rebuild freed that row; the second press lands on its successor.
	_hand_row(bears).gui_input.emit(_press(true))
	assert_eq(g.stack.size(), 1, "the spell went on the chain")
	var tapped := 0
	for land in g.players[0].battlefield:
		if land.tapped:
			tapped += 1
	assert_eq(tapped, 2, "and the suitable lands tapped themselves")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "the cast is over")


func test_the_first_press_of_the_pair_is_left_alone() -> void:
	# A press without `double_click` must fall straight through to the
	# row's own `pressed`, or there would be no first click for a double
	# click to be the second half of.
	var bears := _stage()
	if _hand_window() == null:
		pass_test("fan hand")
		return
	screen._on_hand_card_input(_press(false), bears)
	assert_null(screen._pending_card, "nothing was cast")
	assert_eq(screen.game.stack.size(), 0)


func test_the_double_click_is_the_LEFT_button_only() -> void:
	# The right button on a card is *look*, never *act* (§2.15).
	var bears := _stage()
	var ev := _press(true)
	ev.button_index = MOUSE_BUTTON_RIGHT
	screen._on_hand_card_input(ev, bears)
	assert_eq(screen.game.stack.size(), 0, "a right double-click casts nothing")
