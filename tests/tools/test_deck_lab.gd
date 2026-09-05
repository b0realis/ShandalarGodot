extends GutTest
## Deck Lab component tests: the deck-file loader, the statistics math,
## and the chart generators. The tool's full pipeline is exercised by the
## shell-level smoke in CI docs (a 20-game run) — these pin the parts.


# ---------------------------------------------------------------- DeckList --

func test_all_shipped_decks_load_cleanly() -> void:
	# Every example deck must be valid against the CURRENT registry — this
	# is the regression net that keeps decks/ in sync with the card pool.
	var dir := DirAccess.open("res://decks")
	assert_not_null(dir)
	dir.list_dir_begin()
	var entry := dir.get_next()
	var found := 0
	while entry != "":
		if entry.ends_with(".deck"):
			found += 1
			var deck := DeckList.load_file("res://decks/" + entry)
			assert_eq(deck.errors, [] as Array[String], entry)
			assert_eq(deck.cards.size(), 40, "%s is a 40-card deck" % entry)
		entry = dir.get_next()
	assert_gte(found, 5, "the shipped gauntlet has at least five styles")


func test_deck_parser_reports_all_problems_at_once() -> void:
	var deck := DeckList.new()
	deck.parse("""
name: Broken Brew
4 Lightning Bolt
3 Totally Fake Card
zero Mountain
2 Also Not Real
""")
	assert_eq(deck.deck_name, "Broken Brew")
	assert_eq(deck.errors.size(), 3, "every problem reported, none hidden")
	assert_eq(deck.cards.size(), 4, "the valid line still parsed")


func test_deck_parser_expands_counts() -> void:
	var deck := DeckList.new()
	deck.parse("2 Forest\n1 Grizzly Bears")
	assert_eq(deck.cards, ["Forest", "Forest", "Grizzly Bears"] as Array[String])


func test_dojo_dec_format_parses() -> void:
	# The community (Dojo/Apprentice-era) .dec conventions: // comments,
	# a // NAME header, 4x counts, and SB: sideboard lines.
	var deck := DeckList.new()
	deck.parse("""// NAME : Classic Burn
// a comment line
4x Lightning Bolt
1 Fireball
SB: 2 Shatter
SB: 1x Tranquility
""")
	assert_eq(deck.errors, [] as Array[String])
	assert_eq(deck.deck_name, "Classic Burn")
	assert_eq(deck.cards.size(), 5, "4x expanded + the Fireball")
	assert_eq(deck.sideboard.size(), 3, "SB: lines validated into the sideboard")
	assert_eq(deck.sideboard[0], "Shatter")


func test_microprose_dck_format_parses() -> void:
	# The original 1997 format: header line, .ID<TAB>count<TAB>name lines,
	# per-opponent-color sideboard sections that fold to max-per-name.
	var deck := DeckList.new()
	deck.parse_dck("Lord of Fate (Bl/Wh, 4th Edition)\n\n" +
		".188\t2\tPlains\n.55\t2\tDark Ritual\n\n" +
		".vNone\n.70\t3\tDrudge Skeletons\n" +
		".vBlack\n.70\t1\tDrudge Skeletons\n.28\t2\tCastle\n")
	assert_eq(deck.errors, [] as Array[String])
	assert_eq(deck.deck_name, "Lord of Fate", "the '(colors, set)' suffix trims")
	assert_eq(deck.cards.size(), 4)
	assert_eq(deck.sideboard.count("Drudge Skeletons"), 3,
		"per-color sections fold to MAX count per name")
	assert_eq(deck.sideboard.count("Castle"), 2)


func test_lenient_mode_accepts_unimplemented_cards() -> void:
	# The converter must handle historic decks the engine can't play yet.
	var deck := DeckList.new()
	deck.parse_dck("Old Deck\n\n.999\t4\tYotian Soldiers\n", "x", false)
	assert_eq(deck.errors, [] as Array[String], "no registry complaints")
	assert_eq(deck.cards.size(), 4)
	var strict := DeckList.new()
	strict.parse_dck("Old Deck\n\n.999\t4\tYotian Soldiers\n", "x", true)
	assert_eq(strict.errors.size(), 1, "gameplay loading still refuses")


