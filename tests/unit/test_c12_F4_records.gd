extends GameTest
## RECORDS AND CHECKPOINTS, WRITTEN WHOLE (the bug campaign c12).
##
##   h5-3  A game record holding a 20-digit number — an event serial, an
##         object handle — made the engine print "Cannot represent … as a
##         64-bit signed integer" on the way to refusing it. Past Games,
##         Open MPN, Watch duel and Export all parse first.
##   h5-7  Export MPN and the move list's Save text… wrote straight over
##   h6-3  the chosen file; MpnArchive appended its records, and a Booster
##         Draft checkpoint was renamed in, all unchecked. On a full disk a
##         buffered write and its flush report no error, so a cut-short
##         file replaced a good one — or records were dropped — while the
##         game said it had saved.
##   h6-2  The tournament checkpoint likewise said OK on a full disk, and
##         every later save said OK while the `.bak` stayed frozen.
##
## A full disk cannot be made inside a test; what can is a write that
## does not land: a folder at the pending name [method
## Settings.write_atomically] writes to (the shell-I/O bug pass's way), or
## the recording's file taken from under it. Each test holds the earlier
## file to its bytes and the caller to having heard. (The campaign also
## ran each writer under a 4096-byte file-size limit, before and after.)

var _folder := ""


func before_each() -> void:
	super.before_each()
	_folder = "user://c12_f4_records_" + Crypto.new().generate_random_bytes(6).hex_encode()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_folder))


func after_each() -> void:
	_remove_tree(ProjectSettings.globalize_path(_folder))


# ----------------------------------------------------------- h5-3 ----

func test_a_twenty_digit_serial_is_refused_without_an_engine_error() -> void:
	var text := _record_text().replace("\n1 state ", "\n12345678901234567890 state ")
	assert_string_contains(MpnCodec.parse(text).error, "Broken event sequence")
	assert_engine_error_count(0, "no 'Cannot represent' from the engine")


func test_a_twenty_digit_object_handle_is_refused_without_an_engine_error() -> void:
	assert_false(MpnCodec._id("o12345678901234567890", "o"))
	assert_false(MpnCodec.valid_patch({"removed": ["o12345678901234567890"]}))
	assert_engine_error_count(0, "no 'Cannot represent' from the engine")
	assert_true(MpnCodec._id("o123456789012345678", "o"), "eighteen digits are still a handle")
	assert_true(MpnCodec._id("o7", "o"))


func test_a_serial_with_leading_zeros_reads_as_it_always_did() -> void:
	var text := _record_text().replace("\n1 state ", "\n0000001 state ")
	assert_eq(MpnCodec.parse(text).error, "")


# -------------------------------------------------- h5-7: MpnFiles ----

func test_an_export_that_cannot_finish_keeps_the_earlier_record_and_says_so() -> void:
	var path := ProjectSettings.globalize_path(_folder.path_join("kept.mpn"))
	var earlier := _record_text().to_utf8_buffer()
	_put(path, earlier)
	var host := _host()
	DirAccess.make_dir_recursive_absolute(Settings.pending_path(path))
	var bytes := (_record_text() + "2 comment {\"text\":\"newer\"}\n").to_utf8_buffer()
	MpnFiles.export_bytes(host, bytes, "kept.mpn")
	_picker(host).file_selected.emit(path)
	DirAccess.remove_absolute(Settings.pending_path(path))
	assert_eq(FileAccess.get_file_as_bytes(path), earlier, "the earlier record is whole")
	assert_string_contains(_said(host), "Could not save the recording.")
	assert_false(_said(host).contains("saved."), "and nothing says it was saved")


func test_an_export_replaces_the_earlier_record_whole() -> void:
	var path := ProjectSettings.globalize_path(_folder.path_join("replaced.mpn"))
	_put(path, _record_text().to_utf8_buffer())
	var host := _host()
	var bytes := (_record_text() + "2 comment {\"text\":\"newer\"}\n").to_utf8_buffer()
	MpnFiles.export_bytes(host, bytes, "replaced.mpn")
	_picker(host).file_selected.emit(path)
	assert_eq(FileAccess.get_file_as_bytes(path), bytes)
	assert_string_contains(_said(host), "Public game record saved.")
	assert_false(FileAccess.file_exists(Settings.pending_path(path)), "nothing pending left behind")


