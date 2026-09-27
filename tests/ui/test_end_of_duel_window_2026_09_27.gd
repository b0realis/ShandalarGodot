extends GutTest
## THE END OF DUEL WINDOW FOLDS ITS LINES (2026-09-27). The fourth playtest
## report: *"in the gauntlet with long named decks the text can overflow
## the you won window"*, and then *"probably overflows with long card names
## not decks as no deck is displayed there"*. Both were right. A gauntlet
## opponent is NAMED after its deck (`GauntletState.name_for_round`), and
## `decks/` carries a title seventy characters long, so `%s won`, `%s  %d
## life` and `%s next draw:` all carried it into a 272px window whose lines
## could not fold — the title alone widened the column past the ground and
## took every line with it. And the next draw's own name runs to thirty-one
## characters (`The Tabernacle at Pendrell Vale`), which no 272px window
## holds beside `Your next draw:`.
##
## Now every line in the window wraps at its edge (`OriginalDialog.wrapped`,
## and the title too, in `create`), the card sits on its own row under its
## caption (`DuelScreen.next_draw_lines`), and the window grows to hold the
## rows and stays centred (`OriginalDialog.fit_height`).

const DECK_TITLE := "Menendian — Eternal Weekend 2016 Old School finalist (UR Aggro-Control)"
const CARD := "The Tabernacle at Pendrell Vale"
const DRAWS_KEY := "SeeNextDrawsAtEndOfDuel"
## `Vector2(272, 300)` in `DuelScreen._show_result_window` — the width of
## `Winbk_Endduel.pic` (272x422) and the height measured for the usual
## four lines.
const USUAL := Vector2(272, 300)

var screen: DuelScreen
var _had_draws := false
var _draws_value = null


func before_each() -> void:
	# The toggle is the player's, in their own file: remembered and put
	# back, the way `test_duel_options.gd` does it.
	_had_draws = Settings.has_value(DRAWS_KEY)
	_draws_value = Settings.get_value(DRAWS_KEY, null) if _had_draws else null
	DuelOptions.set_toggle(DRAWS_KEY, true)
	# A player against the Wizard: the seat whose name the window says.
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	if _had_draws:
		Settings.set_value(DRAWS_KEY, _draws_value)
	else:
		Settings.clear_value(DRAWS_KEY)


## Put a card of this name on top of a seat's library.
func _put_on_top(pid: int, card_name: String) -> void:
	var data := CardData.new(card_name)
	screen.game.players[pid].library.append(CardInstance.new(data, 900 + pid, pid))


## Every line the window says: the title, then the body's rows.
func _lines(dialog: OriginalDialog) -> Array[Label]:
	var out: Array[Label] = []
	for node in dialog.body().get_parent().get_children() + dialog.body().get_children():
		if node is Label:
			out.append(node)
	return out


func _open(verdict: String) -> OriginalDialog:
	screen._show_result_window(verdict)
	await get_tree().process_frame
	await get_tree().process_frame
	return screen._over_dialog


func test_the_usual_window_keeps_its_measured_size() -> void:
	var dialog: OriginalDialog = await _open("You won!")
	assert_eq(dialog.size, USUAL, "four short lines need no more than 1997 measured")
	var lines := _lines(dialog)
	assert_eq(lines.size(), 5, "the title, two life lines, two next draws")
	for i in 3:
		assert_eq(lines[i].get_line_count(), 1, lines[i].text)
	for i in [3, 4]:
		assert_eq(lines[i].get_line_count(), 2,
			"the caption and, under it, the card: " + lines[i].text)


func test_the_next_draw_names_the_card_on_its_own_row() -> void:
	_put_on_top(0, CARD)
	_put_on_top(1, CARD)
	var lines := screen.next_draw_lines()
	assert_eq(lines.size(), 2, "one entry per seat, as before")
	assert_eq(lines[0], "Your next draw:\n%s" % CARD)
	assert_eq(lines[1], "%s next draw:\n%s" % [screen.game.players[1].player_name, CARD])