func test_sideboard_lines_are_validated_too() -> void:
	var deck := DeckList.new()
	deck.parse("4 Lightning Bolt\nSB: 2 Imaginary Card")
	assert_eq(deck.errors.size(), 1, "bad sideboard cards are reported, not dropped")


# --------------------------------------------------------------- EloLedger --

const ELO_TMP := "user://test_elo_ledger.txt"


func test_elo_moves_toward_the_winner_and_stays_zero_sum() -> void:
	var ledger := EloLedger.new()
	ledger.record_matchup("Alpha", "Beta", 70, 30)
	assert_gt(ledger.rating("Alpha"), 1500.0)
	assert_lt(ledger.rating("Beta"), 1500.0)
	assert_almost_eq(ledger.rating("Alpha") + ledger.rating("Beta"), 3000.0, 0.01,
		"zero-sum: what Alpha gained, Beta lost")
	assert_eq(ledger.entries["Alpha"].wins, 70)
	assert_eq(ledger.entries["Beta"].losses, 70)


func test_elo_converges_rather_than_diverges() -> void:
	# Feeding the same 65% matchup repeatedly approaches the gap that
	# winrate implies (~108 Elo) instead of growing without bound.
	var ledger := EloLedger.new()
	for _i in 8:
		ledger.record_matchup("Alpha", "Beta", 65, 35)
	var gap: float = ledger.rating("Alpha") - ledger.rating("Beta")
	assert_between(gap, 60.0, 160.0, "settled near the winrate-implied gap")


func test_elo_ledger_round_trips_through_its_file() -> void:
	var ledger := EloLedger.new()
	ledger.path = ELO_TMP
	ledger.record_matchup("Alpha", "Beta", 10, 5)
	ledger.save()
	var reloaded := EloLedger.load_from(ELO_TMP)
	assert_almost_eq(reloaded.rating("Alpha"), ledger.rating("Alpha"), 0.05)
	assert_eq(reloaded.entries["Beta"].games, 15)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ELO_TMP))


# --------------------------------------------------------------- matrix svg --

func test_matrix_chart_renders_cells_and_diagonal() -> void:
	var svg := SvgCharts.matrix_chart(["A", "B"], {"0,1": 0.75, "1,0": 0.25})
	assert_string_contains(svg, "75%")
	assert_string_contains(svg, "25%")
	assert_string_contains(svg, "</svg>")


# ---------------------------------------------------------------- SimStats --

func test_wilson_interval_known_values() -> void:
	# 50/100: the Wilson 95% interval is ~[40.4%, 59.6%].
	var interval := SimStats.wilson_interval(50, 100)
	assert_almost_eq(interval.mid, 0.5, 0.001)
	assert_almost_eq(interval.low, 0.404, 0.005)
	assert_almost_eq(interval.high, 0.596, 0.005)
	# Extremes stay sane: 0/10 has a nonzero upper bound, never negative.
	var zero := SimStats.wilson_interval(0, 10)
	assert_eq(zero.mid, 0.0)
	assert_gt(zero.high, 0.0)
	assert_almost_eq(zero.low, 0.0, 0.0001)


func test_wilson_tightens_with_sample_size() -> void:
	var small := SimStats.wilson_interval(60, 100)
	var large := SimStats.wilson_interval(6000, 10000)
	assert_lt(large.high - large.low, small.high - small.low,
		"10k games beats 100 games — the whole point of the tool")


func test_summarize_splits_play_and_draw() -> void:
	var records := [
		{"a_won": true, "a_on_play": true, "turns": 10, "stalled": false},
		{"a_won": false, "a_on_play": true, "turns": 12, "stalled": false},
		{"a_won": true, "a_on_play": false, "turns": 8, "stalled": false},
		{"a_won": true, "a_on_play": false, "turns": 14, "stalled": false},
		{"a_won": false, "a_on_play": false, "turns": 20, "stalled": true},
	]
	var stats := SimStats.summarize(records)
	assert_eq(stats.games, 5)
	assert_eq(stats.a_wins, 3)
	assert_eq(stats.b_wins, 1)
	assert_eq(stats.stalled, 1, "stalled games counted, not mixed in")
	assert_eq(stats.a_games_on_play, 2)
	assert_eq(stats.a_wins_on_play, 1)
	assert_eq(stats.a_games_on_draw, 2)
	assert_eq(stats.a_wins_on_draw, 2)
	assert_almost_eq(stats.avg_turns, 11.0, 0.001)


