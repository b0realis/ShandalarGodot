extends GutTest
## THE AUTODECK CLI — DeckLab/auto_deck_cli.gd: the AutoDeck window's own
## builder on the command line, by the thousand, for the Deck Lab to mine.
## These pin the three things a mining run depends on, and nothing about
## whether a deck is any good:
##
##   * THE PARSER, every switch and every refusal, including the exit code
##     the shell sees. The parser is `static` and reads no file, so all of
##     it is held here without starting a process — the same way
##     tests/tools/test_deck_lab_sweep.gd holds the Lab's own.
##   * THE WALK AND THE SEEDS — the cartesian odometer, its cycling, and
##     THE PROMISE the tool makes in its --help: any deck it made can be
##     built again in the AutoDeck window from that deck's seed and its
##     row of `decks.csv`. That promise is tested the way a player would
##     keep it: read the row back, set an [AutoDeck] up from it, build,
##     and compare the deck card for card with the file on disk.
##   * THE OUTPUT — the manifest's columns, the deck list's order, the
##     file names, and the refusal to write into a folder that already
##     holds something.
##
## Everything a test writes goes under `user://`, which run_tests.sh
## points at SHANDALAR_TEST_DATA_HOME, and is removed again in
## [method after_each] — including the one case that has to write inside
## the project, where the hidden `.gdignore` is removed by name.

## The tool, instantiated but never started: a `-s` SceneTree script's
## `_initialize` runs only when Godot is told to run it as one, so `new()`
## gives a plain object whose statics and `_main` a test can call.
var cli: Object = null
## Every folder a test made, removed in [method after_each].
var _made: Array[String] = []


func before_each() -> void:
	cli = autofree(load("res://DeckLab/auto_deck_cli.gd").new())
	_made.clear()


func after_each() -> void:
	for path in _made:
		var dir := DirAccess.open(path)
		if dir != null:
			# `.gdignore` is hidden, and a folder with a file left in it
			# cannot be removed — which would leave a stray directory in
			# the checkout for the one test that writes inside it.
			dir.include_hidden = true
			for name in dir.get_files():
				dir.remove(name)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made.clear()


func _parse(args: Array) -> Dictionary:
	return cli.parse_args(PackedStringArray(args))


## One run of the tool, in process. Returns the exit code the shell sees.
func _run(args: Array) -> int:
	return cli._main(PackedStringArray(args + ["--quiet"]))


## A fresh output folder nothing else is using.
func _out_dir() -> String:
	var path := "user://auto_deck_cli_test_%d_%d" % [Time.get_ticks_usec(),
		_made.size()]
	_made.append(path)
	return path


## The manifest as rows of fields. A NAIVE SPLIT ON COMMAS, deliberately:
## the one test about quoting says so out loud, and every other test here
## uses a pool whose label has no comma in it.
func _rows_of(path: String) -> Array:
	var rows: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		rows.append(Array(line.split(",")))
	return rows


## One manifest row as `column -> value`.
func _cells(header: Array, row: Array) -> Dictionary:
	var out := {}
	for i in header.size():
		out[String(header[i])] = String(row[i]) if i < row.size() else ""
	return out


## A deck's cards as one comparable string — `2 Forest|4 Shock`, by name.
## Two DeckModels are compared through this rather than through their
## `counts` dictionaries, so the comparison cannot depend on how the
## engine happens to compare a Dictionary.
static func _cards_of(model: DeckModel) -> String:
	var names: Array = model.counts.keys()
	names.sort()
	var parts := PackedStringArray()
	for name in names:
		parts.append("%d %s" % [int(model.counts[name]), String(name)])
	return "|".join(parts)


# ------------------------------------------------------------ the parser --

func test_the_defaults_are_the_autodeck_windows_own() -> void:
	# THE RULE THIS FILE EXISTS FOR: the CLI invents nothing. Every wish
	# defaults to the value AutoDeckWindow.DEFAULTS holds, so a deck built
	# with no switches is the deck the window's first visit builds.
	var opts := _parse(["--out", "x"])
	var window: Dictionary = AutoDeckWindow.DEFAULTS
	assert_eq(opts.source, String(window["source"]), "source")
	assert_eq(opts["sets"], [window["sets"]], "the same one set, as one pool")
	assert_eq(opts["max_colors"], [int(window["max_colors"])], "max_colors")
	assert_eq(opts["gold"], [bool(window["gold"])], "gold")
	assert_eq(opts["size"], [int(window["size"])], "size")
	assert_eq(opts["lean"], [String(window["lean"])], "lean")
	assert_eq(opts["speed"], [String(window["speed"])], "speed")
	assert_eq(opts["rarity"], [String(window["rarity"])], "rarity")
	assert_eq(opts["lands"], [String(window["lands"])], "lands")
	assert_eq(opts["tournament"], [bool(window["tournament"])], "tournament")
	assert_eq(opts["power_nine"], [bool(window["power_nine"])], "power_nine")
	# The window's blank colors are 0; the CLI's word for them is `none`.
	assert_eq(opts["colors"], [cli.COLORS_NONE])
	assert_eq(cli.asked_colors(cli.COLORS_NONE, 1, 2, false),
		int(window["colors"]), "`none` is the window's 0")
	# The seed range is the window's, to the number.
	assert_eq(cli.SEED_MOST, AutoDeckWindow.SEED_MOST)


