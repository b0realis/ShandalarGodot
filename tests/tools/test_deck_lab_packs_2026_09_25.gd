extends GutTest
## `--packs` (2026-09-25): the Deck Lab plays with the card packs it is
## told to — every one found, none, or a list — for the one run, workers
## included, without touching the player's own setting. Until this
## switch the stock Lab could only play the base cards: 71 of the 76
## tournament decks under `decks/tournament/` were "proxies" to it, and
## a run over the pack cards meant one of the isolated
## `tools/pack_N_deck_lab.gd` entry points under the test profile.
##
## The pack tests below run only where a pack is found (the checkout's
## sibling `shandalar-packs/`, never a runner) and put the player's
## setting and the registry back as they found them. The last section
## is the rest of the same day's code pass over the Lab.

const ICE_AGE := "pack-3"
const ICE_AGE_CARD := "Zuran Orb"
const BASE := ["--deck-a", "white_knights.deck", "--deck-b", "big_green.deck"]

var _before: Array[String] = []
var _had_value := false


func before_each() -> void:
	_had_value = Settings.has_value("enabled_card_packs")
	_before = Settings.enabled_card_packs()


func after_each() -> void:
	# Back to the setting this suite started from — in memory, the way
	# the Lab changed it, and the registry reconfigured from it.
	if _had_value:
		Settings.set_value("enabled_card_packs", _before, false)
	elif Settings.has_value("enabled_card_packs"):
		Settings.set_value("enabled_card_packs", [] as Array[String], false)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


func _lab():
	return autofree(load("res://DeckLab/simulate.gd").new())


func _parse(args: Array) -> Dictionary:
	return _lab()._parse_args(PackedStringArray(args))


func _ice_age_here() -> bool:
	if CardPacks.has_pack(ICE_AGE):
		return true
	pass_test("no %s here — the pack tests run where the pack zips are" % ICE_AGE)
	return false


# ----------------------------------------------------------- parse_packs --

func test_all_is_every_pack_found_and_none_is_the_base_cards() -> void:
	var lab = _lab()
	assert_eq(lab.parse_packs("all", ["pack-1", "pack-3"]), {"ids": ["pack-1", "pack-3"]})
	assert_eq(lab.parse_packs(" ALL ", ["pack-7"]), {"ids": ["pack-7"]}, "case and spacing forgiven")
	assert_eq(lab.parse_packs("all", []), {"ids": []}, "every pack found: none found")
	assert_eq(lab.parse_packs("none", ["pack-1", "pack-3"]), {"ids": []})
	assert_eq(lab.parse_packs("None", ["pack-1"]), {"ids": []})


func test_a_list_names_packs_by_id_or_bare_number_once_each() -> void:
	var lab = _lab()
	var every := CardPacks.known_ids()
	assert_eq(lab.parse_packs("pack-3,pack-7", every), {"ids": ["pack-3", "pack-7"]})
	assert_eq(lab.parse_packs("3,7", every), {"ids": ["pack-3", "pack-7"]}, "the bare number is the id")
	assert_eq(lab.parse_packs("7, pack-3 ,7", every), {"ids": ["pack-7", "pack-3"]},
		"spaces forgiven, a pack named twice is one pack, the order is the list's")
	assert_eq(lab.parse_packs("PACK-2", every), {"ids": ["pack-2"]})


func test_a_word_that_is_no_pack_is_refused_in_the_switchs_own_terms() -> void:
	var lab = _lab()
	var every := CardPacks.known_ids()
	for bad in ["foo", "pack-x", "pack-0", "0", "-3", "pack-", "3,zz", "all,none"]:
		var read: Dictionary = lab.parse_packs(bad, every)
		assert_true(read.has("error"), bad)
		assert_string_contains(str(read.get("error", "")), "--packs takes all, none or pack ids like pack-3,pack-7", bad)
	assert_string_contains(str(lab.parse_packs("3,zz", every).error), "not 'zz'",
		"the offending token, not the whole list")


