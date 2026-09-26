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
## THE COLORS FINDING, which is the reason [constant COLORS_RANDOM] and
## the coverage words exist (measured 2026-09-25, and the reason is in
## the source rather than in a preference): [method
## AutoDeck._choose_colors] reads no random number at all. It rates all
## 31 color sets by the sum of their best castable cards and takes the
## best — so with `--colors none`, the window's own default, one pool and
## one set of wishes land on ONE color pair however many seeds are thrown
## at them. At variety 0 the only randomness in a build is a 0.05 jitter
## on the fill's tie-breaks ([method AutoDeck._fill_spells]), which moves
## a card or two and never a color. A 10,000-deck mining run with no
## colors asked for is therefore 10,000 decks of one color pair, which is
## the opposite of mining. So `--colors` has three shapes beyond the
## window's letters ([method _axis_value]):
##
##   * `random` draws 1..`--max-colors` colors per deck from that deck's
##     OWN seed and builds in EXACTLY those (2026-09-26: exact, where it
##     used to be a floor the builder could add to — a floor of one color
##     let the builder add the same second color to every mono draw, so
##     the field leaned where the pool did).
##   * `=WU` is EXACTLY white and blue: the letters, with `--max-colors`
##     set to their count, the way a player ticks two colors and sets
##     `At most` to 2 ([method asked_max_colors]). Bare `WU` stays the
##     window's floor: those two, and the builder may add up to
##     `--max-colors`.
##   * `mono`, `pairs`, `triples`, `quads`, `five` and `every` are the 5,
##     10, 10, 5, 1 and 31 exact color sets as ALTERNATIVES of the colors
##     axis ([constant COLORS_COVERAGE], [method exact_masks]) —
##     `--colors pairs --count 1000` is a hundred decks of each pair,
##     walked in WUBRG order, and that is how a run makes sure of certain
##     color combinations, or of all of them.
##
## The builder may still find no card of one allowed color worth the
## lands it would want ([method AutoDeck._source_strain]); the deck's
## spells are then the narrower set, its notes say so, and
## `colors_built` records the set that was ALLOWED — which, with the
## row's `max_colors`, is what the window is set to for the rebuild.
##
## VARIETY AND DISTINCTNESS (2026-09-26). At variety 0 the best card
## wins every slot, so one wish and a hundred seeds are a hundred decks a
## card or two apart. `--variety 25|50|100` is the builder's own dial
## ([member AutoDeck.variety], an axis and the window's Variety row):
## the seed's taste moves each card's worth by up to 0.375, 0.75 or 1.5
## points, and the field spreads. `--distinct PCT` is the promise on
## top: every deck of the run differs from every earlier deck by PCT of
## its builder's cards at least ([method AutoDeck.difference] — basics
## and the `--keep` cards do not count), built again from a fresh seed
## up to [constant DISTINCT_TRIES] times until it does; a deck that
## never gets there keeps its most distinct attempt and the summary
## counts it. At variety 0 `--distinct` would fail on the second deck of
## any one wish, so it implies `--variety 50` when none was spoken — and
## after [constant DISTINCT_WILD_AFTER] seeds that fell short, `100`,
## which is what reaches 60% in one set of one pair; the row records the
## variety the kept deck was built at, so the row still rebuilds it.
##
## VARYING A DECK (`--keep FILE --vary "Fireball, 2 Lightning Bolt"`,
## 2026-09-26): the deck held but for the named cards, which LEAVE the
## pool, and the builder fills their slots from what is left — the
## deck's own size, its own lands as they are, its own colors — so a Lab
## run of the field says whether any card in the pool beats the ones
## named ([method varied_cards]).

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
## picks", the mining tool's own draw, the exact prefix and the coverage
## words (see the class doc). A coverage word expands to the exact color
## sets of that many colors (`every` to all 31), as alternatives.
const COLORS_NONE := "none"
const COLORS_RANDOM := "random"
const COLORS_EXACT := "="
const COLORS_COVERAGE := {"mono": 1, "pairs": 2, "triples": 3, "quads": 4,
	"five": 5, "every": 0}

## How many fresh seeds `--distinct` tries for one deck before keeping
## the most distinct attempt. Twenty is a build's worth of patience at
## variety 50: a run of one wish in Fourth Edition reaches 60% in a few
## tries, and one that has run its pool out of ways will not reach it in
## a thousand.
const DISTINCT_TRIES := 20
## The variety `--distinct` implies when `--variety` was not spoken, and
## the seeds it spends at that before the attempts go to variety 100.
const DISTINCT_VARIETY := 50
const DISTINCT_WILD_AFTER := 5

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
	"lean", "speed", "rarity", "lands", "tournament", "power_nine", "variety"]

