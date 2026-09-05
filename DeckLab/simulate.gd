extends SceneTree
## THE DECK LAB — headless AI-vs-AI deck testing. Run via DeckLab/deck_lab.sh
## (which forwards everything after itself to this script); full manual in
## DeckLab/README.md. Text output only; charts land as SVG files.
##
## Three modes:
##   duel      --deck-a X --deck-b Y           one matchup, N games
##   gauntlet  --deck-a X --gauntlet LIST|DIR  A vs each opponent, N each
##   matrix    --matrix LIST|DIR               round-robin: every pair, N each
##
## Parallelism: games fan out over WorkerThreadPool across all CPU cores
## (cap with --jobs). Each game is an independent MtgGame + two AiPlayers
## seeded as base_seed + game_index, and each thread writes only its own
## slot of a preallocated results array — no locks needed, and a given
## --seed reproduces every game bit-for-bit at any job count.
##
## Elo: unless --no-elo, every run folds its results into the persistent
## text ledger (default decks/ratings.txt — see EloLedger), so a deck's
## rating accumulates across runs.
##
## EVERY DUEL SETTING THE BATTLE-SETUP SCREEN CAN CHOOSE IS REACHABLE FROM
## HERE. That is a rule, not a nicety: a setting only the GUI can set is a
## setting that can only ever be exercised by a human clicking, and this is
## the tool that runs a thousand games. `--lives`, `--ante`, `--names`,
## `--format`, `--group`, `--mulligan`, `--rules` and `--rule` were added
## for that reason; `--seed` was already the same knob as
## `DuelConfig.rng_seed`.
##
## ONE OF THE SETUP SCREEN'S CHOICES IS DELIBERATELY NOT HERE:
##   * `<random deck>` — the Lab is told which decks to compare; picking
##     one at random is the opposite of the question it answers.
##
## `&Best of:` and `Side&board between duels` used to be on that list, with
## the reason that a best-of-N between two FIXED decks is N independent
## duels whose match win rate is a closed-form function of the duel win
## rate this already reports. [AiSideboard] is what made them worth
## wiring: with it the decks are no longer fixed — duel 2 is played with a
## deck chosen against what duel 1 showed — and `--best-of 3 --sideboard
## on` against `--sideboard off` on the same seed is the experiment that
## says whether the heuristic (or the sideboard) is any good.
##
## DEFAULTS NEVER MOVE. Every flag above defaults to what this script did
## before it existed, because the determinism check — same seed, same
## win/loss split, byte-identical matchups.csv — is how this project proves
## an engine change was safe, and a moved default silently invalidates it.
##
## AND THE OUTPUT HAS TWO CHANNELS, for the same reason. stdout is the
## INSTRUMENT: the report, and byte for byte the text that lands in
## report.txt. stderr is the HUMAN: the banner, the progress bar, warnings
## and hints, decorated only when stderr is a terminal (deck_lab.sh finds
## out and passes DECK_LAB_TTY; see [LabConsole]). So `deck_lab.sh ... >
## run.log 2>&1` — what a script or a measuring agent writes — contains no
## artwork, no bar and no escape code, and nobody has to remember a flag
## for that to be true. The section at the foot of this file holds it.

## `--format` values -> [DeckFormat]'s own names. Short spellings because
## `--format "Tournament (Type 1.5)"` on a command line is a punishment;
## `@DECKTYPES` (`Program/Text.res:890`) spells the same five without the
## parentheses, which is where `type1` / `type1.5` come from.
const FORMAT_FLAGS := {
	"unrestricted": DeckFormat.UNRESTRICTED,
	"wild": DeckFormat.WILD,
	"type1": DeckFormat.RESTRICTED_T1,
	"restricted": DeckFormat.RESTRICTED_T1,
	"type1.5": DeckFormat.TOURNAMENT_T15,
	"tournament": DeckFormat.TOURNAMENT_T15,
	"highlander": DeckFormat.HIGHLANDER,
}

## `--group` values -> [DeckGroups]' headings. One flag per heading, in
## the headings' own order; the five after `planeswalkers` arrived with
## the 2026-09-02 port of every deck group the mtg.wiki page lists
## (`docs/decks-1997.md`, `decks/1997/<group>/`), and `tournament` /
## `extended_community` the same day, when the non-MicroProse decks were
## split three ways (`decks/tournament/`, `decks/community/`,
## `decks/extended_community/`).
const GROUP_FLAGS := {
	"originals": DeckGroups.ORIGINALS,
	"ancients": DeckGroups.ANCIENTS,
	"planeswalkers": DeckGroups.PLANESWALKERS,
	"coyote_tex": DeckGroups.COYOTE_TEX,
	"kevin_bane": DeckGroups.KEVIN_BANE,
	"other": DeckGroups.OTHER,
	"starter": DeckGroups.STARTER,
	"tournament": DeckGroups.TOURNAMENT,
	"community": DeckGroups.COMMUNITY,
	"extended_community": DeckGroups.EXTENDED_COMMUNITY,
	"user": DeckGroups.USER,
}

const HELP := """Deck Lab — headless AI-vs-AI deck testing for Shandalar
========================================================
Plays whole duels with no graphics, on every core the machine has, and
reports each win rate with the interval that says how much of it to
believe. The long-form manual is DeckLab/README.md.

USAGE
  DeckLab/deck_lab.sh --deck-a DECK --deck-b DECK       [options]  (duel)
  DeckLab/deck_lab.sh --deck-a DECK --deck-b random     [options]  (vs the field)
  DeckLab/deck_lab.sh --deck-a DECK --gauntlet LIST|DIR [options]  (gauntlet)
  DeckLab/deck_lab.sh --matrix LIST|DIR                 [options]  (matrix)
  DeckLab/deck_lab.sh -h | --help

QUICK START — copy one of these
  # my brew against one known deck, two minutes, nothing recorded
  DeckLab/deck_lab.sh --deck-a decks/my_brew.deck \\
                      --deck-b decks/big_green.deck --games 200 --no-elo

  # my brew against the five shipped styles, one number per opponent
  DeckLab/deck_lab.sh --deck-a decks/my_brew.deck --gauntlet decks/ --games 1000

  # the whole shipped gauntlet against itself, with a heatmap
  DeckLab/deck_lab.sh --matrix decks/ --games 2000

DECK ARGUMENTS ARE PATHS, NOT DECK NAMES
  `--deck-a decks/big_green.deck`, not `--deck-a "Big Green"`. A path is
  tried as typed and then under decks/, so `--deck-a big_green.deck`
  works too; a name that matches no file is refused with a list of the
  decks it looked most like. `ls decks/` is the shipped five.

  DECK is a .deck/.dec file — the community (Dojo/Apprentice) format:
  '4 Lightning Bolt' lines, '//' comments, '4x' counts, 'SB:' sideboard
  lines — or an ORIGINAL MicroProse .dck file (used interchangeably;
  convert between them with ./deck_convert.sh). Sideboards parse and
  validate; the AI only SWAPS with them in a best-of-N match with
  `--sideboard on` (see DUEL SETTINGS). LIST is comma-separated deck
  files; DIR is a directory whose *.deck/*.dec/*.dck files become the
  pool (see --group for the 300+ decks filed in its subfolders).

  The literal word `random` may be given instead of a path, for either
  side. It is the setup screen's own `<random deck>` entry: a REAL deck
  drawn from the pool, freshly per game, so `--deck-b random --games 500`
  is 500 games against the field rather than 500 against one opponent.
  `--deck-pool` says what the field is; the draw is seeded, so a run
  replays which decks it was dealt. Only one side may be random.

MODES
  duel      A vs B, --games N.
  gauntlet  A vs each opponent deck, --games N per matchup, plus A's
            record across the whole gauntlet.
  matrix    every deck vs every other deck (round robin), --games N per
            pair, plus a standings table and a win-rate heatmap
            (matrix.svg).

OPTIONS
  --deck-a DECK       The deck under test (duel/gauntlet modes).
  --deck-b DECK       Single opponent (duel mode).
  --gauntlet LIST|DIR Opponent pool (gauntlet mode).
  --deck-pool LIST|DIR What `random` draws from (default: decks/). The
                      deck under test is excluded, and --group narrows it
                      the same way it narrows --gauntlet.
  --matrix LIST|DIR   Round-robin pool of >= 2 decks (matrix mode).
  --games N           Games per matchup (default 1000). See HOW MANY
                      GAMES DO I NEED below — it is the flag that decides
                      whether the answer means anything.
  --seed N            Base RNG seed (default 1). Same seed + same decks =
                      identical results, regardless of --jobs. Quote it
                      whenever you quote a number.
  --jobs N            Worker threads INSIDE one process (default 4).
                      More is not faster: measured on 22 idle cores, one
                      duel runs at 12 games/s on 1 thread, 18 on 4, and
                      4.4 on 22. --jobs 0 means every core, and is slower.
  --procs N           Separate worker PROCESSES (default 8 once a run is
                      big enough to pay for starting them; 1 turns it
                      off). This is where the speed is: the same
                      1,000-game duel takes 19.0s in one process and 8.7s
                      across eight, and writes the same matchups.csv
                      byte for byte. Each process is a whole engine
                      holding the card pool, about 235 MB, so the default
                      stops at eight; raise it if you have the RAM.
  --profile-a NAME    AI skill piloting deck A / the row deck:
  --profile-b NAME    apprentice|magician|sorcerer|wizard (default wizard
                      both — skill-neutral deck comparison).
  --out DIR           Output directory (default DeckLab/results/run_<stamp>,
                      printed before the run starts).
  --no-svg            Skip chart generation.
  --no-elo            Do NOT update the Elo ledger. Use it for every rerun
                      and experiment: a repeated seed re-counts the same
                      games into a deck's lifetime record.
  --elo-file PATH     Ledger location (default decks/ratings.txt).
  --quiet             No banner, no progress bar — errors only. (Both are
                      already silent when stderr is not a terminal.)
  --no-banner         Keep the progress bar, drop the artwork. Or export
                      DECK_LAB_NO_BANNER=1 once and forget it.
  -h, --help          This text.

DUEL SETTINGS (everything the battle-setup screen can choose)
  --lives A,B         Starting life per seat (default 20,20). One number
                      sets both.
  --ante N            Stake N cards each before the deal — the original's
                      `&Ante` (default 0, i.e. not for ante, so nothing
                      programmatic loses a card it did not ask to).
  --names A,B         Seat names in the log (default SeatZero,SeatOne).
  --format NAME       Require a deck format: unrestricted | wild |
                      type1 | type1.5 | highlander. A deck that does not
                      meet it FAILS AT PARSE TIME, naming the card.
  --group NAME        Keep only decks of one group when a DIR is expanded:
                      originals | ancients | planeswalkers | coyote_tex |
                      kevin_bane | other | starter | tournament |
                      community | extended_community | user.
                      With --group set, a DIR is walked INTO its
                      subfolders (decks/1997/<group>/, decks/tournament/,
                      decks/community/, decks/extended_community/);
                      without it a DIR is its own files only, so the
                      default field stays the five starter decks. A DIR
                      deck that holds proxies is skipped with a note on
                      stderr (a named file is never skipped).
  --mulligan on|off   Offer the Shandalar mulligan before turn 1 — a hand
                      with no land or all land, plus the courtesy offer
                      (default OFF; see DeckLab/README.md for why, and for
                      the measured cost of leaving it off).
  --best-of N         The original's `&Best of:` — play MATCHES of up to N
                      duels instead of single duels, N = 1, 3 or 5
                      (default 0 = `&Free play`, one duel; 1 is the
                      gauntlet's `Best of &One`, a match that keeps a
                      record where free play keeps none). --games counts
                      matches, and every reported figure is a MATCH
                      figure. The loser of a duel is on the play in the
                      next one.
  --sideboard on|off  `Side&board between duels`: let each AI seat swap
                      cards with its own sideboard between the duels of a
                      match, judged only on what it SAW the opponent play
                      (engine/ai/ai_sideboard.gd). Needs --best-of 3 or 5;
                      default off. How many cards a seat may move is the
                      AI profile's own `sideboard_swaps`, so
                      --profile-a/--profile-b change this too, and
                      apprentice never sideboards at all.
  --rules NAME        fifth | modern (default modern). `fifth` turns every
                      rules fork to the 1997 answer, so a whole pool can
                      be replayed under the ruleset the original played.
  --rule KEY=on|off   Override one fork on top of --rules. Repeatable.
                      Keys: mana_burn, attackers_revocable,
                      tapped_artifacts_stop, life_checked_at_phase_end,
                      pool_empties_on_attack, damage_prevention_window,
                      free_damage_assignment.

HOW MANY GAMES DO I NEED
  Every win rate is printed with its Wilson 95% interval, and THE
  INTERVAL, NOT THE PERCENTAGE, is what you may quote. At an even win
  rate, per matchup:

       games      95% interval     the smallest edge it can see
         100        +-9.6 points     60/40
         200        +-6.9 points     57/43
         500        +-4.4 points     54/46
       1,000        +-3.1 points     53/47
      10,000        +-1.0 point      51/49

  So a 200-game run reading 44.0% has NOT found a worse deck: 50% is
  inside [37.3%, 50.9%]. Each run says in words how many of its matchups
  are DECIDED (interval clear of 50%) and how many are still even —
  believe that line rather than the headline percentage. Comparing two
  runs means the same --seed, decks, profiles, duel settings and engine;
  anything else is a different experiment.

WHAT GOES WHERE
  stdout   the run's plan, the report (byte for byte the text that lands
           in report.txt) and the line naming the files written. Never
           anything decorative, and never an escape code.
  stderr   the banner, the progress bar, warnings, errors and hints —
           and the first two not at all when stderr is not a terminal.
           So `deck_lab.sh ... > run.log` keeps the log clean with the
           banner still on screen, and `... > run.log 2>&1`, which is
           what a script writes, gets no decoration anywhere.
  --out    report.txt, results.json, matchups.csv — always.
           winrates.svg, turns.svg — duel/gauntlet (unless --no-svg).
           matrix.svg             — matrix mode (unless --no-svg).
           The Elo ledger lives at --elo-file and persists across runs.

EXIT CODES
  0  the run finished and every output file was written
  1  the run broke (a worker thread stopped, a file could not be written)
  2  the command line was wrong (bad flag, missing or illegal deck)
  3  no Godot binary (deck_lab.sh; set GODOT=/path/to/godot)

ENVIRONMENT
  GODOT               Which Godot to run (default ../tools/godot, then PATH).
  NO_COLOR            Set to anything: never colour the output.
  DECK_LAB_NO_BANNER  Set to 1: never print the banner.

EXAMPLES
  DeckLab/deck_lab.sh --deck-a white_knights.deck --deck-b big_green.deck --games 10000
  DeckLab/deck_lab.sh --deck-a my_brew.deck --gauntlet decks/ --games 10000 --jobs 8
  DeckLab/deck_lab.sh --deck-a my_brew.deck --gauntlet decks/ --group originals --games 1000
  DeckLab/deck_lab.sh --matrix decks/ --games 2000
  DeckLab/deck_lab.sh --deck-a a.deck --deck-b b.deck --profile-b apprentice --no-elo
  DeckLab/deck_lab.sh --deck-a my_brew.deck --deck-b random --games 2000
  DeckLab/deck_lab.sh --deck-a my_brew.deck --deck-b random --deck-pool tier1/ --games 2000
  DeckLab/deck_lab.sh --deck-a a.deck --deck-b b.deck --best-of 3 --sideboard on --no-elo
"""

