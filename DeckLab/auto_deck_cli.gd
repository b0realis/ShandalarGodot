extends SceneTree
## AUTODECK CLI — the Deck Builder's AutoDeck tool on the command line,
## and by the thousand (2026-09-25). Run through
## DeckLab/auto_deck_cli.sh, which forwards everything after itself to
## this script; the long-form manual is the AutoDeck CLI section of
## DeckLab/README.md.
##
## WHY IT EXISTS, in the owner's own words: *"in the gui we have AutoDeck
## tool. Can you make also an AutoDeck cli tool ... but you can make many
## decks in a folder along with deck list of made decks. For example you
## make 10k random decks and the general idea is to test them with
## DeckLab to mine a really good deck!"* So this is the Lab's FEEDER: it
## makes the field, `deck_lab.sh --matrix` plays it, and the winner is
## rebuilt in the AutoDeck window from the seed and the row this tool
## wrote down.
##
## THREE THINGS IT IS, AND NOTHING ELSE:
##
## 1. THE SAME BUILDER. Every wish here is [AutoDeck]'s own member with
##    the same name and the same values as the AutoDeck window's
##    ([constant AutoDeckWindow.DEFAULTS]) — nothing is invented, nothing
##    is defaulted differently, and the deck a seed makes here is the deck
##    that seed makes in the game. The tool holds no opinion about decks.
## 2. A CARTESIAN WALK. Any wish may be given alternatives, and the decks
##    walk every combination of them in a fixed order, cycling when the
##    combinations run out — so `--count 10000` over 18 combinations is
##    556 decks of each and not 10,000 of the first.
## 3. A SEED PER DECK THAT THE WINDOW CAN REPLAY. See THE SEEDS below:
##    the guarantee is that ANY deck this tool made can be built again by
##    typing its seed and its row of `decks.csv` into the AutoDeck window,
##    and that is a promise the tests hold it to.
##
## THE COLORS FINDING, which is the reason [constant COLORS_RANDOM]
## exists (measured 2026-09-25, and the reason is in the source rather
## than in a preference): [method AutoDeck._choose_colors] reads no
## random number at all. It rates all 31 color sets by the sum of their
## best castable cards and takes the best — so with `--colors none`, the
## window's own default, one pool and one set of wishes land on ONE color
## pair however many seeds are thrown at them. The only randomness in a
## build is a 0.05 jitter on the fill's tie-breaks
## ([method AutoDeck._fill_spells]), which moves a card or two and never
## a color. A 10,000-deck mining run with no colors asked for is
## therefore 10,000 decks of one color pair, which is the opposite of
## mining. `--colors random` draws 1..`--max-colors` colors per deck from
## that deck's OWN seed, records what it drew, and the window reproduces
## it because the letters are in the manifest and in the file name.

## The seeds the AutoDeck window will accept — [constant
## AutoDeckWindow.SEED_MOST] and [method AutoDeck.build]'s own roll.
const SEED_LEAST := 1
const SEED_MOST := 999_999
## THE STRIDE BETWEEN ONE DECK'S SEED AND THE NEXT. 524,287 is prime and
## does not divide 999,999 (= 3^3 x 7 x 11 x 13 x 37), so stepping by it
## around the seed space visits every one of the 999,999 seeds before it
## repeats: a run of up to 999,999 decks CANNOT deal the same seed twice,
## which a hash of the index could not promise (10,000 draws from 999,999
## values collide about fifty times). Deck 0 gets the base seed itself,
## so `--seed 4242 --count 1` is the deck the window builds from 4242.
const SEED_STRIDE := 524_287

## The three card pools, the window's own two plus the sealed deal.
const SOURCE_SETS := "sets"
const SOURCE_LIST := "list"
const SOURCE_SEALED := "sealed"
const SOURCES: Array[String] = [SOURCE_SETS, SOURCE_LIST, SOURCE_SEALED]

## `--sets` takes set codes; this word takes every set the registry has
## active. NOT the word "all", which is Alliances' own set code (card
## pack 5) — a keyword that shadows a real value is a trap, and the
## refusal for `--sets all` says so out loud.
const SETS_EVERY := "every"

## `--colors` beyond the letters: the window's "none ticked, the builder
## picks" and the mining tool's own draw (see the class doc).
const COLORS_NONE := "none"
const COLORS_RANDOM := "random"

## `--rarity` spellings -> [AutoDeck]'s own constants. Short because
## `--rarity uncommon_up` is not what a hand types.
const RARITY_FLAGS := {
	"any": AutoDeck.RARITY_ANY,
	"pauper": AutoDeck.RARITY_PAUPER,
	"no-rares": AutoDeck.RARITY_NO_RARES,
	"uncommon-up": AutoDeck.RARITY_UNCOMMON_UP,
	"rares": AutoDeck.RARITY_RARES,
}
## `--lands` spellings -> [AutoDeck]'s own constants.
const LANDS_FLAGS := {
	"classic": AutoDeck.LANDS_CLASSIC,
	"non-classic": AutoDeck.LANDS_NONCLASSIC,
}

## THE AXES, IN THE ORDER THE ODOMETER TURNS THEM. The LAST one moves
## fastest, the way a number counts, so `--lean a,b --speed x,y` deals
## a/x, a/y, b/x, b/y — every wish of the first axis in a block, which is
## what a reader skimming `decks.csv` expects to see. Nothing outside
## this list may take alternatives, and everything in it must.
const AXES: Array[String] = ["sets", "colors", "max_colors", "gold", "size",
	"lean", "speed", "rarity", "lands", "tournament", "power_nine"]

## The two files a run leaves beside its decks.
const MANIFEST_NAME := "decks.csv"
const DECKLIST_NAME := "decklist.txt"
## THE MANIFEST'S COLUMNS, and this array IS the header line — a row is
## built by walking it, so a column cannot be added to one and not the
## other. `colors_asked` is what was wished for (letters, `none` or
## `random`) and `colors_built` what the builder actually chose; those
## two differing is the normal case and the whole point of the finding in
## the class doc.
const MANIFEST_COLUMNS: Array[String] = ["file", "index", "seed", "source",
	"sets", "pool", "colors_asked", "colors_built", "max_colors", "gold",
	"size", "lean", "speed", "rarity", "lands", "tournament", "power_nine",
	"cards", "land_count", "creature_count", "spell_count", "deck_name"]

## The progress shapes, [DeckLab]'s own four (see DeckLab/simulate.gd).
const PROGRESS_AUTO := "auto"
const PROGRESS_BAR := "bar"
const PROGRESS_LOG := "log"
const PROGRESS_OFF := "off"
const PROGRESS_MODES: Array[String] = [PROGRESS_AUTO, PROGRESS_BAR,
	PROGRESS_LOG, PROGRESS_OFF]
const PROGRESS_TICK := 25
const PROGRESS_QUIET_SECONDS := 2.0
const PROGRESS_LOG_SECONDS := 60.0