## The two files a run leaves beside its decks.
const MANIFEST_NAME := "decks.csv"
const DECKLIST_NAME := "decklist.txt"
## THE MANIFEST'S COLUMNS, and this array IS the header line — a row is
## built by walking it, so a column cannot be added to one and not the
## other. `colors_asked` is what was wished for (letters, `=letters`,
## `none` or `random`) and `colors_built` what the builder actually
## chose; those two differing is the normal case and the whole point of
## the finding in the class doc. `max_colors` is the count IN FORCE after
## the build — the letters' own count for an exact wish, 2 at least for
## a gold deck — so the row rebuilds as it is. `distinct` is the deck's
## distance to the nearest earlier deck of the run, in per cent of its
## builder's cards (100 for the first deck, which has none).
const MANIFEST_COLUMNS: Array[String] = ["file", "index", "seed", "source",
	"sets", "pool", "colors_asked", "colors_built", "max_colors", "gold",
	"size", "lean", "speed", "rarity", "lands", "tournament", "power_nine",
	"variety", "cards", "land_count", "creature_count", "spell_count",
	"distinct", "deck_name"]

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
	"--colors": "--colors WU,=WU,none,random,pairs: colors to build in — letters a floor the builder may add to, =letters exactly those, `none` the builder picks, `random` 1..max per deck from its seed, mono|pairs|triples|quads|five|every every exact set of that many (axis)",
	"--max-colors": "--max-colors 1..5: how many colors a deck may have, default 2 (axis)",
	"--gold": "--gold on|off: multicolored cards preferred, two colors at least, default off (axis; bare --gold means on)",
	"--size": "--size 40|60: cards in the deck, default 60 (axis)",
	"--lean": "--lean creatures|balanced|spells: the creature share, default balanced (axis)",
	"--speed": "--speed fast|medium|slow: the curve and the land count, default medium (axis)",
	"--rarity": "--rarity any|pauper|no-rares|uncommon-up|rares: the rarity window, default any (axis)",
	"--lands": "--lands classic|non-classic: basics only, or the pool's own lands first, default classic (axis)",
	"--tournament": "--tournament on|off: no banned cards and restricted cards once, default on (axis; --no-tournament means off)",
	"--power-nine": "--power-nine on|off: the Lotus, the Moxen and the blue three, default off (axis; bare --power-nine means on)",
	"--variety": "--variety 0|25|50|100: how far the seed's taste moves a card's worth, default 0 (axis)",
	"--distinct": "--distinct PCT: every deck at least PCT% different by cards from every earlier one, built again from fresh seeds until it is (implies --variety 50, then 100)",
	"--keep": "--keep FILE: a deck file whose non-land cards every deck is built around (with --vary, the deck held but for the named cards)",
	"--vary": "--vary \"Fireball, 2 Lightning Bolt\": with --keep, hold the deck but for these cards and fill their slots from the pool",
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
const WHOLE_NUMBER_FLAGS: Array[String] = ["--count", "--seed", "--distinct",
	"--boosters", "--starters", "--free-lands", "--extras"]

## The Deck Lab, for its `--packs` reading and enabling — the one switch
## the two tools share, so a field mined from a pack is played with the
## same word. Reached as a script and not a class name: simulate.gd has
## none, being a `--script` of its own.
const Lab := preload("res://DeckLab/simulate.gd")
## The CardPacks autoload's SCRIPT, for its static set → pack table: a
## `--script` run compiles before the autoloads are named, so `CardPacks`
## is not an identifier here (see [method Lab.card_packs]).
const PacksScript := preload("res://game/card_packs.gd")

