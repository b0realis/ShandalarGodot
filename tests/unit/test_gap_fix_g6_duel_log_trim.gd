extends GutTest
## THE GAP REVIEW OF 2026-11-10 (r6-2): the running log's trim keeps the
## duel that does not fit whole.
##
## WAS: `DuelLogFile._trim` measured the slab to drop (the file down to
## `CAP - SLACK`) and then searched for the next game banner from that cut
## TO THE END OF THE FILE. A log holding one long duel and the start of the
## next lost the long duel entirely — 410 KB kept of a megabyte, the record
## of exactly the duel a player would report. NOW a banner is taken only
## where it falls within the slab — no more than `SLACK` past the cut, or
## the one the cut splits — and otherwise the cut stays on its line: the
## file then opens mid-duel, keeping that duel's tail.

var _dir := ""
var _filler := "x".repeat(99)    # 100 bytes a line with its newline


func before_each() -> void:
	_dir = ProjectSettings.globalize_path("user://").path_join("gap_fix_g6_duel_log")
	DirAccess.make_dir_recursive_absolute(_dir)
	DuelLogFile.location = _dir
	_wipe()


func after_each() -> void:
	_wipe()
	DuelLogFile.location = ""
	DirAccess.remove_absolute(_dir)


func _wipe() -> void:
	var pending := Settings.pending_path(DuelLogFile.path())
	if FileAccess.file_exists(pending):
		DirAccess.remove_absolute(pending)
	if FileAccess.file_exists(DuelLogFile.path()):
		DirAccess.remove_absolute(DuelLogFile.path())


func _read() -> String:
	return FileAccess.get_file_as_string(DuelLogFile.path())


func _bytes(line: String) -> int:
	return line.to_utf8_buffer().size() + 1


## Writes [param lines] as the log, each with its newline.
func _store(lines: PackedStringArray) -> void:
	var file := FileAccess.open(DuelLogFile.path(), FileAccess.WRITE)
	for line in lines:
		file.store_line(line)
	file.close()


## [param count] filler lines.
func _fill(lines: PackedStringArray, count: int) -> void:
	for i in count:
		lines.append(_filler)


## Pads [param lines] up to exactly [param total] bytes with filler lines
## and one last shorter line.
func _pad_to(lines: PackedStringArray, total: int) -> void:
	var now := 0
	for line in lines:
		now += _bytes(line)
	while total - now >= 200:
		lines.append(_filler)
		now += 100
	assert_gt(total - now, 1, "room for the last line")
	lines.append("y".repeat(total - now - 1))


## The slab the trim drops from a file of [param total] bytes.
func _drop(total: int) -> int:
	return total - (DuelLogFile.CAP - DuelLogFile.SLACK)


func _banner(seed_value: int) -> PackedStringArray:
	return DuelLogFile.banner(PackedStringArray(["A", "B"]), seed_value)


## The reviewer's case through the public door: one long duel (~600 KB),
## then the next one's banner and ~410 KB of it; the line that takes the
## log past the cap trims it.
func test_a_long_previous_duel_keeps_its_tail() -> void:
	var lines := PackedStringArray()
	lines.append_array(_banner(1))
	_fill(lines, 6000)
	lines.append_array(_banner(2))
	_fill(lines, 4100)
	_store(lines)
	assert_gt(_read().to_utf8_buffer().size(), DuelLogFile.CAP, "control: past the cap")
	var log := DuelLogFile.new()
	for i in 20:
		log.write("line %d" % i, {})
	var kept := _read()
	var size := kept.to_utf8_buffer().size()
	assert_lte(size, DuelLogFile.CAP, "under the cap")
	assert_gte(size, DuelLogFile.CAP - DuelLogFile.SLACK - 200, "only the slab went: kept %d" % size)
	assert_true(kept.contains("(seed 2)"), "the new duel's banner kept")
	assert_eq(kept.split("\n")[0], _filler, "the cut lands on a line, inside the long duel")


## A banner just beyond the slab is not taken.
func test_a_banner_past_the_slab_is_not_taken() -> void:
	var total := 1_100_000
	var lines := PackedStringArray()
	_fill(lines, int((_drop(total) + DuelLogFile.SLACK + 5_000) / 100.0))
	lines.append_array(_banner(7))
	_pad_to(lines, total)
	_store(lines)
	DuelLogFile.new()._trim(DuelLogFile.path())
	var kept := _read()
	var size := kept.to_utf8_buffer().size()
	assert_gte(size, DuelLogFile.CAP - DuelLogFile.SLACK - 200, "the slab alone went: kept %d" % size)
	assert_true(kept.contains("(seed 7)"))
	assert_eq(kept.split("\n")[0], _filler, "cut on a line")


## A banner inside the slab still opens the file (the cap's design).
func test_a_banner_inside_the_slab_is_still_taken() -> void:
	var total := 1_100_000
	var lines := PackedStringArray()
	_fill(lines, int((_drop(total) + 30_000) / 100.0))
	lines.append_array(_banner(8))
	_pad_to(lines, total)
	_store(lines)
	DuelLogFile.new()._trim(DuelLogFile.path())
	var kept := _read()
	assert_lte(kept.to_utf8_buffer().size(), DuelLogFile.CAP)
	assert_eq(kept.split("\n")[0], DuelLogFile.RULE, "the file opens on the banner's rule")
	assert_true(kept.split("\n")[1].contains("(seed 8)"))


## The cut falling INSIDE a banner (between its opening rule and its
## `GAME at` line) opens the file on that banner, not on half of it.
func test_a_banner_the_cut_splits_is_taken_whole() -> void:
	var lines := PackedStringArray()
	_fill(lines, 1000)
	var before_rule := 1000 * 100 + 1      # the filler and the banner's blank line
	lines.append_array(_banner(9))
	_fill(lines, 2000)
	# The slab to drop ends one byte into the banner's opening rule.
	var total := before_rule + 1 + (DuelLogFile.CAP - DuelLogFile.SLACK)
	_pad_to(lines, total)
	_store(lines)
	assert_eq(_drop(total), before_rule + 1, "control: the cut lands on the GAME line")
	DuelLogFile.new()._trim(DuelLogFile.path())
	var kept := _read()
	assert_lte(kept.to_utf8_buffer().size(), DuelLogFile.CAP)
	assert_eq(kept.split("\n")[0], DuelLogFile.RULE, "the banner's rule")
	assert_true(kept.split("\n")[1].contains("(seed 9)"), "and its GAME line")