func test_a_move_list_save_that_cannot_finish_keeps_the_earlier_text_and_says_so() -> void:
	var path := ProjectSettings.globalize_path(_folder.path_join("moves.txt"))
	_put(path, "the earlier move list\n".to_utf8_buffer())
	var host := _host()
	DirAccess.make_dir_recursive_absolute(Settings.pending_path(path))
	MpnFiles.export_text(host, "1. Mountain\n2. Lightning Bolt\n", "moves.txt")
	_picker(host).file_selected.emit(path)
	DirAccess.remove_absolute(Settings.pending_path(path))
	assert_eq(FileAccess.get_file_as_string(path), "the earlier move list\n")
	assert_string_contains(_said(host), "Could not save the move list.")
	await get_tree().process_frame   # the first dialog goes before the second opens
	var again := _host()
	MpnFiles.export_text(again, "1. Mountain\n", "moves.txt")
	_picker(again).file_selected.emit(path)
	assert_eq(FileAccess.get_file_as_string(path), "1. Mountain\n", "the next save goes through")
	assert_string_contains(_said(again), "Move list saved.")


# ----------------------------------------------- h6-3: MpnArchive ----

func test_a_recording_whose_lines_stop_landing_says_so() -> void:
	var archive := MpnArchive.new()
	var heard: Array = []
	archive.failed.connect(func(message: String) -> void: heard.append(message))
	assert_true(archive.start(g, MpnArchive.metadata(g, "test"), ProjectSettings.globalize_path(_folder)),
		archive.error)
	var path := archive.path
	assert_true(FileAccess.file_exists(path))
	# The file goes from under the recording: its writes still "succeed"
	# into a file nobody will ever read, exactly as a full disk's did.
	DirAccess.remove_absolute(path)
	archive._record("comment", {"text": "after the file went"})
	assert_ne(archive.error, "", "the recording knows its lines did not land")
	assert_eq(heard.size(), 1, "and says so once")
	archive.close()
	assert_false(FileAccess.file_exists(path), "and no file of its own is made in its place")


func test_a_whole_recording_is_still_written_line_by_line() -> void:
	var archive := MpnArchive.new()
	assert_true(archive.start(g, MpnArchive.metadata(g, "test"), ProjectSettings.globalize_path(_folder)),
		archive.error)
	archive._record("comment", {"text": "one"})
	archive._record("comment", {"text": "two"})
	assert_eq(archive.error, "")
	var parsed := MpnArchive.read(archive.path)
	assert_eq(parsed.error, "", "the prefix so far is a readable record")
	assert_eq(parsed.records.size(), 3, "the opening state and both lines")
	archive.close()


# ------------------------------------------------- h6-3: DraftStore ----

func test_a_draft_checkpoint_that_cannot_finish_keeps_the_earlier_one_and_says_so() -> void:
	var path := ProjectSettings.globalize_path(_folder.path_join("draft.deck"))
	assert_eq(DraftStore._write(path, "name: Draft\n1 Mountain\n"), "")
	DirAccess.make_dir_recursive_absolute(Settings.pending_path(path))
	var refusal := DraftStore._write(path, "name: Draft\n2 Mountain\n")
	DirAccess.remove_absolute(Settings.pending_path(path))
	assert_ne(refusal, "", "a checkpoint that did not land is not called saved")
	assert_string_contains(refusal, "Cannot save the draft")
	assert_eq(FileAccess.get_file_as_string(path), "name: Draft\n1 Mountain\n",
		"the earlier checkpoint is whole")
	assert_eq(DraftStore._write(path, "name: Draft\n2 Mountain\n"), "")
	assert_eq(FileAccess.get_file_as_string(path), "name: Draft\n2 Mountain\n")
	assert_false(FileAccess.file_exists(Settings.pending_path(path)), "nothing pending left behind")