## EVERY FLAG THAT TAKES A VALUE, one line each saying what the value is
## — the Deck Lab's own contract ([constant DeckLab.FLAG_HINTS]): this
## table IS the parser's list, so an argument that is not a key here is
## an unknown option, and a flag with nothing after it answers its own
## question by quoting its line.
const FLAG_HINTS := {
	"--out": "--out DIR: where the deck files, decks.csv and decklist.txt are written (required)",
	"--count": "--count N: how many decks to make, default 1",
	"--seed": "--seed N: the base seed, 1..999999; omitted, a fresh one is rolled and recorded",
	"--source": "--source sets|list|sealed: where the card pool comes from, default sets",
	"--sets": "--sets CODE,CODE: the sets of one pool, or `every`; repeat the flag for alternative pools (axis)",
	"--packs": "--packs LIST: card packs enabled for this run alone — all, none, or ids like pack-3,pack-7 (bare 3,7 too); the game's own setting otherwise",
	"--list": "--list FILE: a card list to build from — `4 Lightning Bolt` lines, as a .deck file holds them",
	"--colors": "--colors WU,BR,none,random: colors to build in, `none` = the builder picks, `random` = 1..max per deck from its seed (axis)",
	"--max-colors": "--max-colors 1..5: how many colors a deck may have, default 2 (axis)",
	"--gold": "--gold on|off: multicolored cards preferred, two colors at least, default off (axis; bare --gold means on)",
	"--size": "--size 40|60: cards in the deck, default 60 (axis)",
	"--lean": "--lean creatures|balanced|spells: the creature share, default balanced (axis)",
	"--speed": "--speed fast|medium|slow: the curve and the land count, default medium (axis)",
	"--rarity": "--rarity any|pauper|no-rares|uncommon-up|rares: the rarity window, default any (axis)",
	"--lands": "--lands classic|non-classic: basics only, or the pool's own lands first, default classic (axis)",
	"--tournament": "--tournament on|off: no banned cards and restricted cards once, default on (axis; --no-tournament means off)",
	"--power-nine": "--power-nine on|off: the Lotus, the Moxen and the blue three, default off (axis; bare --power-nine means on)",
	"--keep": "--keep FILE: a deck file whose non-land cards every deck is built around",
	"--original-cards": "--original-cards on|off: the Extras window's `Original 1997` switch, default on",
	"--completion-pack": "--completion-pack on|off: the Extras window's `tDotP Pack 1` switch, default on",
	# The four numbers' defaults are the Sealed Deck window's own
	# ([constant SealedPool.DEFAULT_BOOSTERS] and its three neighbours);
	# they are spelled out here because a `const` initializer cannot format
	# a string, and test_auto_deck_cli.gd pins the words to the constants.
	"--boosters": "--boosters N: boosters in a sealed pool, default 3",
	"--starters": "--starters N: tournament packs in a sealed pool, default 1",
	"--free-lands": "--free-lands N: free basics of EACH type in a sealed pool, default 0",
	"--extras": "--extras N: extra cards of any rarity in a sealed pool, default 0",
	"--progress": "--progress auto|bar|log|off: a redrawing bar on a terminal, a heartbeat line a minute in a log, or neither",
}

## The flags that take no value. Same contract as [constant FLAG_HINTS]:
## the parser reads this table, --help must name every key, and a refusal
## can quote the line.
const TOGGLE_HINTS := {
	"-h": "-h: this help",
	"--help": "--help: this help",
	"--force": "--force: write into an output folder that already holds files",
	"--gold": "--gold: the same as --gold on",
	"--power-nine": "--power-nine: the same as --power-nine on",
	"--no-tournament": "--no-tournament: the same as --tournament off",
	"--quiet": "--quiet: no banner and no progress — errors only",
	"--no-banner": "--no-banner: keep the progress, drop the artwork",
}

## THE THREE FLAGS THAT ARE IN BOTH TABLES, and why that is not a
## mistake: `--gold`, `--power-nine` and `--tournament` are booleans, so
## a bare `--gold` has an obvious meaning AND an axis needs `--gold
## on,off`. The parser looks at what FOLLOWS the flag: a value it can
## read as on/off is the value, anything else (another flag, or the end
## of the line) makes it the bare toggle. `--no-tournament` is the bare
## form of the third, since `--tournament` alone would mean the default.
const BOOLEAN_TOGGLES := {"--gold": "gold", "--power-nine": "power_nine"}

## The whole-number flags. `String.to_int()` reads "abc" as 0 in silence,
## so these are refused before anything runs.
const WHOLE_NUMBER_FLAGS: Array[String] = ["--count", "--seed", "--boosters",
	"--starters", "--free-lands", "--extras"]

## The Deck Lab, for its `--packs` reading and enabling — the one switch
## the two tools share, so a field mined from a pack is played with the
## same word. Reached as a script and not a class name: simulate.gd has
## none, being a `--script` of its own.
const Lab := preload("res://DeckLab/simulate.gd")

