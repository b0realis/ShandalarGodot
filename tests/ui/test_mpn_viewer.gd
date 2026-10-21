extends GameTest
## Archive/Options/result-window integration, independent read-only viewer.
var archive: MpnArchive
var folder := ""
class QuietDuel extends DuelScreen:
	func _ready() -> void: pass

func before_each() -> void:
	super.before_each()
	folder = "user://mpn-test-" + MpnArchive.new_id()
	archive = MpnArchive.new()

func after_each() -> void:
	archive.close()
	for path in MpnArchive.files(folder): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)

func test_archive_is_flushable_complete_and_grouped_without_private_metadata() -> void:
	assert_true(archive.start(g, MpnArchive.metadata(g, "test", "series-example", 2), folder))
	assert_eq(MpnArchive.read(archive.path).error, "")
	put_battlefield(0, "Grizzly Bears")
	g.concede(1)
	var parsed := MpnArchive.read(archive.path)
	assert_true(parsed.finished)
	assert_eq(parsed.headers.Match, "series-example")
	assert_eq(int(parsed.headers.Game), 2)
	assert_true(parsed.headers.Started.ends_with("Z"))
	assert_true(parsed.headers.has("RulesOptions"))
	assert_true(parsed.headers.has("CardPool"))
	for forbidden in ["seed", "rng", "hand", "decklist", "path", "resume", "access"]:
		assert_false(parsed.headers.has(forbidden))
	assert_eq(MpnArchive.files(folder), [archive.path])

func test_stopping_is_not_a_loss_and_keeps_readable_prefix() -> void:
	assert_true(archive.start(g, MpnArchive.metadata(g, "test"), folder))
	archive.close()
	var parsed := MpnArchive.read(archive.path)
	assert_eq(parsed.error, "")
	assert_false(parsed.finished)
	assert_eq(parsed.records.back().kind, "close")

func test_viewer_opens_steps_seeks_and_keeps_current_game_after_invalid_file() -> void:
	assert_true(archive.start(g, MpnArchive.metadata(g, "test"), folder))
	put_battlefield(0, "Grizzly Bears")
	g.adjust_life(0, 5)
	g.concede(1)
	var screen := PastGamesScreen.new()
	screen.archive_directory = folder
	add_child_autofree(screen)
	assert_true(screen.open_record(archive.path))
	assert_eq(int(screen._state.players[0].life), 20)
	screen.seek(screen._record_count() - 1)
	assert_eq(int(screen._state.players[0].life), 25)
	assert_eq(screen._state.objects.size(), 1)
	screen.seek(0)
	assert_eq(screen._state.objects.size(), 0)
	assert_false(screen.open_record(folder.path_join("absent.mpn")))
	assert_eq(screen.current_path, archive.path)
	assert_false(screen._export.disabled)
	await get_tree().process_frame

func test_options_offer_the_requested_file_picker() -> void:
	var options: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options)
	var button: Button = options.find_child("ViewPastGames", true, false)
	assert_not_null(button)
	button.pressed.emit()
	var picker: FileDialog
	for child in options.get_children():
		if child is FileDialog: picker = child
	assert_not_null(picker)
	assert_eq(picker.ok_button_text, "View")
	assert_eq(picker.cancel_button_text, "Cancel")
	picker.canceled.emit()
	await get_tree().process_frame

func test_optional_fields_from_another_writer_cannot_crash_either_view() -> void:
	var doc := MpnCodec.parse(FileAccess.get_file_as_string("res://docs/mpn-examples/finished-game.mpn"))
	doc.headers.RulesProfile = ["wrong optional type"]
	doc.records[0].data.objects[0].printing = {}
	doc.records[0].data.objects[0].rules_text = []
	doc.records.insert(1, {"kind": "draw", "data": {"player": {}, "count": []}})
	var text := MpnCodec.header_text(doc.headers)
	for i in doc.records.size(): text += MpnCodec.record_text(i + 1, doc.records[i].kind, doc.records[i].data)
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("optional-fields.mpn")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file.store_string(text))
	file.close()
	var screen := PastGamesScreen.new()
	screen.archive_directory = folder
	add_child_autofree(screen)
	assert_true(screen.open_record(path))
	assert_true(screen._notice.text.contains("Rules not specified"))
	screen._show_card(screen._state.objects.values()[0])
	assert_true(screen._details.text.contains("Rules text not recorded"))
	screen.seek(1)
	assert_true(screen._details.text.contains("Unknown player draws ?"))
	screen.watch_duel()
	assert_eq(screen._player.cursor, 1)
	screen._player.close_player()
	await get_tree().process_frame

func test_local_and_online_results_offer_export_without_next_draw_leak() -> void:
	assert_true(archive.start(g, MpnArchive.metadata(g, "test"), folder))
	g.concede(1)
	var screen := QuietDuel.new()
	screen.config = DuelConfig.new()
	screen.game = g
	screen._public_archive = archive
	add_child_autofree(screen)
	screen._show_result_window("You won")
	assert_true(_has_button(screen._over_dialog, "Export MPN"))
	var online := SgDuelView.new()
	online.game = g
	online.config = DuelConfig.new()
	add_child_autofree(online)
	online._show_result_window("You lost")
	assert_true(_has_button(online._over_dialog, "Export MPN"))
	await get_tree().process_frame
	await get_tree().process_frame
	for dialog in [screen._over_dialog, online._over_dialog]:
		var primary := _button_named(dialog, "OK")
		var secondary := _button_named(dialog, "Export MPN")
		var foot := secondary.get_global_rect()
		var confirm := primary.get_global_rect()
		assert_eq(secondary.size, primary.size, "export and OK have matching sizes")
		assert_eq(secondary.get_parent(), primary.get_parent(), "both buttons share the footer row")
		assert_almost_eq(foot.get_center().y, confirm.get_center().y, 1.0)
		assert_gte(confirm.position.x - foot.end.x, 12.0, "clear gap between export and OK")
		assert_almost_eq(foot.position.x, dialog.global_position.x + OriginalDialog.MARGIN, 1.0)
		assert_almost_eq(confirm.end.x, dialog.get_global_rect().end.x - OriginalDialog.MARGIN, 1.0)
		assert_almost_eq(confirm.end.y, dialog.get_global_rect().end.y - OriginalDialog.MARGIN, 1.0)
		assert_eq(secondary.focus_mode, Control.FOCUS_ALL, "still reachable with the keyboard")
	assert_true(_button_named(online._over_dialog, "OK").has_focus(), "OK remains the default")
	var exports := [0]
	online.mpn_requested.connect(func() -> void: exports[0] += 1)
	var export_button := _button_named(online._over_dialog, "Export MPN")
	export_button.pressed.emit()
	assert_eq(exports[0], 1, "the LAN result button requests the neutral archive")
	assert_false(FileAccess.get_file_as_string(archive.path).contains("next draw"))

func _has_button(node: Node, label: String) -> bool:
	if node is Button and node.text == label: return true
	for child in node.get_children():
		if _has_button(child, label): return true
	return false

func _button_named(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var button := _button_named(child, label)
		if button != null: return button
	return null
