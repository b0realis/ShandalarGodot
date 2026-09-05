extends GutTest
## The duel's arrows — blockers in RED, spells/abilities in AMBER — ported
## from s30's drawArrowLine / drawBlockerArrows / drawStackArrows
## (s30/game/screens/duel/duel.go:3449-3554). These tests pin the port's
## two halves: the pure ARROW GEOMETRY (which needs no viewport) and the
## LINK BUILDING off live game state through the real duel screen.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


# ------------------------------------------------------- arrow geometry --

func test_the_head_is_two_strokes_back_from_the_destination() -> void:
	# s30 drawArrowLine: arrowLen 10, spread 0.5 — both barbs sit 10px back
	# along the shaft from the tip, half that far to either side.
	var barbs := TargetArrows.head_points(Vector2(100, 0), Vector2(100, 200))
	assert_eq(barbs.size(), 2, "an arrowhead is two strokes")
	# Shaft points straight down, so the barbs sit 10 above the tip and
	# 2.5 to each side (10 * 0.5 * 0.5 either way from the axis).
	assert_almost_eq(barbs[0].y, 190.0, 0.01, "barb rides back up the shaft")
	assert_almost_eq(barbs[1].y, 190.0, 0.01)
	assert_almost_eq(barbs[0].x + barbs[1].x, 200.0, 0.01,
		"the barbs straddle the shaft symmetrically")
	assert_almost_eq(absf(barbs[0].x - barbs[1].x),
		TargetArrows.HEAD_LENGTH * TargetArrows.HEAD_SPREAD * 2.0, 0.01,
		"each barb sits half a spread either side of the shaft")


func test_a_zero_length_arrow_has_no_head() -> void:
	# s30 returns early when length == 0 rather than dividing by it.
	assert_eq(TargetArrows.head_points(Vector2(5, 5), Vector2(5, 5)).size(), 0)


func test_the_head_sits_at_the_destination_end() -> void:
	# The head belongs to the TARGET, never the source: both barbs are
	# nearer `to` than `from`.
	var from := Vector2(0, 0)
	var to := Vector2(300, 120)
	for barb in TargetArrows.head_points(from, to):
		assert_lt(barb.distance_to(to), barb.distance_to(from),
			"the head marks what is being pointed at")


func test_the_two_arrow_colours_are_the_reference_colours() -> void:
	assert_eq(TargetArrows.BLOCK_COLOR, Color8(255, 0, 0), "s30: blockers red")
	assert_eq(TargetArrows.SPELL_COLOR, Color8(255, 200, 0), "s30: stack amber")


func test_edges_name_the_top_and_bottom_centres() -> void:
	# s30 anchors a blocker at its TOP-CENTRE and its attacker at the
	# attacker's BOTTOM-CENTRE, so the arrow spans the gap between rows.
	var rect := Rect2(10, 20, 100, 50)
	assert_eq(TargetArrows.edge_point(rect, TargetArrows.Edge.TOP), Vector2(60, 20))
	assert_eq(TargetArrows.edge_point(rect, TargetArrows.Edge.BOTTOM), Vector2(60, 70))
	assert_eq(TargetArrows.edge_point(rect, TargetArrows.Edge.CENTER), Vector2(60, 45))


# ---------------------------------------------------------- the wiring --