const HELP := """AutoDeck CLI — build decks by the thousand, for the Deck Lab to mine
===================================================================
The Deck Builder's AutoDeck tool on the command line: the same builder
and the same wishes, one deck file per deck in a folder, a manifest that
says how each one was made, and a plain list of the files for the Lab to
walk. The long-form manual is DeckLab/README.md.

USAGE
  DeckLab/auto_deck_cli.sh --out DIR [--count N] [wishes]
  DeckLab/auto_deck_cli.sh -h | --help

QUICK START — copy one of these
  # a thousand Fourth Edition decks, a color pair per deck from its seed
  DeckLab/auto_deck_cli.sh --out mine --count 1000 --colors random

  # the corners of the wish space: 3 leans x 3 speeds x 2 sizes = 18
  # combinations, 900 decks, 50 of each
  DeckLab/auto_deck_cli.sh --out mine --count 900 --colors random \\
      --lean creatures,balanced,spells --speed fast,medium,slow --size 40,60

  # and then mine them
  DeckLab/deck_lab.sh --matrix mine/ --games 50 --no-elo

THE POOL — `--source`
  sets    the cards of the sets `--sets` names (the default; `--sets`
          defaults to 4ed, the AutoDeck window's own default). The Extras
          window's two switches are honored: --original-cards on|off and
          --completion-pack on|off.
  list    the cards of `--list FILE` — `4 Lightning Bolt` lines, the same
          lines a .deck file holds; SB: lines count too. Giving --list
          selects this source on its own.
  sealed  a SEALED POOL DEALT PER DECK from that deck's own seed, out of
          the sets `--sets` names: --boosters, --starters, --free-lands
          and --extras are the Sealed Deck window's four numbers. Every
          deck gets its own pool, so the field varies even with one wish.

  `--sets 4ed,drk` is ONE pool of two sets, the way the window ticks two
  boxes. REPEAT the flag for alternative pools: `--sets 4ed --sets 2ed`
  builds some decks from each. `--sets every` is every active set.
  (`all` is not that word: `all` is Alliances' own set code.)

  The sets in play are the game's enabled card packs. `--packs LIST`
  enables packs for THIS RUN ALONE — `all`, `none`, or ids like
  pack-3,pack-7 (bare 3,7 too) — so `--packs 3 --sets ice` mines Ice
  Age without touching the game's own setting. The Deck Lab's own
  switch: play the field with the same `--packs`.

THE WISHES — every one of them the AutoDeck window's own
  --colors WU        build in white and blue; letters from WUBRG
  --colors none      the builder picks the strongest colors in the pool
  --colors random    1..--max-colors colors drawn from THIS deck's seed
  --max-colors 1..5  how many colors a deck may have           (2)
  --gold on|off      multicolored cards preferred, 2 colors at least (off)
  --size 40|60       cards in the deck                          (60)
  --lean creatures|balanced|spells   the creature share      (balanced)
  --speed fast|medium|slow           the curve and the lands   (medium)
  --rarity any|pauper|no-rares|uncommon-up|rares               (any)
  --lands classic|non-classic        basics only, or the pool's (classic)
  --tournament on|off   no banned cards, restricted once        (on)
  --power-nine on|off   the Lotus, the Moxen, the blue three    (off)
  --keep FILE           build every deck around this deck's non-land cards

  `--colors none` IS DETERMINISTIC, and that is the one thing to know
  before starting a mining run. The builder rates all 31 color sets and
  takes the best; no random number is involved, so one pool and one set
  of wishes give the SAME colors for every seed. Ten thousand decks with
  no colors asked for are ten thousand decks of one color pair. Use
  `--colors random` (or `--source sealed`, whose pool moves per deck).

ALTERNATIVES AND THE CARTESIAN WALK
  Every wish marked (axis) in the list above takes a comma-separated list
  of ALTERNATIVES — `--lean creatures,spells --speed fast,slow` is four
  combinations — and may also be repeated. `--sets` is the one exception
  to the comma rule: there a comma joins sets into ONE pool, so repeat
  the flag instead.

  The decks walk the combinations in a fixed order (the last axis moving
  fastest: sets, colors, max-colors, gold, size, lean, speed, rarity,
  lands, tournament, power-nine) and start again from the first when the
  list runs out. So `--count N` spreads N decks evenly over however many
  combinations were asked for, and the same command line always deals the
  same combination to deck number K.

THE SEEDS — AND THE PROMISE THEY CARRY
  `--seed N` is the BASE seed (1..999999). Deck 1 gets it; deck K+1 gets
  the base stepped K times by 524287 around the 999999 seeds, so no two
  decks of a run under a million share a seed. With no --seed a fresh
  base is rolled and printed, and written into decks.csv, so a run is
  never lost.

  THE PROMISE: any deck this tool made can be built again in the game.
  Open the Deck Builder, open AutoDeck, set the options of that deck's
  row of decks.csv — including the colors_built letters, not the
  colors_asked word — type its seed into the Seed field, and the deck
  that comes out is the deck in the file, card for card. The seed is
  also written into the deck file itself, as the last of its `# note:`
  lines. tests/tools/test_auto_deck_cli.gd holds this tool to it.

OUTPUT — what lands in `--out DIR`
  deck_00001_WU_s004242.deck   one file per deck: index, the colors the
                               builder chose, the deck's own seed. The
                               project's .deck format, which the Deck Lab
                               and the Deck Builder both read.
  decks.csv                    one row per deck: the file, the index, the
                               seed, every wish that deck was built with,
                               the colors the builder actually chose, the
                               card/land/creature/spell counts and the
                               pool it came from.
  decklist.txt                 the deck files in order, one path a line —
                               the list to walk, or to paste into a
                               --gauntlet.

  A folder that already holds files is REFUSED unless --force is given.

MINING WORKFLOW
  1. make the field          auto_deck_cli.sh --out mine --count 500 --colors random
  2. play it off             deck_lab.sh --matrix mine/ --games 50 --no-elo
  3. read the standings, take the best few deck files
  4. play those properly     deck_lab.sh --matrix best/ --games 2000 --no-elo
  5. rebuild the winner in the AutoDeck window from its seed and its row

OTHER SWITCHES
  --gold                        the same as --gold on
  --power-nine                  the same as --power-nine on
  --no-tournament               the same as --tournament off
  --progress auto|bar|log|off   the shape of the progress (auto)
  --quiet                       no banner, no progress; errors only
  --no-banner                   keep the progress, drop the artwork
  --force                       write into a folder that is not empty
  -h, --help                    this help

EXIT CODES
  0  every deck written
  1  the run broke — no output folder, a folder that is not empty and no
     --force, or a pool with nothing in it
  2  the command line was wrong
  3  no Godot to run (the wrapper's own)
"""


# ------------------------------------------------------------ the state --

## Terminal chrome, resolved once in [method _main]; see the section at
## the foot of DeckLab/simulate.gd, whose rules these follow.
var _quiet := false
var _banner_wanted := true
var _progress_mode := PROGRESS_AUTO
var _progress_open := false
var _last_logged := 0.0
var _eta := LabEta.new()
## Card pools already built, keyed by the set alternative and the two
## Extras switches — `pool_from_sets` walks every card in the registry
## once per set, which is not a thing to do ten thousand times.
var _pool_cache: Dictionary = {}
var _library_cache: Dictionary = {}
## The packs `--packs` put in force, for the run's header.
var _packs_in_force: Variant = null


func _initialize() -> void:
	# THE AUTOLOADS ARE NOT READY YET. A `-s` script cannot name one at
	# compile time, and `_initialize` runs before any autoload's `_ready`
	# — CardPacks has not scanned for its archives nor configured the
	# registry — while `DeckModel.to_text()` reaches for it through the
	# tree to ask which packs a deck needs. So the run starts one frame
	# later, when the root's autoloads have had their `_ready` (the same
	# shape as tools/pack_3_deck_lab.gd).
	_run.call_deferred()


func _run() -> void:
	quit(exit_code_of(_main(OS.get_cmdline_user_args())))


## A runtime error inside `_main` unwinds it to NULL, and `int(null)` is
## 0 — a broken run that exits 0 and looks clean. Null is exit 1.
## (DeckLab/simulate.gd's own guard, for the same reason.)
static func exit_code_of(main_result: Variant) -> int:
	if main_result == null:
		printerr("auto_deck: the run stopped on an error (see above); no decks")
		return 1
	return int(main_result)


# ----------------------------------------------------------- the parser --

## "unknown option '--colours'" is true but unhelpful. The refusal names
## the nearest flags instead, the way the Lab's does.
static func unknown_option(arg: String) -> String:
	var flags := PackedStringArray()
	for flag in FLAG_HINTS:
		flags.append(String(flag))
	for flag in TOGGLE_HINTS:
		flags.append(String(flag))
	var near := LabConsole.closest(arg, flags, 2, 0.40, 0.05)
	if near.is_empty():
		return "unknown option '%s'" % arg
	return "unknown option '%s' — did you mean %s?" % [arg, " or ".join(near)]


## The wishes as the window holds them, each axis an ARRAY of
## alternatives with the window's own default as its only member
## ([constant AutoDeckWindow.DEFAULTS]). Everything outside [constant
## AXES] is a plain value.
static func default_options() -> Dictionary:
	return {
		"out": "", "count": 1, "seed": 0, "force": false,
		"source": SOURCE_SETS, "list": "", "keep": "",
		"original_cards": true, "completion_pack": true,
		"packs": null,
		"boosters": SealedPool.DEFAULT_BOOSTERS,
		"starters": SealedPool.DEFAULT_STARTERS,
		"free_lands": SealedPool.DEFAULT_FREE_LANDS,
		"extras": SealedPool.DEFAULT_EXTRAS,
		"quiet": false, "no_banner": false, "progress": "",
		# The axes. `sets` alone takes a LIST per alternative, because a
		# pool is a set of sets; the rest take one value each.
		"sets": [["4ed"]],
		"colors": [COLORS_NONE],
		"max_colors": [2],
		"gold": [false],
		"size": [60],
		"lean": [AutoDeck.LEAN_BALANCED],
		"speed": [AutoDeck.SPEED_MEDIUM],
		"rarity": [AutoDeck.RARITY_ANY],
		"lands": [AutoDeck.LANDS_CLASSIC],
		"tournament": [true],
		"power_nine": [false],
	}