const PROFILES := ["apprentice", "magician", "sorcerer", "wizard"]

## THE FIELD — `--deck-b random` (DeckLab/README.md). The setup screen's
## `<random deck>` row is the same idea in the GUI, and this is
## deliberately the same MECHANISM and not a second one: the pick runs
## through [method SetupScreen.random_deck_path], which is static and
## RNG-injected precisely so both callers share it. A CLI value cannot be
## the GUI's own `<random deck>` string (a shell eats the angle brackets),
## so the TOKEN is the bare word and the REPORTS use the GUI's label.
const RANDOM_TOKEN := "random"
const RANDOM_LABEL := SetupScreen.RANDOM_DECK
## Where the field comes from when `--deck-pool` is not given.
const DEFAULT_POOL := "res://decks/"


## Is this deck argument the field rather than a path? Case-insensitive,
## because `--deck-b Random` is obviously the same request.
static func is_random(deck_arg: String) -> bool:
	return deck_arg.to_lower() == RANDOM_TOKEN


## The file names of every deck named on the command line — the decks
## under test, which the field must not contain.
static func decks_under_test(opts: Dictionary) -> PackedStringArray:
	var named := PackedStringArray()
	if not is_random(opts.deck_a):
		named.append(String(opts.deck_a).get_file())
	for opponent in opts.opponents:
		if not is_random(opponent):
			named.append(String(opponent).get_file())
	return named


## NO DECK UNDER TEST IS IN ITS OWN FIELD, whichever side it sits on.
## `_expand_pool` can only drop one name (that is `--gauntlet`'s own
## exclusion, and it drops `--deck-a`), so with `--deck-a random` the deck
## to drop is on the OTHER side — which is how `Blue Skies vs the field`
## first measured Blue Skies against a field containing Blue Skies.
## Filtering by file name here holds in both directions, and for a
## `--gauntlet` list too.
static func without_decks_under_test(paths: Array,
		named: PackedStringArray) -> Array:
	var out: Array = []
	for path in paths:
		if not named.has(String(path).get_file()):
			out.append(path)
	return out


## WHOSE WIN RATE the per-deck breakdown's column is.
## [method SimStats.summarize] always reports the pair's ROW deck, so when
## the field is the row the number belongs to the deck on the line, and
## when it is the column it belongs to the deck under test. Saying
## "<A>'s win rate against each" in both cases printed every figure
## inverted for `--deck-a random`.
static func field_caption(field_is_row: bool, against: String) -> String:
	if field_is_row:
		return "each deck's win rate against %s" % against
	return "%s's win rate against each" % against

var _tasks: Array = []      # per-game work orders
var _results: Array = []    # per-game records, index-matched to _tasks
## Games finished, for the progress bar. Written by every worker thread
## under [member _progress_lock] and read by the main thread — the run's
## only shared mutable state besides the results array, and deliberately
## something no result is computed from.
var _games_done := 0
var _progress_lock := Mutex.new()
## Terminal chrome (see the section at the foot of this file).
var _quiet := false
var _banner_wanted := true
var _progress_open := false
var _last_logged := 0.0
## The duel settings, resolved once and READ ONLY by the worker threads
## (which write nothing but their own results slot, so this stays as
## lock-free as the rest of the run).
var _duel_opts: Dictionary = {}


func _initialize() -> void:
	quit(exit_code_of(_main(OS.get_cmdline_user_args())))


## `_main` is typed `-> int`, but a runtime error inside it (a nil in
## the aggregation, a record a worker never wrote) unwinds it to NULL,
## and `var code := _main()` then held a 0 — a crashed run that exited 0
## and looked like a clean one. Null is exit 1.
static func exit_code_of(main_result: Variant) -> int:
	if main_result == null:
		printerr("deck_lab: the run stopped on an error (see above); no result")
		return 1
	return int(main_result)


## How many of the per-game slots a worker thread never filled. An error
## on a worker aborts `_run_one_game` before it writes `_results[index]`,
## and `SimStats.summarize` then threw on the null — which is one way
## `_main` unwound to a null exit code.
static func missing_records(results: Array) -> int:
	var missing := 0
	for record in results:
		if record == null:
			missing += 1
	return missing