func test_the_duel_screen_carries_an_arrow_layer_over_the_board() -> void:
	assert_not_null(screen._arrows, "the duel screen builds the arrow layer")
	assert_eq(screen._arrows.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the overlay must not swallow clicks meant for cards")
	assert_eq(screen._arrows.board_root, screen)
	# s30's Draw() paints the arrows AFTER the board and BEFORE the hand
	# panel, so the layer must sit above the board node in sibling order.
	var board_index := -1
	for child in screen.get_children():
		if child is HBoxContainer and child.get_index() < screen._arrows.get_index():
			board_index = child.get_index()
	assert_gt(screen._arrows.get_index(), board_index,
		"arrows draw over the board")


func test_no_arrows_on_a_quiet_board() -> void:
	assert_eq(screen._arrows.link_count(), 0,
		"nothing is blocking and nothing is on the stack")


func test_a_pending_block_draws_a_red_arrow_to_its_attacker() -> void:
	var g: MtgGame = screen.game
	var attacker := _summon(g, "Savannah Lions", g.active_player)
	var blocker := _summon(g, "Savannah Lions", g.opponent_of(g.active_player))
	screen._block_map = {blocker.id: attacker.id}
	screen._refresh()
	var found := _find_link(blocker.id, attacker.id)
	assert_false(found.is_empty(), "the pending block has an arrow")
	assert_eq(found["color"], TargetArrows.BLOCK_COLOR)
	assert_eq(found["from_edge"], TargetArrows.Edge.TOP,
		"s30: from the blocker's top-centre")
	assert_eq(found["to_edge"], TargetArrows.Edge.BOTTOM,
		"s30: to the attacker's bottom-centre")


func test_declared_blocks_keep_their_arrows_through_the_damage_step() -> void:
	# s30 shows the AI's DECLARED blocks during declare-blockers and the
	# first-strike damage step, not just the player's pending picks.
	var g: MtgGame = screen.game
	var attacker := _summon(g, "Savannah Lions", g.active_player)
	var blocker := _summon(g, "Savannah Lions", g.opponent_of(g.active_player))
	g.combat.attackers[attacker.id] = true
	g.combat.blocks[blocker.id] = attacker.id
	for step in [Mtg.Step.DECLARE_BLOCKERS, Mtg.Step.COMBAT_DAMAGE]:
		screen._arrows.rebuild(_game_at_step(g, step), {}, null, [])
		assert_false(_find_link(blocker.id, attacker.id).is_empty(),
			"declared block shows during %s" % Mtg.step_name(step))


func test_a_spell_on_the_stack_points_amber_at_its_target() -> void:
	var g: MtgGame = screen.game
	var victim := _summon(g, "Savannah Lions", 1)
	var bolt := StackItem.new()
	bolt.kind = Mtg.StackKind.SPELL
	bolt.controller = 0
	bolt.card = victim              # any card: only the id lookup matters
	bolt.targets = [TargetRef.card(victim)]
	g.stack.append(bolt)
	screen._refresh()
	var amber := _links_of_color(TargetArrows.SPELL_COLOR)
	assert_gt(amber.size(), 0, "the stack item drew an arrow")
	assert_eq(amber[0]["to"], victim.id, "it points at the target")
	g.stack.clear()


func test_a_player_target_terminates_on_their_life_panel() -> void:
	# Players ARE legal targets (the original's wizard portraits), so an
	# arrow must be able to end on a life panel — s30's targetPosition.
	var g: MtgGame = screen.game
	var source := _summon(g, "Savannah Lions", 0)
	var bolt := StackItem.new()
	bolt.kind = Mtg.StackKind.SPELL
	bolt.controller = 0
	bolt.card = source
	bolt.targets = [TargetRef.player(1)]
	g.stack.append(bolt)
	screen._refresh()
	var amber := _links_of_color(TargetArrows.SPELL_COLOR)
	assert_gt(amber.size(), 0)
	assert_eq(amber[0]["to"], screen._life_buttons[1],
		"the arrow ends on the opponent's life panel")
	g.stack.clear()


func test_targets_picked_so_far_are_already_drawn() -> void:
	# Our extension of drawStackArrows: a spell still collecting targets
	# shows what it has caught, in the same amber, before it is submitted.
	var g: MtgGame = screen.game
	var victim := _summon(g, "Savannah Lions", 1)
	screen.mode = DuelScreen.Mode.TARGETING
	screen._pending_card = victim
	screen._pending_groups = [[TargetRef.card(victim)]]
	screen._refresh()
	assert_gt(_links_of_color(TargetArrows.SPELL_COLOR).size(), 0,
		"the half-declared spell already shows its arrow")
	screen._clear_pending()


func test_arrows_clear_when_the_declaration_is_cancelled() -> void:
	var g: MtgGame = screen.game
	var attacker := _summon(g, "Savannah Lions", g.active_player)
	var blocker := _summon(g, "Savannah Lions", g.opponent_of(g.active_player))
	# In the declare-blockers step, or _refresh drops the assignment as
	# stale (§3.5 — s30 duel.go:1629-1656).
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS)
	screen.mode = DuelScreen.Mode.BLOCKERS
	screen._block_map = {blocker.id: attacker.id}
	screen._refresh()
	assert_gt(screen._arrows.link_count(), 0)
	screen._on_cancel()
	assert_eq(screen._arrows.link_count(), 0, "cancel takes the arrows with it")