## Whether [param value] reads as a boolean flag value — `on`, `off`, or
## a comma list of them, since a boolean is an axis too (`--gold on,off`).
## Anything else after `--gold` — another flag, or nothing at all — makes
## it the bare toggle instead.
static func is_boolean_word(value: String) -> bool:
	var words := value.split(",", false)
	if words.is_empty():
		return false
	for word in words:
		if not ["on", "off"].has(word.strip_edges().to_lower()):
			return false
	return true


## The letters of [param text] as an [enum Mtg.ManaColor] mask, or -1
## when one of them is not a color.
static func colors_from_letters(text: String) -> int:
	var mask := 0
	for letter in text.to_upper():
		match letter:
			"W": mask |= Mtg.ManaColor.W
			"U": mask |= Mtg.ManaColor.U
			"B": mask |= Mtg.ManaColor.B
			"R": mask |= Mtg.ManaColor.R
			"G": mask |= Mtg.ManaColor.G
			_: return -1
	return mask


## A mask back as letters in WUBRG order — the deck file's name and the
## manifest's `colors_built`. An empty mask is `C`, a deck of no color.
static func color_letters(mask: int) -> String:
	var out := ""
	for color in Mtg.WUBRG:
		if mask & color:
			match color:
				Mtg.ManaColor.W: out += "W"
				Mtg.ManaColor.U: out += "U"
				Mtg.ManaColor.B: out += "B"
				Mtg.ManaColor.R: out += "R"
				Mtg.ManaColor.G: out += "G"
	return out if out != "" else "C"


## The wishes from the command line, or `{"help": true}` / `{"error":
## "..."}`. PURE: it reads no file and asks the registry nothing (a set
## code is checked against the live registry later, in [method _main]),
## so a test can hold every refusal in this file.
static func parse_args(argv: PackedStringArray) -> Dictionary:
	var opts := default_options()
	# Which axes the command line spoke about. The second `--lean` ADDS
	# alternatives; the first REPLACES the default, or `--lean spells`
	# would silently be "balanced or spells".
	var spoken := {}
	var source_said := false
	var i := 0
	while i < argv.size():
		var arg := argv[i]
		# A boolean axis is in both tables; what FOLLOWS decides which.
		# Anything that is not another flag is read as the value, even a
		# bad one — `--gold maybe` has to answer "takes on or off" rather
		# than "unknown option 'maybe'", which is what looking for `on`
		# and `off` alone did (found by the test that reads the message).
		var bare_toggle := TOGGLE_HINTS.has(arg)
		if bare_toggle and FLAG_HINTS.has(arg):
			bare_toggle = i + 1 >= argv.size() or argv[i + 1].begins_with("-")
		if bare_toggle:
			match arg:
				"-h", "--help":
					return {"help": true}
				"--force":
					opts.force = true
				"--quiet":
					opts.quiet = true
					opts.no_banner = true
				"--no-banner":
					opts.no_banner = true
				"--no-tournament":
					opts.tournament = [false]
					spoken["tournament"] = true
				_:
					# `--gold` / `--power-nine`, the bare on.
					var key: String = BOOLEAN_TOGGLES[arg]
					opts[key] = [true]
					spoken[key] = true
			i += 1
			continue
		if not FLAG_HINTS.has(arg):
			return {"error": unknown_option(arg)}
		i += 1
		if i >= argv.size():
			return {"error": "%s needs a value  (%s)" % [arg, FLAG_HINTS[arg]]}
		var value := argv[i]
		i += 1
		if WHOLE_NUMBER_FLAGS.has(arg) and not value.is_valid_int():
			return {"error": "%s takes a whole number, not '%s'  (%s)"
				% [arg, value, FLAG_HINTS[arg]]}
		match arg:
			"--out":
				opts.out = value
			"--count":
				opts.count = value.to_int()
				if opts.count < 1:
					return {"error": "--count must be >= 1"}
			"--seed":
				opts.seed = value.to_int()
				if opts.seed < SEED_LEAST or opts.seed > SEED_MOST:
					return {"error": "--seed must be %d..%d — the seeds the AutoDeck window accepts"
						% [SEED_LEAST, SEED_MOST]}
			"--source":
				if not SOURCES.has(value.to_lower()):
					return {"error": "unknown source '%s' (try %s)"
						% [value, ", ".join(SOURCES)]}
				opts.source = value.to_lower()
				source_said = true
			"--list":
				opts.list = value
				if not source_said:
					opts.source = SOURCE_LIST
			"--keep":
				opts.keep = value
			"--packs":
				# Read against the packs on this machine in _main, where
				# the CardPacks node is; the parser stays pure.
				opts.packs = value
			"--progress":
				if not PROGRESS_MODES.has(value.to_lower()):
					return {"error": "--progress takes one of %s, not '%s'"
						% [", ".join(PROGRESS_MODES), value]}
				opts.progress = value.to_lower()
			"--original-cards", "--completion-pack":
				if not is_boolean_word(value) or value.contains(","):
					return {"error": "%s takes on or off, not '%s'" % [arg, value]}
				opts["original_cards" if arg == "--original-cards"
					else "completion_pack"] = value.to_lower() == "on"
			"--boosters", "--starters", "--free-lands", "--extras":
				var n := value.to_int()
				if n < 0:
					return {"error": "%s must be >= 0  (%s)" % [arg, FLAG_HINTS[arg]]}
				opts[{"--boosters": "boosters", "--starters": "starters",
					"--free-lands": "free_lands", "--extras": "extras"}[arg]] = n
			_:
				var added := _axis_values(arg, value)
				if added.has("error"):
					return {"error": added["error"]}
				var key := _axis_key(arg)
				# THE FIRST MENTION REPLACES THE DEFAULT, a later one ADDS:
				# `--lean spells` must mean spells, not "balanced or
				# spells", while `--lean spells --lean creatures` means
				# both. Which is why the parser remembers what was spoken.
				if spoken.has(key):
					opts[key].append_array(added["values"])
				else:
					opts[key] = added["values"]
					spoken[key] = true
	if opts.out == "":
		return {"error": "--out DIR is required  (%s)" % FLAG_HINTS["--out"]}
	if opts.source == SOURCE_LIST and opts.list == "":
		return {"error": "--source list needs --list FILE  (%s)" % FLAG_HINTS["--list"]}
	if opts.source != SOURCE_LIST and opts.list != "":
		return {"error": "--list only means something with --source list"}
	if opts.source == SOURCE_SEALED:
		var deal := SealedPool.new()
		deal.boosters = opts.boosters
		deal.starters = opts.starters
		deal.free_lands = opts.free_lands
		deal.extras = opts.extras
		if deal.card_total() == 0:
			return {"error": "a sealed pool of no cards: --boosters, --starters, --free-lands and --extras are all 0"}
	return opts


## The option key an axis flag writes to.
static func _axis_key(flag: String) -> String:
	return flag.trim_prefix("--").replace("-", "_")