const HELP := """AutoDeck CLI — build decks by the thousand, for the Deck Lab to mine
===================================================================
The Deck Builder's AutoDeck tool on the command line: the same builder
and the same wishes, one deck file per deck in a folder, a manifest that
says how each one was made, and a plain list of the files for the Lab to
walk. The long-form manual is DeckLab/README.md.

THIS TOOL BUILDS DECKS AND PLAYS NO GAME. The Deck Lab (deck_lab.sh)
plays games and builds no deck. They meet at one folder: this tool
writes it, the Lab's --field (or --matrix) reads it — and at one switch,
--packs, explained under THE POOL, because a deck built from a card
pack's cards can only be played with that pack in play.

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

  # every color pair, exactly, from every set in play — 50 decks a
  # pair, each at least 60% apart by cards from the rest
  DeckLab/auto_deck_cli.sh --out mine --count 500 --colors pairs \\
      --sets every --packs all --distinct 60

  # and then mine them: each against the tournament decks, ranked
  DeckLab/deck_lab.sh --field mine/ --gauntlet decks/ --group tournament \\
                      --games 20 --no-elo

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

  WHAT --packs HAS TO DO WITH BUILDING DECKS. A set's cards exist only
  while its card pack is in play: the base game is 4ed, 2ed, arn, atq,
  leg, drk, past and phpr, and fem (pack 2), ice (3), hml (4), all (5),
  por and p02 (6) and 5ed (7) arrive with their packs. `--sets ice` with
  no pack in play is refused by name, and `--sets every` builds from
  whatever is in play at the time. `--packs LIST` puts packs in play
  for THIS RUN ALONE — `all`, `none`, or ids like pack-3,pack-7 (bare
  3,7 too) — and never touches the game's own setting, so
  `--packs 3 --sets ice` mines Ice Age from any checkout that has the
  pack. This tool never plays a game with them.

  THE COUPLING, in one sentence: a deck built with `--packs X` is a deck
  of proxies to any run without them, so play the field with the Lab's
  own `--packs X` (the same switch, the same words) — the Lab skips a
  pack deck it cannot play and, when every deck of a field is skipped,
  says why.

THE WISHES — every one of them the AutoDeck window's own
  --colors WU        white and blue at least; the builder may add up to
                     --max-colors. Letters from WUBRG.
  --colors =WU       white and blue EXACTLY (--max-colors set to 2)
  --colors none      the builder picks the strongest colors in the pool
  --colors random    1..--max-colors colors drawn from THIS deck's seed,
                     exactly those
  --colors pairs     every color pair, exactly, as alternatives (axis):
                     mono 5, pairs 10, triples 10, quads 5, five 1 and
                     every 31 — the run walks every combination there is
  --max-colors 1..5  how many colors a deck may have           (2)
  --gold on|off      multicolored cards preferred, 2 colors at least (off)
  --size 40|60       cards in the deck                          (60)
  --lean creatures|balanced|spells   the creature share      (balanced)
  --speed fast|medium|slow           the curve and the lands   (medium)
  --rarity any|pauper|no-rares|uncommon-up|rares               (any)
  --lands classic|non-classic        basics only, or the pool's (classic)
  --tournament on|off   no banned cards, restricted once        (on)
  --power-nine on|off   the Lotus, the Moxen, the blue three    (off)
  --variety 0|25|50|100 how far the seed's taste moves a card's worth (0)
  --keep FILE           build every deck around this deck's non-land cards
  --vary "A, 2 B"       with --keep: hold the deck but for the named cards

  `--colors none` IS DETERMINISTIC, and that is the one thing to know
  before starting a mining run. The builder rates all 31 color sets and
  takes the best; no random number is involved, so one pool and one set
  of wishes give the SAME colors for every seed. Ten thousand decks with
  no colors asked for are ten thousand decks of one color pair. Use
  `--colors random`, a coverage word (`--colors pairs`), `--variety`, or
  `--source sealed`, whose pool moves per deck.

  A color the builder was allowed but found no card worth the lands for
  is left out of the spells — the deck's notes say so — and colors_built
  in decks.csv records the colors ALLOWED, which with the row's
  max_colors is what the window is set to for the rebuild.

A FIELD THAT VARIES — `--variety` and `--distinct`
  At variety 0 the best card wins every slot: one wish and a hundred
  seeds are a hundred decks a card or two apart. `--variety 25|50|100`
  (an axis, and the AutoDeck window's own Variety row) lets the seed's
  taste for each card move its worth by up to 0.375, 0.75 or 1.5 points,
  and the field spreads — at 100 in Fourth Edition, two decks of one
  wish are 41% apart at the least and 67% on average.

  `--distinct 60` PROMISES that every deck of the run differs from every
  earlier deck by 60% of its builder's cards at least (basic lands and
  the --keep cards do not count; the measure is the copies not shared,
  over the larger deck). A deck that falls short is built again from a
  fresh seed — seeds past the run's own, so no two decks share one — up
  to 20 times; one that never gets there keeps its most distinct attempt,
  and the summary counts those. decks.csv records each deck's distance
  to the nearest earlier deck in its `distinct` column. Given with no
  --variety, --distinct implies --variety 50 for a deck's first five
  seeds and 100 for the rest — the row records the one the kept deck
  was built at.

VARYING A DECK YOU HAVE — `--keep FILE --vary "Fireball, 2 Lightning Bolt"`
  The deck held but for the named cards: they LEAVE the pool, and the
  builder fills their slots from what is left — the deck's own size, its
  own lands as they are, its own colors (unless --colors says otherwise).
  `2 Lightning Bolt` varies two of the four and holds the rest; a bare
  name varies every copy. A Lab run of the field, with the deck itself
  as the control, then says whether any card in the pool beats the ones
  named:

  DeckLab/auto_deck_cli.sh --out vary --keep decks/mine.deck \\
      --vary "Fireball" --sets every --packs all --count 20 --distinct 25
  DeckLab/deck_lab.sh --field vary/ --field decks/mine.deck \\
      --gauntlet decks/ --group tournament --games 20 --packs all --no-elo

ALTERNATIVES AND THE CARTESIAN WALK
  Every wish marked (axis) in the list above takes a comma-separated list
  of ALTERNATIVES — `--lean creatures,spells --speed fast,slow` is four
  combinations — and may also be repeated. `--sets` is the one exception
  to the comma rule: there a comma joins sets into ONE pool, so repeat
  the flag instead.

  The decks walk the combinations in a fixed order (the last axis moving
  fastest: sets, colors, max-colors, gold, size, lean, speed, rarity,
  lands, tournament, power-nine, variety) and start again from the first
  when the list runs out. So `--count N` spreads N decks evenly over however many
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
  row of decks.csv — the colors_built letters, not the colors_asked
  word, and max_colors as the row has it — type its seed into the Seed
  field, and the deck that comes out is the deck in the file, card for
  card. The seed is
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
                               card/land/creature/spell counts, how far
                               it is from the nearest earlier deck, and
                               the pool it came from.
  decklist.txt                 the deck files in order, one path a line —
                               the list to walk, or to paste into a
                               --gauntlet.

  A folder that already holds files is REFUSED unless --force is given.

MINING WORKFLOW (the Lab's tournament mode: the field vs the known good)
  1. make the field          auto_deck_cli.sh --out mine --count 1000 --colors random
  2. play it off             deck_lab.sh --field mine/ --gauntlet decks/ --group tournament \
                                         --games 10 --top 30 --no-elo --out round1
  3. round1/top.txt names the best thirty; play those properly
                             deck_lab.sh --field round1/top.txt --gauntlet decks/ --group all \
                                         --games 50 --no-elo --out round2
  4. rebuild the winner in the AutoDeck window from its seed and its row
  (a field mined with --packs X is played with --packs X — see THE POOL)

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
## AXES] is a plain value. `spoken` is the set of axes the command line
## named, for the run-level switches that fill in an unspoken one
## (`--distinct` its variety, `--vary` its colors).
static func default_options() -> Dictionary:
	return {
		"out": "", "count": 1, "seed": 0, "force": false,
		"source": SOURCE_SETS, "list": "", "keep": "", "vary": [],
		"distinct": 0, "spoken": {},
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
		"variety": [0],
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


## The `--colors` word for EXACTLY the colors of [param mask]: `=WU`.
static func exact_word(mask: int) -> String:
	return COLORS_EXACT + color_letters(mask)


## Whether a colors wish is an exact one — `=WU`, or `random`, whose
## draw is exact too.
static func is_exact_wish(wish: Variant) -> bool:
	if typeof(wish) != TYPE_STRING:
		return false
	return String(wish) == COLORS_RANDOM or String(wish).begins_with(COLORS_EXACT)


## The masks of every color set of [param count] colors (0 for all 31),
## in WUBRG combination order — W, U, B, R, G; WU, WB, WR, WG, UB, UR,
## UG, BR, BG, RG; and so on — so a `--colors pairs` run walks the pairs
## the way a player would list them.
static func exact_masks(count: int) -> Array:
	var out: Array = []
	for n in range(1, 6):
		if count != 0 and n != count:
			continue
		var masks: Array = []
		for mask in range(1, 32):
			if AutoDeck._count_colors(mask) == n:
				masks.append(mask)
		masks.sort_custom(func(a: int, b: int) -> bool:
			return _combination_key(a) < _combination_key(b))
		out.append_array(masks)
	return out


## The WUBRG positions of a mask's colors as digits — `01` for WU — so
## that sorting the keys sorts the combinations the way they are listed.
static func _combination_key(mask: int) -> String:
	var key := ""
	for i in Mtg.WUBRG.size():
		if mask & int(Mtg.WUBRG[i]):
			key += str(i)
	return key


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
			"--vary":
				var varied := parse_vary(value)
				if varied.has("error"):
					return {"error": varied["error"]}
				opts.vary = varied["cards"]
			"--distinct":
				opts.distinct = value.to_int()
				if opts.distinct < 1 or opts.distinct > 100:
					return {"error": "--distinct takes 1..100, a percentage  (%s)"
						% FLAG_HINTS["--distinct"]}
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
	if not (opts.vary as Array).is_empty() and String(opts.keep) == "":
		return {"error": "--vary needs --keep FILE, the deck to hold  (%s)" % FLAG_HINTS["--keep"]}
	# `--distinct` at variety 0 would fail on the second deck of any one
	# wish (the class doc), so it brings the variety the window's middle
	# choice has — unless the line said what variety it wants.
	if int(opts.distinct) > 0 and not spoken.has("variety"):
		opts.variety = [DISTINCT_VARIETY]
	opts.spoken = spoken
	return opts


## `--vary "Fireball, 2 Lightning Bolt"` as `{"cards": [{"name", "copies"}]}`
## — copies 0 for a bare name, meaning every copy the deck holds — or
## `{"error": ...}`. Which cards the deck actually holds is checked in
## [method varied_cards], once the deck is read.
static func parse_vary(text: String) -> Dictionary:
	var cards: Array = []
	for raw in text.split(",", false):
		var word := raw.strip_edges()
		if word == "":
			continue
		var copies := 0
		var name := word
		var parts := word.split(" ", false, 1)
		if parts.size() == 2 and parts[0].is_valid_int():
			copies = parts[0].to_int()
			name = parts[1].strip_edges()
			if copies < 1:
				return {"error": "--vary: '%s' — the count before a name is 1 or more" % word}
		if name == "":
			return {"error": "--vary: '%s' names no card" % word}
		cards.append({"name": name, "copies": copies})
	if cards.is_empty():
		return {"error": "--vary needs at least one card name  (%s)" % FLAG_HINTS["--vary"]}
	return {"cards": cards}


## The cards `--vary` takes out of [param deck], `name -> copies`, or
## `{"error": ...}` naming the card the deck has not got (or has fewer
## of). A name is matched as typed first, then without regard to case,
## so `lightning bolt` finds Lightning Bolt.
static func varied_cards(deck: DeckModel, vary: Array, file: String) -> Dictionary:
	var out := {}
	for entry in vary:
		var typed := String(entry["name"])
		var name := typed
		if deck.count_of(name) == 0:
			name = ""
			for held in deck.names():
				if String(held).to_lower() == typed.to_lower():
					name = String(held)
					break
		if name == "":
			return {"error": "--vary: '%s' is not in %s" % [typed, file]}
		var held := deck.count_of(name)
		var copies := held if int(entry["copies"]) == 0 else int(entry["copies"])
		copies += int(out.get(name, 0))
		if copies > held:
			return {"error": "--vary: %s holds %d %s, not %d" % [file, held, name, copies]}
		out[name] = copies
	return {"cards": out}


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
		# A coverage word (`--colors pairs`) is several alternatives.
		if read.has("values"):
			out.append_array(read["values"])
		else:
			out.append(read["value"])
	if out.is_empty():
		return {"error": "%s needs a value  (%s)" % [flag, FLAG_HINTS[flag]]}
	return {"values": out}


## ONE alternative of one axis flag, typed the way [AutoDeck] wants it:
## `{"value": ...}` or `{"error": "..."}` — or `{"values": [...]}` for
## the one word that is several alternatives at once, a `--colors`
## coverage word. A colors wish is an int (letters, the window's floor)
## or a String: `none`, `random`, or `=WU` for exactly those letters.
static func _axis_value(flag: String, word: String) -> Dictionary:
	match flag:
		"--colors":
			var lower := word.to_lower()
			if lower == COLORS_NONE or lower == COLORS_RANDOM:
				return {"value": lower}
			if COLORS_COVERAGE.has(lower):
				var values: Array = []
				for mask in exact_masks(int(COLORS_COVERAGE[lower])):
					values.append(exact_word(int(mask)))
				return {"values": values}
			var exact := word.begins_with(COLORS_EXACT)
			var mask := colors_from_letters(word.trim_prefix(COLORS_EXACT))
			if mask <= 0:
				return {"error": "--colors: '%s' is not colors — letters from WUBRG (=WU for exactly those), `none`, `random`, or mono, pairs, triples, quads, five, every" % word}
			return {"value": exact_word(mask) if exact else mask}
		"--variety":
			if not word.is_valid_int() or not AutoDeck.VARIETY_LEVELS.has(word.to_int()):
				return {"error": "--variety takes %s, not '%s'" % [
					", ".join(PackedStringArray(_words(AutoDeck.VARIETY_LEVELS))), word]}
			return {"value": word.to_int()}
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


## The mask a deck is actually ASKED to build in: the letters as typed
## (`WU` and `=WU` alike), the window's 0 for `none`, or the draw for
## `random`.
static func asked_colors(wish: Variant, seed_value: int, max_colors: int,
		gold: bool) -> int:
	if typeof(wish) == TYPE_INT:
		return int(wish)
	if String(wish) == COLORS_RANDOM:
		return random_colors(seed_value, max_colors, gold)
	if String(wish).begins_with(COLORS_EXACT):
		return maxi(colors_from_letters(String(wish).trim_prefix(COLORS_EXACT)), 0)
	return 0


## The `max_colors` a deck is built with: the wish's own, or for an exact
## wish (`=WU`, `random`) the count of the colors asked — which is how
## the window says "these and no other" (tick them, set At most to their
## number). [method AutoDeck.build] still raises 1 to 2 for a gold deck.
static func asked_max_colors(wish: Variant, asked_mask: int, max_colors: int) -> int:
	if is_exact_wish(wish):
		return maxi(AutoDeck._count_colors(asked_mask), 1)
	return max_colors


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
	# THE DECK HELD BUT FOR A FEW CARDS (`--vary`): `held` is the deck as
	# the file has it, `keep` the same less the varied copies, and
	# `varied` the names that leave the pool.
	var held: DeckModel = null
	var varied: Dictionary = {}
	if String(opts.keep) != "":
		var kept := DeckList.load_file(
			ProjectSettings.globalize_path(String(opts.keep)))
		if not kept.errors.is_empty():
			printerr("auto_deck: problems reading '%s':" % opts.keep)
			for problem in kept.errors:
				printerr("  " + String(problem))
			return 1
		keep = DeckModel.from_deck_list(kept)
		if not (opts.vary as Array).is_empty():
			var read := varied_cards(keep, opts.vary, String(opts.keep).get_file())
			if read.has("error"):
				printerr("auto_deck: %s" % read["error"])
				_usage_hint(false)
				return 2
			varied = read["cards"]
			held = keep.duplicate_model()
			for name in varied:
				for i in int(varied[name]):
					keep.remove(String(name))

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
	if held != null:
		print("held: %s (%d cards, %d lands) but for %s — those leave the pool"
			% [opts.keep, held.total(), held.land_count(), _varied_line(varied)])
	elif keep != null:
		print("built around: %s (%d non-land card(s))" % [opts.keep,
			_non_lands(keep)])
	if int(opts.distinct) > 0:
		print("distinct: every deck %d%% from every earlier one by its builder's cards, %d seeds tried a deck%s"
			% [int(opts.distinct), DISTINCT_TRIES,
			"" if (opts.spoken as Dictionary).has("variety")
			else " (--variety %d implied, 100 after %d seeds)"
			% [DISTINCT_VARIETY, DISTINCT_WILD_AFTER]])
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
	# `--distinct`: the field so far, the seeds spent on second attempts
	# (past the run's own, so no two decks of the run share one), and the
	# decks that never reached the distance asked.
	var field := Field.new()
	var distinct := int(opts.distinct)
	var retries := 0
	var unreached := 0
	var nearest := 100
	for index in count:
		var wish := combo_at(opts, index)
		var pool := _pool_for(wish, opts, list_pool, deck_seed(base_seed, index))
		if not varied.is_empty():
			pool = pool.duplicate()
			for name in varied:
				pool.erase(name)
		var pool_label := _pool_label_for(wish, opts, list_label, pool)
		if AutoDeck.pool_total(pool) == 0:
			printerr("auto_deck: the pool for deck %d is empty (%s)"
				% [index + 1, pool_label])
			if index == 0 and String(opts.source) == SOURCE_SETS:
				# The three ways a set selection ends with nothing in it,
				# named rather than left to be found: two of them are
				# switches that look harmless on the line.
				printerr("  --sets names a set the registry has no card for, or")
				printerr("  --original-cards off / --completion-pack off left nothing in it.")
			return 1
		# THE ATTEMPTS: one, or with --distinct as many fresh seeds as it
		# takes (DISTINCT_TRIES at most) — and the most distinct of them
		# is the deck kept, which is the only one when there was one.
		var best_auto: AutoDeck = null
		var best_deck: DeckModel = null
		var best_seed := 0
		var best_cards: Dictionary = {}
		var best_percent := -1
		var attempt := 0
		while true:
			var seed_value := deck_seed(base_seed, index)
			if attempt > 0:
				seed_value = deck_seed(base_seed, count + retries)
				retries += 1
			var auto := _builder_for(wish, opts, seed_value, keep, held, pool, pool_label)
			if distinct > 0 and attempt >= DISTINCT_WILD_AFTER \
					and not (opts.spoken as Dictionary).has("variety"):
				auto.variety = AutoDeck.VARIETY_LEVELS[AutoDeck.VARIETY_LEVELS.size() - 1]
			if String(opts.source) == SOURCE_SEALED and attempt > 0:
				# A sealed pool is the seed's own, so a fresh seed is a
				# fresh deal too.
				auto.pool = _pool_for(wish, opts, list_pool, seed_value)
				auto.pool_label = _pool_label_for(wish, opts, list_label, auto.pool)
			var deck := auto.build()
			var cards := AutoDeck.builders_cards(deck, keep)
			var percent := field.nearest_percent(cards)
			if percent > best_percent:
				best_auto = auto
				best_deck = deck
				best_seed = seed_value
				best_cards = cards
				best_percent = percent
			attempt += 1
			if distinct <= 0 or percent >= distinct or attempt >= DISTINCT_TRIES:
				break
		if distinct > 0 and best_percent < distinct:
			unreached += 1
		if index > 0:
			nearest = mini(nearest, best_percent)
		field.add(best_cards)
		var auto := best_auto
		var deck := best_deck
		var seed_value := best_seed
		# A NAME PER DECK, because a whole field of "Blue-Black Midrange"
		# is a matrix report nobody can read: the builder's own archetype
		# name plus the index the file carries — or the held deck's own
		# name, for a field that is that deck varied.
		deck.deck_name = "%s %0*d" % [held.deck_name if held != null
			else deck.deck_name, width, index + 1]
		if held != null:
			_note_varied(deck, varied, held.deck_name)
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
			opts, wish, auto, deck, best_percent)))
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
	if distinct > 0:
		print("distinct: the nearest two decks are %d%% apart; %d second attempt(s) over the run"
			% [nearest if count > 1 else 100, retries])
		if unreached > 0:
			print("%d deck(s) could not reach --distinct %d in %d tries (the most distinct attempt kept)"
				% [unreached, distinct, DISTINCT_TRIES])
	print("manifest: %s   deck list: %s" % [manifest_path, decklist_path])
	print("seeds %d..%d (base %d, stride %d%s) — any row of %s rebuilds %s"
		% [deck_seed(base_seed, 0), deck_seed(base_seed, count - 1), base_seed,
			SEED_STRIDE, ", %d more for second attempts" % retries if retries > 0 else "",
			MANIFEST_NAME, "with the same --keep and --vary" if held != null
			else "in the AutoDeck window"])
	print(next_step_line(out_dir, _packs_in_force, String(opts.keep) if held != null else ""))
	return 0


## One deck's builder, set up from its wish, its seed and the run's
## kept deck — the window's own members, nothing else ([AutoDeck]).
## With a `--vary` deck ([param held]) the deck's own size, its own
## lands and, unless the line said otherwise, its own colors, exactly.
static func _builder_for(wish: Dictionary, opts: Dictionary, seed_value: int,
		keep: DeckModel, held: DeckModel, pool: Dictionary, pool_label: String) -> AutoDeck:
	var auto := AutoDeck.new()
	auto.pool = pool
	auto.pool_label = pool_label
	auto.size = int(wish["size"])
	auto.gold = bool(wish["gold"])
	auto.colors = asked_colors(wish["colors"], seed_value,
		int(wish["max_colors"]), bool(wish["gold"]))
	auto.max_colors = asked_max_colors(wish["colors"], auto.colors,
		int(wish["max_colors"]))
	auto.lean = String(wish["lean"])
	auto.speed = String(wish["speed"])
	auto.rarity = String(wish["rarity"])
	auto.land_kind = String(wish["lands"])
	auto.tournament = bool(wish["tournament"])
	auto.power_nine = bool(wish["power_nine"])
	auto.variety = int(wish["variety"])
	auto.keep = keep.duplicate_model() if keep != null else null
	auto.seed = seed_value
	if held != null:
		auto.keep_lands = true
		auto.size = held.total()
		auto.land_total = held.land_count()
		var spoken: Dictionary = opts.spoken
		if not spoken.has("colors"):
			auto.colors = _colors_of(held)
			if not spoken.has("max_colors"):
				auto.max_colors = maxi(AutoDeck._count_colors(auto.colors), 1)
	return auto


## The colors of a deck's non-land cards, as a mask.
static func _colors_of(deck: DeckModel) -> int:
	var mask := 0
	for name in deck.names():
		var data := DeckModel._card(String(name))
		if data != null and not data.is_land():
			mask |= data.color_mask() & ~Mtg.ManaColor.C
	return mask


## `4 Fireball, 2 Lightning Bolt` — the varied cards as one phrase.
static func _varied_line(varied: Dictionary) -> String:
	var parts := PackedStringArray()
	for name in varied:
		parts.append("%d %s" % [int(varied[name]), String(name)])
	return ", ".join(parts)


## The note a varied deck carries above its seed line, so the file says
## what was held: "Varied: 4 Fireball — the rest of Big Red held."
static func _note_varied(deck: DeckModel, varied: Dictionary, held_name: String) -> void:
	var lines := deck.notes.split("\n")
	var note := "Varied: %s — the rest of %s held." % [_varied_line(varied), held_name]
	if lines.size() > 0 and lines[lines.size() - 1].begins_with("Seed "):
		lines.insert(lines.size() - 1, note)
	else:
		lines.append(note)
	deck.notes = "\n".join(lines)


## THE FIELD SO FAR, for `--distinct`: every kept deck's builder's cards
## indexed by name, so a new deck is measured against the decks it
## shares a card with and no other — a deck that shares nothing is a
## whole deck apart, and ten thousand decks are not ten thousand
## comparisons of forty names each per deck.
class Field:
	## `name -> {deck index -> copies}`.
	var held: Dictionary = {}
	## Each deck's total of builder's cards, by index.
	var totals: Array[int] = []
	## Decks with no builder's card at all (a held deck varied by nothing
	## the pool could replace): two of those are the same deck.
	var empties := 0

	func add(cards: Dictionary) -> void:
		var index := totals.size()
		var total := 0
		for name in cards:
			total += int(cards[name])
			if not held.has(name):
				held[name] = {}
			held[name][index] = int(cards[name])
		totals.append(total)
		if total == 0:
			empties += 1

	## The distance from [param cards] to the nearest deck held, in per
	## cent — [method AutoDeck.difference], floored, 100 with no deck to
	## measure against.
	func nearest_percent(cards: Dictionary) -> int:
		if totals.is_empty():
			return 100
		var total := 0
		for name in cards:
			total += int(cards[name])
		if total == 0:
			return 0 if empties > 0 else 100
		var shared := {}
		for name in cards:
			if not held.has(name):
				continue
			var holders: Dictionary = held[name]
			for index in holders:
				shared[index] = int(shared.get(index, 0)) + mini(int(cards[name]), int(holders[index]))
		var least := 1.0
		for index in shared:
			var larger := maxi(total, totals[index])
			least = minf(least, 1.0 - float(shared[index]) / larger)
		return int(floor(least * 100.0 + 0.000001))


## WHAT TO TYPE NEXT, packs included: a field mined with `--packs X` is
## a field of proxies to a Lab run without them, so the Lab command
## carries the same switch (`--packs none` when that was the wish).
## `packs` is null when no --packs was given. A varied deck's field is
## played with the deck itself in it, as the control the field is
## measured against.
static func next_step_line(out_dir: String, packs: Variant, held_file := "") -> String:
	var packs_word := ""
	if packs != null:
		var ids: Array = packs
		var numbers := PackedStringArray()
		for id in ids:
			numbers.append(String(id).trim_prefix("pack-"))
		packs_word = " --packs %s" % ("none" if ids.is_empty() else ",".join(numbers))
	var control := " --field %s" % held_file if held_file != "" else ""
	return "next: DeckLab/deck_lab.sh --field %s%s --gauntlet decks/ --group tournament --games 20%s --no-elo" \
		% [out_dir, control, packs_word]


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
				return "unknown set code 'all' — `every` is the word for every active set; `all` is Alliances' own code and needs card pack 5 (--packs 5)"
			# A SET THAT EXISTS BUT IS NOT IN PLAY is not a typo, and the
			# fix is a switch rather than a spelling: name the pack.
			var pack: String = PacksScript.pack_of_set(String(code))
			if pack != "":
				return "set '%s' (%s) is in card pack %s, which is not in play — add `--packs %s`, or `--packs all` for every pack found (active sets: %s)" % [
					code, DeckFilter.SET_LABELS.get(String(code), code),
					pack.trim_prefix("pack-"), pack.trim_prefix("pack-"),
					", ".join(PackedStringArray(active))]
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
		deck: DeckModel, distinct_percent: int) -> Dictionary:
	return {
		"file": file_name, "index": index + 1, "seed": seed_value,
		"source": String(opts.source),
		"sets": " ".join(PackedStringArray(_strings(expand_sets(wish["sets"]))))
			if String(opts.source) != SOURCE_LIST else "",
		"pool": auto.pool_label,
		"colors_asked": colors_word(wish["colors"]),
		"colors_built": color_letters(auto.chosen_colors),
		# The count IN FORCE after the build (the class doc of
		# MANIFEST_COLUMNS), not the wish's number.
		"max_colors": auto.max_colors,
		"gold": on_off(bool(wish["gold"])),
		"size": int(wish["size"]),
		"lean": String(wish["lean"]),
		"speed": String(wish["speed"]),
		"rarity": rarity_word(String(wish["rarity"])),
		"lands": lands_word(String(wish["lands"])),
		"tournament": on_off(bool(wish["tournament"])),
		"power_nine": on_off(bool(wish["power_nine"])),
		"variety": auto.variety,
		"cards": deck.total(),
		"land_count": deck.land_count(),
		"creature_count": deck.creature_count(),
		"spell_count": deck.spell_count(),
		"distinct": distinct_percent,
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
		var line := ",".join(words)
		if key == "colors":
			# `--colors every` is thirty-one words; the line says the one.
			var coverage := coverage_word(alternatives)
			if coverage != "":
				line = "%s (%s)" % [coverage, "%d exact sets" % alternatives.size()]
		parts.append("%s %s" % [key.replace("_", "-"), line])
	return "; ".join(parts)


## The coverage word whose exact sets [param alternatives] are, or "".
static func coverage_word(alternatives: Array) -> String:
	for word in COLORS_COVERAGE:
		var masks := exact_masks(int(COLORS_COVERAGE[word]))
		if masks.size() != alternatives.size():
			continue
		var same := true
		for i in masks.size():
			if str(alternatives[i]) != exact_word(int(masks[i])):
				same = false
				break
		if same:
			return String(word)
	return ""


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
