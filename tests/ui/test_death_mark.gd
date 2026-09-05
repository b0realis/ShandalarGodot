extends GameTest
## THE DYING MARK — `game/duel/death_mark.gd`, the 1997 `Dying` state held
## on the table for a beat over a permanent that has just been destroyed.
##
## THE FIDELITY PIN THIS FILE EXISTS FOR is that the mark hangs off the
## DEATH, not off the damage. The original's own predicate is
## `instance->kill_code == KILL_DESTROY` — marked to be destroyed and not
## reaped yet (`shandalar-src/src/functions/windows.c:724`, quoting the
## 1997 exe's `@CUECARD_SMALLCARD[7]` at `0x786f08`) — which is the same
## thing a regeneration effect targets (`defs.h:2481`,
## `TARGET_SPECIAL_REGENERATION`, refused with `Illegal target (not
## dying).`), and which `Duel.hlp`'s **Regeneration** topic states in
## words: *"You can use regeneration ONLY at the time when a creature is
## about to go to the graveyard."*
##
## So: destroyed gets the mark, REGENERATED DOES NOT, sacrificed does not,
## and the mark goes when its hold is up. Those four are the file.


## The board a card lives on: `DeathMark.raise_over` hangs a mark off the
## highest Control ABOVE the card, because the duel screen frees every
## widget on the table on every refresh. A bare `add_child_autofree(card)`
## in a GutTest parents it to a plain Node, so there is nothing to hang
## from — the same reason the real card is inside `DuelScreen`.
var _board: Control = null


func before_each() -> void:
	super.before_each()
	_board = Control.new()
	_board.size = Vector2(640, 480)
	add_child_autofree(_board)


## A card on the board, laid out where the mark can find it. The size and
## position are set by hand: nothing lays this container out, and
## `TargetArrows.anchor_rect` returns an empty rect for a widget with no
## rectangle, which is exactly the "a mark floating over nothing" case
## `raise_over` refuses.
func _card_on_board(inst: CardInstance, at := Vector2(120, 90)) -> MiniCard:
	var card := MiniCard.new(inst, g)
	_board.add_child(card)
	card.position = at
	card.size = MiniCard.SIZE
	return card


func _marks() -> Array:
	var out: Array = []
	for child in _board.get_children():
		if child is DeathMark:
			out.append(child)
	return out


# ================================================ when the mark appears ==

func test_a_destroyed_creature_leaves_the_dying_mark_on_the_table() -> void:
	# The owner's playtest defect: "Killed creatures should have blood
	# state graphic over them!" — nothing drew one, because the widget for
	# a dead creature is freed by the next board rebuild and the engine's
	# own `Dying` window has no duration under the modern ruleset.
	var bears := put_battlefield(0, "Grizzly Bears")
	var card := _card_on_board(bears)
	assert_eq(_marks().size(), 0, "nothing on the table before the kill")
	g.destroy(bears)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "it really died")
	var marks := _marks()
	assert_eq(marks.size(), 1, "the kill leaves exactly one mark")
	var mark: DeathMark = marks[0]
	assert_not_null(mark.ghost, "the mark carries the dead card's face")
	assert_true(mark.ghost.active_states().has(MiniCard.State.DYING),
		"and that face wears @CUECARD_SMALLCARD's `Dying`")
	assert_true(card != null)


func test_the_mark_stands_where_the_card_stood() -> void:
	# The duel screen has twice shipped an overlay in the wrong corner.
	var bears := put_battlefield(0, "Grizzly Bears")
	var card := _card_on_board(bears, Vector2(210, 64))
	var was := TargetArrows.anchor_rect(card)
	g.destroy(bears)
	var mark: DeathMark = _marks()[0]
	assert_almost_eq(mark.global_position.x, was.position.x, 0.5)
	assert_almost_eq(mark.global_position.y, was.position.y, 0.5)
	assert_eq(mark.size, MiniCard.SIZE, "and at the one card size")


func test_the_mark_is_the_1997_cracks_over_the_art() -> void:
	# `Dying.pic` is 194x97 — a 97x97 IMAGE beside a 97x97 MASK, the exact
	# shape of `Summon.pic` — so it is ONE frame drawn over the card's art
	# window, not a strip. Placement is not re-derived by the mark: it is
	# the small card's own art region.
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported — the state art stays hidden")
		return
	var bears := put_battlefield(0, "Grizzly Bears")
	_card_on_board(bears)
	g.destroy(bears)
	var ghost: MiniCard = (_marks()[0] as DeathMark).ghost
	var cracks: TextureRect = ghost._overlays.get(MiniCard.State.DYING)
	assert_not_null(cracks, "the cracks overlay was built")
	assert_true(cracks.visible, "and is drawn")
	assert_not_null(cracks.texture, "with the decoded 1997 sprite")
	assert_eq(cracks.tooltip_text, "Dying", "@CUECARD_SMALLCARD, verbatim")
	# The art region, shared with the summoning-sickness spiral.
	assert_almost_eq(cracks.anchor_left, MiniCard.ART_LEFT, 0.001)
	assert_almost_eq(cracks.anchor_top, MiniCard.ART_TOP, 0.001)
	assert_almost_eq(cracks.anchor_right, MiniCard.ART_RIGHT, 0.001)
	assert_almost_eq(cracks.anchor_bottom, MiniCard.ART_BOTTOM, 0.001)


func test_the_imported_dying_sheet_is_one_frame_and_a_mask() -> void:
	# How we know it does not animate: the right half is a two-tone MASK,
	# not a second drawing, so `masked_sprite` yields one 97x97 sprite.
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported")
		return
	var sheet := GameSkin.texture("state_dying")
	assert_not_null(sheet, "Dying.pic is imported as `state_dying`")
	assert_eq(sheet.get_width(), 194, "194 = 97 image + 97 mask")
	assert_eq(sheet.get_height(), 97)
	var sprite := MiniCard.masked_sprite("state_dying")
	assert_eq(sprite.get_width(), 97, "one square frame comes out")
	assert_eq(sprite.get_height(), 97)