func test_a_drawn_game_is_not_a_win_for_deck_b() -> void:
	# THE BUG THIS PINS: a game record carries `a_won`, and SimStats read
	# "not a_won" as "B won". A DRAW (MtgGame.is_draw — CR 104.4b, both
	# duelists losing at once; verified reachable in AI play, 1 game in 600
	# of the shipped gauntlet) therefore landed in b_wins, inflating the
	# opponent's win rate and its Elo, while SimStats' own class doc
	# promised draws were "counted and excluded from winrate denominators,
	# never silently mixed into either side".
	var records := [
		{"a_won": true, "a_on_play": true, "turns": 10, "stalled": false,
			"drawn": false},
		{"a_won": false, "a_on_play": false, "turns": 18, "stalled": false,
			"drawn": true},
	]
	var stats := SimStats.summarize(records)
	assert_eq(stats.games, 2)
	assert_eq(stats.draws, 1, "the draw is counted as a draw")
	assert_eq(stats.b_wins, 0, "and NOT as a win for deck B")
	assert_eq(stats.a_wins, 1)
	assert_almost_eq(stats.winrate.mid, 1.0, 0.001,
		"the draw leaves the winrate denominator")
	assert_eq(stats.a_games_on_draw, 0,
		"and the play/draw denominators too, so the splits agree with it")
	assert_almost_eq(stats.avg_turns, 14.0, 0.001,
		"a draw is still a game that took turns")


func test_every_game_record_says_whether_it_was_drawn() -> void:
	# The other half of the draw fix: SimStats can only exclude a draw if
	# the Lab reports one. This runs one real game through the worker-task
	# body and pins the RECORD SHAPE — deliberately not a specific seed's
	# outcome, which any engine change is entitled to move.
	var lab := _lab()
	var deck := DeckList.load_file("res://decks/mountain_artillery.deck")
	assert_eq(deck.errors, [] as Array[String])
	lab._duel_opts = {"lives": [20, 20], "names": ["A", "B"], "rules": "modern",
		"rule_overrides": {}, "ante": 0, "mulligan": false}
	lab._tasks = [{"pair": 0, "seed": 4242, "a_on_play": true,
		"deck_a": deck.cards, "deck_b": deck.cards, "dealt": "",
		"profile_a": "wizard", "profile_b": "wizard"}]
	lab._results.resize(1)
	lab._run_one_game(0)
	var record: Dictionary = lab._results[0]
	assert_true(record.has("drawn"), "the record carries the draw flag")
	assert_eq(typeof(record["drawn"]), TYPE_BOOL)
	assert_false(record["drawn"] and record["a_won"],
		"a draw is never also a win")


func test_a_record_without_the_drawn_key_still_summarizes() -> void:
	# Older records (and every test above) omit `drawn`; the key is read
	# with a default so no caller has to be updated in lockstep.
	var stats := SimStats.summarize([
		{"a_won": false, "a_on_play": true, "turns": 7, "stalled": false},
	])
	assert_eq(stats.b_wins, 1)
	assert_eq(stats.draws, 0)


# --------------------------------------------------------------- SvgCharts --

func test_winrate_chart_is_valid_svg_with_data() -> void:
	var stats := SimStats.summarize([
		{"a_won": true, "a_on_play": true, "turns": 9, "stalled": false},
		{"a_won": false, "a_on_play": false, "turns": 11, "stalled": false},
	])
	var svg := SvgCharts.winrate_chart("Test Deck",
		[{"label": "Opponent & Co", "stats": stats}])
	assert_string_contains(svg, "<svg")
	assert_string_contains(svg, "</svg>")
	assert_string_contains(svg, "Test Deck")
	assert_string_contains(svg, "Opponent &amp; Co", "labels are XML-escaped")


func test_turns_chart_handles_empty_histograms() -> void:
	var svg := SvgCharts.turns_chart("Test Deck",
		[{"label": "Nobody", "histogram": {}}])
	assert_string_contains(svg, "</svg>", "no crash, still a closed document")


# =========================================== the CLI's duel settings ==
#
# THE RULE THESE PIN: any setting the battle-setup screen can choose, the
# Deck Lab must be able to set. A GUI-only setting is a setting that can
# only be exercised by a human clicking, and this is the tool that runs a
# thousand games — so a missing flag is a hole in the project's ability to
# test itself. The parser is exercised directly (running games would make
# these a benchmark, not a test).