func test_every_flag_parses_to_the_builders_own_values() -> void:
	var opts := _parse(["--out", "x", "--count", "7", "--seed", "4242",
		"--source", "sets", "--sets", "4ed,drk", "--colors", "WU",
		"--max-colors", "3", "--gold", "on", "--size", "40",
		"--lean", "creatures", "--speed", "fast", "--rarity", "uncommon-up",
		"--lands", "non-classic", "--tournament", "off", "--power-nine", "on",
		"--original-cards", "off", "--completion-pack", "off",
		"--boosters", "6", "--starters", "2", "--free-lands", "3",
		"--extras", "5", "--progress", "log", "--force"])
	assert_false(opts.has("error"), str(opts.get("error", "")))
	assert_eq(opts.count, 7)
	assert_eq(opts.seed, 4242)
	assert_eq(opts["sets"], [["4ed", "drk"]], "a comma joins sets into ONE pool")
	assert_eq(opts["colors"], [Mtg.ManaColor.W | Mtg.ManaColor.U])
	assert_eq(opts["max_colors"], [3])
	assert_eq(opts["gold"], [true])
	assert_eq(opts["size"], [40])
	assert_eq(opts["lean"], [AutoDeck.LEAN_CREATURES])
	assert_eq(opts["speed"], [AutoDeck.SPEED_FAST])
	assert_eq(opts["rarity"], [AutoDeck.RARITY_UNCOMMON_UP],
		"the short spelling maps to AutoDeck's own constant")
	assert_eq(opts["lands"], [AutoDeck.LANDS_NONCLASSIC])
	assert_eq(opts["tournament"], [false])
	assert_eq(opts["power_nine"], [true])
	assert_false(opts.original_cards)
	assert_false(opts.completion_pack)
	assert_eq(opts.boosters, 6)
	assert_eq(opts.starters, 2)
	assert_eq(opts.free_lands, 3)
	assert_eq(opts.extras, 5)
	assert_eq(opts.progress, "log")
	assert_true(opts.force)


func test_every_value_the_cli_offers_is_one_the_builder_knows() -> void:
	# A value AutoDeck does not know is silently corrected by
	# `AutoDeck.build` (to `any`, to `classic`), so a typo in the CLI's own
	# table would be a run that quietly built something else.
	var rarities := PackedStringArray()
	for word in cli.RARITY_FLAGS:
		rarities.append(String(cli.RARITY_FLAGS[word]))
		assert_eq(_parse(["--out", "x", "--rarity", String(word)])["rarity"],
			[String(cli.RARITY_FLAGS[word])], "--rarity %s" % word)
	for rarity in rarities:
		assert_true(AutoDeck.RARITIES.has(rarity), "%s is AutoDeck's own" % rarity)
	for word in cli.LANDS_FLAGS:
		assert_true(AutoDeck.LAND_KINDS.has(String(cli.LANDS_FLAGS[word])),
			"--lands %s" % word)
	for lean in AutoDeck.LEANS:
		assert_eq(_parse(["--out", "x", "--lean", lean])["lean"], [lean])
	for speed in AutoDeck.SPEEDS:
		assert_eq(_parse(["--out", "x", "--speed", speed])["speed"], [speed])
	for size in AutoDeck.SIZES:
		assert_eq(_parse(["--out", "x", "--size", str(size)])["size"], [size])


func test_the_bare_boolean_toggles_are_the_same_as_on() -> void:
	# `--gold` and `--gold on` must mean one thing, and the look-ahead
	# that decides which must not eat the NEXT flag.
	assert_eq(_parse(["--out", "x", "--gold"])["gold"], [true])
	assert_eq(_parse(["--out", "x", "--gold", "on"])["gold"], [true])
	assert_eq(_parse(["--out", "x", "--power-nine"])["power_nine"], [true])
	assert_eq(_parse(["--out", "x", "--no-tournament"])["tournament"], [false])
	assert_eq(_parse(["--out", "x", "--tournament", "off"])["tournament"], [false])
	# The flag after a bare toggle is still read as a flag.
	var both := _parse(["--out", "x", "--gold", "--size", "40"])
	assert_false(both.has("error"), str(both.get("error", "")))
	assert_eq(both["gold"], [true])
	assert_eq(both["size"], [40])
	# And a boolean axis still takes a list.
	assert_eq(_parse(["--out", "x", "--gold", "on,off"])["gold"], [true, false])