func _main(argv: PackedStringArray) -> int:
	# THE WORKER ENTRY, first and silent. A fanned-out run re-invokes this
	# same script once per slice; the child reads a task list, plays it,
	# writes the records back and exits. It never parses the real options,
	# never prints and never writes a report — the PARENT still does all
	# of the aggregation, which is what keeps a fanned-out run identical
	# to an in-process one.
	if argv.size() >= 3 and argv[0] == WORKER_FLAG:
		return _run_worker(argv[1], argv[2])
	var opts := _parse_args(argv)
	_quiet = bool(opts.get("quiet", false))
	_banner_wanted = not bool(opts.get("no_banner", false)) \
		and OS.get_environment(LabConsole.NO_BANNER_ENV) != "1"
	if opts.has("help"):
		_banner()
		# THE HELP GOES TO stdout, the banner to stderr: `deck_lab.sh
		# --help | less` is then the switch reference and nothing else.
		print(HELP)
		return 0
	if opts.has("error"):
		# NO ARTWORK ON A FAILURE. Somebody who mistyped a flag wants the
		# refusal and the way out of it, on the first line, not a logo.
		printerr("deck_lab: %s" % opts.error)
		_usage_hint(argv.is_empty())
		return 2
	_banner()

	CardRegistry.ensure_loaded()
	# ---- load the deck pool and build the pair list per mode ----
	var decks: Array[DeckList] = []
	var pairs: Array = []   # [row_deck_index, col_deck_index]
	# THE FIELD: which slot of `decks` is the `<random deck>` placeholder
	# (-1 for none), and the real decks it draws from.
	var random_index := -1
	var field: Array[DeckList] = []
	## Index-matched to [code]field[/code]. The pick is made on the PATHS
	## because they are unique by construction and two deck FILES may
	## carry the same `name:`.
	var field_paths: Array[String] = []
	if opts.matrix_pool.is_empty():
		var deck_a: DeckList = null
		if is_random(opts.deck_a):
			deck_a = _field_placeholder()
			random_index = 0
		else:
			deck_a = _load_deck(opts.deck_a, opts.format)
		if deck_a == null:
			return 2
		decks.append(deck_a)
		for deck_path in opts.opponents:
			var deck: DeckList = null
			if is_random(deck_path):
				deck = _field_placeholder()
				random_index = decks.size()
			else:
				deck = _load_deck(deck_path, opts.format)
			if deck == null:
				return 2
			decks.append(deck)
			pairs.append([0, decks.size() - 1])
		if random_index >= 0:
			# LOADED AND VALIDATED UP FRONT, all of it, before a single
			# game runs — a pool deck that does not parse, or that the
			# `--format` refuses, must fail on the command line and not
			# 400 games into a run that has already printed a header.
			var source: String = opts.deck_pool if opts.deck_pool != "" \
				else DEFAULT_POOL
			# NO DECK UNDER TEST IS IN ITS OWN FIELD, whichever side it
			# sits on. `_expand_pool` can only drop one name (it is
			# `--gauntlet`'s own exclusion), and with `--deck-a random`
			# the deck to drop is on the OTHER side — which is how
			# `Blue Skies vs the field` first measured Blue Skies against
			# a field containing Blue Skies. Every named deck is filtered
			# out here instead, so the rule holds in both directions and
			# for a `--gauntlet` list too.
			var paths := without_decks_under_test(
				_expand_pool(source, ""), decks_under_test(opts))
			if paths.is_empty():
				printerr("deck_lab: no decks in the field '%s'%s" % [source,
					"" if _group_filter == "" else " for --group " + _group_filter])
				return 2
			for path in paths:
				var deck := _load_deck(path, opts.format)
				if deck == null:
					return 2
				field.append(deck)
				field_paths.append(path)
	else:
		for deck_path in opts.matrix_pool:
			var deck := _load_deck(deck_path, opts.format)
			if deck == null:
				return 2
			decks.append(deck)
		if decks.size() < 2:
			printerr("deck_lab: matrix mode needs at least 2 decks")
			return 2
		for i in decks.size():
			for j in range(i + 1, decks.size()):
				pairs.append([i, j])

	# THE DEFAULT IS NOT EVERY CORE, and that is a measurement rather than
	# a preference. On a 22-core idle machine (load 0.52), the same 40-game
	# duel runs at 12.1 games/s on ONE job, peaks at 18.1 from two to four,
	# and collapses to 4.4 at twenty-two — a third of the speed of a single
	# thread (2026-09-05). Every long measurement this project has made was
	# paying that, because `--jobs 0` meant `get_processor_count()`.
	#
	# The cause is not this loop: the curve is identical on the unmodified
	# script, so it is the engine or the pool oversubscribing. Until that is
	# understood, the default is the measured plateau and `--jobs 0` still
	# means every core for anyone who wants it. Determinism is unaffected —
	# `matchups.csv` is byte-identical at every job count, which is what
	# made it safe to move.
	var jobs: int = opts.jobs if opts.jobs > 0 else mini(4, OS.get_processor_count())
	var mode := "matrix" if not opts.matrix_pool.is_empty() \
		else ("gauntlet" if pairs.size() > 1 else "duel")
	# WHERE THE RUN IS WRITING, DECIDED BEFORE IT STARTS — printed with
	# the plan, so a sweep interrupted after forty minutes still says
	# where its half of a result was going, and a bad --out fails now
	# rather than after the games.
	var out_dir: String = opts.out
	if out_dir == "":
		out_dir = "DeckLab/results/run_%d" % int(Time.get_unix_time_from_system())
	var made := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(out_dir))
	if made != OK and not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(out_dir)):
		printerr("deck_lab: cannot create the output directory '%s' (error %d)"
			% [out_dir, made])
		printerr("  --out takes a directory this user may write to.")
		return 1
	_keep_the_importer_out(out_dir)
	var unit := "games" if opts.best_of == MatchState.FREE_PLAY else "matches"
	print("Deck Lab (%s): %d deck(s), %d matchup(s) x %d %s, seed %d, %d thread(s)"
		% [mode, decks.size(), pairs.size(), opts.games, unit, opts.seed, jobs])
	# WHICH DECKS, BY NAME. "5 deck(s)" is not enough to know that the
	# folder expanded to what was meant — a --group typo that finds four
	# decks instead of forty-eight looks identical otherwise.
	print("decks: %s" % _deck_summary(decks))
	if random_index >= 0:
		print("field: %d deck(s) — %s" % [field.size(),
			", ".join(_deck_names(field))])
	print("total: %s %s   out: %s" % [
		LabConsole.commas(pairs.size() * opts.games), unit, out_dir])
	_duel_opts = {
		"lives": opts.lives, "ante": opts.ante, "names": opts.names,
		"mulligan": opts.mulligan, "rules": opts.rules,
		"rule_overrides": opts.rule_overrides,
		# THE MATCH PARAMETERS. `format` rides along because the sideboard
		# step has to keep a deck legal in the format the run required.
		"best_of": opts.best_of, "sideboard": opts.sideboard,
		"format": opts.format,
	}
	var settings_line := _settings_line(opts)
	if settings_line != "":
		print(settings_line)

	# ---- work list: alternate play/draw within each matchup ----
	for pair_index in pairs.size():
		for game_index in opts.games:
			var task_seed: int = opts.seed + pair_index * opts.games + game_index
			var row: DeckList = decks[pairs[pair_index][0]]
			var col: DeckList = decks[pairs[pair_index][1]]
			# WHICH DECK THE FIELD DEALT THIS GAME, "" when no side is the
			# field. Seeded from the GAME's own seed rather than from one
			# RNG walked down the list, so game i faces the same opponent
			# however many games the run asks for: --games 200 and
			# --games 2000 share their first 200 pairings, and the longer
			# run is the shorter one plus more evidence. (True of the
			# FIRST matchup only — the seed carries `pair_index *
			# opts.games`, so a later pair's seeds move when --games
			# does. `random` is a duel-mode argument, so its pair is
			# always the first one.)
			var dealt := ""
			if random_index >= 0 and pairs[pair_index].has(random_index):
				var pick := RandomNumberGenerator.new()
				pick.seed = task_seed
				var chosen: DeckList = field[
					field_paths.find(SetupScreen.random_deck_path(field_paths, pick))]
				dealt = chosen.deck_name
				if pairs[pair_index][0] == random_index:
					row = chosen
				else:
					col = chosen
			_tasks.append({
				"pair": pair_index,
				"seed": task_seed,
				"a_on_play": game_index % 2 == 0,
				"deck_a": row.cards,
				"deck_b": col.cards,
				# READ-ONLY HERE, like the decks: a match DUPLICATES both
				# piles before it starts, because the sideboard step edits
				# them and these arrays belong to the shared DeckList that
				# every other task of this pairing is reading.
				"sb_a": row.sideboard,
				"sb_b": col.sideboard,
				"dealt": dealt,
				"profile_a": opts.profile_a, "profile_b": opts.profile_b,
			})
	_results.resize(_tasks.size())

	# ---- run, in parallel ----
	var started_at := Time.get_ticks_msec()
	# ---- fan out across PROCESSES when that is faster, which is nearly
	# always. Measured on an idle 22-core machine, 240 games: the thread
	# pool peaks at 18.1 games/s (four threads) and falls to 4.4 at
	# twenty-two, while four separate single-threaded PROCESSES do 61.3
	# and twenty do 155.5 — 8.6x the pool, still climbing. Whatever
	# serialises the work (the VM, the allocator, the pool itself) is
	# inside one process, and separate processes step around it.
	#
	# SAFE BECAUSE THE TASK LIST IS ALREADY DECIDED. Every seed is
	# computed above, before any game runs, so a slice played in another
	# process is the same game with the same rolls — proven rather than
	# assumed: a matchup run on its own writes a byte-identical
	# `matchups.csv` row to the same matchup inside a `--matrix` sweep.
	#
	# FALLS BACK RATHER THAN FAILING. If a child cannot be spawned (a
	# sandbox, no executable path, a full disk for the slice files), the
	# in-process pool below runs the same work and the only cost is time.
	var procs := _process_count(opts, _tasks.size())
	var fanned := procs > 1 and _fan_out(procs, unit, started_at)
	if not fanned:
		var group := WorkerThreadPool.add_group_task(
			_run_one_game, _tasks.size(), jobs, true, "deck_lab")
		# WAITED ON IN A POLLING LOOP RATHER THAN ONE BLOCKING CALL, so the
		# run can say how far along it is. A 10,000-game matchup is ten
		# minutes and a matrix sweep an hour; before this the tool printed a
		# header and then nothing at all, which is indistinguishable from a
		# hang — and this project has lost hours to exactly that ambiguity.
		# The wait itself is unchanged (the pool's own threads do the work,
		# and `wait_for_group_task_completion` still frees the group).
		_watch(group, _tasks.size(), unit, started_at)
	var elapsed := (Time.get_ticks_msec() - started_at) / 1000.0
	var missing := missing_records(_results)
	if missing > 0:
		printerr("deck_lab: %d of %d games produced no record — a worker thread stopped on an error (see above)"
			% [missing, _results.size()])
		return 1

	# ---- aggregate ----
	var per_pair_stats: Array = []
	var per_pair_records: Array = []
	for pair_index in pairs.size():
		var records: Array = []
		for i in _tasks.size():
			if _tasks[i].pair == pair_index:
				records.append(_results[i])
		per_pair_records.append(records)
		per_pair_stats.append(SimStats.summarize(records))

	# ---- the field, deck by deck ----
	# An aggregate `58.2% vs the field` is the number that was asked for,
	# but on its own it hides WHICH decks the field is made of and which
	# of them did the damage — and with a small field the aggregate is
	# just a weighted average of a handful of matchups. So the run also
	# reports the split, which costs nothing: every game already knows
	# the deck it was dealt.
	var field_rows: Array = []
	if random_index >= 0:
		var by_deck := {}
		for i in _tasks.size():
			var dealt: String = _tasks[i].dealt
			if dealt == "":
				continue
			if not by_deck.has(dealt):
				by_deck[dealt] = []
			by_deck[dealt].append(_results[i])
		var dealt_names: Array = by_deck.keys()
		dealt_names.sort()
		for dealt_name in dealt_names:
			field_rows.append({"name": dealt_name,
				"stats": SimStats.summarize(by_deck[dealt_name])})

	# ---- Elo ledger ----
	var elo_lines := PackedStringArray()
	if not opts.no_elo:
		var ledger := EloLedger.load_from(opts.elo_file)
		# THE PLACEHOLDER IS NOT A DECK, so it neither takes a rating nor
		# gives one: a `<random deck>` row in the ledger would be an Elo
		# for "the field", which changes meaning every time the field
		# does. Its games are recorded against the deck that really
		# played them, which is both true and more useful — a run against
		# the field rates every deck in the field.
		var rated: Array[DeckList] = []
		for deck in decks:
			if deck.deck_name != RANDOM_LABEL:
				rated.append(deck)
		if random_index >= 0:
			rated.append_array(field)
		var before := {}
		for deck in rated:
			before[deck.deck_name] = ledger.rating(deck.deck_name)
		for pair_index in pairs.size():
			var stats: Dictionary = per_pair_stats[pair_index]
			var row_deck: DeckList = decks[pairs[pair_index][0]]
			var col_deck: DeckList = decks[pairs[pair_index][1]]
			if row_deck.deck_name == RANDOM_LABEL \
					or col_deck.deck_name == RANDOM_LABEL:
				continue
			ledger.record_matchup(row_deck.deck_name, col_deck.deck_name,
				stats.a_wins, stats.b_wins)
		for row in field_rows:
			var stats: Dictionary = row["stats"]
			var opponent: String = decks[0].deck_name
			if random_index == 0:
				# The FIELD is deck A, so the dealt deck is the row and
				# the winrate already belongs to it.
				ledger.record_matchup(row["name"], decks[1].deck_name,
					stats.a_wins, stats.b_wins)
			else:
				ledger.record_matchup(opponent, row["name"],
					stats.a_wins, stats.b_wins)
		ledger.save()
		elo_lines.append("Elo (%s):" % opts.elo_file)
		for deck in rated:
			var old: float = before[deck.deck_name]
			var new := ledger.rating(deck.deck_name)
			elo_lines.append("  %-24s %7.1f -> %7.1f  (%+.1f)" % [
				deck.deck_name, old, new, new - old])

	# ---- report ---- (out_dir was resolved and created with the plan)
	var report := PackedStringArray()
	report.append("Deck Lab report (%s mode)" % mode)
	# THE NOUN FOLLOWS `--best-of`: with a match length set, every figure
	# in this report is a MATCH figure and calling them games would be a
	# lie. The default spelling is untouched, which is what keeps a
	# default run's report.txt reading as it always has.
	report.append("%s/matchup: %d   seed: %d   pilots: %s vs %s   %.1fs (%.0f %s/s)"
		% [unit, opts.games, opts.seed, opts.profile_a, opts.profile_b,
			elapsed, _tasks.size() / maxf(elapsed, 0.001), unit])
	# ONLY THE NON-DEFAULT SETTINGS, and only when there are any — so a
	# report from a default run reads exactly as the reports this tool
	# has always written. (The byte-for-byte determinism check is
	# matchups.csv alone: this file's second line carries the elapsed
	# time and results.json its "elapsed_seconds", so neither is
	# byte-stable between two runs of the same seed.)
	var settings_report := _settings_line(opts)
	if settings_report != "":
		report.append(settings_report)
	report.append("")
	var csv := PackedStringArray()
	csv.append("deck_a,deck_b,games,a_wins,b_wins,stalled,winrate,ci_low,ci_high,winrate_on_play,winrate_on_draw,avg_turns,median_turns")
	var json_matchups: Array = []
	for pair_index in pairs.size():
		var stats: Dictionary = per_pair_stats[pair_index]
		var row_name := decks[pairs[pair_index][0]].deck_name
		var col_name := decks[pairs[pair_index][1]].deck_name
		# THE DRAW COUNT ONLY APPEARS WHEN THERE IS ONE, for the same
		# reason results.json's "field" key does: a draw-free run must
		# still write the report this tool has always written, so that
		# a diff against a baseline report shows only the timing line.
		var drawn_note := "" if stats.draws == 0 else ", %d drawn" % stats.draws
		report.append("%-24s vs %-24s %s  CI [%s..%s]  (%d-%d, %d stalled%s)" % [
			row_name, col_name, SimStats.percent(stats.winrate.mid),
			SimStats.percent(stats.winrate.low).strip_edges(),
			SimStats.percent(stats.winrate.high).strip_edges(),
			stats.a_wins, stats.b_wins, stats.stalled, drawn_note])
		report.append("   on the play %s   on the draw %s   avg %.1f turns (median %d)" % [
			SimStats.percent(stats.winrate_on_play.mid),
			SimStats.percent(stats.winrate_on_draw.mid),
			stats.avg_turns, stats.median_turns])
		csv.append("%s,%s,%d,%d,%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%d" % [
			row_name.replace(",", " "), col_name.replace(",", " "),
			stats.games, stats.a_wins, stats.b_wins, stats.stalled,
			stats.winrate.mid, stats.winrate.low, stats.winrate.high,
			stats.winrate_on_play.mid, stats.winrate_on_draw.mid,
			stats.avg_turns, stats.median_turns])
		var json_stats := stats.duplicate()
		json_stats.erase("turns")
		# Same rule as the report line and as the "field" key below: a
		# `"draws": 0` on every matchup would rewrite every results.json
		# this tool has ever produced. matchups.csv keeps its columns for
		# the same reason — `games - a_wins - b_wins - stalled` is the
		# draw count there.
		if int(json_stats["draws"]) == 0:
			json_stats.erase("draws")
		json_stats["deck_a"] = row_name
		json_stats["deck_b"] = col_name
		json_matchups.append(json_stats)
	# THE READING OF THE MATCHUPS, not more matchups: the standings or
	# the gauntlet aggregate, and what a sample this size can see.
	# report.txt only — results.json and matchups.csv are read by other
	# tooling and their shape does not move.
	report.append_array(_reading_block(mode, opts, decks, pairs,
		per_pair_stats, unit))
	if not field_rows.is_empty():
		report.append("")
		var against: String = decks[1 if random_index == 0 else 0].deck_name
		report.append("the field, deck by deck (%s):"
			% field_caption(random_index == 0, against))
		for row in field_rows:
			var stats: Dictionary = row["stats"]
			report.append("  %-24s %s  CI [%s..%s]  (n=%d)" % [
				row["name"], SimStats.percent(stats.winrate.mid),
				SimStats.percent(stats.winrate.low).strip_edges(),
				SimStats.percent(stats.winrate.high).strip_edges(),
				stats.games])
	if not elo_lines.is_empty():
		report.append("")
		report.append_array(elo_lines)
	var report_text := "\n".join(report)
	print("\n" + report_text)
	_stall_warning(per_pair_stats, opts, unit)

	# ---- files ----
	var wrote_all := true
	wrote_all = _write(out_dir + "/report.txt", report_text + "\n") and wrote_all
	var results_json := {
		"mode": mode, "games_per_matchup": opts.games, "seed": opts.seed,
		"profile_a": opts.profile_a, "profile_b": opts.profile_b,
		"lives": opts.lives, "ante": opts.ante, "mulligan": opts.mulligan,
		"rules": opts.rules, "rule_overrides": opts.rule_overrides,
		"format": opts.format,
		"elapsed_seconds": elapsed, "matchups": json_matchups,
	}
	# SAME RULE AS THE "field" AND "draws" KEYS: present only when the run
	# actually used them, so a default run's results.json has exactly the
	# keys it has always had.
	if opts.best_of != MatchState.FREE_PLAY:
		results_json["best_of"] = opts.best_of
		results_json["sideboard"] = opts.sideboard
	# THE KEY ONLY EXISTS WHEN THERE IS A FIELD. An always-present
	# `"field": []` would change every results.json this tool has ever
	# written. (Only matchups.csv is compared byte for byte — see the
	# report header above for why this file and report.txt cannot be.)
	if not field_rows.is_empty():
		results_json["field"] = _field_json(field_rows)
	wrote_all = _write(out_dir + "/results.json",
		JSON.stringify(results_json, "  ") + "\n") and wrote_all
	wrote_all = _write(out_dir + "/matchups.csv", "\n".join(csv) + "\n") and wrote_all
	var chart_names := PackedStringArray(["report.txt", "results.json", "matchups.csv"])
	if not opts.no_svg:
		if mode == "matrix":
			var names: Array = []
			for deck in decks:
				names.append(deck.deck_name)
			var grid := {}
			for pair_index in pairs.size():
				var stats: Dictionary = per_pair_stats[pair_index]
				var decided: int = stats.a_wins + stats.b_wins
				if decided > 0:
					var winrate: float = float(stats.a_wins) / decided
					grid["%d,%d" % [pairs[pair_index][0], pairs[pair_index][1]]] = winrate
					grid["%d,%d" % [pairs[pair_index][1], pairs[pair_index][0]]] = 1.0 - winrate
			wrote_all = _write(out_dir + "/matrix.svg",
				SvgCharts.matrix_chart(names, grid)) and wrote_all
			chart_names.append("matrix.svg")
		else:
			var chart_rows: Array = []
			var histogram_rows: Array = []
			for pair_index in pairs.size():
				var label := decks[pairs[pair_index][1]].deck_name
				chart_rows.append({"label": label, "stats": per_pair_stats[pair_index]})
				histogram_rows.append({"label": label,
					"histogram": SimStats.turn_histogram(per_pair_records[pair_index])})
			wrote_all = _write(out_dir + "/winrates.svg",
				SvgCharts.winrate_chart(decks[0].deck_name, chart_rows)) and wrote_all
			wrote_all = _write(out_dir + "/turns.svg",
				SvgCharts.turns_chart(decks[0].deck_name, histogram_rows)) and wrote_all
			chart_names.append_array(["winrates.svg", "turns.svg"])
	if not wrote_all:
		printerr("deck_lab: not every file of %s was written (see above); the run is not a result" % out_dir)
		return 1
	print("\nwrote %s/{%s}" % [out_dir, ", ".join(chart_names)])
	return 0