## `simulate.gd` extends SceneTree, and a SceneTree is a plain Object that
## builds a root [Window] the moment it is constructed. So every `.new()`
## here leaked one orphan node AND the tree itself — 62 of the suite's 63
## reported orphans came from this one line. `autofree` hands it to GUT to
## `free()` after the test (free, not queue_free: a SceneTree is not a Node
## and never reaches the frame's delete queue).
func _lab() -> Object:
	return autofree(load("res://tools/simulate.gd").new())


func _parse(args: Array) -> Dictionary:
	return _lab()._parse_args(PackedStringArray(args))


const BASE := ["--deck-a", "white_knights.deck", "--deck-b", "big_green.deck"]


func test_every_new_flag_defaults_to_what_the_lab_always_did() -> void:
	# THE DETERMINISM CONTRACT. The Lab proves engine changes are safe by
	# comparing a fixed seed's results against a recorded baseline, and a
	# moved default silently invalidates that. Every default below is the
	# behaviour this tool had before the flag existed.
	var opts := _parse(BASE)
	assert_eq(opts.lives, [20, 20], "20 life a side")
	assert_eq(opts.ante, 0, "not for ante — nothing programmatic loses a card")
	assert_eq(opts.names, ["SeatZero", "SeatOne"])
	assert_eq(opts.format, "", "no format required")
	assert_eq(opts.group, "", "every deck group")
	assert_false(opts.mulligan, "OFF: turning it on changes every opening hand")
	assert_eq(opts.rules, "modern")
	assert_eq(opts.rule_overrides, {})
	assert_eq(opts.best_of, MatchState.FREE_PLAY,
		"`&Free play` — one duel and no record, as before matches existed")
	assert_false(opts.sideboard, "nothing swaps unless a match asks for it")


func test_the_seed_flag_is_the_same_knob_as_the_configs() -> void:
	# `--seed` and `DuelConfig.rng_seed` must not become two ideas.
	assert_eq(_parse(BASE + ["--seed", "4242"]).seed, 4242)


func test_lives_takes_one_number_or_two() -> void:
	assert_eq(_parse(BASE + ["--lives", "30"]).lives, [30, 30])
	assert_eq(_parse(BASE + ["--lives", "15,25"]).lives, [15, 25])
	assert_true(_parse(BASE + ["--lives", "0"]).has("error"))
	assert_true(_parse(BASE + ["--lives", "1,2,3"]).has("error"))


func test_ante_and_names_come_through() -> void:
	assert_eq(_parse(BASE + ["--ante", "2"]).ante, 2)
	assert_true(_parse(BASE + ["--ante", "-1"]).has("error"))
	assert_eq(_parse(BASE + ["--names", "Alice,Bob"]).names, ["Alice", "Bob"])
	assert_true(_parse(BASE + ["--names", "Alice"]).has("error"))


func test_the_format_flag_names_the_1997_formats() -> void:
	assert_eq(_parse(BASE + ["--format", "highlander"]).format,
		DeckFormat.HIGHLANDER)
	assert_eq(_parse(BASE + ["--format", "type1.5"]).format,
		DeckFormat.TOURNAMENT_T15)
	assert_eq(_parse(BASE + ["--format", "type1"]).format,
		DeckFormat.RESTRICTED_T1)
	var bad := _parse(BASE + ["--format", "modern"])
	assert_true(bad.has("error"), "an unknown format is refused, not ignored")
	# Every short spelling must land on a real format.
	for key in _lab().FORMAT_FLAGS:
		assert_true(DeckFormat.ORDER.has(_lab().FORMAT_FLAGS[key]), key)


func test_an_illegal_deck_fails_at_parse_time_naming_the_card() -> void:
	# The Lab must not play a thousand games with a deck the format bars.
	# Blue Skies plays an Ancestral Recall, so Tournament (Type 1.5)
	# refuses it — and the refusal says which card.
	var deck := DeckList.load_file("res://decks/blue_skies.deck", true)
	var refusal := DeckFormat.legal(deck.cards, DeckFormat.TOURNAMENT_T15)
	assert_ne(refusal, "")
	assert_true(refusal.contains("Ancestral Recall"))
	assert_null(_lab()._load_deck("res://decks/blue_skies.deck",
		DeckFormat.TOURNAMENT_T15), "the loader refuses it")
	assert_not_null(_lab()._load_deck("res://decks/blue_skies.deck",
		DeckFormat.RESTRICTED_T1), "and accepts it where it is legal")