func test_the_refusals_name_the_flag_and_what_it_takes() -> void:
	assert_string_contains(str(_parse([]).error), "--out DIR is required")
	assert_string_contains(str(_parse(["--out"]).error), "--out needs a value")
	assert_string_contains(str(_parse(["--out", "x", "--count", "0"]).error),
		"--count must be >= 1")
	assert_string_contains(str(_parse(["--out", "x", "--count", "many"]).error),
		"--count takes a whole number, not 'many'")
	assert_string_contains(str(_parse(["--out", "x", "--seed", "0"]).error),
		"--seed must be 1..999999")
	assert_string_contains(str(_parse(["--out", "x", "--seed", "1000000"]).error),
		"--seed must be 1..999999")
	assert_string_contains(str(_parse(["--out", "x", "--source", "dealt"]).error),
		"unknown source 'dealt'")
	assert_string_contains(str(_parse(["--out", "x", "--colors", "WX"]).error),
		"'WX' is not colors")
	assert_string_contains(str(_parse(["--out", "x", "--max-colors", "6"]).error),
		"--max-colors takes 1..5")
	assert_string_contains(str(_parse(["--out", "x", "--size", "50"]).error),
		"--size takes")
	assert_string_contains(str(_parse(["--out", "x", "--lean", "creature"]).error),
		"--lean takes")
	assert_string_contains(str(_parse(["--out", "x", "--speed", "quick"]).error),
		"--speed takes")
	assert_string_contains(str(_parse(["--out", "x", "--rarity", "commons"]).error),
		"--rarity takes")
	assert_string_contains(str(_parse(["--out", "x", "--lands", "duals"]).error),
		"--lands takes")
	assert_string_contains(str(_parse(["--out", "x", "--gold", "maybe"]).error),
		"--gold takes on or off")
	assert_string_contains(str(_parse(["--out", "x", "--original-cards", "yes"]).error),
		"--original-cards takes on or off")
	assert_string_contains(str(_parse(["--out", "x", "--boosters", "-1"]).error),
		"--boosters must be >= 0")
	assert_string_contains(str(_parse(["--out", "x", "--progress", "loud"]).error),
		"--progress takes one of")
	assert_string_contains(str(_parse(["--out", "x", "--sets", ","]).error),
		"--sets needs at least one set code")


func test_a_flag_that_would_be_ignored_is_refused_instead() -> void:
	# A flag that is silently ignored is a flag that lies about the run —
	# the Deck Lab's own rule for --null and the control decks.
	assert_string_contains(str(_parse(["--out", "x", "--list", "p.txt",
		"--source", "sets"]).error), "--list only means something with --source list")
	assert_string_contains(str(_parse(["--out", "x", "--source", "list"]).error),
		"--source list needs --list FILE")
	assert_string_contains(str(_parse(["--out", "x", "--source", "sealed",
		"--boosters", "0", "--starters", "0", "--free-lands", "0",
		"--extras", "0"]).error), "a sealed pool of no cards")
	# --list on its own selects the source it needs, so the common case
	# is not a refusal.
	assert_eq(_parse(["--out", "x", "--list", "p.txt"]).source, cli.SOURCE_LIST)


func test_a_mistyped_flag_names_the_one_that_was_meant() -> void:
	assert_string_contains(str(_parse(["--outt", "x"]).error),
		"unknown option '--outt' — did you mean --out?")
	assert_string_contains(str(_parse(["--colours", "WU"]).error), "--colors")
	assert_string_contains(str(_parse(["--wat"]).error), "unknown option '--wat'")


func test_a_bad_command_line_is_exit_2_and_help_is_exit_0() -> void:
	# Through `_main`, so these are the codes the shell sees.
	assert_eq(_run(["--lean", "creature", "--out", "x"]), 2)
	assert_eq(_run(["--nonsense"]), 2)
	assert_eq(_run([]), 2)
	assert_eq(_run(["--help"]), 0)
	assert_eq(_run(["-h"]), 0)


func test_every_flag_is_documented_and_the_tables_are_the_parsers_own() -> void:
	# The Deck Lab's own contract: a flag --help does not mention is a
	# flag nobody can use, and the two hint tables ARE the parser's list.
	var help: String = cli.HELP
	var asked := 0
	for flag in cli.FLAG_HINTS:
		assert_true(help.contains(String(flag)), "--help documents %s" % flag)
		assert_true(String(cli.FLAG_HINTS[flag]).begins_with(String(flag)),
			"the hint for %s starts by naming it" % flag)
		# A flag in BOTH tables is a boolean axis, and on its own it is the
		# bare toggle rather than a flag missing its value — so only the
		# others are held to "needs a value".
		if cli.TOGGLE_HINTS.has(flag):
			continue
		asked += 1
		var missing := _parse([String(flag)])
		assert_true(missing.has("error"), String(flag))
		assert_string_contains(str(missing.error), "needs a value")
	assert_gt(asked, 15, "most of the flags take a value, and say so")
	for flag in cli.TOGGLE_HINTS:
		assert_true(help.contains(String(flag)), "--help documents %s" % flag)


func test_the_sealed_defaults_in_the_hints_are_the_windows_numbers() -> void:
	# They are written into the hint text as words, because a `const`
	# initializer cannot format a string — so they are pinned here.
	assert_string_contains(String(cli.FLAG_HINTS["--boosters"]),
		"default %d" % SealedPool.DEFAULT_BOOSTERS)
	assert_string_contains(String(cli.FLAG_HINTS["--starters"]),
		"default %d" % SealedPool.DEFAULT_STARTERS)
	assert_string_contains(String(cli.FLAG_HINTS["--free-lands"]),
		"default %d" % SealedPool.DEFAULT_FREE_LANDS)
	assert_string_contains(String(cli.FLAG_HINTS["--extras"]),
		"default %d" % SealedPool.DEFAULT_EXTRAS)


