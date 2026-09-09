extends GutTest
## THE POINTS ALREADY PLACED — `MiniCard.pending_damage` and
## `DuelScreen._pending_damage_for`, 2026-09-08 [QoL]. The owner's note:
## *"during combat and I have to distribute combat damage amongst
## creatures I cannot see which point went where? This should be somewhat
## shown on minicards."* The 1997 game showed nothing but its `%d points
## left` counter; the screen now writes each blocker's running share on
## its own small card, in the damage marker's place, and takes it off
## again the moment the division submits. The prompt's own count (§1.4,
## `@PROMPT_RESOLVECOMBAT`) is pinned in `test_duel_prompts.gd`.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _make(pid: int, card_name: String, zone: int) -> CardInstance:
	var game: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, game._next_instance_id, pid)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.HAND:
			game.players[pid].hand.append(inst)
		Mtg.Zone.BATTLEFIELD:
			game._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	return inst


## A 3/3 blocked by two 2/2s — the same table `test_duel_prompts.gd`
## divides, so the two files agree on what the player is looking at.
func _gang_block() -> Array:
	var game: MtgGame = screen.game
	var giant := _make(0, "Hill Giant", Mtg.Zone.BATTLEFIELD)
	var first := _make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var second := _make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	game.active_player = 0
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	assert_eq(game.declare_attackers(0, [giant.id]), "")
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS))
	game.awaiting_blockers = true
	assert_eq(game.declare_blockers(1,
		{first.id: giant.id, second.id: giant.id}), "")
	return [giant, first, second]


## Every small card the player can SEE drawing [param inst] — a blocker
## is drawn on the field row AND in the combat window while the window is
## up, and both must agree. (The window keeps its last cards, hidden,
## once combat is over; a card nobody sees is not the picture.)
func _cards_for(inst: CardInstance) -> Array[MiniCard]:
	var out: Array[MiniCard] = []
	var stack: Array = [screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MiniCard and (n as MiniCard).instance == inst \
				and not n.is_queued_for_deletion() and n.is_visible_in_tree():
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _pending(inst: CardInstance) -> int:
	var cards := _cards_for(inst)
	assert_gt(cards.size(), 0, "%s is drawn somewhere" % inst.data.card_name)
	var value := -1
	for card in cards:
		if value == -1:
			value = card.pending_damage
		assert_eq(card.pending_damage, value,
			"every widget of %s shows the same share" % inst.data.card_name)
	return value


func test_each_point_shows_on_the_blocker_it_went_to_and_clears_on_submit() -> void:
	var game: MtgGame = screen.game
	var cast := _gang_block()
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_DAMAGE))
	assert_true(game.awaiting_damage_assignment, "the engine stopped")
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.DAMAGE)
	assert_eq(_pending(cast[1]), 0, "nothing placed yet")
	assert_eq(_pending(cast[2]), 0)
	# One click, one point — on the card it went to and nowhere else.
	screen._on_card_clicked(cast[1])
	assert_eq(_pending(cast[1]), 1, "the first blocker shows its point")
	assert_eq(_pending(cast[2]), 0, "the second shows none")
	assert_string_contains(screen._prompt_label.text, "2 points left")
	screen._on_card_clicked(cast[1])
	assert_eq(_pending(cast[1]), 2, "...and its second")
	assert_eq(_pending(cast[2]), 0)
	# The widget: a number in the marker's place, in the pending colour,
	# not the salmon of marked damage.
	var card := _cards_for(cast[1])[0]
	assert_true(card._pending_count.visible)
	assert_eq(card._pending_count.text, "2")
	assert_eq(card._pending_count.get_theme_color("font_color"), MiniCard.PENDING_COLOR)
	assert_false(card._damage_count.visible, "no REAL damage is marked yet")
	# The last point spends itself, the division submits, and the marks go
	# with it — what is on the cards now is the damage itself.
	screen._on_card_clicked(cast[2])
	assert_false(game.awaiting_damage_assignment)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_eq(cast[1].zone, Mtg.Zone.GRAVEYARD, "the first blocker took lethal")
	assert_eq(_pending(cast[2]), 0, "nothing pending after the submit")
	assert_eq(cast[2].damage, 1, "the second's point is real damage now")
	for w in _cards_for(cast[2]):
		assert_false(w._pending_count.visible)
		assert_eq(w._damage_count.text, "1", "...marked the ordinary way")


func test_a_widget_shows_pending_beside_real_damage_without_overprinting() -> void:
	var game: MtgGame = screen.game
	var bears := _make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var card := MiniCard.new(bears, game)
	add_child_autofree(card)
	card.pending_damage = 1
	assert_true(card._pending_count.visible)
	var unwounded_top := card._pending_count.offset_top
	assert_eq(unwounded_top, card._damage_count.offset_top,
		"unwounded: the pending number stands in the marker's own place")
	bears.damage = 1
	card.refresh()
	assert_true(card._damage_count.visible, "now wounded for real")
	assert_true(card._pending_count.visible, "...and still pending one more")
	assert_lt(card._pending_count.offset_top, card._damage_count.offset_top,
		"wounded: the pending number moves up a row, off the real one")
	card.pending_damage = 0
	assert_false(card._pending_count.visible, "zero draws nothing")
	assert_false(card._pending_icon.visible)


func test_a_card_outside_any_division_carries_nothing() -> void:
	var bears := _make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	screen._refresh()
	assert_eq(_pending(bears), 0)
	assert_eq(screen._pending_damage_for(bears.id), 0)
	assert_eq(screen._pending_damage_for(-1), 0, "an unknown id is zero, not an error")