func test_the_group_flag_names_the_deck_groups() -> void:
	assert_eq(_parse(BASE + ["--group", "starter"]).group, DeckGroups.STARTER)
	assert_true(_parse(BASE + ["--group", "nonsense"]).has("error"))
	for key in _lab().GROUP_FLAGS:
		assert_true(DeckGroups.ORDER.has(_lab().GROUP_FLAGS[key]), key)


func test_the_group_filter_is_read_before_the_pools_expand() -> void:
	# `--matrix DIR` expands as it parses, so a `--group` after it would
	# silently do nothing. The pre-scan is what makes the order not matter.
	var after := _parse(["--matrix", "decks/", "--group", "starter"])
	assert_false(after.has("error"), "the pool still found decks")
	assert_gt((after.matrix_pool as Array).size(), 1)
	# `user` is derived from `user://decks`, so no file under `res://decks`
	# can ever be one — the one group a shipped DIR is guaranteed not to
	# hold. (`originals` was the empty group here until 2026-09-02, when
	# `decks/1997/originals/` arrived and `--group` began walking into
	# the subfolders — `test_decks_1997.gd` pins that side.)
	var none := _parse(["--matrix", "decks/", "--group", "user"])
	assert_true(none.has("error"),
		"a group with no decks refuses loudly rather than running empty")


func test_the_rules_flags_reach_every_fork() -> void:
	assert_eq(_parse(BASE + ["--rules", "fifth"]).rules, "fifth")
	assert_true(_parse(BASE + ["--rules", "sixth"]).has("error"))
	for fork in RulesOptions.FORKS:
		var opts := _parse(BASE + ["--rule", "%s=on" % fork["key"]])
		assert_false(opts.has("error"), fork["key"])
		assert_eq(opts.rule_overrides[fork["key"]], true, fork["key"])
	assert_true(_parse(BASE + ["--rule", "nonsense=on"]).has("error"))
	assert_true(_parse(BASE + ["--rule", "mana_burn=maybe"]).has("error"))


func test_fifth_edition_really_flips_every_fork() -> void:
	# The point of --rules: a whole pool replayed under the 1997 ruleset.
	var rules := RulesOptions.new()
	rules.set_edition("fifth")
	assert_eq(rules.edition(), "fifth")
	rules.set_edition("modern")
	assert_eq(rules.edition(), "modern")


func test_mulligan_takes_on_or_off_only() -> void:
	assert_true(_parse(BASE + ["--mulligan", "on"]).mulligan)
	assert_false(_parse(BASE + ["--mulligan", "off"]).mulligan)
	assert_true(_parse(BASE + ["--mulligan", "yes"]).has("error"))


func test_best_of_offers_only_the_lengths_1997_has() -> void:
	# `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` ships one record sentence for
	# best of 3 and one for best of 5, with the number written into the
	# sentence — so those are the two lengths it can NARRATE, and 7 is not
	# on offer. `@DIALOG_GAUNTLETOPTIONS`' `Best of &One` adds the third
	# (docs/duel-todo.md §6.21): a one-duel MATCH, which keeps a record
	# where `&Free play` keeps none.
	assert_eq(_parse(BASE + ["--best-of", "3"]).best_of, 3)
	assert_eq(_parse(BASE + ["--best-of", "5"]).best_of, 5)
	assert_eq(_parse(BASE + ["--best-of", "1"]).best_of, 1)
	assert_true(_parse(BASE + ["--best-of", "7"]).has("error"))
	assert_true(_parse(BASE + ["--best-of", "2"]).has("error"))


func test_sideboarding_needs_a_match_to_happen_between() -> void:
	# `Side&board between duels` has no moment in `&Free play`: there is
	# no second duel for it to be between.
	assert_true(_parse(BASE + ["--sideboard", "on"]).has("error"))
	assert_true(_parse(BASE + ["--best-of", "3", "--sideboard", "on"]).sideboard)
	assert_false(_parse(BASE + ["--best-of", "3", "--sideboard", "off"]).sideboard)
	assert_true(_parse(BASE + ["--best-of", "3", "--sideboard", "maybe"])
		.has("error"))