func test_a_pack_this_build_does_not_know_is_refused_by_name() -> void:
	var read: Dictionary = _lab().parse_packs("pack-9", CardPacks.known_ids())
	assert_string_contains(str(read.get("error", "")), "pack-9 is not a pack this build knows")
	assert_string_contains(str(read.get("error", "")), ", ".join(PackedStringArray(CardPacks.known_ids())))
	assert_eq(CardPacks.known_ids(), ["pack-1", "pack-2", "pack-3", "pack-4", "pack-5", "pack-6", "pack-7"] as Array[String])


func test_a_known_pack_that_was_not_found_says_where_it_looked() -> void:
	# The id is one the build knows; the zip is not where the game looks
	# for it. The refusal names the file and every folder tried, so the
	# fix — put the zip there, or SHANDALAR_PACK_7=path — is in the text.
	var read: Dictionary = _lab().parse_packs("pack-7", ["pack-3"])
	var error := str(read.get("error", ""))
	assert_string_contains(error, "pack-7 was not found — looked for %s at: " % CardPacks.file_name_for("pack-7"))
	for path in CardPacks.candidate_paths("pack-7"):
		assert_string_contains(error, ProjectSettings.globalize_path(String(path)))
	assert_eq(_lab().parse_packs("pack-3", ["pack-3"]), {"ids": ["pack-3"]}, "the one that was found is fine")


# ---------------------------------------------------------------- parser --

func test_the_switch_is_parsed_documented_and_off_by_default() -> void:
	var lab = _lab()
	assert_null(_parse(BASE).get("packs", "unset"), "no switch: the game's own settings decide")
	assert_eq(_parse(BASE + ["--packs", "none"]).packs, [] as Array[String])
	var bad := _parse(BASE + ["--packs", "foo"])
	assert_string_contains(str(bad.get("error", "")), "--packs takes all, none")
	assert_string_contains(str(_parse(BASE + ["--packs"]).get("error", "")), "--packs needs a value")
	assert_true(lab.FLAG_HINTS.has("--packs"))
	assert_string_contains(lab.HELP, "--packs LIST")
	assert_string_contains(lab.HELP, "SHANDALAR_PACK_N")
	assert_string_contains(lab.HELP, "--group tournament --packs all --games 10 --no-elo")


func test_the_settings_line_names_the_packs_in_force() -> void:
	# A deck of Ice Age cards is not the same experiment as one without
	# them; the report says which it was. Silent without the switch, so
	# a default run's report reads as it always did.
	var lab = _lab()
	assert_eq(lab._settings_line(_parse(BASE)), "")
	assert_string_contains(lab._settings_line(_parse(BASE + ["--packs", "none"])), "packs none")
	var opts := _parse(BASE)
	opts.packs = ["pack-3", "pack-7"]
	assert_string_contains(lab._settings_line(opts), "packs pack-3, pack-7")


# ---------------------------------------------------------- enable_packs --

func test_enabling_a_pack_puts_its_cards_in_the_registry_in_memory_only() -> void:
	if not _ice_age_here():
		return
	var lab = _lab()
	var on_disk := FileAccess.get_file_as_string(Settings.PATH)
	assert_eq(lab.enable_packs([ICE_AGE]), "")
	assert_true(CardPacks.is_enabled(ICE_AGE))
	assert_true(CardRegistry.has_card(ICE_AGE_CARD), "%s is a card now" % ICE_AGE_CARD)
	assert_eq(Settings.enabled_card_packs(), [ICE_AGE] as Array[String])
	assert_eq(FileAccess.get_file_as_string(Settings.PATH), on_disk,
		"the player's settings file is untouched")
	assert_eq(lab.enable_packs([]), "", "none: the base cards alone")
	assert_false(CardPacks.is_enabled(ICE_AGE))
	assert_false(CardRegistry.has_card(ICE_AGE_CARD))
	assert_true(CardRegistry.has_card("Lightning Bolt"))
	assert_eq(FileAccess.get_file_as_string(Settings.PATH), on_disk)