## One axis flag's value as the ALTERNATIVES it adds:
## `{"values": [...]}` or `{"error": "..."}`. Everything but `--sets`
## splits on commas into alternatives; `--sets` splits on commas into the
## SETS OF ONE POOL, because that is what ticking two boxes in the window
## means, and repeating the flag is how a run gets two pools.
##
## THE RESULT IS A DICTIONARY AND NOT A VALUE-OR-STRING, because half the
## axes have legitimate String values (`balanced`, `classic`, `none`) and
## a refusal that is also a String cannot be told from one of those
## without guessing. Guessing is how `--lean balanced` would one day be
## read as an error message.
static func _axis_values(flag: String, value: String) -> Dictionary:
	if flag == "--sets":
		var codes: Array = []
		for raw in value.split(",", false):
			var code := raw.strip_edges().to_lower()
			if code != "" and not codes.has(code):
				codes.append(code)
		if codes.is_empty():
			return {"error": "--sets needs at least one set code  (%s)"
				% FLAG_HINTS["--sets"]}
		return {"values": [codes]}
	var out: Array = []
	for raw in value.split(",", false):
		var word := raw.strip_edges()
		if word == "":
			continue
		var read := _axis_value(flag, word)
		if read.has("error"):
			return read
		out.append(read["value"])
	if out.is_empty():
		return {"error": "%s needs a value  (%s)" % [flag, FLAG_HINTS[flag]]}
	return {"values": out}


## ONE alternative of one axis flag, typed the way [AutoDeck] wants it:
## `{"value": ...}` or `{"error": "..."}`.
static func _axis_value(flag: String, word: String) -> Dictionary:
	match flag:
		"--colors":
			var lower := word.to_lower()
			if lower == COLORS_NONE or lower == COLORS_RANDOM:
				return {"value": lower}
			var mask := colors_from_letters(word)
			if mask < 0:
				return {"error": "--colors: '%s' is not colors — letters from WUBRG, or `none`, or `random`" % word}
			return {"value": mask}
		"--max-colors":
			if not word.is_valid_int() or word.to_int() < 1 or word.to_int() > 5:
				return {"error": "--max-colors takes 1..5, not '%s'" % word}
			return {"value": word.to_int()}
		"--size":
			if not word.is_valid_int() or not AutoDeck.SIZES.has(word.to_int()):
				return {"error": "--size takes %s, not '%s'" % [
					" or ".join(PackedStringArray(_words(AutoDeck.SIZES))), word]}
			return {"value": word.to_int()}
		"--lean":
			if not AutoDeck.LEANS.has(word.to_lower()):
				return {"error": "--lean takes %s, not '%s'" % [
					", ".join(PackedStringArray(_words(AutoDeck.LEANS))), word]}
			return {"value": word.to_lower()}
		"--speed":
			if not AutoDeck.SPEEDS.has(word.to_lower()):
				return {"error": "--speed takes %s, not '%s'" % [
					", ".join(PackedStringArray(_words(AutoDeck.SPEEDS))), word]}
			return {"value": word.to_lower()}
		"--rarity":
			if not RARITY_FLAGS.has(word.to_lower()):
				return {"error": "--rarity takes %s, not '%s'" % [
					", ".join(PackedStringArray(_words(RARITY_FLAGS.keys()))), word]}
			return {"value": String(RARITY_FLAGS[word.to_lower()])}
		"--lands":
			if not LANDS_FLAGS.has(word.to_lower()):
				return {"error": "--lands takes %s, not '%s'" % [
					", ".join(PackedStringArray(_words(LANDS_FLAGS.keys()))), word]}
			return {"value": String(LANDS_FLAGS[word.to_lower()])}
		"--gold", "--tournament", "--power-nine":
			if not is_boolean_word(word):
				return {"error": "%s takes on or off, not '%s'" % [flag, word]}
			return {"value": word.to_lower() == "on"}
	return {"error": "%s is not an axis" % flag}


## The values of one flag, quoted for a refusal. `str()` and never
## `String()`: half of these are ints (`--size 40`) and `String(40)` is not
## a constructor Godot has — which was a SCRIPT ERROR inside the message
## for a bad `--size`, found by the test that reads that message.
static func _words(values: Array) -> Array:
	var out: Array = []
	for value in values:
		var word := str(value)
		out.append("`%s`" % ("any" if word == "" else word))
	return out


# ------------------------------------------------------- the wish space --

## How many combinations the alternatives make.
static func combo_total(opts: Dictionary) -> int:
	var total := 1
	for key in AXES:
		total *= maxi((opts[key] as Array).size(), 1)
	return total


## The wishes deck [param index] is built with — the odometer of
## [constant AXES], the last axis moving fastest, wrapping round when the
## combinations run out.
static func combo_at(opts: Dictionary, index: int) -> Dictionary:
	var out := {}
	var n := posmod(index, maxi(combo_total(opts), 1))
	for i in range(AXES.size() - 1, -1, -1):
		var key: String = AXES[i]
		var alternatives: Array = opts[key]
		out[key] = alternatives[n % alternatives.size()]
		@warning_ignore("integer_division")
		n = n / alternatives.size()
	return out


## Deck [param index]'s own seed: the base, stepped [constant
## SEED_STRIDE] times [param index] around the 999,999 seeds the AutoDeck
## window accepts. Deck 0 IS the base seed, and no two decks of a run
## under a million share one (see the constant).
static func deck_seed(base: int, index: int) -> int:
	var span := SEED_MOST - SEED_LEAST + 1
	return posmod(base - SEED_LEAST + index * SEED_STRIDE, span) + SEED_LEAST