func test_the_match_parameters_reach_the_settings_line() -> void:
	var lab := _lab()
	var line: String = lab._settings_line(
		_parse(BASE + ["--best-of", "3", "--sideboard", "on"]))
	assert_true(line.contains("best of 3"), line)
	assert_true(line.contains("sideboard on"), line)


func test_the_settings_line_is_silent_at_the_defaults() -> void:
	# A default run's report must keep reading as the ones the recorded
	# baseline was taken from (only its timing line moves between runs;
	# the byte-for-byte determinism check is matchups.csv).
	var lab := _lab()
	assert_eq(lab._settings_line(_parse(BASE)), "")
	assert_true(lab._settings_line(_parse(BASE + ["--ante", "1"]))
		.contains("ante 1"))


func test_the_lab_opens_a_game_the_way_the_duel_screen_does() -> void:
	# `MtgGame.start()` IS `deal_opening_hands()` + `start_duel()`, so the
	# two paths were never different — the mulligan OFFER between them is
	# the only thing the Lab lacked, and it is now a flag.
	var game := MtgGame.new()
	game.setup(StarterDecks.WHITE_KNIGHTS, StarterDecks.BLACK_RED_RAIDERS,
		"A", "B", 20, 20, 99)
	game.deal_opening_hands(7)
	assert_true(game.mulligan_open, "the offer is open between the two calls")
	assert_eq(game.players[0].hand.size(), 7)
	game.start_duel(0)
	assert_false(game.mulligan_open)
	assert_eq(game.turn_number, 1)


# ============================================ `--deck-b random`: the field ==
#
# THE RULE THESE PIN: `random` is the setup screen's `<random deck>` in
# the CLI — a REAL deck drawn from a pool, freshly per game, so one run
# measures a deck against the field rather than against one opponent.
# It shares the GUI's pick function on purpose (SetupScreen is the only
# place that logic lives), and the pool is validated up front.


func test_the_random_token_is_recognised_however_it_is_typed() -> void:
	var lab := _lab()
	assert_true(lab.is_random("random"))
	assert_true(lab.is_random("Random"), "a shell user will type it this way")
	assert_true(lab.is_random("RANDOM"))
	assert_false(lab.is_random("random.deck"), "a FILE called random is a file")
	assert_false(lab.is_random("decks/big_green.deck"))


func test_the_field_label_is_the_setup_screens_own_words() -> void:
	# One source of truth: the CLI must not invent a second name for the
	# thing the GUI already calls `<random deck>`. The TOKEN differs only
	# because a shell eats angle brackets.
	assert_eq(_lab().RANDOM_LABEL, SetupScreen.RANDOM_DECK)
	assert_eq(_lab().RANDOM_TOKEN, "random")


func test_only_one_side_may_be_the_field() -> void:
	# Both sides random would make the per-deck breakdown two-dimensional
	# and the Elo attribution ambiguous.
	var opts := _parse(["--deck-a", "random", "--deck-b", "random"])
	assert_true(opts.has("error"), "refused")
	assert_string_contains(opts.get("error", ""), "only one side")
	# Either side alone is fine.
	assert_false(_parse(["--deck-a", "x.deck", "--deck-b", "random"]).has("error"))
	assert_false(_parse(["--deck-a", "random", "--deck-b", "x.deck"]).has("error"))


func test_deck_pool_is_refused_where_it_would_do_nothing() -> void:
	# A flag that is silently ignored is a flag that lies about the run.
	var no_random := _parse(BASE + ["--deck-pool", "decks/"])
	assert_true(no_random.has("error"), "no `random` side to draw for")
	var in_matrix := _parse(["--matrix", "decks/", "--deck-pool", "decks/"])
	assert_true(in_matrix.has("error"), "matrix mode draws nothing")


func test_the_pool_defaults_to_the_shipped_decks() -> void:
	var opts := _parse(["--deck-a", "x.deck", "--deck-b", "random"])
	assert_eq(opts.deck_pool, "", "unset means the default")
	assert_eq(_lab().DEFAULT_POOL, "res://decks/")