func test_the_help_is_in_the_familys_voice_and_says_what_it_promises() -> void:
	var help: String = cli.HELP
	# American spelling, the family's rule for anything a reader sees.
	assert_false(help.to_lower().contains("colour"), "--help says color")
	assert_false(help.to_lower().contains("honour"), "--help says honor")
	# The promise the rest of this file tests is one a reader must be able
	# to find, so it is pinned to the manual too.
	assert_string_contains(help, "999999")
	assert_string_contains(help, str(cli.SEED_STRIDE))
	assert_string_contains(help, "AutoDeck window")
	assert_string_contains(help, cli.MANIFEST_NAME)
	assert_string_contains(help, cli.DECKLIST_NAME)
	assert_string_contains(help, "deck_lab.sh")


# ------------------------------------------------------------- the axes --

func test_one_alternative_each_is_one_combination() -> void:
	var opts := _parse(["--out", "x"])
	assert_eq(cli.combo_total(opts), 1)
	var wish: Dictionary = cli.combo_at(opts, 0)
	assert_eq(wish["lean"], AutoDeck.LEAN_BALANCED)
	assert_eq(cli.combo_at(opts, 9_999), wish, "one combination, for every deck")


func test_the_first_mention_replaces_the_default_and_a_later_one_adds() -> void:
	# `--lean spells` must MEAN spells, not "balanced or spells".
	assert_eq(_parse(["--out", "x", "--lean", "spells"])["lean"],
		[AutoDeck.LEAN_SPELLS])
	assert_eq(_parse(["--out", "x", "--lean", "spells", "--lean", "creatures"])["lean"],
		[AutoDeck.LEAN_SPELLS, AutoDeck.LEAN_CREATURES])
	# `--sets` is the flag where a comma joins rather than branches, so
	# repeating it is the only way to ask for two pools.
	assert_eq(_parse(["--out", "x", "--sets", "4ed,drk", "--sets", "2ed"])["sets"],
		[["4ed", "drk"], ["2ed"]])


func test_the_walk_is_the_cartesian_product_in_a_fixed_order() -> void:
	var opts := _parse(["--out", "x", "--lean", "creatures,spells",
		"--speed", "fast,slow"])
	assert_eq(cli.combo_total(opts), 4)
	# The LAST axis of AXES moves fastest, the way a number counts: speed
	# comes after lean, so the two speeds run inside each lean.
	var walked: Array = []
	for i in 4:
		var wish: Dictionary = cli.combo_at(opts, i)
		walked.append("%s/%s" % [wish["lean"], wish["speed"]])
	assert_eq(walked, ["creatures/fast", "creatures/slow",
		"spells/fast", "spells/slow"])


func test_the_walk_cycles_and_spreads_a_count_evenly() -> void:
	var opts := _parse(["--out", "x", "--lean", "creatures,balanced,spells",
		"--speed", "fast,medium,slow", "--size", "40,60"])
	assert_eq(cli.combo_total(opts), 18, "3 x 3 x 2")
	# Cycling: deck 18 is deck 0's combination again, and so on.
	var cycled := 0
	for i in 18:
		if cli.combo_at(opts, i + 18) == cli.combo_at(opts, i):
			cycled += 1
	assert_eq(cycled, 18, "every combination cycles back after 18 decks")
	# And 900 decks are 50 of each, which is the whole reason for the walk.
	var seen := {}
	for i in 900:
		var wish: Dictionary = cli.combo_at(opts, i)
		var key := "%s|%s|%d" % [wish["lean"], wish["speed"], int(wish["size"])]
		seen[key] = int(seen.get(key, 0)) + 1
	assert_eq(seen.size(), 18, "every combination was dealt")
	var evenly := 0
	for key in seen:
		if int(seen[key]) == 50:
			evenly += 1
	assert_eq(evenly, 18, "fifty decks of each")


func test_every_axis_takes_alternatives_and_the_list_is_closed() -> void:
	# The axes are a closed list, and each one has to be reachable from
	# the command line AS a list — a wish that cannot vary cannot mine.
	var flags := {"sets": ["--sets", "4ed", "--sets", "2ed"],
		"colors": ["--colors", "WU,BR"], "max_colors": ["--max-colors", "1,2"],
		"gold": ["--gold", "on,off"], "size": ["--size", "40,60"],
		"lean": ["--lean", "creatures,spells"], "speed": ["--speed", "fast,slow"],
		"rarity": ["--rarity", "any,pauper"], "lands": ["--lands", "classic,non-classic"],
		"tournament": ["--tournament", "on,off"], "power_nine": ["--power-nine", "on,off"]}
	assert_eq(Array(cli.AXES).size(), flags.size(), "one entry per axis")
	for axis in cli.AXES:
		assert_true(flags.has(String(axis)), "%s is reachable as a list" % axis)
		var opts := _parse(["--out", "x"] + flags[String(axis)])
		assert_false(opts.has("error"), str(opts.get("error", "")))
		assert_eq((opts[String(axis)] as Array).size(), 2,
			"--%s took two alternatives" % String(axis).replace("_", "-"))
		assert_eq(cli.combo_total(opts), 2)


