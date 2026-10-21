extends GameTest
## THE HISTORY VIEW'S SEEK, HUNTED (second bug hunt, 2026-10-21). Past Games'
## text view folded every state patch from record 1 on each seek that was
## not the next record — and its seek bar seeks on every step of a drag.
## Measured on a 2,000-record recording: 0.15-0.22 s a seek; 20,000 records:
## 1-2 s, so dragging the bar froze the screen. The graphical player kept
## checkpoints from the start; the text view now keeps them too, taken
## while the event list is labelled (which folds every patch anyway).

func _row(i: int, tapped: bool) -> Dictionary:
	return {"id": "o%d" % i, "name": "Grizzly Bears", "zone": "battlefield", "owner": i % 2, "controller": i % 2,
		"power": 2, "toughness": 2, "damage": 0, "tapped": tapped, "face_down": false, "creature": true,
		"counters": {}}


func _document(records: int, board: int) -> String:
	var headers := {"Notation": "MPN/0.1", "Visibility": "public", "Coverage": "public-observations",
		"Started": "2026-10-21T00:00:00Z", "Match": "m", "Player.P1": "One", "Player.P2": "Two"}
	var objects: Array = []
	for i in board: objects.append(_row(i + 1, false))
	var players := [{"life": 20, "poison": 0, "hand": 7, "library": 53, "mana": {}},
		{"life": 20, "poison": 0, "hand": 7, "library": 53, "mana": {}}]
	var parts := PackedStringArray([MpnCodec.header_text(headers), MpnCodec.record_text(1, "state",
		{"turn": 1, "step": "main1", "active": 0, "players": players, "objects": objects, "stack": [],
		"combat": {"attackers": [], "blocks": []}})])
	for serial in range(2, records + 1):
		if serial % 2 == 0:
			parts.append(MpnCodec.record_text(serial, "state", {"turn": 1 + serial / 100,
				"objects": [_row(serial % board + 1, serial % 4 == 0)]}))
		else:
			parts.append(MpnCodec.record_text(serial, "tap", {"player": "P1", "object": "o%d" % (serial % board + 1)}))
	return "".join(parts)


func _screen(records: int) -> PastGamesScreen:
	var folder := "user://mpn-history-hunt-" + MpnArchive.new_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("long.mpn")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(_document(records, 40))
	file.close()
	var screen := PastGamesScreen.new()
	screen.archive_directory = folder
	add_child_autofree(screen)
	assert_true(screen.open_record(path))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
	return screen


func test_an_arbitrary_seek_folds_from_a_checkpoint_not_from_record_one() -> void:
	var screen := _screen(1500)
	assert_false(screen._checkpoints.is_empty(), "checkpoints are taken while the list is labelled")
	var at := -1
	for index: int in screen._checkpoints:
		if index > 0 and (at < 0 or index < at): at = index
	assert_gt(at, 0)
	# A marked checkpoint: a seek past it that starts from record 1 never sees the mark.
	screen._checkpoints[at] = screen._checkpoints[at].duplicate(true)
	screen._checkpoints[at].players[0].life = 77
	screen.seek(at + 7)
	assert_eq(int(screen._state.players[0].life), 77, "the fold started at the checkpoint")
	await get_tree().process_frame


func test_every_seek_still_lands_on_the_fold_from_record_one() -> void:
	var screen := _screen(1500)
	var records: Array = screen.document.records
	for index in [1499, 0, 731, 732, 256, 255, 257, 1024, 3]:
		screen.seek(index)
		assert_eq(screen._state, MpnCodec.state_at(records, index), "record %d" % index)
	screen.seek(1000)
	for step in 5:
		screen.seek(screen.cursor + 1)
	assert_eq(screen._state, MpnCodec.state_at(records, 1005), "playback after a seek")
	await get_tree().process_frame