func test_no_deck_under_test_is_ever_in_its_own_field() -> void:
	# THE BUG THIS PINS: `--deck-a random --deck-b blue_skies.deck` first
	# measured Blue Skies against a field that contained Blue Skies,
	# because the pool's exclusion only knew how to drop `--deck-a`.
	var lab := _lab()
	var pool := ["decks/big_green.deck", "decks/blue_skies.deck",
		"decks/white_knights.deck"]
	var field_on_b: PackedStringArray = lab.decks_under_test(
		{"deck_a": "decks/white_knights.deck", "opponents": ["random"]})
	assert_eq(lab.without_decks_under_test(pool, field_on_b),
		["decks/big_green.deck", "decks/blue_skies.deck"],
		"the deck under test is dropped when the field is the OPPONENT")
	var field_on_a: PackedStringArray = lab.decks_under_test(
		{"deck_a": "random", "opponents": ["decks/blue_skies.deck"]})
	assert_eq(lab.without_decks_under_test(pool, field_on_a),
		["decks/big_green.deck", "decks/white_knights.deck"],
		"and when the field is the deck under test's OWN side")
	# A path typed differently to the pool's own spelling still matches:
	# the comparison is on the file name, not the whole path.
	var typed_bare: PackedStringArray = lab.decks_under_test(
		{"deck_a": "big_green.deck", "opponents": ["random"]})
	assert_eq(lab.without_decks_under_test(pool, typed_bare).size(), 2)


func test_the_breakdown_says_whose_win_rate_it_is_printing() -> void:
	# THE BUG THIS PINS: SimStats always reports the pair's ROW deck, so
	# one caption for both directions printed every figure inverted for
	# `--deck-a random` — "Blue Skies's win rate" over numbers that were
	# each opponent's win rate against Blue Skies.
	var lab := _lab()
	assert_eq(lab.field_caption(false, "White Knights"),
		"White Knights's win rate against each",
		"field on the column: the number is the deck under test's")
	assert_eq(lab.field_caption(true, "Blue Skies"),
		"each deck's win rate against Blue Skies",
		"field on the row: the number belongs to the line it is on")


# ------------------------------------ the 2026-09-02 tool-wrapper sweep --
# Each of these was a way the Lab could exit 0, or read a flag, other than
# as its console said. None is a rules question; all are about the tool
# telling the truth about its own run.


func test_non_numbers_are_refused_not_read_as_zero() -> void:
	# `String.to_int()` reads "abc" as 0: `--seed abc` ran seed 0, `--jobs
	# abc` used every core and `--best-of abc` was free play — silently.
	for flag in ["--seed", "--jobs", "--games", "--ante", "--best-of"]:
		var opts := _parse(BASE + [flag, "abc"])
		assert_true(opts.has("error"), flag + " abc must be refused")
		assert_true(str(opts.get("error", "")).contains(flag),
			"the refusal names the flag: " + str(opts.get("error", "")))
	assert_true(_parse(BASE + ["--lives", "20,abc"]).has("error"))
	assert_true(_parse(BASE + ["--jobs", "-1"]).has("error"))
	assert_eq(_parse(BASE + ["--jobs", "0"]).jobs, 0, "0 is 'every core'")
	assert_eq(_parse(BASE + ["--seed", "-7"]).seed, -7,
		"a negative seed is still a whole number")


func test_help_names_every_rules_fork() -> void:
	# --help listed six `--rule` keys while RulesOptions has seven.
	var lab := _lab()
	for fork in RulesOptions.FORKS:
		assert_true(str(lab.HELP).contains(fork["key"]),
			"--help names the fork '%s'" % fork["key"])


func test_the_gauntlet_excludes_the_deck_under_test_whichever_flag_came_first() -> void:
	# `--gauntlet DIR` used to expand as it was parsed, so typed BEFORE
	# `--deck-a` it put the deck under test in its own gauntlet.
	var after := _parse(["--deck-a", "decks/white_knights.deck",
		"--gauntlet", "res://decks"])
	var before := _parse(["--gauntlet", "res://decks",
		"--deck-a", "decks/white_knights.deck"])
	assert_false(after.has("error"), str(after.get("error", "")))
	assert_false(before.has("error"), str(before.get("error", "")))
	assert_eq(before.opponents, after.opponents,
		"flag order does not change the gauntlet")
	assert_gte(before.opponents.size(), 4, "the other starter decks")
	for opponent in before.opponents:
		assert_ne(String(opponent).get_file(), "white_knights.deck",
			"the deck under test is not its own opponent")