# ------------------------------------------------------------ the seeds --

func test_every_deck_seed_is_one_the_autodeck_window_accepts() -> void:
	var outside := 0
	for base in [1, 2, 4242, 500_000, 999_999]:
		for index in [0, 1, 2, 999, 9_999, 99_999, 999_998]:
			var value: int = cli.deck_seed(int(base), int(index))
			if value < 1 or value > AutoDeckWindow.SEED_MOST:
				outside += 1
	assert_eq(outside, 0, "every derived seed is 1..999999 — the window's range")


func test_the_first_deck_gets_the_base_seed_and_no_two_decks_share_one() -> void:
	assert_eq(cli.deck_seed(4242, 0), 4242, "deck 1 is the base seed itself")
	assert_eq(cli.deck_seed(1, 0), 1)
	assert_eq(cli.deck_seed(999_999, 0), 999_999)
	# The stride is coprime with the seed space, so the ten-thousand-deck
	# run this tool was written for deals ten thousand different seeds.
	var seen := {}
	for index in 10_000:
		seen[cli.deck_seed(4242, index)] = true
	assert_eq(seen.size(), 10_000, "ten thousand decks, ten thousand seeds")


func test_the_seeds_are_a_function_of_the_base_and_the_index_alone() -> void:
	var stable := 0
	for index in [0, 1, 7, 1_234]:
		if cli.deck_seed(77, int(index)) == cli.deck_seed(77, int(index)):
			stable += 1
	assert_eq(stable, 4, "the same answer every time it is asked")
	assert_ne(cli.deck_seed(77, 3), cli.deck_seed(78, 3), "another base, another seed")


func test_random_colors_are_drawn_from_the_decks_own_seed() -> void:
	# Deterministic, so the letters in the manifest are a fact about the
	# deck and not a note about one run.
	assert_eq(cli.random_colors(4242, 2, false), cli.random_colors(4242, 2, false))
	var counts := {}
	var out_of_range := 0
	var colored := 0
	for index in 400:
		var mask: int = cli.random_colors(cli.deck_seed(4242, index), 3, false)
		var n := AutoDeck._count_colors(mask)
		if n < 1 or n > 3:
			out_of_range += 1
		if n > 1:
			colored += 1
		counts[mask] = int(counts.get(mask, 0)) + 1
	assert_eq(out_of_range, 0, "1..max colors, never none and never more")
	assert_gt(counts.size(), 10, "the draw explores the color space")
	assert_gt(colored, 0, "and reaches more than one color")
	# A gold deck is two colors at least, as AutoDeck.build insists.
	var thin := 0
	for index in 50:
		if AutoDeck._count_colors(cli.random_colors(
				cli.deck_seed(7, index), 1, true)) < 2:
			thin += 1
	assert_eq(thin, 0, "a gold deck is never mono-colored")
	# `--max-colors 1` draws exactly one, which is how a mono sweep is asked for.
	var mono := 0
	for index in 20:
		if AutoDeck._count_colors(cli.random_colors(
				cli.deck_seed(11, index), 1, false)) == 1:
			mono += 1
	assert_eq(mono, 20)


func test_the_builders_own_color_choice_does_not_follow_the_seed() -> void:
	# THE FINDING `--colors random` EXISTS FOR (2026-09-25):
	# AutoDeck._choose_colors reads no random number, so one pool and one
	# set of wishes land on ONE color set however many seeds are thrown at
	# it — which is why a mining run with `--colors none` would be ten
	# thousand decks of the same two colors. If this test ever fails
	# because the builder learned to vary its colors, the paragraph in
	# auto_deck_cli.gd's class doc and in DeckLab/README.md is stale.
	var pool := AutoDeck.pool_from_sets(["4ed"])
	assert_gt(AutoDeck.pool_total(pool), 0, "the Fourth Edition pool")
	var chosen := {}
	for seed_value in [1, 4242, 528_529, 999_999]:
		var auto := AutoDeck.new()
		auto.pool = pool
		auto.seed = int(seed_value)
		auto.build()
		chosen[auto.chosen_colors] = true
	assert_eq(chosen.size(), 1,
		"four seeds, one color choice — the colors do not follow the seed")


# -------------------------------------------- the promise to the window --