## One work order, run on a worker thread. Writes ONLY _results[index] and
## the shared finished-game counter (one lock, for the progress bar — see
## THE TERMINAL at the foot of this file). In free play the order is one
## duel; with `--best-of` it is a whole MATCH, and every figure in the
## record is then a match figure.
func _run_one_game(index: int) -> void:
	_results[index] = _play_task(_tasks[index])
	# THE ONLY LOCK IN THE RUN, held for one increment per game — and a
	# game is a tenth of a second of work, so the contention is nil. It
	# exists so the main thread can draw a progress bar; it touches
	# nothing any result is computed from, which is why a seeded run is
	# byte-for-byte what it was before the bar existed.
	_progress_lock.lock()
	_games_done += 1
	_progress_lock.unlock()



# ------------------------------------------------- the process fan-out --

## The hidden flag that turns this script into a worker. Not in `--help`
## and not in the flag tables: it is an implementation detail of a run,
## not something to type.
const WORKER_FLAG := "--worker"

## How many processes to fan out over when nobody says.
##
## EIGHT, and both halves of that are measured. Throughput keeps climbing
## past it (16 processes 145 games/s, 20 gives 155), but each process is
## a whole Godot holding the card pool — 235 MB, measured — so eight is
## about 1.9 GB, which fits on a machine that also has a browser open.
## Somebody with the RAM and the cores should pass `--procs 16`; that is
## what the flag is for.
const AUTO_PROCS := 8

## Below this there is nothing to gain: a process costs ~1.5 s to start
## and import, so a short run finishes in-process before a fan-out has
## even begun playing.
const FAN_OUT_FLOOR := 40


## How many worker processes this run should use. `--procs 1` turns the
## fan-out off; `--procs 0` (the default) decides from the size of the run.
func _process_count(opts: Dictionary, task_count: int) -> int:
	var asked := int(opts.get("procs", 0))
	if asked > 0:
		return asked
	if task_count < FAN_OUT_FLOOR:
		return 1
	return mini(AUTO_PROCS, maxi(1, OS.get_processor_count()))