func test_sideboarding_in_a_best_of_one_is_refused_too() -> void:
	# A best-of-ONE match is a single duel with a scoreboard: there is no
	# second duel for the swap to happen before. `--best-of 1 --sideboard
	# on` used to pass the free-play check and silently never sideboard.
	assert_true(_parse(BASE + ["--best-of", "1", "--sideboard", "on"]).has("error"))
	assert_false(_parse(BASE + ["--best-of", "1", "--sideboard", "off"]).has("error"))
	assert_true(_parse(BASE + ["--best-of", "5", "--sideboard", "on"]).sideboard)


func test_a_file_that_cannot_be_written_is_a_failure_the_caller_hears() -> void:
	# `_write` printed "cannot write" and returned nothing, so a run whose
	# report never landed still ended in "wrote ..." and exit 0.
	var lab := _lab()
	var stamp := Time.get_ticks_usec()
	assert_false(lab._write("user://deck_lab_no_such_dir_%d/report.txt" % stamp, "x"),
		"a missing directory is a failed write")
	var path := "user://deck_lab_test_write_%d.txt" % stamp
	assert_true(lab._write(path, "hello\n"))
	assert_eq(FileAccess.get_file_as_string(path), "hello\n")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_crashed_run_is_not_exit_zero() -> void:
	# A runtime error inside `_main` unwinds it to null, and `quit(null)`
	# was exit 0 — a crashed run that looked clean to the shell.
	var lab := _lab()
	assert_eq(lab.exit_code_of(null), 1)
	assert_eq(lab.exit_code_of(0), 0)
	assert_eq(lab.exit_code_of(2), 2)
	# A worker thread that stopped on an error leaves its result slot
	# null, and `SimStats.summarize` threw on it; the slots are counted
	# before aggregation and the run exits 1 with a message instead.
	assert_eq(lab.missing_records([{}, null, {}, null]), 2)
	assert_eq(lab.missing_records([{}, {}]), 0)


# --------------------------------- the soak does not change the player's --

## `tools/duel_soak.gd` is a SceneTree with no class_name, so its statics
## are reached through the script itself — the same way this file already
## reaches `tools/simulate.gd`.
func _soak() -> GDScript:
	return load("res://tools/duel_soak.gd") as GDScript



## A REPORTING TOOL MUST NOT CHANGE THE GAME IT REPORTS ON.
##
## `./duel_soak.sh` drives a FUZZED human seat through the live duel
## screen, and that screen carries the Dueling Options panel — so a run
## can flip any option the player owns. One did on 2026-09-03: a soak left
## `PlayerTerritoryColor="Red"` in `user://settings.cfg`, which changed
## the owner's own game and then failed the test that asserts the shipped
## default. `--rules` already restored the seven rule keys; these pin the
## guard that covers the whole file, including the case that is easiest to
## get wrong — there WAS no file, and there must not be one afterwards.
func test_the_soak_puts_the_settings_file_back_byte_for_byte() -> void:
	var before: Variant = _soak().snapshot_settings()
	# A key nothing else uses, so the file is guaranteed to differ — this
	# is what a fuzzer's click on the Dueling Options panel amounts to.
	Settings.set_value("SoakGuardProbe", "clicked")
	var probed: Variant = _soak().snapshot_settings()
	assert_ne(probed, before, "the run changed the file")
	assert_true(_soak().restore_settings(before), "it had to put it back")
	var after: Variant = _soak().snapshot_settings()
	assert_eq(after, before, "and it matches byte for byte")
	assert_false(Settings.has_value("SoakGuardProbe"),
		"nothing the run wrote survives")


func test_a_machine_with_no_settings_file_still_has_none_afterwards() -> void:
	var real: Variant = _soak().snapshot_settings()
	var existed := FileAccess.file_exists(Settings.PATH)
	Settings.set_value("SoakGuardProbe", "clicked")
	_soak().restore_settings(null)      # as if the player had never saved
	assert_false(FileAccess.file_exists(Settings.PATH),
		"restoring 'there was no file' means there is no file")
	# and put the player's own file back, since this test deleted it
	_soak().restore_settings(real)
	assert_eq(FileAccess.file_exists(Settings.PATH), existed)
	assert_eq(_soak().snapshot_settings(), real)