func test_a_deck_the_tool_made_rebuilds_from_its_row() -> void:
	# THE PROMISE IN --help, TESTED THE WAY A PLAYER WOULD KEEP IT: read a
	# row of decks.csv, set an AutoDeck up from those wishes and that seed
	# — nothing else — and the deck that comes out is the deck in the
	# file, card for card.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "6", "--seed", "4242",
		"--colors", "random", "--lean", "creatures,spells",
		"--speed", "fast,slow", "--size", "40,60"]), 0)
	var rows := _rows_of(out.path_join(cli.MANIFEST_NAME))
	assert_eq(rows.size(), 7, "a header and six decks")
	var rebuilt_all := 0
	var same_colors := 0
	for i in range(1, rows.size()):
		var cell := _cells(rows[0], rows[i])
		var auto := AutoDeck.new()
		auto.pool = AutoDeck.pool_from_sets([String(cell["sets"])])
		# The colors the row says the builder BUILT, which is what a
		# player ticks in the window.
		auto.colors = cli.colors_from_letters(String(cell["colors_built"]))
		auto.max_colors = int(cell["max_colors"])
		auto.gold = String(cell["gold"]) == "on"
		auto.size = int(cell["size"])
		auto.lean = String(cell["lean"])
		auto.speed = String(cell["speed"])
		auto.rarity = String(cli.RARITY_FLAGS[String(cell["rarity"])])
		auto.land_kind = String(cli.LANDS_FLAGS[String(cell["lands"])])
		auto.tournament = String(cell["tournament"]) == "on"
		auto.power_nine = String(cell["power_nine"]) == "on"
		auto.seed = int(cell["seed"])
		var rebuilt := auto.build()
		var written := DeckList.load_file(out.path_join(String(cell["file"])))
		assert_eq(written.errors, [] as Array[String], String(cell["file"]))
		var from_file := DeckModel.from_deck_list(written)
		assert_eq(_cards_of(rebuilt), _cards_of(from_file),
			"%s rebuilds from seed %s" % [cell["file"], cell["seed"]])
		if _cards_of(rebuilt) == _cards_of(from_file):
			rebuilt_all += 1
		if cli.color_letters(auto.chosen_colors) == String(cell["colors_built"]):
			same_colors += 1
		assert_eq(int(cell["cards"]), from_file.total(),
			"the row's card count is the file's")
	assert_eq(rebuilt_all, 6, "all six decks rebuilt")
	assert_eq(same_colors, 6, "and in the colors the row records")


func test_the_same_base_seed_and_options_build_identical_folders() -> void:
	# The other half of reproducibility: the WHOLE RUN is a function of
	# its command line, so two runs of one command are two identical
	# folders — which is what makes a mining result something to keep.
	var first := _out_dir()
	var again := _out_dir()
	var args := ["--count", "5", "--seed", "1997", "--colors", "random",
		"--lean", "creatures,spells"]
	assert_eq(_run(["--out", first] + args), 0)
	assert_eq(_run(["--out", again] + args), 0)
	var names := DirAccess.open(first).get_files()
	assert_eq(names.size(), 7, "five decks, a manifest and a deck list")
	var identical := 0
	for name in names:
		# The deck list holds the folder's own path, so that one is
		# compared with the folder taken out of it.
		if FileAccess.get_file_as_string(first.path_join(name)).replace(first, "") \
				== FileAccess.get_file_as_string(again.path_join(name)).replace(again, ""):
			identical += 1
	assert_eq(identical, names.size(), "every file is byte-identical")


func test_a_fresh_base_seed_is_recorded_so_a_run_is_never_lost() -> void:
	# With no --seed a base is rolled; it has to be written down, or the
	# run cannot be repeated and the promise above is empty.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "2"]), 0)
	var rows := _rows_of(out.path_join(cli.MANIFEST_NAME))
	var first_seed := int(rows[1][2])
	assert_between(first_seed, 1, AutoDeckWindow.SEED_MOST)
	assert_eq(int(rows[2][2]), cli.deck_seed(first_seed, 1),
		"deck 1's seed IS the base, so the second follows from the first")


# ----------------------------------------------------------- the output --

func test_the_manifest_has_a_row_per_deck_and_the_columns_it_says() -> void:
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "3", "--seed", "4242",
		"--sets", "4ed", "--colors", "WU", "--rarity", "no-rares",
		"--lands", "non-classic", "--power-nine", "on", "--no-tournament"]), 0)
	var rows := _rows_of(out.path_join(cli.MANIFEST_NAME))
	assert_eq(rows[0], Array(cli.MANIFEST_COLUMNS), "the header IS the column list")
	assert_eq(rows.size(), 4, "a header and three decks")
	for i in range(1, 4):
		var cell := _cells(rows[0], rows[i])
		assert_eq(int(cell["index"]), i, "the rows are in build order")
		assert_eq(String(cell["source"]), "sets")
		assert_eq(String(cell["sets"]), "4ed")
		assert_eq(String(cell["pool"]), "Fourth Edition",
			"the pool label is the window's own wording")
		assert_eq(String(cell["colors_asked"]), "WU")
		assert_string_contains(String(cell["colors_built"]), "W",
			"the colors asked for are always in the ones built")
		assert_eq(String(cell["rarity"]), "no-rares", "the word the switch took")
		assert_eq(String(cell["lands"]), "non-classic")
		assert_eq(String(cell["power_nine"]), "on")
		assert_eq(String(cell["tournament"]), "off")
		assert_eq(int(cell["cards"]), 60)
		assert_eq(int(cell["cards"]), int(cell["land_count"])
			+ int(cell["creature_count"]) + int(cell["spell_count"]),
			"the three counts add up to the deck")
		assert_true(FileAccess.file_exists(out.path_join(String(cell["file"]))),
			"the file the row names exists")
		assert_string_contains(String(cell["file"]), "s%06d" % int(cell["seed"]),
			"the file name carries the seed")
		assert_string_contains(String(cell["file"]), String(cell["colors_built"]))


