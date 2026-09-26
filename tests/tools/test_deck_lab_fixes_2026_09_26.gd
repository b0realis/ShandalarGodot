extends GutTest
## The Deck Lab's bug pass of 2026-09-26 — one pass over
## DeckLab/simulate.gd and its neighbours for the things the manual
## promised and the code did not keep. Each test names the bug it pins:
##
##   * a `--profile-a wizard:counter_threshold=abc` swept 0, silently;
##   * a worker whose parent was killed played on for hours;
##   * a comma-list or FILE.txt gauntlet kept deck A (the mirror match the
##     manual warns about), where a folder dropped it;
##   * a field that named a deck twice ranked it twice;
##   * `--top 10` was refused nowhere and `--top` was refused by value;
##   * a `--gauntlet` of one deck was reported as a duel;
##   * `--out` naming a FILE was accepted and failed after the games;
##   * the abandon line named "game 1" after a relaunch cleared the beat;
##   * a gauntlet deck that played nobody had a 50% row over no games,
##     and the reading counted games a mirror never played;
##   * `median 12.0` after a results.json round trip; a ledger whose
##     equal ratings changed places; a chart label that ran under the
##     bars; a `res://` output folder that got no `.gdignore`; the pack
##     scan on the report's stdout.

var _made: Array[String] = []
var _before: Array[String] = []
var _had_value := false


func before_each() -> void:
	_had_value = Settings.has_value("enabled_card_packs")
	_before = Settings.enabled_card_packs()


func after_each() -> void:
	for path in _made:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			var dir := DirAccess.open(absolute)
			dir.include_hidden = true
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(absolute)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	_made.clear()
	if _had_value:
		Settings.set_value("enabled_card_packs", _before, false)
	elif Settings.has_value("enabled_card_packs"):
		Settings.set_value("enabled_card_packs", [] as Array[String], false)


func _lab():
	return autofree(load("res://DeckLab/simulate.gd").new())


func _parse(args: Array) -> Dictionary:
	return _lab()._parse_args(PackedStringArray(args))


func _scratch(kind: String) -> String:
	var path := "user://deck_lab_fixes_%s_%d_%d" % [kind, Time.get_ticks_usec(), _made.size()]
	_made.append(path)
	return path


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f, "can write " + path)
	f.store_string(text)
	f.close()


const DUEL := ["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"]


# ----------------------------------------------------------- profiles --

func test_a_profile_knob_value_the_knob_cannot_read_is_refused() -> void:
	# `apply_overrides` read `counter_threshold=abc` as 0 and
	# `pays_sacrifices=maybe` as off, and the settings line printed the
	# typo as the knob's value. The profile spec is now checked the way
	# `--sweep` checks its values: by the knob's type, before a game.
	assert_string_contains(str(_parse(DUEL + ["--profile-a", "wizard:counter_threshold=abc"]).error),
		"'abc' is not a number (the knob counter_threshold takes one)")
	assert_string_contains(str(_parse(DUEL + ["--profile-b", "wizard:pays_sacrifices=maybe"]).error),
		"'maybe' is not a boolean")
	assert_string_contains(str(_parse(DUEL + ["--profile-a", "wizard:no_such_knob=1"]).error),
		"unknown knob 'no_such_knob'")
	assert_string_contains(str(_parse(DUEL + ["--profile-a", "wizard:pays_sacrifices"]).error),
		"KNOB=VALUE")
	var good := _parse(DUEL + ["--profile-a", "wizard:pays_sacrifices=off,counter_threshold=4"])
	assert_false(good.has("error"), str(good.get("error", "")))
	assert_eq(good.profile_a, "wizard:pays_sacrifices=off,counter_threshold=4")
	assert_string_contains(str(_parse(DUEL + ["--profile-a", "wizard:chump_threshold=1.5"]).error),
		"'1.5' is not a whole number", "an integer knob takes no fraction")
	# And the profile itself refuses rather than reads a typo — the part
	# it could not read is the one returned, as an unknown knob's name is.
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("counter_threshold=abc"), "counter_threshold=abc")
	assert_eq(profile.apply_overrides("pays_sacrifices=maybe"), "pays_sacrifices=maybe")
	assert_eq(profile.apply_overrides("pays_sacrifices=off,counter_threshold=4"), "")
	assert_false(profile.pays_sacrifices)
	assert_eq(profile.counter_threshold, 4.0)
	assert_eq(profile.apply_overrides("pays_sacrifices=TRUE"), "", "the spellings the sweep takes")
	assert_true(profile.pays_sacrifices)