func test_anchors_survive_a_refresh_that_rebuilds_the_board() -> void:
	# THE regression. The board is immediate-mode: every _refresh() frees
	# and rebuilds every widget, and CardPile.populate queue_free()s its old
	# cards WITHOUT removing them, so for one frame the tree holds both the
	# doomed card and its replacement. Caching the doomed one made _draw
	# assign a freed object to a typed local a frame later — 40-odd
	# "Trying to assign invalid previously freed instance" errors per tour,
	# invisible to every other UI test because none of them refreshes
	# between caching an anchor and resolving it.
	var g: MtgGame = screen.game
	var attacker := _summon(g, "Savannah Lions", g.active_player)
	var blocker := _summon(g, "Wall of Stone", g.opponent_of(g.active_player))
	# Fill both seats' land rows so the piles (the queue_free-without-remove
	# path) are genuinely in play.
	for _i in DuelScreen.PILE_SIZE + 1:
		_summon(g, "Plains", 0)
		_summon(g, "Plains", 1)
	screen._block_map = {blocker.id: attacker.id}
	for _pass in 3:
		screen._refresh()
		await get_tree().process_frame
		for widget in screen._arrows._cards.values():
			assert_true(is_instance_valid(widget),
				"a cached anchor was freed under the arrow layer")
			assert_false(widget.is_queued_for_deletion(),
				"a doomed widget was cached instead of its replacement")
		# The resolve path is what actually crashed; run it explicitly.
		assert_gt(screen._arrows.resolved_arrows().size(), 0,
			"the block arrow still resolves after the rebuild")


func test_a_dead_anchor_is_dropped_rather_than_re_tested() -> void:
	var g: MtgGame = screen.game
	var attacker := _summon(g, "Savannah Lions", g.active_player)
	var blocker := _summon(g, "Savannah Lions", g.opponent_of(g.active_player))
	screen._block_map = {blocker.id: attacker.id}
	screen._refresh()
	# Simulate the widget dying without a rebuild behind it.
	for id in screen._arrows._cards.keys():
		var widget: Node = screen._arrows._cards[id]
		widget.get_parent().remove_child(widget)
		widget.free()
	assert_eq(screen._arrows.resolved_arrows().size(), 0,
		"nothing resolves once every anchor is gone — and nothing errors")
	# A dead entry the resolver touched is dropped, so it is not re-tested
	# on every one of the 60 frames a second _process asks for.
	assert_false(screen._arrows._cards.has(blocker.id), "dead anchor dropped")
	assert_false(screen._arrows._cards.has(attacker.id), "dead anchor dropped")


func test_a_target_with_no_widget_is_skipped_not_drawn_to_nowhere() -> void:
	var g: MtgGame = screen.game
	var ghost := _summon(g, "Savannah Lions", 0)
	# The SPELL is its own card in the stack zone, because the spell chain
	# draws a MiniCard for whatever it holds (forty-second pass) — staging
	# the ghost as both source and target would give it a widget after all
	# and measure nothing.
	var bolt_data := CardRegistry.get_card("Lightning Bolt")
	var bolt := CardInstance.new(bolt_data, g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[bolt.id] = bolt
	bolt.zone = Mtg.Zone.STACK
	var spell := StackItem.new()
	spell.kind = Mtg.StackKind.SPELL
	spell.controller = 0
	spell.card = bolt
	spell.targets = [TargetRef.card(ghost)]
	g.stack.append(spell)
	# Move the TARGET off the battlefield so no MiniCard exists for it.
	g.players[0].battlefield.erase(ghost)
	ghost.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(ghost)
	screen._refresh()
	var pointed_at_ghost := false
	for link in screen._arrows.links():
		if link["to"] == ghost.id:
			pointed_at_ghost = true
	assert_false(pointed_at_ghost, "no arrow to a card with no widget")
	g.stack.clear()


# ------------------------------------------------------------- helpers --

## Put a real card on the battlefield through the same surgery the other UI
## tests use (tests/game_test.gd's convention: reach into engine internals
## only from test code).
func _summon(g: MtgGame, card_name: String, pid: int) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	return inst


## The same game, reported as sitting in [param step] — the arrow layer
## asks current_step() to decide whether declared blocks are shown.
func _game_at_step(g: MtgGame, step: int) -> MtgGame:
	g._step_index = Mtg.STEP_ORDER.find(step)
	return g


func _find_link(from_id: int, to_id: int) -> Dictionary:
	for link in screen._arrows.links():
		if link["from"] == from_id and link["to"] == to_id:
			return link
	return {}


func _links_of_color(want: Color) -> Array:
	var out: Array = []
	for link in screen._arrows.links():
		if link["color"] == want:
			out.append(link)
	return out


# -------------------------------------- the CLOSED graveyard overlay --

func _bury(pid: int, card_name: String) -> CardInstance:
	var game: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, game._next_instance_id, pid)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	inst.zone = Mtg.Zone.GRAVEYARD
	game.players[pid].graveyard.append(inst)
	return inst