func test_a_pack_that_cannot_be_enabled_is_a_refusal_not_a_silent_base_run() -> void:
	var lab = _lab()
	var refusal: String = lab.enable_packs(["pack-9"])
	assert_string_contains(refusal, "could not enable pack-9")
	assert_false(CardPacks.is_enabled("pack-9"))


# --------------------------------------------------------------- workers --

func test_the_packs_in_force_ride_the_worker_payload_and_the_worker_applies_them() -> void:
	# A child process is a fresh engine with the base cards; the parent's
	# `--packs` reaches it through the payload, before its slice.
	var lab = _lab()
	assert_false(lab._worker_payload(0, 0).has("packs"), "no switch: nothing on the wire")
	lab._packs_in_force = [ICE_AGE] as Array[String]
	var payload: Dictionary = JSON.parse_string(JSON.stringify(lab._worker_payload(0, 0)))
	assert_eq(Array(payload.packs), [ICE_AGE])
	if not _ice_age_here():
		return
	var in_path := "user://deck_lab_packs_%d.json" % Time.get_ticks_usec()
	var out_path := in_path + ".out"
	assert_true(lab._write(in_path, JSON.stringify(payload)))
	assert_eq(lab._run_worker(in_path, out_path), 0)
	assert_true(CardRegistry.has_card(ICE_AGE_CARD), "the worker put the pack on")
	payload.packs = ["pack-9"]
	assert_true(lab._write(in_path, JSON.stringify(payload)))
	assert_eq(lab._run_worker(in_path, out_path), 1, "a pack the worker cannot enable fails its slice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(in_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))


# ------------------------------------------------------------------ _main --

func test_a_run_over_ice_age_cards_plays_with_the_pack_and_refuses_without() -> void:
	if not _ice_age_here():
		return
	var lab = _lab()
	var deck := "user://deck_lab_ice_age_%d.deck" % Time.get_ticks_usec()
	var text := FileAccess.get_file_as_string("res://decks/mountain_artillery.deck")
	text = text.replace("1 Sol Ring\n", "1 %s\n" % ICE_AGE_CARD)
	assert_true(lab._write(deck, text))
	var out := "user://deck_lab_packs_run_%d" % Time.get_ticks_usec()
	var args := ["--deck-a", deck, "--deck-b", "big_green.deck", "--games", "1",
		"--procs", "1", "--jobs", "1", "--no-elo", "--quiet", "--out", out]
	assert_eq(lab._main(PackedStringArray(args + ["--packs", "none"])), 2,
		"without the pack the deck is a proxy deck and the run is refused")
	assert_eq(lab._main(PackedStringArray(args + ["--packs", "3"])), 0)
	assert_eq(lab._packs_in_force, [ICE_AGE] as Array[String])
	var report := FileAccess.get_file_as_string(out + "/report.txt")
	assert_string_contains(report, "settings: packs pack-3")
	assert_string_contains(report, "Mountain Artillery       vs Big Green")
	assert_string_contains(report, "(0-1, 0 stalled)", "one game, played")
	var results: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out + "/results.json"))
	assert_eq(Array(results.packs), [ICE_AGE], "results.json records the packs too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(deck))


# ------------------------------------------------------- the code pass --

func test_an_empty_folder_refusal_names_the_decks_one_folder_down() -> void:
	# `--gauntlet decks/1997/` found nothing — the 157 decks are in its
	# subfolders, which a DIR is walked into only with --group — and
	# said so without a word about them.
	var lab = _lab()
	var note: String = lab._subfolders_note("decks/1997/")
	assert_string_contains(note, "its subfolders hold 157 deck files")
	assert_string_contains(note, "--group NAME")
	assert_eq(lab._subfolders_note("res://decks/1997"), note, "either spelling of the folder")
	assert_eq(lab._subfolders_note("decks/tournament/"), "", "no subfolders: nothing to say")
	assert_eq(lab._subfolders_note("decks/no_such_folder/"), "", "no folder: nothing to say")
	assert_eq(lab._subfolders_note("decks/big_green.deck"), "", "a file: nothing to say")
	lab._group_filter = "originals"
	assert_eq(lab._subfolders_note("decks/1997/"), "", "with --group the walk happened")
	for args in [["--deck-a", "big_green.deck", "--gauntlet", "decks/1997/"],
			["--matrix", "decks/1997/"]]:
		var read := _parse(args)
		assert_string_contains(str(read.get("error", "")), "decks/1997/' — its subfolders hold 157 deck files", str(args))
	assert_eq(_parse(["--deck-a", "big_green.deck", "--gauntlet", "decks/1997/", "--group", "originals"]).get("error", ""), "",
		"with --group the folder is walked and the field is found")


# ------------------------------------------------- the AutoDeck CLI's --

## The same switch on the Lab's feeder (DeckLab/auto_deck_cli.gd), read
## by the Lab's own code: a field mined from a pack is played with the
## same word.
func _cli():
	return autofree(load("res://DeckLab/auto_deck_cli.gd").new())


func test_the_autodeck_cli_takes_the_labs_packs_switch() -> void:
	var cli = _cli()
	assert_eq(cli.parse_args(PackedStringArray(["--out", "x"])).packs, null, "off by default")
	assert_eq(cli.parse_args(PackedStringArray(["--out", "x", "--packs", "3,7"])).packs, "3,7",
		"kept as typed — read against this machine's packs in _main")
	assert_string_contains(str(cli.parse_args(PackedStringArray(["--out", "x", "--packs"])).error),
		"--packs needs a value")
	assert_true(cli.FLAG_HINTS.has("--packs"))
	assert_string_contains(String(cli.HELP), "--packs LIST")
	assert_string_contains(String(cli.HELP), "--packs 3 --sets ice")
	var bad: int = cli._main(PackedStringArray(["--out", "user://never_written", "--packs", "pack-x", "--quiet"]))
	assert_eq(bad, 2, "a word that is no pack is exit 2 before anything is written")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://never_written")))
	assert_eq(cli._main(PackedStringArray(["--out", "user://never_written", "--packs", "pack-9", "--quiet"])), 2,
		"a pack this build does not know, likewise")


func test_the_autodeck_cli_mines_a_pack_with_the_switch_and_refuses_without() -> void:
	if not _ice_age_here():
		return
	var cli = _cli()
	var out := "user://auto_deck_packs_%d" % Time.get_ticks_usec()
	var args := ["--out", out, "--count", "2", "--seed", "4242", "--sets", "ice", "--quiet"]
	# Without the pack, Ice Age is not a set the registry has — the
	# refusal is the CLI's own for a set code it does not know.
	assert_eq(cli._main(PackedStringArray(args + ["--packs", "none"])), 2)
	assert_eq(cli._main(PackedStringArray(args + ["--packs", "3", "--force"])), 0)
	assert_eq(cli._packs_in_force, [ICE_AGE] as Array[String])
	var rows: PackedStringArray = FileAccess.get_file_as_string(out + "/decks.csv").strip_edges().split("\n")
	assert_eq(rows.size(), 3, "a header and two rows")
	assert_string_contains(rows[1], ",sets,ice,", "the row names the set")
	var listed: PackedStringArray = FileAccess.get_file_as_string(out + "/decklist.txt").strip_edges().split("\n")
	assert_eq(listed.size(), 2)
	var deck := DeckList.load_file(ProjectSettings.globalize_path(listed[0]))
	assert_eq(deck.errors, [] as Array[String], "the deck loads with the pack in force")
	var ice_age_cards := 0
	for name in deck.cards:
		if CardRegistry.card_in_set(String(name), "ice", true, true):
			ice_age_cards += 1
	assert_gt(ice_age_cards, 5, "built from Ice Age: %s" % [deck.cards])
	var dir := DirAccess.open(out)
	dir.include_hidden = true
	for name in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out))