# ---------------------------------------- h6-2: the tournament store ----

func test_a_tournament_checkpoint_that_cannot_finish_is_not_called_saved() -> void:
	var folder := ProjectSettings.globalize_path(_folder.path_join("tournaments"))
	var event := _event()
	assert_eq(SgTournamentStore.save(event, folder), OK)
	var path := folder.path_join(event.id + ".json")
	var first := FileAccess.get_file_as_bytes(path)
	assert_eq(SgTournamentStore.save(event, folder), OK, "a second save rotates the first to .bak")
	var backup := FileAccess.get_file_as_bytes(path + ".bak")
	event.register("Latecomer", "late".sha256_text())
	DirAccess.make_dir_recursive_absolute(Settings.pending_path(path))
	var result := SgTournamentStore.save(event, folder)
	DirAccess.remove_absolute(Settings.pending_path(path))
	assert_ne(result, OK, "a checkpoint that did not land is not OK")
	assert_eq(FileAccess.get_file_as_bytes(path), first, "the last good checkpoint is whole")
	assert_eq(FileAccess.get_file_as_bytes(path + ".bak"), backup, "and so is the one before")
	assert_eq(SgTournamentStore.save(event, folder), OK, "the next save goes through")
	assert_eq(FileAccess.get_file_as_bytes(path + ".bak"), first, "the .bak still rotates")
	assert_eq(FileAccess.get_file_as_string(path), SgProtocol.encode(event.checkpoint()),
		"the newest checkpoint is the one on disk")
	assert_false(SgTournamentStore.read_checkpoint(path).is_empty(), "and it reads back")
	for name in DirAccess.get_files_at(folder):
		assert_false(name.contains(".tmp"), "no pending file left behind: " + name)


func test_the_pending_checkpoint_is_this_process_own() -> void:
	# Two instances restoring one event shared `<id>.json.tmp`: one could
	# rename the other's half-written file in. A stale shared one is left
	# alone and never read.
	var folder := ProjectSettings.globalize_path(_folder.path_join("tournaments"))
	DirAccess.make_dir_recursive_absolute(folder)
	var event := _event()
	var path := folder.path_join(event.id + ".json")
	_put(path + ".tmp", "{\"half\":".to_utf8_buffer())
	assert_eq(SgTournamentStore.save(event, folder), OK)
	assert_eq(FileAccess.get_file_as_string(path + ".tmp"), "{\"half\":", "another's pending file is not touched")
	assert_false(SgTournamentStore.read_checkpoint(path).is_empty())


# ------------------------------------------------------------ helpers --

## A minimal public record [MpnCodec.parse] accepts.
func _record_text() -> String:
	var headers := {"Notation": MpnCodec.VERSION, "Visibility": "public", "Coverage": MpnCodec.COVERAGE,
		"Started": "2026-10-27T00:00:00Z", "Match": "m1", "Player.P1": "One", "Player.P2": "Two"}
	var player := {"life": 20, "hand": 7, "library": 33, "mana": {}}
	var state := {"turn": 1, "step": "main1", "active": 0, "players": [player, player],
		"objects": [], "stack": [], "combat": {"attackers": [], "blocks": []}}
	return MpnCodec.header_text(headers) + MpnCodec.record_text(1, "state", state)


func _event() -> SgTournament:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Checkpoint Cup", "limit": 8, "wins": 1, "policy": "own",
		"decks": []}, 1212), "")
	for i in 4:
		event.register("Player %d" % (i + 1), str(i).sha256_text())
	return event


func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child_autofree(host)
	return host


func _picker(host: Node) -> FileDialog:
	for child in host.get_children():
		if child is FileDialog:
			return child
	assert_true(false, "the save dialog opened")
	return FileDialog.new()


## Every label's text under [param host] — what a popup said.
func _said(host: Node) -> String:
	var out := ""
	var stack: Array[Node] = [host]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label:
			out += (node as Label).text + "\n"
		elif node is RichTextLabel:
			out += (node as RichTextLabel).text + "\n"
		stack.append_array(node.get_children())
	return out


func _put(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for dir_name in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(dir_name))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