## The colors `--colors random` draws for a deck: 1..[param max_colors]
## of them (2 at least for a gold deck, as [method AutoDeck.build]
## insists), from THIS deck's seed and nothing else — so the draw is part
## of the deck's own reproducible identity even though the window has no
## `random` button. The letters land in the manifest and in the file
## name, which is how the window replays it.
static func random_colors(seed_value: int, max_colors: int, gold: bool) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var least := 2 if gold else 1
	var most := maxi(clampi(max_colors, 1, 5), least)
	var wheel: Array = Mtg.WUBRG.duplicate()
	for i in range(wheel.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var keep: int = wheel[i]
		wheel[i] = wheel[j]
		wheel[j] = keep
	var mask := 0
	for i in rng.randi_range(least, most):
		mask |= int(wheel[i])
	return mask


## The mask a deck is actually ASKED to build in: the letters as typed,
## the window's 0 for `none`, or the draw for `random`.
static func asked_colors(wish: Variant, seed_value: int, max_colors: int,
		gold: bool) -> int:
	if typeof(wish) == TYPE_INT:
		return int(wish)
	if String(wish) == COLORS_RANDOM:
		return random_colors(seed_value, max_colors, gold)
	return 0


## `deck_00042_WU_s004242.deck` — sortable first, then readable: the
## index pads to the width of the run so `ls` and a matrix report are in
## build order, the colors are the ones the builder CHOSE, and the seed
## is the thing that rebuilds it.
static func deck_file_name(index: int, width: int, mask: int, seed_value: int) -> String:
	return "deck_%0*d_%s_s%06d.deck" % [maxi(width, 1), index + 1,
		color_letters(mask), seed_value]


## The width the index pads to: five digits for anything up to 99,999, so
## the ten-thousand-deck run the tool was written for reads as 00001.
static func index_width(count: int) -> int:
	return maxi(5, str(maxi(count, 1)).length())


# ----------------------------------------------------------- the output --

## One CSV field, quoted only when it has to be — a pool label is
## "Fourth Edition, The Dark" often enough that an unquoted manifest
## would be a lie by the second row.
static func csv_field(text: String) -> String:
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text


static func csv_row(fields: Array) -> String:
	var out := PackedStringArray()
	for field in fields:
		out.append(csv_field(str(field)))
	return ",".join(out)


## The manifest's header — [constant MANIFEST_COLUMNS] itself, so the
## header and the rows can never describe different tables.
static func manifest_header() -> String:
	return csv_row(MANIFEST_COLUMNS)


## One manifest row from a finished build. [param record] is keyed by
## [constant MANIFEST_COLUMNS]; a column the record has no value for is
## empty rather than absent, so every row has the same number of commas.
static func manifest_row(record: Dictionary) -> String:
	var fields: Array = []
	for column in MANIFEST_COLUMNS:
		fields.append(record.get(column, ""))
	return csv_row(fields)


## The word a manifest writes for a boolean: the same `on`/`off` the
## command line takes, so a row can be pasted back as switches.
static func on_off(value: bool) -> String:
	return "on" if value else "off"


## The `--colors` word a row reports as asked for.
static func colors_word(wish: Variant) -> String:
	if typeof(wish) == TYPE_INT:
		return color_letters(int(wish))
	return String(wish)


## The `--rarity` word for one of [AutoDeck]'s own constants.
static func rarity_word(rarity: String) -> String:
	for word in RARITY_FLAGS:
		if String(RARITY_FLAGS[word]) == rarity:
			return String(word)
	return "any"


## The `--lands` word for one of [AutoDeck]'s own constants.
static func lands_word(kind: String) -> String:
	for word in LANDS_FLAGS:
		if String(LANDS_FLAGS[word]) == kind:
			return String(word)
	return "classic"


## THE POOL'S NAME, the AutoDeck window's own wording ([method
## AutoDeckWindow.pool_label]) so that a deck built here and a deck built
## in the game carry the same sentence in their notes: the set names, or
## a count once there are more than three.
static func sets_label(codes: Array) -> String:
	var names := PackedStringArray()
	for code in codes:
		names.append(String(DeckFilter.SET_LABELS.get(String(code),
			String(code).to_upper())))
	if names.is_empty():
		return "no set"
	if names.size() > 3:
		return "%d sets" % names.size()
	return ", ".join(names)


# ------------------------------------------------------------- the run --

func _main(argv: PackedStringArray) -> int:
	var opts := parse_args(argv)
	_quiet = bool(opts.get("quiet", false))
	_banner_wanted = not bool(opts.get("no_banner", false)) \
		and OS.get_environment(LabConsole.NO_BANNER_ENV) != "1"
	_progress_mode = String(opts.get("progress", ""))
	if _progress_mode == "":
		_progress_mode = PROGRESS_OFF if _quiet else PROGRESS_AUTO
	if opts.has("help"):
		_banner()
		# THE HELP GOES TO stdout, the banner to stderr, so
		# `auto_deck_cli.sh --help | less` is the switch reference alone.
		print(HELP)
		return 0
	if opts.has("error"):
		# NO ARTWORK ON A REFUSAL — the Lab's rule, and the reason is that
		# somebody who mistyped a flag wants the fix on the first line.
		printerr("auto_deck: %s" % opts.error)
		_usage_hint(argv.is_empty())
		return 2
	_banner()
	# THE PACKS FIRST, since they decide which sets are in play: the Lab's
	# own reading and refusals, in memory alone — the player's settings
	# file is never written.
	if opts.packs != null:
		var chosen: Dictionary = Lab.parse_packs(String(opts.packs), Lab.available_packs())
		if chosen.has("error"):
			printerr("auto_deck: %s" % chosen.error)
			return 2
		var refusal: String = Lab.enable_packs(chosen.ids)
		if refusal != "":
			printerr("auto_deck: %s" % refusal)
			return 1
		_packs_in_force = chosen.ids
	CardRegistry.ensure_loaded()

	# THE SET CODES ARE CHECKED AGAINST THE LIVE REGISTRY, which is why
	# this is not in the parser: which sets exist depends on the card
	# packs installed, and a typo must fail on the command line rather
	# than after ten thousand builds from an empty pool.
	var sets_error := unknown_sets_message(opts)
	if sets_error != "":
		printerr("auto_deck: %s" % sets_error)
		return 2

	var list_pool: Dictionary = {}
	var list_label := ""
	if opts.source == SOURCE_LIST:
		var text := FileAccess.get_file_as_string(
			ProjectSettings.globalize_path(String(opts.list)))
		if text == "":
			printerr("auto_deck: cannot read the card list '%s'" % opts.list)
			return 1
		var report: Array = []
		list_pool = AutoDeck.pool_from_text(text, report)
		for line in report:
			printerr("auto_deck: %s" % String(line))
		if list_pool.is_empty():
			printerr("auto_deck: '%s' holds no card the game has" % opts.list)
			return 1
		list_label = String(opts.list).get_file()

	var keep: DeckModel = null
	if String(opts.keep) != "":
		var kept := DeckList.load_file(
			ProjectSettings.globalize_path(String(opts.keep)))
		if not kept.errors.is_empty():
			printerr("auto_deck: problems reading '%s':" % opts.keep)
			for problem in kept.errors:
				printerr("  " + String(problem))
			return 1
		keep = DeckModel.from_deck_list(kept)

	var out_dir := String(opts.out)
	var prepared := _prepare_out_dir(out_dir, bool(opts.force))
	if prepared != "":
		printerr("auto_deck: %s" % prepared)
		return 1

	var base_seed := int(opts.seed)
	if base_seed == 0:
		var roller := RandomNumberGenerator.new()
		base_seed = roller.randi_range(SEED_LEAST, SEED_MOST)
	var count := int(opts.count)
	var total := combo_total(opts)
	print("AutoDeck: %s deck(s), %d wish combination(s), base seed %d, out: %s"
		% [LabConsole.commas(count), total, base_seed, out_dir])
	print("pool: %s" % _source_line(opts))
	if _packs_in_force != null:
		print("packs: %s" % ("none" if (_packs_in_force as Array).is_empty()
			else ", ".join(PackedStringArray(_packs_in_force))))
	print("wishes: %s" % _wishes_line(opts))
	# THE RUN-LEVEL OPTIONS THAT ARE NOT AXES, said out loud only when
	# they are not the default: a log of a run has to be enough to repeat
	# it, and `--keep` in particular decides the colors of every deck.
	if keep != null:
		print("built around: %s (%d non-land card(s))" % [opts.keep,
			_non_lands(keep)])
	if not bool(opts.original_cards) or not bool(opts.completion_pack):
		print("extras: original cards %s, completion pack %s" % [
			on_off(bool(opts.original_cards)), on_off(bool(opts.completion_pack))])
	if int(opts.seed) == 0:
		print("the base seed was rolled; `--seed %d` deals this run again"
			% base_seed)

	var started_at := Time.get_ticks_msec()
	var width := index_width(count)
	var manifest := PackedStringArray([manifest_header()])
	var files := PackedStringArray()
	var by_colors := {}
	var short_runs := 0
	for index in count:
		var wish := combo_at(opts, index)
		var seed_value := deck_seed(base_seed, index)
		var auto := AutoDeck.new()
		auto.pool = _pool_for(wish, opts, list_pool, seed_value)
		auto.pool_label = _pool_label_for(wish, opts, list_label, auto.pool)
		if AutoDeck.pool_total(auto.pool) == 0:
			printerr("auto_deck: the pool for deck %d is empty (%s)"
				% [index + 1, auto.pool_label])
			if index == 0 and String(opts.source) == SOURCE_SETS:
				# The three ways a set selection ends with nothing in it,
				# named rather than left to be found: two of them are
				# switches that look harmless on the line.
				printerr("  --sets names a set the registry has no card for, or")
				printerr("  --original-cards off / --completion-pack off left nothing in it.")
			return 1
		auto.size = int(wish["size"])
		auto.max_colors = int(wish["max_colors"])
		auto.gold = bool(wish["gold"])
		auto.colors = asked_colors(wish["colors"], seed_value,
			int(wish["max_colors"]), bool(wish["gold"]))
		auto.lean = String(wish["lean"])
		auto.speed = String(wish["speed"])
		auto.rarity = String(wish["rarity"])
		auto.land_kind = String(wish["lands"])
		auto.tournament = bool(wish["tournament"])
		auto.power_nine = bool(wish["power_nine"])
		auto.keep = keep.duplicate_model() if keep != null else null
		auto.seed = seed_value
		var deck := auto.build()
		# A NAME PER DECK, because a whole field of "Blue-Black Midrange"
		# is a matrix report nobody can read: the builder's own archetype
		# name plus the index the file carries.
		deck.deck_name = "%s %0*d" % [deck.deck_name, width, index + 1]
		var file_name := deck_file_name(index, width, auto.chosen_colors, seed_value)
		var written := FileAccess.open(out_dir.path_join(file_name), FileAccess.WRITE)
		if written == null:
			printerr("auto_deck: cannot write '%s' (error %d)"
				% [out_dir.path_join(file_name), FileAccess.get_open_error()])
			return 1
		written.store_string(deck.to_text())
		written.close()
		files.append(out_dir.path_join(file_name))
		manifest.append(manifest_row(_record(file_name, index, seed_value,
			opts, wish, auto, deck)))
		var letters := color_letters(auto.chosen_colors)
		by_colors[letters] = int(by_colors.get(letters, 0)) + 1
		if auto.short_by > 0:
			short_runs += 1
		if index % PROGRESS_TICK == 0 or index == count - 1:
			_progress(index + 1, count,
				(Time.get_ticks_msec() - started_at) / 1000.0, false)
	_progress(count, count, (Time.get_ticks_msec() - started_at) / 1000.0, true)

	var manifest_path := out_dir.path_join(MANIFEST_NAME)
	var decklist_path := out_dir.path_join(DECKLIST_NAME)
	if not _write_text(manifest_path, "\n".join(manifest) + "\n"):
		return 1
	if not _write_text(decklist_path, "\n".join(files) + "\n"):
		return 1
	var elapsed := (Time.get_ticks_msec() - started_at) / 1000.0
	print("")
	print("%s deck(s) in %s (%.1f decks/s)" % [LabConsole.commas(count),
		LabConsole.duration(elapsed), count / maxf(elapsed, 0.001)])
	print("colors built: %s" % _colors_line(by_colors))
	if short_runs > 0:
		print("%d deck(s) ran the pool out of spells and took basics instead"
			% short_runs)
	print("manifest: %s   deck list: %s" % [manifest_path, decklist_path])
	print("seeds %d..%d (base %d, stride %d) — any row of %s rebuilds in the AutoDeck window"
		% [deck_seed(base_seed, 0), deck_seed(base_seed, count - 1), base_seed,
			SEED_STRIDE, MANIFEST_NAME])
	print("next: DeckLab/deck_lab.sh --matrix %s --games 50 --no-elo" % out_dir)
	return 0


## The non-land cards of a `--keep` deck — what [member AutoDeck.keep]
## actually puts into every build.
static func _non_lands(model: DeckModel) -> int:
	var n := 0
	for name in model.names():
		var data := DeckModel._card(String(name))
		if data != null and not data.is_land():
			n += int(model.counts[name])
	return n


## The set codes the registry does not have, as a refusal — or "" when
## every one of them is a set. `every` is expanded before this, so a bad
## code is the only thing left to complain about.
static func unknown_sets_message(opts: Dictionary) -> String:
	if String(opts.source) == SOURCE_LIST:
		return ""
	var active := CardRegistry.active_set_order()
	for alternative in opts["sets"]:
		for code in alternative:
			if String(code) == SETS_EVERY or active.has(String(code)):
				continue
			if String(code) == "all":
				return "unknown set code 'all' — `every` is the word for every active set; `all` is Alliances' own code and needs card pack 5"
			return "unknown set code '%s' (active: %s)" % [code,
				", ".join(PackedStringArray(active))]
	return ""


## The set codes one alternative really means: `every` is every active
## set, in the registry's own order.
static func expand_sets(codes: Array) -> Array:
	var out: Array = []
	for code in codes:
		if String(code) == SETS_EVERY:
			for active in CardRegistry.active_set_order():
				if not out.has(String(active)):
					out.append(String(active))
			continue
		if not out.has(String(code)):
			out.append(String(code))
	return out


## The card pool for one deck. The set pools are cached (one walk of the
## registry per set alternative); a sealed pool is dealt per deck from
## that deck's own seed, which is the whole reason the source exists.
func _pool_for(wish: Dictionary, opts: Dictionary, list_pool: Dictionary,
		seed_value: int) -> Dictionary:
	match String(opts.source):
		SOURCE_LIST:
			return list_pool
		SOURCE_SEALED:
			var deal := SealedPool.new()
			deal.boosters = int(opts.boosters)
			deal.starters = int(opts.starters)
			deal.free_lands = int(opts.free_lands)
			deal.extras = int(opts.extras)
			deal.deal(_library_for(wish, opts), seed_value)
			return AutoDeck.pool_from_counts(deal.counts)
	var key := _pool_key(wish, opts)
	if not _pool_cache.has(key):
		_pool_cache[key] = AutoDeck.pool_from_sets(expand_sets(wish["sets"]),
			bool(opts.completion_pack), bool(opts.original_cards))
	return _pool_cache[key]


## The [CardData] the sealed deal opens packs out of — the cards of the
## alternative's sets, cached the same way the set pools are.
func _library_for(wish: Dictionary, opts: Dictionary) -> Array:
	var key := _pool_key(wish, opts)
	if not _library_cache.has(key):
		var library: Array = []
		for name in AutoDeck.pool_from_sets(expand_sets(wish["sets"]),
				bool(opts.completion_pack), bool(opts.original_cards)):
			library.append(CardRegistry.get_card(String(name)))
		# The five basics are never in an AutoDeck pool (they are free),
		# but a sealed pack has a land slot, so they join the library.
		for land in SealedPool.LAND_NAMES:
			if CardRegistry.has_card(land):
				library.append(CardRegistry.get_card(land))
		_library_cache[key] = library
	return _library_cache[key]


static func _pool_key(wish: Dictionary, opts: Dictionary) -> String:
	return "%s|%s|%s" % [",".join(PackedStringArray(_strings(wish["sets"]))),
		opts.completion_pack, opts.original_cards]


static func _strings(values: Array) -> Array:
	var out: Array = []
	for value in values:
		out.append(str(value))
	return out


func _pool_label_for(wish: Dictionary, opts: Dictionary, list_label: String,
		pool: Dictionary) -> String:
	match String(opts.source):
		SOURCE_LIST:
			return list_label
		SOURCE_SEALED:
			return "a sealed pool of %d cards from %s" % [
				AutoDeck.pool_total(pool), sets_label(expand_sets(wish["sets"]))]
	return sets_label(expand_sets(wish["sets"]))


## One manifest row's worth of facts about a finished deck.
static func _record(file_name: String, index: int, seed_value: int,
		opts: Dictionary, wish: Dictionary, auto: AutoDeck,
		deck: DeckModel) -> Dictionary:
	return {
		"file": file_name, "index": index + 1, "seed": seed_value,
		"source": String(opts.source),
		"sets": " ".join(PackedStringArray(_strings(expand_sets(wish["sets"]))))
			if String(opts.source) != SOURCE_LIST else "",
		"pool": auto.pool_label,
		"colors_asked": colors_word(wish["colors"]),
		"colors_built": color_letters(auto.chosen_colors),
		"max_colors": int(wish["max_colors"]),
		"gold": on_off(bool(wish["gold"])),
		"size": int(wish["size"]),
		"lean": String(wish["lean"]),
		"speed": String(wish["speed"]),
		"rarity": rarity_word(String(wish["rarity"])),
		"lands": lands_word(String(wish["lands"])),
		"tournament": on_off(bool(wish["tournament"])),
		"power_nine": on_off(bool(wish["power_nine"])),
		"cards": deck.total(),
		"land_count": deck.land_count(),
		"creature_count": deck.creature_count(),
		"spell_count": deck.spell_count(),
		"deck_name": deck.deck_name,
	}


## Make the output folder, and REFUSE A FOLDER THAT ALREADY HOLDS
## SOMETHING unless --force: a mining run writes thousands of files, and
## a second run into the same folder silently mixes two fields into one
## manifest that describes neither. Returns "" or the refusal.
func _prepare_out_dir(out_dir: String, force: bool) -> String:
	var absolute := ProjectSettings.globalize_path(out_dir)
	if DirAccess.dir_exists_absolute(absolute):
		var dir := DirAccess.open(absolute)
		if dir != null and not force:
			var held := dir.get_files().size() + dir.get_directories().size()
			if held > 0:
				return "'%s' already holds %d file(s) — --force writes into it anyway" \
					% [out_dir, held]
	else:
		var made := DirAccess.make_dir_recursive_absolute(absolute)
		if made != OK and not DirAccess.dir_exists_absolute(absolute):
			return "cannot create the output directory '%s' (error %d)" % [out_dir, made]
	_keep_the_importer_out(out_dir)
	return ""


## A run's folder inside the project must not be imported by the editor:
## a `.deck` file is fine, but `decks.csv` would be read as a translation
## table. DeckLab/simulate.gd's own guard, for its own reason.
static func _keep_the_importer_out(out_dir: String) -> void:
	var dir := DirAccess.open(ProjectSettings.globalize_path(out_dir))
	if dir == null:
		return
	if not dir.get_current_dir().path_join("").begins_with(
			ProjectSettings.globalize_path("res://")):
		return
	var marker := FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)
	if marker != null:
		marker.close()


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("auto_deck: cannot write '%s' (error %d)"
			% [path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	return true


func _source_line(opts: Dictionary) -> String:
	match String(opts.source):
		SOURCE_LIST:
			return "the card list %s" % opts.list
		SOURCE_SEALED:
			var deal := SealedPool.new()
			deal.boosters = int(opts.boosters)
			deal.starters = int(opts.starters)
			deal.free_lands = int(opts.free_lands)
			deal.extras = int(opts.extras)
			# The window's own arithmetic ("Each player gets %d cards")
			# counts the basic lands the packs deal; the pool the builder
			# then sees does not, since basics are free to it — hence
			# "dealt", and the smaller number in each deck's own label.
			return "a sealed pool per deck — %d card(s) dealt from %s" % [
				deal.card_total(), _sets_line(opts)]
	return _sets_line(opts)


func _sets_line(opts: Dictionary) -> String:
	var parts := PackedStringArray()
	for alternative in opts["sets"]:
		parts.append(sets_label(expand_sets(alternative)))
	return " | ".join(parts)


## The wishes as one line, and only the axes that were given more than
## one alternative are spelled out at length — a run of one combination
## says what it is, a run of many says what it varies.
func _wishes_line(opts: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in AXES:
		if key == "sets":
			continue
		var alternatives: Array = opts[key]
		var words := PackedStringArray()
		for value in alternatives:
			words.append(_wish_word(key, value))
		parts.append("%s %s" % [key.replace("_", "-"), ",".join(words)])
	return "; ".join(parts)


static func _wish_word(key: String, value: Variant) -> String:
	match key:
		"colors": return colors_word(value)
		"rarity": return rarity_word(String(value))
		"lands": return lands_word(String(value))
		"gold", "tournament", "power_nine": return on_off(bool(value))
	return str(value)


static func _colors_line(by_colors: Dictionary) -> String:
	var letters: Array = by_colors.keys()
	letters.sort_custom(func(a: String, b: String) -> bool:
		if int(by_colors[a]) != int(by_colors[b]):
			return int(by_colors[a]) > int(by_colors[b])
		return a < b)
	var parts := PackedStringArray()
	for word in letters:
		parts.append("%s %d" % [word, int(by_colors[word])])
	return ", ".join(parts)


# ---------------------------------------------------------- the terminal --

## The banner, once, on stderr — DeckLab/simulate.gd's rules exactly: off
## for --quiet / --no-banner / DECK_LAB_NO_BANNER=1, and off by itself
## when stderr is not a terminal.
func _banner() -> void:
	if _quiet or not _banner_wanted or not LabConsole.is_terminal():
		return
	printerr(LabConsole.banner(LabConsole.use_colour()))
	printerr("")


## What to type instead, after a refusal. Two copyable command lines are
## usually the whole fix.
func _usage_hint(no_arguments: bool) -> void:
	if no_arguments:
		printerr("")
		printerr("AutoDeck CLI builds decks by the thousand for the Deck Lab to mine.")
	printerr("")
	printerr("  DeckLab/auto_deck_cli.sh --out mine --count 500 --colors random")
	printerr("  DeckLab/auto_deck_cli.sh --out mine --count 900 --colors random \\")
	printerr("      --lean creatures,balanced,spells --speed fast,medium,slow")
	printerr("  DeckLab/auto_deck_cli.sh --help      # every switch, with examples")


func _drawing_bar() -> bool:
	if _progress_mode == PROGRESS_BAR:
		return true
	if _progress_mode == PROGRESS_LOG:
		return false
	return LabConsole.is_terminal()


## One progress update: a redrawing bar on a terminal, a heartbeat line a
## minute in a log. The estimate is [LabEta]'s — the rate over the last
## thirty seconds, which is the thing to divide into the decks left.
func _progress(done: int, total: int, elapsed: float, finished: bool) -> void:
	if _progress_mode == PROGRESS_OFF:
		return
	_eta.observe(elapsed, done)
	if finished:
		if _progress_open:
			printerr(LabConsole.LINE_UP)
			_progress_open = false
		elif not _drawing_bar() and _last_logged > 0.0:
			_log_progress(total, total, elapsed)
		return
	if elapsed < PROGRESS_QUIET_SECONDS:
		return
	if _drawing_bar():
		var line := LabConsole.progress_line(done, total, elapsed, "decks",
			LabConsole.width() - 1, _eta.rate())
		printerr((LabConsole.LINE_UP if _progress_open else "")
			+ LabConsole.paint(line, LabConsole.DIM, LabConsole.use_colour()))
		_progress_open = true
		return
	if elapsed - _last_logged < PROGRESS_LOG_SECONDS:
		return
	_log_progress(done, total, elapsed)


func _log_progress(done: int, total: int, elapsed: float) -> void:
	_last_logged = elapsed
	printerr("auto_deck: %s" % LabConsole.progress_line(done, total, elapsed,
		"decks", 78, _eta.rate() if done < total else -1.0).strip_edges())
