extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: the running log's trim
## is whole or not at all.
##
## WAS: when an append took `duel_log.txt` past its megabyte,
## `DuelLogFile._trim` opened the file for WRITE — which empties it — and
## then wrote the kept part back. For that moment the log on disk was
## empty or cut short (a reader polling it saw 0 bytes), so a crash or a
## kill then lost the whole running log, the record kept for exactly the
## duel that crashed. NOW the kept part is written beside the log and
## renamed over it (`Settings.write_atomically`); where that cannot be
## done (a folder that takes no new file) it is rewritten in place as
## before.

var _dir := ""
var _stop := false
var _smallest := -1


func before_each() -> void:
	_dir = ProjectSettings.globalize_path("user://").path_join("hunt_screens_duel_log")
	DirAccess.make_dir_recursive_absolute(_dir)
	DuelLogFile.location = _dir
	_stop = false
	_smallest = -1


func after_each() -> void:
	var pending := Settings.pending_path(DuelLogFile.path())
	if DirAccess.dir_exists_absolute(pending):
		DirAccess.remove_absolute(pending)
	if FileAccess.file_exists(DuelLogFile.path()):
		DirAccess.remove_absolute(DuelLogFile.path())
	DuelLogFile.location = ""
	DirAccess.remove_absolute(_dir)


## A log of twelve ~100 KB games, past the cap.
func _over_the_cap() -> void:
	var file := FileAccess.open(DuelLogFile.path(), FileAccess.WRITE)
	var filler := "x".repeat(99)
	for game in 12:
		for line in DuelLogFile.banner(PackedStringArray(["A", "B"]), game + 1):
			file.store_line(line)
		for i in 1000:
			file.store_line(filler)
	file.close()


## On a thread: the log's length, as often as it can be read.
func _watch() -> void:
	var path := DuelLogFile.path()
	while not _stop:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_smallest = 0   # gone is as bad as empty
			continue
		var length := file.get_length()
		file.close()
		if _smallest < 0 or length < _smallest:
			_smallest = length


func test_no_moment_of_the_trim_leaves_a_cut_log() -> void:
	_over_the_cap()
	var watcher := Thread.new()
	watcher.start(_watch)
	OS.delay_msec(20)
	DuelLogFile.new()._trim(DuelLogFile.path())
	OS.delay_msec(5)
	_stop = true
	watcher.wait_to_finish()
	var kept := FileAccess.get_file_as_string(DuelLogFile.path())
	var size := kept.to_utf8_buffer().size()
	assert_lte(size, DuelLogFile.CAP, "trimmed under the cap")
	assert_true(kept.begins_with(DuelLogFile.RULE), "on a game's banner")
	assert_gte(_smallest, size, "the log on disk was never shorter than what was kept")


func test_a_folder_that_takes_no_new_file_still_trims_in_place() -> void:
	_over_the_cap()
	# A folder where the pending file would go: the rename route is refused.
	DirAccess.make_dir_recursive_absolute(Settings.pending_path(DuelLogFile.path()))
	DuelLogFile.new()._trim(DuelLogFile.path())
	var kept := FileAccess.get_file_as_string(DuelLogFile.path())
	assert_lte(kept.to_utf8_buffer().size(), DuelLogFile.CAP, "trimmed all the same")
	assert_true(kept.begins_with(DuelLogFile.RULE))
	assert_true(kept.contains("(seed 12)"), "the newest game kept")
	assert_false(kept.contains("(seed 1)"), "the oldest gone")