## Play [member _tasks] in [param procs] child processes. Returns false if
## the fan-out could not start, in which case the caller runs the work
## in-process instead and nothing is lost but time.
func _fan_out(procs: int, unit: String, started_at: int) -> bool:
	var exe := OS.get_executable_path()
	if exe == "":
		return false
	var root := ProjectSettings.globalize_path("res://")
	var dir := OS.get_user_data_dir().path_join("deck_lab_fan_%d" % Time.get_ticks_usec())
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	# Contiguous slices, so a child's own indices are its slice offset plus
	# its position — the parent puts each record back exactly where the
	# in-process run would have.
	var per := int(ceil(float(_tasks.size()) / float(procs)))
	var slices: Array = []
	var pids: Array = []
	for p in procs:
		var lo := p * per
		if lo >= _tasks.size():
			break
		var hi := mini(lo + per, _tasks.size())
		var in_path := dir.path_join("slice_%d.json" % p)
		var out_path := dir.path_join("done_%d.json" % p)
		var payload := {"offset": lo, "duel": _duel_opts,
			"tasks": _tasks.slice(lo, hi)}
		var f := FileAccess.open(in_path, FileAccess.WRITE)
		if f == null:
			_clean_fan(dir, pids)
			return false
		f.store_string(JSON.stringify(payload))
		f.close()
		# `--no-header` on every child: without it each one greets the
		# terminal with Godot's version line and a fanned-out run opens
		# with eight identical banners (caught by running it, 2026-09-05).
		# The shell already passes it for the parent.
		var pid := OS.create_process(exe, ["--headless", "--no-header",
			"--path", root, "--script", "res://DeckLab/simulate.gd", "--",
			WORKER_FLAG, in_path, out_path])
		if pid <= 0:
			_clean_fan(dir, pids)
			return false
		pids.append(pid)
		slices.append({"lo": lo, "hi": hi, "out": out_path})

	# Wait, reporting as the slices land. A child writes its file once, at
	# the end, so progress is per SLICE rather than per game — coarser
	# than the in-process bar and honest about it.
	var done := 0
	while done < slices.size():
		done = 0
		for slice in slices:
			if FileAccess.file_exists(String(slice["out"])):
				done += 1
		if done < slices.size():
			_progress(done * per, _tasks.size(),
				(Time.get_ticks_msec() - started_at) / 1000.0, unit, procs)
			OS.delay_msec(200)
	for pid in pids:
		if OS.is_process_running(int(pid)):
			OS.kill(int(pid))

	# Read the records back into the places their tasks came from.
	for slice in slices:
		var text := FileAccess.get_file_as_string(String(slice["out"]))
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Array):
			_clean_fan(dir, [])
			return false
		var lo := int(slice["lo"])
		for i in (parsed as Array).size():
			_results[lo + i] = (parsed as Array)[i]
	_games_done = _tasks.size()
	_clean_fan(dir, [])
	return true


## Stop any children still running and remove the slice directory.
func _clean_fan(dir: String, pids: Array) -> void:
	for pid in pids:
		if OS.is_process_running(int(pid)):
			OS.kill(int(pid))
	var d := DirAccess.open(dir)
	if d != null:
		for file_name in d.get_files():
			d.remove(file_name)
	DirAccess.remove_absolute(dir)