# ------------------------------------------------------------- workers --

func test_a_worker_whose_parent_is_gone_stops_without_an_answer() -> void:
	# Ctrl-C on the driver killed the parent; its eight children played
	# on. The parent's pid rides the payload and a child that finds it
	# gone leaves before the next game, without writing.
	var lab = _lab()
	var payload: Dictionary = lab._worker_payload(0, 0)
	assert_eq(int(payload.parent), OS.get_process_id(), "the payload names its parent")
	assert_true(lab._parent_alive(OS.get_process_id()), "this process is alive")
	assert_true(lab._parent_alive(0), "no parent named: nothing to watch")
	var gone := _dead_pid()
	assert_false(lab._parent_alive(gone), "a process that has exited is gone")
	# A slice whose parent is that dead process: the worker stops at once.
	var dir := ProjectSettings.globalize_path(_scratch("fan"))
	assert_eq(DirAccess.make_dir_recursive_absolute(dir), OK)
	var deck := DeckList.load_file("res://decks/mountain_artillery.deck")
	lab._duel_opts = {"fingerprint": true, "best_of": 0, "sideboard": false}
	lab._tasks.append({"pair": 0, "seed": 4242, "a_on_play": true,
		"deck_a": deck.cards, "deck_b": deck.cards,
		"sb_a": deck.sideboard, "sb_b": deck.sideboard,
		"profile_a": "wizard", "profile_b": "wizard"})
	payload = lab._worker_payload(0, 1)
	payload["parent"] = gone
	var in_path := dir.path_join("slice_0.json")
	var out_path := dir.path_join("done_0.json")
	_put(in_path, JSON.stringify(payload))
	var child = _lab()
	assert_eq(child._run_worker(in_path, out_path), 1, "the orphan stops")
	assert_false(FileAccess.file_exists(out_path), "and writes no answer")
	assert_false(FileAccess.file_exists(out_path + lab.SLICE_PART))


## The process id of a child of ours that has exited (the fan suite's
## own way of holding a dead pid without asking the engine about a
## made-up number).
func _dead_pid() -> int:
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--version"]))
	assert_gt(pid, 0, "a child to lose")
	var waited := 0
	while OS.is_process_running(pid) and waited < 20000:
		OS.delay_msec(50)
		waited += 50
	assert_false(OS.is_process_running(pid), "…and it has gone")
	return pid


func test_the_abandon_line_names_the_heartbeat_before_the_relaunch() -> void:
	# `_launch` clears the dead child's heartbeat before it starts the
	# next one; when that launch fails the abandon line used to read the
	# cleared file and name game 1. The count is taken first and handed in.
	var lab = _lab()
	for i in 4:
		lab._tasks.append({"pair": 0, "seed": 4242 + i})
	var slice := {"lo": 0, "hi": 4, "beat": "user://no_such_beat.txt", "attempts": 3}
	assert_string_contains(lab._abandon_message(0, slice, 2), "game 3 (pair 0, seed 4244)")
	assert_string_contains(lab._abandon_message(0, slice, 9), "game 4 (pair 0, seed 4245)",
		"a heartbeat past the end names the slice's last game")
	assert_string_contains(lab._abandon_message(0, slice), "game 1 (pair 0, seed 4242)",
		"no count handed in: the file, which is not there")


# -------------------------------------------------------- the gauntlet --

func test_a_listed_gauntlet_drops_deck_a_as_a_folder_does() -> void:
	# "deck A excluded" is `--gauntlet`'s promise; a comma list or a
	# FILE.txt that named it played the mirror match the manual warns
	# dilutes the record.
	var listed := _parse(["--deck-a", "big_green.deck",
		"--gauntlet", "big_green.deck,white_knights.deck"])
	assert_false(listed.has("error"), str(listed.get("error", "")))
	assert_eq(listed.opponents, ["white_knights.deck"])
	var file := _scratch("list") + ".txt"
	_put(file, "decks/big_green.deck\nwhite_knights.deck\n")
	var from_file := _parse(["--deck-a", "big_green.deck", "--gauntlet", file])
	assert_false(from_file.has("error"), str(from_file.get("error", "")))
	assert_eq(from_file.opponents.size(), 1, "by file name, as the folder walk drops it")
	assert_eq(String(from_file.opponents[0]).get_file(), "white_knights.deck")
	assert_string_contains(str(_parse(["--deck-a", "big_green.deck",
		"--gauntlet", "big_green.deck"]).error), "but deck A itself")
	# `--deck-b` is the way to ask for the mirror, and stays one.
	var mirror := _parse(["--deck-a", "big_green.deck", "--deck-b", "big_green.deck"])
	assert_eq(mirror.opponents, ["big_green.deck"])
	# A random deck A excludes nothing: there is no file to drop.
	var random := _parse(["--deck-a", "random", "--gauntlet", "big_green.deck,white_knights.deck"])
	assert_eq(random.opponents, ["big_green.deck", "white_knights.deck"])