func test_a_gauntlet_opponent_named_after_its_deck_folds_inside_the_window() -> void:
	screen.game.players[1].player_name = DECK_TITLE
	_put_on_top(0, CARD)
	_put_on_top(1, CARD)
	var dialog: OriginalDialog = await _open("%s won" % DECK_TITLE)
	var inner := USUAL.x - 2 * OriginalDialog.MARGIN
	var column: Control = dialog.body().get_parent()
	assert_eq(dialog.size.x, USUAL.x, "the art's width is kept")
	assert_eq(column.size.x, inner, "the column no longer widens past the ground")
	var lines := _lines(dialog)
	assert_eq(lines.size(), 5)
	for line in lines:
		assert_eq(line.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, line.text)
		assert_eq(line.size.x, inner, "the row is as wide as the column: " + line.text)
		assert_eq(line.get_visible_line_count(), line.get_line_count(),
			"and no row of it is clipped: " + line.text)
	assert_gte(lines[0].get_line_count(), 2, "the title folds")
	assert_gte(lines[2].get_line_count(), 2, "the opponent's life line folds")
	assert_gte(lines[4].get_line_count(), 3, "the caption, the name's fold and the card")


func test_the_window_grows_to_hold_the_rows_and_stays_centred() -> void:
	screen.game.players[1].player_name = DECK_TITLE
	_put_on_top(0, CARD)
	_put_on_top(1, CARD)
	var dialog: OriginalDialog = await _open("%s won" % DECK_TITLE)
	var column: Control = dialog.body().get_parent()
	assert_gt(dialog.size.y, USUAL.y, "taller than the usual window")
	assert_almost_eq(dialog.size.y,
		column.get_combined_minimum_size().y + 2 * OriginalDialog.MARGIN, 0.5,
		"by exactly what the rows need")
	assert_lte(column.size.y, dialog.size.y - 2 * OriginalDialog.MARGIN + 0.5,
		"the column stays on the stone")
	var foot: Control = dialog._buttons
	assert_lte(column.position.y + foot.position.y + foot.size.y,
		dialog.size.y - OriginalDialog.MARGIN + 0.5, "and so does OK")
	var room := dialog.get_parent_area_size()
	assert_almost_eq(dialog.position + dialog.size / 2, room / 2, Vector2(0.5, 0.5),
		"the taller window is centred, not hung off the old centre")


func test_fit_height_never_shrinks_a_window() -> void:
	var dialog := OriginalDialog.create("Concede", Vector2(360, 168), "panel_dark_stone")
	dialog.add_button("OK")
	add_child_autofree(dialog)
	dialog.body().add_child(OriginalDialog.wrapped("Concede this duel?", 14))
	dialog.fit_height()
	assert_eq(dialog.size, Vector2(360, 168), "a window with room keeps its measure")
	for i in 12:
		dialog.body().add_child(OriginalDialog.wrapped(DECK_TITLE, 14))
	dialog.fit_height()
	var grown := dialog.size.y
	assert_gt(grown, 168.0, "twelve folded lines need more")
	dialog.fit_height()
	assert_eq(dialog.size.y, grown, "measured twice, the same")


func test_a_title_wider_than_its_window_folds_rather_than_widening_the_column() -> void:
	# `create` gives every dialog's title the fold — the End of Duel
	# window is only where it was seen.
	var dialog := OriginalDialog.create("%s won" % DECK_TITLE, Vector2(272, 300))
	add_child_autofree(dialog)
	await get_tree().process_frame
	var column: Control = dialog.body().get_parent()
	var head: Label = column.get_child(0)
	assert_eq(column.size.x, 272.0 - 2 * OriginalDialog.MARGIN)
	assert_eq(head.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_gte(head.get_line_count(), 2, "folded, not walked through the edge")