## THE CHILD. Plays a slice and writes its records; says nothing, decides
## nothing, and never touches the report.
func _run_worker(in_path: String, out_path: String) -> int:
	var text := FileAccess.get_file_as_string(in_path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		printerr("deck_lab worker: cannot read %s" % in_path)
		return 1
	var payload: Dictionary = parsed
	_duel_opts = payload.get("duel", {})
	_tasks = payload.get("tasks", [])
	_results.resize(_tasks.size())
	for i in _tasks.size():
		var record := _play_task(_tasks[i])
		# `rng` is a RandomNumberGenerator — used inside a MATCH and never
		# read again afterwards, and not a thing JSON can carry.
		record.erase("rng")
		_results[i] = record
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("deck_lab worker: cannot write %s" % out_path)
		return 1
	f.store_string(JSON.stringify(_results))
	f.close()
	return 0

## The work order itself: one duel in free play, one whole MATCH with
## `--best-of`. Split out of [method _run_one_game] so that counting a
## finished game has exactly one place to happen.
func _play_task(task: Dictionary) -> Dictionary:
	if int(_duel_opts.get("best_of", MatchState.FREE_PLAY)) \
			!= MatchState.FREE_PLAY:
		return _run_one_match(task)
	# Seat 0 always starts; alternate which DECK sits there for play/draw
	# fairness, then map the winner back to deck A (the pair's row deck).
	var a_seat: int = 0 if task.a_on_play else 1
	var seat_decks := [task.deck_a, task.deck_b] if a_seat == 0 \
		else [task.deck_b, task.deck_a]
	var seat_profiles := [task.profile_a, task.profile_b] if a_seat == 0 \
		else [task.profile_b, task.profile_a]
	var duel := _play_duel(seat_decks, seat_profiles, int(task.seed),
		[null, null])
	# `drawn` IS NOT DERIVABLE FROM `a_won`. A draw (CR 104.4b — both
	# duelists losing at once) leaves `winner` at -1, so before this key
	# existed SimStats read the game as a win for deck B and the Elo
	# ledger charged deck A a loss for it. Rare but real: 1 game in 600 of
	# the shipped gauntlet, measured 2026-09-01.
	return {
		"a_won": duel["finished"] and int(duel["winner"]) == a_seat,
		"a_on_play": task.a_on_play,
		"turns": duel["turns"],
		"stalled": not duel["finished"],
		"drawn": duel["drawn"],
	}


## ONE DUEL, start to finish, on this thread. [param seat_decks] and
## [param seat_profiles] are index-matched to the SEATS (seat 0 starts);
## [param watchers] holds an [AiMatchMemory] per seat, or nulls in free
## play, and each is re-pointed at its seat before the duel because a
## match moves a deck between seats.
##
## Returns `{winner, turns, finished, drawn, rng}` — `rng` is the duel's
## own [RandomNumberGenerator], which is what the sideboard step between
## two duels of a match rolls on (CONTRIBUTING.md rule 7: no other source).
func _play_duel(seat_decks: Array, seat_profiles: Array, duel_seed: int,
		watchers: Array) -> Dictionary:
	var game := MtgGame.new()
	var names: Array = _duel_opts.get("names", ["SeatZero", "SeatOne"])
	var lives: Array = _duel_opts.get("lives", [20, 20])
	game.setup(seat_decks[0], seat_decks[1], String(names[0]), String(names[1]),
		int(lives[0]), int(lives[1]), duel_seed)
	var ai0 := AiPlayer.new(0, _profile(String(seat_profiles[0])))
	var ai1 := AiPlayer.new(1, _profile(String(seat_profiles[1])))
	game.set_agent(0, ai0)
	game.set_agent(1, ai1)
	for pid in 2:
		var memory: AiMatchMemory = watchers[pid]
		if memory != null:
			memory.pid = pid
			memory.watch(game)
	# THE RULES FORKS — the duel screen applies these from Settings; here
	# they come from --rules / --rule, so a whole pool can be replayed
	# under the 1997 ruleset instead of the modern one.
	game.rules.set_edition(String(_duel_opts.get("rules", "modern")))
	for key in _duel_opts.get("rule_overrides", {}):
		game.rules.set_fork(String(key), bool(_duel_opts["rule_overrides"][key]))
	# THE ANTE, staked between the shuffle and the deal — the duel screen's
	# own order (`DuelScreen._new_game`). Neither seat is human here, so
	# neither gets the player's basic-land exemption.
	var ante := int(_duel_opts.get("ante", 0))
	if ante > 0:
		for pid in 2:
			game.stake_ante(pid, ante, false)
	# THE OPENING. `game.start()` is exactly `deal_opening_hands()` then
	# `start_duel()`, so the two paths were never actually different — what
	# the Lab lacked was the MULLIGAN OFFER the duel screen makes between
	# them (`OpeningHand.run`). With --mulligan on, the AI branch of that
	# loop is reproduced here, in its order: first player first, twice
	# round, because "the other player has the option to do so as well".
	game.deal_opening_hands(7)
	if bool(_duel_opts.get("mulligan", false)):
		for _round in 2:
			for step in 2:
				var pid := 0 if step == 0 else 1
				if not game.may_mulligan(pid):
					continue
				var forced := game.hand_is_a_mulligan_hand(pid)
				if game.agents[pid].choose_mulligan(game, pid, forced):
					game.take_mulligan(pid)
				else:
					game.decline_mulligan(pid)
	game.start_duel(0)
	var finished := AiPlayer.play_out(game, ai0, ai1)
	return {
		"winner": game.winner,
		"turns": game.turn_number,
		"finished": finished,
		"drawn": finished and game.is_draw,
		"rng": game.rng,
	}


## ONE MATCH — the original's `&Best of:` (`Program/Text.res:2862`), which
## [MatchState] owns the rule for, played out headless.
##
## THREE THINGS MAKE A MATCH MORE THAN N DUELS, and all three are here:
##
##  * THE DECKS ARE COPIED. `task.deck_a` is the shared [DeckList]'s own
##    array, read right now by every other task of this pairing on other
##    threads; the sideboard step edits its deck, so a match works on
##    duplicates and nothing it does escapes this call.
##  * THE LOSER IS ON THE PLAY in the next duel — the tournament
##    convention, and the only reason a best-of-3 is not three
##    independent duels even without sideboarding. A drawn duel leaves it
##    where it was.
##  * BETWEEN DUELS, each seat SIDEBOARDS (with `--sideboard on`), on what
##    it saw and on nothing else. Rolls come from the finished duel's own
##    RNG, so a seeded match still replays line for line.
##
## Everything below indexes by DECK (0 = deck A, the pair's row deck), and
## converts to seats only where the engine needs one — a match moves a
## deck between seats and mixing the two indexes is the bug this note
## exists to prevent.
func _run_one_match(task: Dictionary) -> Dictionary:
	var sideboarding := bool(_duel_opts.get("sideboard", false))
	var format := String(_duel_opts.get("format", ""))
	if format == "":
		format = DeckFormat.UNRESTRICTED
	var deck_cards := [(task.deck_a as Array).duplicate(),
		(task.deck_b as Array).duplicate()]
	var boards := [(task.sb_a as Array).duplicate(),
		(task.sb_b as Array).duplicate()]
	var profiles := [String(task.profile_a), String(task.profile_b)]
	var memories := [AiMatchMemory.new(0), AiMatchMemory.new(1)]
	var state := MatchState.new()
	state.best_of = int(_duel_opts.best_of)
	# The match carries ONE seed and each duel draws its own from it, in
	# order — [MatchScreen]'s own rule, so a duel in the middle of a match
	# is reproducible as that duel of that match.
	var seeder := RandomNumberGenerator.new()
	seeder.seed = task.seed
	var a_on_play := bool(task.a_on_play)
	var turns_total := 0
	var duels := 0
	var stalled := false
	while not state.is_over():
		var a_seat := 0 if a_on_play else 1
		var seat_decks := [deck_cards[0], deck_cards[1]] if a_seat == 0 \
			else [deck_cards[1], deck_cards[0]]
		var seat_profiles := [profiles[0], profiles[1]] if a_seat == 0 \
			else [profiles[1], profiles[0]]
		var watchers := [null, null]
		watchers[a_seat] = memories[0]
		watchers[1 - a_seat] = memories[1]
		var duel := _play_duel(seat_decks, seat_profiles, seeder.randi() | 1,
			watchers)
		duels += 1
		turns_total += int(duel["turns"])
		if not duel["finished"]:
			# A stalled duel cannot be scored, so neither can the match.
			stalled = true
			break
		var deck_winner := -1
		if not duel["drawn"] and int(duel["winner"]) >= 0:
			deck_winner = 0 if int(duel["winner"]) == a_seat else 1
		state.record(deck_winner)
		if deck_winner >= 0:
			a_on_play = deck_winner == 1
		for d in 2:
			(memories[d] as AiMatchMemory).end_duel()
		if sideboarding and not state.is_over():
			for d in 2:
				AiSideboard.sideboard(memories[d], deck_cards[d], boards[d],
					_profile(profiles[d]), duel["rng"], format)
	return {
		"a_won": not stalled and state.winner() == 0,
		"a_on_play": task.a_on_play,
		# The match's own length, in turns per duel — the figure the turn
		# histogram is drawn from, and the only one of these that is not a
		# match figure, because "a match took 34 turns" is not a number
		# anybody reads.
		"turns": int(round(float(turns_total) / maxi(duels, 1))),
		"stalled": stalled,
		"drawn": not stalled and state.winner() == -1,
	}


static func _profile(profile_name: String) -> AiProfile:
	match profile_name:
		"apprentice": return AiProfile.apprentice()
		"magician": return AiProfile.magician()
		"sorcerer": return AiProfile.sorcerer()
		_: return AiProfile.wizard()


## Load one deck, and — when [param format] is set — REFUSE it here rather
## than playing a thousand games with an illegal deck. Parse time is the
## only place a format refusal is any use.
##
## A DECK HOLDING PROXIES IS REFUSED HERE TOO, and by name, exactly as
## `--format` refuses. The Lab is a door into a duel like any other
## ([ProxyCard]'s class doc lists them), and it is the door where getting
## it wrong is worst: a strict load already drops an unresolvable name, so
## without this the Lab would happily play a thousand games with a deck
## silently short of cards and report the win rate as if it meant
## something. The strict load below is what stops that; this is what
## EXPLAINS it, because "unknown/unimplemented card" is a parse complaint
## and "this deck is proxies, you cannot duel with it" is the answer.
func _load_deck(path: String, format := "") -> DeckList:
	var tries := [path, "decks/" + path, "res://decks/" + path]
	for candidate in tries:
		if FileAccess.file_exists(candidate):
			var deck := DeckList.load_file(candidate)
			if not deck.errors.is_empty():
				var lenient := DeckList.load_file(candidate, false)
				var proxied := ProxyCard.refusal_for(lenient.cards,
					lenient.sideboard)
				if proxied != "":
					printerr("deck_lab: %s cannot be played:" % candidate)
					printerr("  " + proxied)
					return null
			if deck.errors.is_empty():
				if format != "":
					# Sideboard included: it is part of the deck for
					# legality even though the Lab never swaps it in.
					var refusal := DeckFormat.legal(deck.cards, format,
						deck.sideboard)
					if refusal != "":
						printerr("deck_lab: %s does not meet the format:" % candidate)
						printerr("  " + refusal)
						return null
				return deck
			printerr("deck_lab: problems in '%s':" % candidate)
			for problem in deck.errors:
				printerr("  " + problem)
			# WHAT TO DO ABOUT IT. A card the pool does not implement yet
			# is the usual cause, and it is not the same complaint as a
			# typo — one is fixed by editing the list, the other by
			# waiting for the card. Neither is obvious from "unknown
			# card", and the converter is deliberately lenient.
			printerr("  the Lab plays IMPLEMENTED cards only, so a deck may parse")
			printerr("  everywhere else and still be refused here. ./deck_convert.sh")
			printerr("  converts such a deck without complaint; editing the list is")
			printerr("  the fix for a misspelling (names must be exact and printed).")
			return null
	_deck_not_found(path, tries)
	return null


## THE SINGLE MOST COMMON MISTAKE THIS TOOL SEES, and until now it was
## answered with a list of three paths that did not exist. A deck
## argument is a PATH (`decks/big_green.deck`), not a deck's name, and the
## three things a reader needs are: that fact, the nearest real files, and
## what a folder does instead. All three are here.
func _deck_not_found(path: String, tried: Array) -> void:
	printerr("deck_lab: deck file not found: '%s'" % path)
	printerr("  looked for: %s" % ", ".join(PackedStringArray(tried)))
	var pool := _every_shipped_deck()
	var near := suggest_decks(path, pool)
	if not near.is_empty():
		printerr("  did you mean:")
		for candidate in near:
			printerr("      %s" % candidate)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		printerr("  '%s' is a FOLDER: a folder is a pool, not a deck —" % path)
		printerr("      --gauntlet %s   (deck A against each of them)" % path)
		printerr("      --matrix %s     (every deck against every other)" % path)
		return
	printerr("  deck arguments are PATHS to a deck file, not deck names:")
	printerr("      --deck-a decks/big_green.deck      yes")
	printerr("      --deck-a \"Big Green\"               no")
	var shipped := 0
	for candidate in pool:
		if not candidate.trim_prefix("decks/").contains("/"):
			shipped += 1
	printerr("  `ls decks/` lists the %d decks in the folder itself; %d more are in"
		% [shipped, pool.size() - shipped])
	printerr("  its subfolders, reached with --group (see --help).")


## THE "DID YOU MEAN" behind a bad deck path, as a pure function of what
## was typed and what exists — so a test can pin it.
##
## Matching is on the FILE NAME without its extension, with spaces,
## dashes and underscores treated alike: `"Big Green"`, `big-green`,
## `big_green` and `BIG_GREEN.DECK` all find `decks/big_green.deck`.
## That is not indulgence — the name a person has to type is the one they
## last saw in a REPORT, where it is spelled `Big Green`.
static func suggest_decks(typed: String, pool: PackedStringArray,
		limit := 3) -> PackedStringArray:
	var by_key := {}
	var keys := PackedStringArray()
	for candidate in pool:
		var key := deck_key(String(candidate))
		if not by_key.has(key):
			by_key[key] = []
			keys.append(key)
		(by_key[key] as Array).append(String(candidate))
	var out := PackedStringArray()
	for key in LabConsole.closest(deck_key(typed), keys, limit):
		for candidate in by_key[key]:
			if out.size() < limit:
				out.append(String(candidate))
	return out


## A deck path reduced to the thing worth comparing: its file name, no
## extension, no case, and no difference between a space, a dash and an
## underscore.
static func deck_key(path: String) -> String:
	return path.get_file().get_basename().to_lower() \
		.replace("_", " ").replace("-", " ").strip_edges()


## Every deck file the project ships, for the "did you mean" above. Read
## from disk rather than a list, so a deck added tomorrow is suggested
## tomorrow. Sorted, so the suggestion order is stable.
func _every_shipped_deck() -> PackedStringArray:
	var found: Array = []
	# The subfolders too: `decks/1997/<group>/` and the community folders
	# hold 300+ decks, and a name typed from one of those is exactly the
	# case where a suggestion earns its keep.
	_collect_deck_paths("res://decks", found)
	found.sort()
	var out := PackedStringArray()
	for entry in found:
		out.append(String(entry).replace("res://", ""))
	return out


func _collect_deck_paths(dir_path: String, found: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_deck_paths(full, found)
		elif entry.ends_with(".deck") or entry.ends_with(".dec") \
				or entry.ends_with(".dck"):
			found.append(full)
		entry = dir.get_next()


## EVERY FLAG THAT TAKES A VALUE, and one line each saying what the value
## is. This table IS the parser's list — an argument that is not a key
## here is an unknown option — and it is what a refusal quotes, so
## `--games` with nothing after it answers its own question instead of
## sending the reader to --help:
##
##     deck_lab: --games needs a value  (--games N: games per matchup,
##     default 1000)
##
## `test_every_flag_is_documented` pins every key to a line in HELP, so a
## flag cannot be added quietly.
const FLAG_HINTS := {
	"--deck-a": "--deck-a PATH: the deck under test, e.g. decks/big_green.deck",
	"--deck-b": "--deck-b PATH: one opponent deck, or the word `random`",
	"--gauntlet": "--gauntlet LIST|DIR: opponents, comma-separated or a folder",
	"--matrix": "--matrix LIST|DIR: >= 2 decks to play a round robin",
	"--deck-pool": "--deck-pool LIST|DIR: what `random` draws from (default decks/)",
	"--games": "--games N: games per matchup, default 1000",
	"--seed": "--seed N: base RNG seed, default 1 — the same seed replays a run",
	"--jobs": "--jobs N: worker threads INSIDE one process, default 4 (0 = every core, which is slower — see --procs)",
	"--procs": "--procs N: separate worker processes, default 8 when the run is big enough (1 = none). Each is ~235 MB and about 8x the speed of threads",
	"--profile-a": "--profile-a NAME: apprentice|magician|sorcerer|wizard, default wizard",
	"--profile-b": "--profile-b NAME: apprentice|magician|sorcerer|wizard, default wizard",
	"--out": "--out DIR: where report.txt/results.json/matchups.csv are written",
	"--elo-file": "--elo-file PATH: the Elo ledger, default " + EloLedger.DEFAULT_PATH,
	"--lives": "--lives N or A,B: starting life per seat, default 20,20",
	"--ante": "--ante N: cards staked per seat before the deal, default 0",
	"--names": "--names A,B: the two seat names, default SeatZero,SeatOne",
	"--format": "--format NAME: unrestricted|wild|type1|type1.5|highlander",
	"--group": "--group NAME: keep one deck group when a folder is expanded",
	"--mulligan": "--mulligan on|off: offer the Shandalar mulligan, default off",
	"--rules": "--rules fifth|modern: which ruleset, default modern",
	"--rule": "--rule KEY=on|off: override one rules fork; repeatable",
	"--best-of": "--best-of N: play matches of 1, 3 or 5 duels instead of single duels",
	"--sideboard": "--sideboard on|off: AI sideboards between duels; needs --best-of 3 or 5",
}

## The flags that take no value. Same contract as [constant FLAG_HINTS]:
## the parser reads this table, --help must name each key, and a refusal
## can quote the line.
const TOGGLE_HINTS := {
	"-h": "-h: this help",
	"--help": "--help: this help",
	"--no-svg": "--no-svg: skip the SVG charts",
	"--no-elo": "--no-elo: do not touch the Elo ledger (use it for reruns)",
	"--quiet": "--quiet: no banner and no progress bar — errors only",
	"--no-banner": "--no-banner: keep the progress bar, drop the artwork",
}


## "unknown option '--gmaes'" is true but unhelpful when the shell has
## already eaten the typo. The refusal names the nearest flags instead —
## one mistyped letter is a bigram score around 0.8, so the suggestion is
## almost always the flag that was meant.
static func unknown_option(arg: String) -> String:
	var flags := PackedStringArray()
	for flag in FLAG_HINTS:
		flags.append(String(flag))
	for flag in TOGGLE_HINTS:
		flags.append(String(flag))
	# MEASURED, not guessed (Godot's `String.similarity` is a bigram
	# score): `--gamez` is 0.83 against `--games`, `--rulz` 0.80 against
	# `--rule`, `--gmaes` 0.50 against `--games`, `--jbos` 0.40 against
	# `--jobs` — and `--wat`, which means nothing, is 0.36 against its
	# nearest flag. So the floor sits at 0.40, and the 0.05 spread keeps
	# the answer to the flags actually in contention (a tie like
	# `--deck_a` between `--deck-a` and `--deck-b` shows both).
	var near := LabConsole.closest(arg, flags, 2, 0.40, 0.05)
	if near.is_empty():
		return "unknown option '%s'" % arg
	return "unknown option '%s' — did you mean %s?" % [arg, " or ".join(near)]


## The flags whose value must be a whole number. `String.to_int()` is
## silent about "abc" (it is 0), so `_parse_args` refuses these up front.
const WHOLE_NUMBER_FLAGS := ["--games", "--seed", "--jobs", "--procs", "--ante", "--best-of"]


func _parse_args(argv: PackedStringArray) -> Dictionary:
	var opts := {
		"deck_a": "", "opponents": [], "gauntlets": [], "matrix_pool": [],
		"deck_pool": "",
		"games": 1000,
		"seed": 1, "jobs": 0, "procs": 0,
		"profile_a": "wizard", "profile_b": "wizard",
		"out": "", "no_svg": false, "no_elo": false,
		"elo_file": EloLedger.DEFAULT_PATH,
		# TERMINAL CHROME, not a duel setting: neither reaches a game, and
		# both are already off when stderr is not a terminal.
		"quiet": false, "no_banner": false,
		# The duel settings. Every default here is what this script did
		# before the flag existed — see the class doc.
		"lives": [20, 20], "ante": 0, "names": ["SeatZero", "SeatOne"],
		"format": "", "group": "", "mulligan": false,
		"rules": "modern", "rule_overrides": {},
		# THE MATCH PARAMETERS. Both default to `&Free play` — one duel,
		# no sideboarding — which is exactly what this script did before
		# they existed, so the determinism baseline is untouched.
		"best_of": MatchState.FREE_PLAY, "sideboard": false,
	}
	# `--group` IS READ FIRST, before the loop, because `--gauntlet DIR`
	# and `--matrix DIR` expand their pools as they are parsed — so a
	# filter parsed afterwards would silently do nothing on half the
	# command lines people will actually type.
	_group_filter = ""
	for scan in argv.size() - 1:
		if argv[scan] == "--group":
			_group_filter = GROUP_FLAGS.get(argv[scan + 1].to_lower(), "")
	var i := 0
	while i < argv.size():
		var arg := argv[i]
		# THE TWO FLAG TABLES ARE THE PARSER'S OWN LIST, so a flag cannot
		# exist without a one-line explanation for --help to check and for
		# an error message to quote (test_every_flag_is_documented).
		if TOGGLE_HINTS.has(arg):
			match arg:
				"-h", "--help":
					return {"help": true}
				"--no-svg":
					opts.no_svg = true
				"--no-elo":
					opts.no_elo = true
				"--quiet":
					opts.quiet = true
					opts.no_banner = true
				"--no-banner":
					opts.no_banner = true
			i += 1
			continue
		if not FLAG_HINTS.has(arg):
			return {"error": unknown_option(arg)}
		i += 1
		# A FLAG WITH NO VALUE SAYS WHAT THE VALUE WOULD HAVE BEEN. "--games
		# needs a value" leaves the reader to go and look it up; the hint
		# table already holds the sentence, so it is quoted here.
		if i >= argv.size():
			return {"error": "%s needs a value  (%s)" % [arg, FLAG_HINTS[arg]]}
		var value := argv[i]
		# `to_int()` READS "abc" AS 0 — so `--seed abc` used to run
		# seed 0, `--jobs abc` every core and `--best-of abc` free
		# play, all silently. (`--lives` checks its own N or A,B.)
		if WHOLE_NUMBER_FLAGS.has(arg) and not value.is_valid_int():
			return {"error": "%s takes a whole number, not '%s'  (%s)"
				% [arg, value, FLAG_HINTS[arg]]}
		match arg:
			"--deck-a": opts.deck_a = value
			"--deck-b": opts.opponents.append(value)
			# EXPANDED AFTER THE LOOP, not here: a DIR excludes the
			# deck under test, and `--gauntlet` may be typed before
			# `--deck-a` — expanded inline, that order put the deck
			# under test in its own gauntlet (until 2026-09-02).
			"--gauntlet": opts.gauntlets.append(value)
			# Likewise, and for the same reason.
			"--deck-pool": opts.deck_pool = value
			"--matrix":
				var pool := _expand_pool(value, "")
				if pool.size() < 2:
					return {"error": "--matrix needs at least 2 decks in '%s'" % value}
				opts.matrix_pool = pool
			"--games":
				opts.games = value.to_int()
				if opts.games < 1:
					return {"error": "--games must be >= 1"}
			"--seed": opts.seed = value.to_int()
			"--procs":
					if value.to_int() < 0:
						return {"error": "--procs must be >= 0 (0 = decide from the size of the run)"}
					opts.procs = value.to_int()
			"--jobs":
				opts.jobs = value.to_int()
				if opts.jobs < 0:
					return {"error": "--jobs must be >= 0 (0 = every core)"}
			"--profile-a", "--profile-b":
				if not PROFILES.has(value.to_lower()):
					return {"error": "unknown profile '%s'" % value}
				opts["profile_a" if arg == "--profile-a" else "profile_b"] = value.to_lower()
			"--out": opts.out = value
			"--elo-file": opts.elo_file = value
			"--lives":
				var parts := value.split(",", false)
				if parts.size() == 1:
					opts.lives = [parts[0].to_int(), parts[0].to_int()]
				elif parts.size() == 2:
					opts.lives = [parts[0].to_int(), parts[1].to_int()]
				else:
					return {"error": "--lives takes N or A,B"}
				for part in parts:
					if not part.is_valid_int():
						return {"error": "--lives takes whole numbers, not '%s'" % part}
				for life in opts.lives:
					if life < 1:
						return {"error": "--lives must be >= 1"}
			"--ante":
				opts.ante = value.to_int()
				if opts.ante < 0:
					return {"error": "--ante must be >= 0"}
			"--names":
				var who := value.split(",", false)
				if who.size() != 2:
					return {"error": "--names takes A,B"}
				opts.names = [who[0], who[1]]
			"--format":
				var format: String = FORMAT_FLAGS.get(value.to_lower(), "")
				if format == "":
					return {"error": "unknown format '%s' (try %s)" % [
						value, ", ".join(FORMAT_FLAGS.keys())]}
				opts.format = format
			"--group":
				var group: String = GROUP_FLAGS.get(value.to_lower(), "")
				if group == "":
					return {"error": "unknown deck group '%s' (try %s)" % [
						value, ", ".join(GROUP_FLAGS.keys())]}
				opts.group = group
			"--mulligan":
				if not ["on", "off"].has(value.to_lower()):
					return {"error": "--mulligan takes on or off"}
				opts.mulligan = value.to_lower() == "on"
			# [MatchState.LENGTHS] AND NOTHING ELSE — 1, 3
			# or 5, for that class's own reasons:
			# `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` ships exactly
			# two record sentences, one per length, with the
			# number written into the sentence (so 3 and 5 and
			# never 7), and `@DIALOG_GAUNTLETOPTIONS` adds the
			# gauntlet's `Best of &One`.
			"--best-of":
				opts.best_of = value.to_int()
				if not MatchState.LENGTHS.has(opts.best_of):
					return {"error": "--best-of takes one of %s"
						% str(MatchState.LENGTHS)}
			"--sideboard":
				if not ["on", "off"].has(value.to_lower()):
					return {"error": "--sideboard takes on or off"}
				opts.sideboard = value.to_lower() == "on"
			"--rules":
				if not ["fifth", "modern"].has(value.to_lower()):
					return {"error": "--rules takes fifth or modern"}
				opts.rules = value.to_lower()
			"--rule":
				var split := value.split("=", false)
				if split.size() != 2 or not ["on", "off"].has(
						split[1].to_lower()):
					return {"error": "--rule takes KEY=on or KEY=off"}
				var known := false
				for fork in RulesOptions.FORKS:
					if fork["key"] == split[0]:
						known = true
						break
				if not known:
					return {"error": "unknown rules fork '%s'" % split[0]}
				opts.rule_overrides[split[0]] = split[1].to_lower() == "on"
		i += 1
	# `--gauntlet`, now that `--deck-a` is known whichever side it was on.
	for value in opts.gauntlets:
		var pool := _expand_pool(value, opts.deck_a)
		if pool.is_empty():
			return {"error": "no opponent decks found in '%s'" % value}
		opts.opponents.append_array(pool)
	# `Side&board between duels` HAS NO MOMENT IN FREE PLAY — nor in a
	# best-of-ONE match, which is a single duel with a scoreboard: the
	# swap happens between two duels, and there is no second duel.
	if opts.sideboard and opts.best_of < 3:
		return {"error": "--sideboard needs --best-of 3 or 5 (there is nothing between one duel and no other)"}
	if not opts.matrix_pool.is_empty():
		if opts.deck_a != "" or not opts.opponents.is_empty():
			return {"error": "--matrix does not combine with --deck-a/--deck-b/--gauntlet"}
		if opts.deck_pool != "":
			return {"error": "--deck-pool has nothing to draw for in --matrix mode"}
		return opts
	if opts.deck_a == "":
		return {"error": "--deck-a is required (or use --matrix)"}
	if opts.opponents.is_empty():
		return {"error": "need --deck-b, --gauntlet, or --matrix"}
	# `random` on both sides would make the per-opponent breakdown
	# two-dimensional and the Elo attribution ambiguous. One side.
	var random_sides := 1 if is_random(opts.deck_a) else 0
	for opponent in opts.opponents:
		if is_random(opponent):
			random_sides += 1
	if random_sides > 1:
		return {"error": "only one side may be `%s`" % RANDOM_TOKEN}
	if opts.deck_pool != "" and random_sides == 0:
		return {"error": "--deck-pool only means something with a `%s` deck"
			% RANDOM_TOKEN}
	return opts


## The `<random deck>` stand-in that sits in the deck list where a real
## deck would. It never plays: every task swaps it for the deck the field
## actually dealt, and it is kept out of the Elo ledger — it is a label
## for a row of the report, not a deck.
func _field_placeholder() -> DeckList:
	var placeholder := DeckList.new()
	placeholder.deck_name = RANDOM_LABEL
	return placeholder


## The field breakdown as plain data for results.json — [] when no side
## was the field, so a run without one writes the same key it always did
## not write anything else into.
func _field_json(field_rows: Array) -> Array:
	var out: Array = []
	for row in field_rows:
		var stats: Dictionary = (row["stats"] as Dictionary).duplicate()
		stats.erase("turns")
		stats["deck"] = row["name"]
		out.append(stats)
	return out


func _deck_names(list: Array[DeckList]) -> PackedStringArray:
	var names := PackedStringArray()
	for deck in list:
		names.append(deck.deck_name)
	return names


## A run directory INSIDE THE PROJECT is otherwise imported: Godot reads
## every `.csv` under `res://` as a translation table and writes one
## `.translation` resource per column beside it — 333 of them across 37
## runs by the time the review of 2026-09-02 looked. A `.gdignore` in the
## directory makes the importer skip it (the same file assets/cardart/
## carries). Directories outside the project are left alone.
static func _keep_the_importer_out(out_dir: String) -> void:
	var dir := DirAccess.open(out_dir)
	if dir == null:
		return
	var project_root := ProjectSettings.globalize_path("res://")
	if not dir.get_current_dir().path_join("").begins_with(project_root):
		return
	var marker := FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)
	if marker != null:
		marker.close()


## A comma list of files, or a directory of *.deck/*.dec (minus exclude).
##
## A DIR IS ITS OWN FILES ONLY unless `--group` is set — the default
## field (`decks/`) is the five starter decks and DEFAULTS NEVER MOVE
## (class doc), so the decks the 2026-09-02 port filed UNDER `decks/`
## (`decks/1997/<group>/`, `decks/tournament/`, `decks/community/`,
## `decks/extended_community/`) are reached by naming their group, which
## walks the subfolders, or by naming their folder.
## A DIR deck that holds proxies (most of `decks/tournament/` and
## `decks/extended_community/`, whose cards this pool does not all hold
## yet) is SKIPPED with a note on stderr rather than failing the whole
## pool: `--gauntlet decks/ --group extended_community` then honestly
## finds only the proxy-free few. A single named file is never skipped —
## if you named it, you meant it, and [method _load_deck] says why not.
func _expand_pool(value: String, exclude_path: String) -> Array:
	if value.contains(","):
		return Array(value.split(",", false))
	var dir_path := value
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://" + dir_path)):
			dir_path = "res://" + dir_path
		else:
			return [value]   # maybe a single file; deck loading will judge
	var found: Array = []
	_collect_decks(dir_path, exclude_path, _group_filter != "", found)
	found.sort()
	return found


## The deck files of one directory into [param found] — and, when
## [param recurse] is set, of every subfolder under it, depth-first.
func _collect_decks(dir_path: String, exclude_path: String, recurse: bool,
		found: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if recurse and not entry.begins_with("."):
				_collect_decks(full, exclude_path, recurse, found)
		elif (entry.ends_with(".deck") or entry.ends_with(".dec") or entry.ends_with(".dck")) \
				and entry != exclude_path.get_file():
			# `--group`: a DIR expands to one group's decks only. A single
			# named file is never filtered — if you named it, you meant it.
			if _group_filter == "" or DeckGroups.of(full) == _group_filter:
				var lenient := DeckList.load_file(full, false)
				if lenient.proxies.is_empty():
					found.append(full)
				else:
					printerr("deck_lab: skipping %s (%d proxy card%s — see docs/decks-1997.md)"
						% [full, lenient.proxies.size(),
							"" if lenient.proxies.size() == 1 else "s"])
		entry = dir.get_next()


## Set from `--group` before the pools are expanded; "" means every group.
var _group_filter := ""


## The non-default duel settings, one line, or "" when everything is at
## its default. Kept out of a default run's output on purpose — see the
## class doc's note about the determinism check.
func _settings_line(opts: Dictionary) -> String:
	var parts := PackedStringArray()
	if opts.lives != [20, 20]:
		parts.append("life %d/%d" % [opts.lives[0], opts.lives[1]])
	if opts.ante > 0:
		parts.append("ante %d" % opts.ante)
	if opts.format != "":
		parts.append("format %s" % opts.format)
	if opts.group != "":
		parts.append("group %s" % opts.group)
	if opts.mulligan:
		parts.append("mulligan on")
	if opts.best_of != MatchState.FREE_PLAY:
		parts.append("best of %d" % opts.best_of)
	if opts.sideboard:
		parts.append("sideboard on")
	if opts.rules != "modern":
		parts.append("rules %s" % opts.rules)
	for key in opts.rule_overrides:
		parts.append("%s=%s" % [key, "on" if opts.rule_overrides[key] else "off"])
	return "settings: " + "   ".join(parts) if not parts.is_empty() else ""


## False when the file could not be opened — and `_main` then exits 1,
## because a run whose report.txt never landed is not a result, however
## green the console looked.
func _write(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("deck_lab: cannot write %s" % path)
		return false
	file.store_string(content)
	return true


# ============================================================ THE TERMINAL ==
#
# THE RULE, AND IT IS THE ONE THIS SECTION EXISTS TO KEEP: stdout is the
# INSTRUMENT — the report, and byte for byte the text that lands in
# report.txt. stderr is the HUMAN — banner, progress, warnings, hints —
# and it is decorated only when stderr is a terminal, which
# `DeckLab/deck_lab.sh` finds out (`[ -t 2 ]`) and passes in
# DECK_LAB_TTY. So a run redirected into a log a script parses
# (`... > run.log 2>&1`) carries no artwork, no bar and no escape codes,
# without anyone having to remember a flag. See [LabConsole].

## How often the main thread looks at the counter while the pool works.
const PROGRESS_TICK_MS := 250
## A run shorter than this never says anything: a 20-game smoke should
## print its report and nothing else.
const PROGRESS_QUIET_SECONDS := 2.0
## The heartbeat when stderr is NOT a terminal — a log file wants to show
## that a long run is alive, not to be filled with bars.
const PROGRESS_LOG_SECONDS := 60.0


## The banner, once, on stderr. Off for `--quiet` / `--no-banner` /
## DECK_LAB_NO_BANNER=1, and off by itself when stderr is not a terminal.
func _banner() -> void:
	if _quiet or not _banner_wanted or not LabConsole.is_terminal():
		return
	printerr(LabConsole.banner(LabConsole.use_colour()))
	printerr("")


## WHAT TO TYPE INSTEAD, after a refusal. A message that only says what
## was wrong leaves the reader to go and find the manual; two copyable
## command lines are usually the whole fix. Printed after the error, so
## the error is still the first line.
func _usage_hint(no_arguments: bool) -> void:
	if no_arguments:
		printerr("")
		printerr("The Deck Lab plays AI-vs-AI duels headless and reports honest win rates.")
	printerr("")
	printerr("  DeckLab/deck_lab.sh --deck-a decks/big_green.deck \\")
	printerr("                      --deck-b decks/blue_skies.deck --games 200")
	printerr("  DeckLab/deck_lab.sh --matrix decks/ --games 200")
	printerr("  DeckLab/deck_lab.sh --help      # every switch, with examples")


## Wait for the pool, saying how far along it is. Polling rather than one
## blocking call is the whole difference between "this is working" and
## "this might be hung" on a run that takes an hour; the pool's own
## threads do the games either way, and the group is still freed by
## `wait_for_group_task_completion`.
func _watch(group: int, total: int, unit: String, started_at: int) -> void:
	while not WorkerThreadPool.is_group_task_completed(group):
		OS.delay_msec(PROGRESS_TICK_MS)
		_progress(_done_so_far(), total,
			(Time.get_ticks_msec() - started_at) / 1000.0, unit, false)
	WorkerThreadPool.wait_for_group_task_completion(group)
	_progress(total, total, (Time.get_ticks_msec() - started_at) / 1000.0,
		unit, true)


func _done_so_far() -> int:
	_progress_lock.lock()
	var done := _games_done
	_progress_lock.unlock()
	return done


## One progress update. On a terminal it rewrites its own line (and is
## erased when the run finishes, so the report starts on a clean screen);
## in a log it is a heartbeat once a minute.
func _progress(done: int, total: int, elapsed: float, unit: String,
		finished: bool) -> void:
	if _quiet:
		return
	if finished:
		if _progress_open:
			printerr(LabConsole.LINE_UP)
			_progress_open = false
		return
	if elapsed < PROGRESS_QUIET_SECONDS:
		return
	if LabConsole.is_terminal():
		# One column short of the width: a line that WRAPS cannot be
		# redrawn, because the cursor can only be sent up one row.
		var line := LabConsole.progress_line(done, total, elapsed, unit,
			LabConsole.width() - 1)
		printerr((LabConsole.LINE_UP if _progress_open else "")
			+ LabConsole.paint(line, LabConsole.DIM, LabConsole.use_colour()))
		_progress_open = true
		return
	if elapsed - _last_logged < PROGRESS_LOG_SECONDS:
		return
	_last_logged = elapsed
	printerr("deck_lab: %s" % LabConsole.progress_line(
		done, total, elapsed, unit, 78).strip_edges())


## The decks by name, capped so a 48-deck group does not fill the screen.
func _deck_summary(decks: Array[DeckList]) -> String:
	var names := _deck_names(decks)
	if names.size() <= 6:
		return ", ".join(names)
	var head := PackedStringArray()
	for i in 5:
		head.append(names[i])
	return "%s, ... (%d more)" % [", ".join(head), names.size() - 5]


## WHAT THE RUN IS ENTITLED TO CLAIM — the standings (matrix) or deck A's
## record across the whole gauntlet, and then, for every mode, the
## sentence that says how much of the headline percentage is real.
##
## THE LESSON THIS BLOCK EXISTS FOR: a win rate over a couple of hundred
## games is read as a fact, and "44.0%" has three times been taken for
## "this change made the deck worse" when 50% sat inside the interval all
## along. The interval was already printed; nobody compared it to 0.5 by
## eye. So the report now does that comparison itself, in words, and says
## what a sample this size can and cannot see.
func _reading_block(mode: String, opts: Dictionary, decks: Array[DeckList],
		pairs: Array, per_pair_stats: Array, unit: String) -> PackedStringArray:
	var out := PackedStringArray()
	if mode == "matrix":
		var names: Array = []
		for deck in decks:
			names.append(deck.deck_name)
		out.append("")
		out.append("standings: win rate across the whole matrix, best first")
		for row in SimStats.standings(names, pairs, per_pair_stats):
			var wr: Dictionary = row["winrate"]
			out.append("  %-24s %s  CI [%s..%s]  (%d-%d)" % [
				row["name"], SimStats.percent(wr.mid),
				SimStats.percent(wr.low).strip_edges(),
				SimStats.percent(wr.high).strip_edges(),
				row["wins"], row["losses"]])
	elif pairs.size() > 1:
		# THE GAUNTLET'S OWN NUMBER. Five per-opponent rows do not add up
		# to "how did the deck do" in anybody's head, and the aggregate
		# is the question the mode was run to answer — with its own
		# interval, which is tighter than any single row's.
		var wins := 0
		var losses := 0
		for stats in per_pair_stats:
			wins += int(stats["a_wins"])
			losses += int(stats["b_wins"])
		var overall := SimStats.wilson_interval(wins, wins + losses)
		out.append("")
		# Padded exactly as the matchup rows above are, so the aggregate
		# lines up under the column it aggregates.
		out.append("%-24s vs %-24s %s  CI [%s..%s]  (%d-%d)" % [
			decks[0].deck_name, "the gauntlet", SimStats.percent(overall.mid),
			SimStats.percent(overall.low).strip_edges(),
			SimStats.percent(overall.high).strip_edges(), wins, losses])
	var decided := 0
	for stats in per_pair_stats:
		if SimStats.is_decided(stats["winrate"]):
			decided += 1
	var margin := SimStats.margin_at(opts.games)
	var matchups := pairs.size()
	out.append("")
	out.append("reading these numbers:")
	out.append("  %s %s per matchup: the 95%% interval is +-%.1f points at an even"
		% [LabConsole.commas(opts.games), unit, margin * 100.0])
	out.append("  win rate, so no edge smaller than %.0f/%.0f is visible at this size."
		% [50.0 + margin * 100.0, 50.0 - margin * 100.0])
	out.append("  decided: %d of %d matchup%s (interval clear of 50%%); %d still even."
		% [decided, matchups, "" if matchups == 1 else "s", matchups - decided])
	if decided < matchups:
		out.append("  a +-3.0 point interval needs %s %s per matchup; +-1.0 needs %s."
			% [LabConsole.commas(SimStats.games_for_margin(0.03)), unit,
				LabConsole.commas(SimStats.games_for_margin(0.01))])
	return out


## A STALL IS A BUG, NOT A STATISTIC — the AI driver gave up on a game
## that never ended. The count has always been in the report; what was
## missing is that it is nobody's win rate, that it is reproducible, and
## that it should be reported rather than averaged over.
func _stall_warning(per_pair_stats: Array, opts: Dictionary,
		unit: String) -> void:
	var stalled := 0
	for stats in per_pair_stats:
		stalled += int(stats["stalled"])
	if stalled == 0:
		return
	printerr("")
	printerr("deck_lab: WARNING — %d %s stalled (the AI driver bailed out of them)."
		% [stalled, unit])
	printerr("  A stall is a bug in the engine or the AI, not a property of the decks;")
	printerr("  those games are excluded from every win rate above rather than given")
	printerr("  to either side. Please report it — `--seed %d` with these decks and"
		% int(opts.seed))
	printerr("  these settings reproduces it exactly.")