func test_a_field_names_each_deck_once() -> void:
	# `--field decks/ --field decks/top.txt` ranked a deck twice, against
	# itself too in matchups.csv.
	var opts := _parse(["--field", "big_green.deck", "--field", "big_green.deck,blue_skies.deck",
		"--field", "decks/big_green.deck", "--deck-b", "white_knights.deck"])
	assert_false(opts.has("error"), str(opts.get("error", "")))
	assert_eq(opts.field.size(), 2, "the same file by its resolved path is one contestant")
	assert_eq(opts.field, ["big_green.deck", "blue_skies.deck"], "the first spelling kept")


func test_top_is_refused_outside_a_tournament_whatever_its_value() -> void:
	# `--top 10` outside a tournament was accepted because 10 is the
	# default; the switch is refused by its being given, not its value.
	assert_string_contains(str(_parse(DUEL + ["--top", "10"]).error),
		"--top only means something in tournament mode")
	assert_false(_parse(DUEL).has("error"))
	var t := _parse(["--field", "big_green.deck", "--deck-b", "white_knights.deck", "--top", "10"])
	assert_false(t.has("error"), str(t.get("error", "")))
	assert_true(bool(t.top_given))


func test_one_gauntlet_deck_is_a_gauntlet_and_a_mirror_plays_nobody() -> void:
	# Two runs of one game each. A `--gauntlet` folder holding one deck
	# used to write a duel's report; and a gauntlet deck that is also the
	# whole field had a row at 50% over no games.
	var lab = _lab()
	var out := _scratch("run")
	assert_eq(lab._main(PackedStringArray(["--deck-a", "big_green.deck",
		"--gauntlet", "white_knights.deck,big_green.deck", "--games", "1",
		"--procs", "1", "--jobs", "1", "--quiet", "--no-elo", "--no-svg", "--out", out])), 0)
	var results: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out + "/results.json"))
	assert_eq(results.mode, "gauntlet", "asked for a gauntlet: reported as one, at one opponent")
	assert_eq(results.matchups.size(), 1)
	var tournament = _lab()
	var out2 := _scratch("run")
	assert_eq(tournament._main(PackedStringArray(["--field", "big_green.deck",
		"--gauntlet", "big_green.deck,white_knights.deck", "--games", "1",
		"--procs", "1", "--jobs", "1", "--quiet", "--no-svg", "--out", out2])), 0)
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out2 + "/results.json"))
	assert_eq(t.mode, "tournament")
	assert_eq(t.gauntlet.size(), 1, "Big Green played nobody in the gauntlet: no row")
	assert_eq(t.gauntlet[0].deck, "White Knights")
	var report := FileAccess.get_file_as_string(out2 + "/report.txt")
	assert_string_contains(report, "a field deck's record is 1 games (2 opponents x 1 games, less the mirror)")


func test_the_reading_counts_the_games_a_field_deck_has() -> void:
	# The tournament suite's own fixture: two opponents, four games each,
	# and a record of eight — the mirror's absence is the only thing
	# that lowers it, never a short fixture.
	var lab = _lab()
	var decks: Array[DeckList] = []
	for name in ["Field One", "Gauntlet A", "Gauntlet B"]:
		var deck := DeckList.new()
		deck.deck_name = name
		decks.append(deck)
	var pairs := [[0, 2]]
	var records := [[{"stalled": false, "a_on_play": true, "a_won": true, "turns": 7}]]
	var stats := [SimStats.summarize(records[0])]
	var t: Dictionary = lab._tournament_tables(decks, 1, ["f1.deck"] as Array[String],
		pairs, records, stats, 10)
	var opts := _parse(["--field", "f1.deck", "--gauntlet", "a.deck,b.deck", "--games", "4"])
	var text := "\n".join(lab._tournament_block(opts, t, decks, 1, pairs, stats, "games"))
	assert_string_contains(text, "a field deck's record is 4 games (2 opponents x 4 games, less the mirror)")
	assert_eq(t.gauntlet.size(), 1, "the opponent that played nobody has no row")