func test_a_pool_label_with_a_comma_in_it_is_quoted() -> void:
	# "Fourth Edition, The Dark" in an unquoted CSV is a manifest that
	# lies about every column after the pool.
	assert_eq(cli.csv_field("Fourth Edition, The Dark"),
		"\"Fourth Edition, The Dark\"")
	assert_eq(cli.csv_field("4ed"), "4ed")
	assert_eq(cli.csv_field("a \"quoted\" name"), "\"a \"\"quoted\"\" name\"")
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "1", "--seed", "4242",
		"--sets", "4ed,drk"]), 0)
	var text := FileAccess.get_file_as_string(out.path_join(cli.MANIFEST_NAME))
	assert_string_contains(text, "\"Fourth Edition, The Dark\"")
	# And the quoted label is the one field a naive split breaks in two,
	# which is the proof the quoting was needed at all.
	var rows := _rows_of(out.path_join(cli.MANIFEST_NAME))
	assert_eq((rows[1] as Array).size(), (rows[0] as Array).size() + 1)


func test_the_deck_list_is_the_files_in_build_order() -> void:
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "4", "--seed", "4242",
		"--colors", "random"]), 0)
	var listed := FileAccess.get_file_as_string(
		out.path_join(cli.DECKLIST_NAME)).split("\n", false)
	assert_eq(listed.size(), 4, "one line a deck, and nothing else")
	var rows := _rows_of(out.path_join(cli.MANIFEST_NAME))
	var in_order := 0
	var readable := 0
	for i in 4:
		if String(listed[i]) == out.path_join(String(rows[i + 1][0])):
			in_order += 1
		if FileAccess.file_exists(String(listed[i])):
			readable += 1
	assert_eq(in_order, 4, "line K is the manifest's row K, as a path to walk")
	assert_eq(readable, 4, "and every path opens")


func test_the_deck_files_are_named_to_sort_and_to_read() -> void:
	assert_eq(cli.deck_file_name(0, 5, Mtg.ManaColor.W | Mtg.ManaColor.U, 4242),
		"deck_00001_WU_s004242.deck")
	assert_eq(cli.deck_file_name(9_999, 5, Mtg.ManaColor.G, 999_999),
		"deck_10000_G_s999999.deck")
	assert_eq(cli.deck_file_name(0, 5, 0, 1), "deck_00001_C_s000001.deck",
		"a deck of no color is C")
	assert_eq(cli.index_width(10_000), 5, "a ten-thousand-deck run reads as 00001")
	assert_eq(cli.index_width(1), 5)
	assert_eq(cli.index_width(1_000_000), 7, "and a bigger one still sorts")
	# WUBRG order, never the order the letters were typed in.
	assert_eq(cli.color_letters(Mtg.ManaColor.G | Mtg.ManaColor.W), "WG")
	assert_eq(cli.colors_from_letters("gw"), Mtg.ManaColor.G | Mtg.ManaColor.W)
	assert_eq(cli.colors_from_letters("WX"), -1)
	assert_eq(cli.color_letters(0), "C")


func test_the_deck_files_are_decks_the_lab_and_the_builder_both_read() -> void:
	# The output has to be a deck file and not a report: DeckList in
	# STRICT mode is what DeckLab/simulate.gd loads a --deck-a with.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "2", "--seed", "4242",
		"--colors", "random"]), 0)
	var checked := 0
	for name in DirAccess.open(out).get_files():
		if not name.ends_with(".deck"):
			continue
		checked += 1
		var deck := DeckList.load_file(out.path_join(name))
		assert_eq(deck.errors, [] as Array[String], name)
		assert_eq(deck.cards.size(), 60, "%s is a whole deck" % name)
		assert_ne(deck.deck_name, "", "and it is named")
		# The seed is in the file itself, as the last of its notes — so a
		# deck that got separated from the manifest still says how it was
		# made.
		var notes := DeckModel.notes_from_text(
			FileAccess.get_file_as_string(out.path_join(name)))
		assert_string_contains(notes, "Seed ")
		assert_string_contains(notes, "Built by AutoDeck")
	assert_eq(checked, 2)


func test_the_deck_names_are_unique_so_a_matrix_report_reads() -> void:
	# A field of forty decks all called "Blue-Black Midrange" is a matrix
	# nobody can read, and an Elo ledger that adds them all together.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "8", "--seed", "4242"]), 0)
	var names := {}
	for name in DirAccess.open(out).get_files():
		if name.ends_with(".deck"):
			names[DeckList.load_file(out.path_join(name)).deck_name] = true
	assert_eq(names.size(), 8, "eight decks, eight names")