# ============================================ when it must NOT appear ==

func test_a_regenerated_creature_never_wears_the_mark() -> void:
	# THE CASE THE MARK IS HUNG ON THE DEATH FOR. `MtgGame.destroy` spends
	# the shield and returns before `_move_to_graveyard`, so no DIES event
	# is ever dispatched and there is nothing for the widget to hear.
	# 1997 draws the same line from the other side: `regenerate_target`
	# clears the `KILL_DESTROY` code, and the cue card goes with it.
	var skeletons := put_battlefield(0, "Drudge Skeletons")   # 1/1
	skeletons.regeneration_shields = 1
	_card_on_board(skeletons)
	g.destroy(skeletons)
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD, "it regenerated")
	assert_true(skeletons.tapped, "tapped, as CR 701.15a says")
	assert_eq(_marks().size(), 0,
		"and wears no dying mark — it survived, and saying otherwise "
		+ "would be a lie about the board")


func test_a_regenerated_creature_drops_the_live_dying_overlay_too() -> void:
	# The other half: while lethal damage sits on it the small card DOES
	# read `Dying` (that is the engine's `awaiting_regeneration` moment,
	# `Duel.hlp`'s "about to go to the graveyard"). Once the shield has
	# been spent the damage is gone and so is the overlay.
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	skeletons.damage = 1
	var card := _card_on_board(skeletons)
	assert_true(card.active_states().has(MiniCard.State.DYING),
		"lethal damage marked: it is about to go to the graveyard")
	skeletons.regeneration_shields = 1
	g.destroy(skeletons)
	card.refresh()
	assert_false(card.active_states().has(MiniCard.State.DYING),
		"regenerated, so not dying any more")


func test_a_sacrificed_permanent_gets_no_mark() -> void:
	# 1997 keeps the kill codes apart: only `KILL_DESTROY` reads `Dying`,
	# and `KILL_SACRIFICE` is why regeneration cannot answer a sacrifice.
	# Our engine draws the same line — `sacrifice_permanent` never enters
	# `destroy` — and the DIES event carries the flag that says so.
	var bears := put_battlefield(0, "Grizzly Bears")
	_card_on_board(bears)
	g.sacrifice_permanent(bears)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "it did go to the graveyard")
	assert_eq(_marks().size(), 0, "but it was not DESTROYED")


func test_a_creature_dying_beside_it_leaves_this_card_alone() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(0, "Savannah Lions")
	var lion_card := _card_on_board(lions, Vector2(20, 20))
	_card_on_board(bears, Vector2(200, 20))
	g.destroy(bears)
	assert_eq(_marks().size(), 1, "one death, one mark")
	assert_false(lion_card.active_states().has(MiniCard.State.DYING),
		"the survivor is untouched")


func test_a_card_with_no_board_under_it_raises_nothing() -> void:
	# The rule TargetArrows and DamageMarkerLayer already follow: a mark
	# floating over nothing is worse than no mark. A widget off the tree,
	# hidden, or with no Control above it has no square to stand on.
	var bears := put_battlefield(0, "Grizzly Bears")
	var loose := MiniCard.new(bears, g)
	add_child_autofree(loose)
	assert_null(DeathMark.raise_over(loose),
		"nothing to hang a mark from")
	assert_null(DeathMark.host_for(loose))


func test_a_hidden_card_raises_nothing() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var card := _card_on_board(bears)
	card.visible = false
	g.destroy(bears)
	assert_eq(_marks().size(), 0, "a card nobody can see marks nothing")


# ================================================= and when it goes ==

func test_the_mark_fades_and_frees_itself() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	_card_on_board(bears)
	g.destroy(bears)
	var mark: DeathMark = _marks()[0]
	mark.advance(DeathMark.HOLD * 0.5)
	assert_almost_eq(mark.modulate.a, 1.0, 0.001,
		"it stands at full strength while the hold lasts")
	mark.advance(DeathMark.HOLD * 0.5 + DeathMark.FADE * 0.5)
	assert_lt(mark.modulate.a, 1.0, "then it starts to go")
	assert_gt(mark.modulate.a, 0.0)
	mark.advance(DeathMark.FADE)
	assert_true(mark.is_queued_for_deletion(), "and it goes")
	assert_eq(_marks().size(), 0,
		"detached before it is freed, so nothing walking the board for "
		+ "MiniCards can still find the ghost")
	await get_tree().process_frame
	assert_false(is_instance_valid(mark), "and the widget is gone with it")


func test_the_ghost_hears_no_events_of_its_own() -> void:
	# The ghost carries no game reference on purpose: `game` is what
	# connects a MiniCard to `event_occurred`, and a ghost that heard
	# events could raise marks of its own.
	var bears := put_battlefield(0, "Grizzly Bears")
	_card_on_board(bears)
	g.destroy(bears)
	var mark: DeathMark = _marks()[0]
	assert_null(mark.ghost.game)
	assert_true(mark.ghost.force_dying)
	assert_false(g.event_occurred.is_connected(mark.ghost._on_game_event))


func test_a_widget_with_no_game_hears_nothing_at_all() -> void:
	# The deck builder, the help screen and the pile views build MiniCards
	# with no game, so they never connect and can never raise a mark.
	var bears := put_battlefield(0, "Grizzly Bears")
	var card := MiniCard.new(bears)
	_board.add_child(card)
	card.position = Vector2(10, 10)
	card.size = MiniCard.SIZE
	g.destroy(bears)
	assert_eq(_marks().size(), 0)