func test_a_closed_graveyard_view_is_not_an_arrow_anchor() -> void:
	# THE BUG THIS PINS: `_collect` walks the whole duel screen, and
	# `DuelScreen._close_graveyard` closes the overlay by setting
	# `visible = false` rather than emptying it — so every MiniCard the
	# view built stayed parented, at its last laid-out rect, for the rest
	# of the duel. A graveyard card has no board widget, so the hidden one
	# was the ONLY match for its id and won: the next Raise Dead or
	# Animate Dead drew an amber arrow into empty board. `_target_anchor`'s
	# own doc says a graveyard card "is skipped rather than drawn to
	# nowhere", which stopped being true when GraveyardView landed.
	var dead := _bury(0, "Grizzly Bears")
	screen._on_grave_pile_clicked(0)
	await get_tree().process_frame
	assert_true(screen.graveyard_is_open(), "the pile opened")
	assert_true(screen._arrows._scan_cards().has(dead.id),
		"while it is open its cards are real, on-screen widgets")
	screen._on_grave_pile_clicked(0)
	assert_false(screen.graveyard_is_open(), "the same pile closes it")
	assert_false(screen._arrows._scan_cards().has(dead.id),
		"and a hidden widget is not somewhere to point an arrow")


# ------------------------------- an ability as the target (2026-09-02) --

func test_an_ability_picked_as_a_target_is_pointed_at_on_the_chain() -> void:
	# Rust, Ayesha Tanaka: the target is an ABILITY on the chain, which
	# has no instance id — _target_anchor found nothing, and the arrow
	# was simply not drawn while the player aimed. The chain draws an
	# ability as a widget of its own (its source's face under an
	# `activates` band, tagged by DuelScreen._make_card), and that widget
	# is where the arrow ends.
	var g: MtgGame = screen.game
	var icy := _summon(g, "Icy Manipulator", 1)
	var item := StackItem.new()
	item.kind = Mtg.StackKind.ABILITY
	item.card = icy
	item.controller = 1
	item.effects = icy.data.activated_abilities[0].effects
	item.description = "%s activates Icy Manipulator" % g.players[1].player_name
	item.id = g._next_stack_id
	g._next_stack_id += 1
	g.stack.append(item)
	var source := _summon(g, "Savannah Lions", 0)
	screen.mode = DuelScreen.Mode.TARGETING
	screen._pending_card = source
	screen._pending_groups = [[TargetRef.ability(item)]]
	screen._refresh()
	var amber := _links_of_color(TargetArrows.SPELL_COLOR)
	assert_eq(amber.size(), 1, "the half-declared spell shows its arrow")
	var dest: Variant = amber[0]["to"]
	assert_true(dest is Control, "ending on a widget, not on a card id")
	assert_eq(dest.get_meta("chain_ability_id"), item.id,
		"the chain's widget for THAT ability")
	assert_ne(dest, screen._arrows._cards.get(icy.id),
		"not the Icy Manipulator's own card on the table")
	screen._clear_pending()
	g.stack.clear()