# ---------------------------------------------------------------- --out --

func test_out_that_is_a_file_is_refused_before_the_games() -> void:
	var lab = _lab()
	var file := _scratch("file") + ".txt"
	_put(file, "not a folder")
	assert_eq(lab._main(PackedStringArray(DUEL + ["--games", "1", "--quiet", "--no-elo",
		"--out", file])), 1)
	assert_eq(FileAccess.get_file_as_string(file), "not a folder", "untouched")
	var opts := _parse(DUEL + ["--out", "results/run/"])
	assert_eq(opts.out, "results/run", "a trailing slash is dropped, not printed twice")
	assert_eq(_parse(DUEL + ["--out", "/"]).out, "/", "but the root is the root")


func test_the_importer_marker_lands_in_a_res_folder_too() -> void:
	# `DirAccess.open("res://x").get_current_dir()` says `res://x`, and the
	# comparison against the globalized project root missed every
	# `res://` output folder.
	var lab = _lab()
	var out := "res://DeckLab/results/deck_lab_fixes_test_%d" % Time.get_ticks_usec()
	_made.append(out)
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)), OK)
	lab._keep_the_importer_out(out)
	assert_true(FileAccess.file_exists(out.path_join(".gdignore")))
	var outside := _scratch("outside")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(outside)), OK)
	lab._keep_the_importer_out(outside)
	assert_false(FileAccess.file_exists(outside.path_join(".gdignore")), "user:// is outside the project")


# ---------------------------------------------------------- neighbours --

func test_the_median_is_a_whole_number_after_a_json_round_trip() -> void:
	var records: Array = JSON.parse_string(JSON.stringify([
		{"stalled": false, "a_on_play": true, "a_won": true, "turns": 12},
		{"stalled": false, "a_on_play": false, "a_won": false, "turns": 9},
		{"stalled": false, "a_on_play": true, "a_won": true, "turns": 15}]))
	var s := SimStats.summarize(records)
	assert_eq(typeof(s.median_turns), TYPE_INT, "an int, not the 12.0 JSON gave back")
	assert_eq(s.median_turns, 12)
	assert_eq("median %d" % s.median_turns, "median 12")


func test_the_ledger_orders_equal_ratings_by_name() -> void:
	var path := _scratch("ledger") + ".txt"
	var ledger := EloLedger.new()
	ledger.path = path
	for name in ["Zebra", "Apple", "Mango"]:
		ledger._entry(name)
	assert_true(ledger.save())
	var lines := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		if not line.begins_with("#"):
			lines.append(line.get_slice("|", 0).strip_edges())
	assert_eq(lines, PackedStringArray(["Apple", "Mango", "Zebra"]),
		"three decks at 1500: the name decides, so a diff shows ratings that moved")


func test_a_chart_label_is_cut_to_its_column() -> void:
	var long := "A Very Long Tournament Deck Title From The Library Of 1995"
	var cut := SvgCharts.label_fit(long)
	assert_eq(cut.length(), SvgCharts.LABEL_CHARS)
	assert_true(cut.ends_with("…"), "the cut is marked")
	assert_eq(SvgCharts.label_fit("Big Green"), "Big Green")
	var stats := SimStats.summarize([{"stalled": false, "a_on_play": true, "a_won": true, "turns": 8}])
	var svg := SvgCharts.winrate_chart("Deck A", [{"label": long, "stats": stats}])
	assert_true(svg.contains(cut.xml_escape()), "the chart holds the cut label")
	assert_false(svg.contains(long), "and not the one that ran under the bars")


func test_the_pack_scan_talks_on_stderr() -> void:
	# The Lab's stdout is its report and nothing else (the manual's
	# promise); the CardPacks autoload's "found" line went there first.
	var source := FileAccess.get_file_as_string("res://game/card_packs.gd")
	assert_true(source.contains('printerr("card pack: found %s" % path)'))
	assert_false(source.contains('print("card pack: found'))


func test_the_quiet_and_out_hints_say_what_they_do() -> void:
	# `--quiet` was "errors only" in two tools whose report prints under it.
	var lab = _lab()
	assert_string_contains(String(lab.TOGGLE_HINTS["--quiet"]), "the report still prints")
	assert_false(String(lab.TOGGLE_HINTS["--quiet"]).contains("errors only"))
	assert_string_contains(String(lab.FLAG_HINTS["--out"]), "under the project root")
	assert_string_contains(lab.HELP, "the report still prints")