func test_a_folder_that_holds_something_is_refused_unless_forced() -> void:
	# A second run into the same folder mixes two fields into one
	# manifest that describes neither.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "2", "--seed", "4242"]), 0)
	var before := DirAccess.open(out).get_files().size()
	assert_eq(_run(["--out", out, "--count", "2", "--seed", "4242"]), 1,
		"the second run is refused")
	assert_eq(DirAccess.open(out).get_files().size(), before,
		"and it wrote nothing")
	assert_eq(_run(["--out", out, "--count", "2", "--seed", "4242", "--force"]), 0,
		"--force writes into it anyway")


func test_a_list_pool_builds_and_a_bad_one_is_refused() -> void:
	var out := _out_dir()
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(out)), OK)
	var list_path := out.path_join("pool.txt")
	var file := FileAccess.open(list_path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string("4 Lightning Bolt\n4 Shivan Dragon\n4 Llanowar Elves\n"
		+ "4 Giant Growth\n4 Serra Angel\n4 Dark Ritual\n")
	file.close()
	# --force, because the list itself is the file that makes the folder
	# not empty.
	assert_eq(_run(["--out", out, "--count", "1", "--seed", "4242",
		"--list", list_path, "--size", "40", "--force"]), 0)
	var cell := _cells(_rows_of(out.path_join(cli.MANIFEST_NAME))[0],
		_rows_of(out.path_join(cli.MANIFEST_NAME))[1])
	assert_eq(String(cell["source"]), "list", "the source the --list implied")
	assert_eq(String(cell["pool"]), "pool.txt", "the pool label is the file")
	assert_eq(String(cell["sets"]), "", "and no set codes, since no set was read")
	# A file with nothing the game has is a run that cannot start, and so
	# is a file that is not there.
	var empty_path := out.path_join("empty.txt")
	var empty := FileAccess.open(empty_path, FileAccess.WRITE)
	empty.store_string("# nothing but a comment\n")
	empty.close()
	assert_eq(_run(["--out", out, "--count", "1", "--list", empty_path,
		"--force"]), 1)
	assert_eq(_run(["--out", out, "--count", "1", "--list",
		out.path_join("no_such_file.txt"), "--force"]), 1)


func test_a_sealed_pool_is_dealt_per_deck_from_that_decks_seed() -> void:
	# The source that makes a field vary without a single wish changing:
	# every deck opens its own packs, from its own seed.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "3", "--seed", "4242",
		"--source", "sealed", "--sets", "4ed", "--size", "40"]), 0)
	var rows := _rows_of(out.path_join(cli.MANIFEST_NAME))
	assert_eq(rows.size(), 4)
	var sealed_rows := 0
	for i in range(1, 4):
		var cell := _cells(rows[0], rows[i])
		if String(cell["source"]) == "sealed" \
				and String(cell["pool"]).contains("a sealed pool of") \
				and int(cell["cards"]) == 40:
			sealed_rows += 1
	assert_eq(sealed_rows, 3, "three 40-card decks out of three sealed pools")
	# And the deal really is the deck's own: the same wishes, three seeds,
	# three different decks.
	var cards := {}
	for name in DirAccess.open(out).get_files():
		if name.ends_with(".deck"):
			cards[FileAccess.get_file_as_string(out.path_join(name))] = true
	assert_eq(cards.size(), 3, "three seeds, three sealed pools, three decks")


func test_an_unknown_set_code_is_refused_before_a_deck_is_built() -> void:
	# Ten thousand builds from an empty pool is not a failure anybody
	# wants to read about at the end of a run.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--sets", "zzz", "--count", "1"]), 2)
	assert_eq(_run(["--out", out, "--sets", "all", "--count", "1"]), 2)
	# `all` IS a set code — Alliances' own, from card pack 5 — so the word
	# for every set cannot be that one, and the refusal says so.
	assert_string_contains(cli.unknown_sets_message(
		_parse(["--out", "x", "--sets", "all"])), "`every` is the word")
	assert_string_contains(cli.unknown_sets_message(
		_parse(["--out", "x", "--sets", "zzz"])), "unknown set code 'zzz'")
	assert_eq(cli.unknown_sets_message(_parse(["--out", "x", "--sets", "4ed"])), "")
	assert_eq(cli.unknown_sets_message(_parse(["--out", "x", "--sets", "every"])), "")
	# `every` is every active set, in the registry's own order.
	assert_eq(cli.expand_sets(["every"]), Array(CardRegistry.active_set_order()))
	assert_eq(cli.expand_sets(["4ed", "4ed"]), ["4ed"], "and never twice")


func test_a_run_inside_the_project_keeps_the_importer_out() -> void:
	# A folder of decks is harmless, but decks.csv would be imported as a
	# translation table — DeckLab/simulate.gd's own reason for the marker.
	var out := "res://DeckLab/results/auto_deck_cli_test_%d" % Time.get_ticks_usec()
	_made.append(out)
	assert_eq(_run(["--out", out, "--count", "1", "--seed", "4242"]), 0)
	assert_true(FileAccess.file_exists(out.path_join(".gdignore")))
