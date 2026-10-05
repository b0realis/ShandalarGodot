# Driving Shandalar's tools from a program

This is the contract for **running** the headless tools — the Deck Lab,
the AutoDeck CLI, the Lab Query, the referee, the deck converter, and
the MCP server that wraps them — from a script, a pipeline or an agent:
what each command is for, what it prints where, what its exit codes
mean, what files it leaves and under which keys.
The house rules for **editing** the repository are in `CONTRIBUTING.md`;
the manuals with the reasoning are `DeckLab/README.md` and `docs/`.
For **learning to play**, read [the MTG play guide](agentic-playgude-mtg.md):
rules, fair information, combat study, worked examples and deck-building
strategy. It complements this interface contract; it does not replace it.
Every claim below is pinned by
`tests/tools/test_lab_for_machines_2026_09_27.gd`,
`tests/tools/test_lab_records_and_queries_2026_09_27.gd`,
`tests/tools/test_lab_resume_2026_09_27.gd`,
`tests/tools/test_referee_2026_09_27.gd`,
`tests/tools/test_mcp_2026_09_27.gd` (with `tools/test_shandalar_mcp.py`),
`tests/tools/test_deck_lab.gd` and `tests/tools/test_auto_deck_cli.gd`.

## The one door — `./shandalar.sh`

```
./shandalar.sh lab ARGS...        the Deck Lab        (DeckLab/deck_lab.sh)
./shandalar.sh autodeck ARGS...   the AutoDeck CLI    (DeckLab/auto_deck_cli.sh)
./shandalar.sh check DECK...      is this deck playable, and why not
./shandalar.sh packs              every card pack: found, on, why not
./shandalar.sh cards NAME...      a card's record     (DeckLab/lab_query.sh)
./shandalar.sh referee ARGS...    one duel through a pipe, a program
                                  in a seat            (DeckLab/referee.sh)
./shandalar.sh convert IN OUT     .deck <-> .dck      (deck_convert.sh)
./shandalar.sh mcp                the tools as an MCP server on stdio
                                                       (tools/shandalar_mcp.py)
./shandalar.sh VERB --help        that tool's own manual
./shandalar.sh -h | --help        the list, on stdout;  -V | --version
```

Each verb `exec`s the tool, so the exit codes, the channels and the
files below are the tool's own. A verb the door does not know is
refused the way every tool refuses — one JSON line on stdout,
`{"error":{"tool":"shandalar","exit":2,"kind":"option",...}}`, exit 2.
A release folder carries the same `shandalar.sh` (`play` runs the game;
`convert` stays in the checkout) beside `deck_lab.sh`, `auto_deck.sh`,
`lab_query.sh` and `referee.sh`, each a one-liner into the game binary,
and `tools/shandalar_mcp.py` behind `mcp`.

## The two channels

- **stdout is the instrument**: the report (byte for byte `report.txt`),
  a `--dry-run` plan, or a refusal envelope — never a banner, never a
  progress bar, never colour.
- **stderr is the human**: banner, progress, warnings, "did you mean",
  decorated only when stderr is a terminal. `2>/dev/null` loses nothing a
  program needs. `--quiet` drops the banner and the bar.
- One process, one run. The Lab fans games out over `--procs` worker
  processes of its own; do not start a second run, a build or the test
  suite against the same checkout while one runs.

## Exit codes (every tool)

| Code | Meaning |
|---|---|
| 0 | done, every file written (a dry run: the plan printed, nothing written) |
| 1 | the run broke — a worker stopped, a file would not write, an output folder that holds files (AutoDeck without `--force`), a pool with nothing in it |
| 2 | the command line was wrong — a flag, a value, a deck or list file that is not there or is not legal |
| 3 | no Godot binary (`GODOT=/path/to/godot`; the shell wrappers answer `-V` without one) |
| 4 | Lab `--sweep` only: the run finished and wrote its files, but the control pair did not replay game for game — the results are suspect |

## The refusal as data

Every refusal **before a game or a deck** — every exit 2, and the exit 1s
a run can hit before it starts — prints ONE line of JSON on stdout, then
exits. Parse stdout when the exit is non-zero; if it holds an `error`
object, that is the reason.

```json
{"error":{"tool":"deck_lab","exit":2,"kind":"deck",
  "message":"deck file not found: 'big_gren.deck'",
  "path":"big_gren.deck",
  "tried":["big_gren.deck","decks/big_gren.deck","res://decks/big_gren.deck"],
  "folder":false,"suggestions":["decks/big_green.deck"]}}
```

| Key | Always | Meaning |
|---|---|---|
| `tool` | yes | `deck_lab`, `auto_deck`, `lab_query` or `shandalar` |
| `exit` | yes | the code the process exits with |
| `kind` | yes | **the thing to branch on** — below |
| `message` | yes | the prose stderr got |
| `flag` | when named | the flag at fault (`--gmes`, `--keep`, `--out`) |
| `suggestions` | when any | the spellings "did you mean" would offer — flags for `option`, deck paths for `deck` |
| `path`, `tried`, `problems`, `format`, `packs_needed` | by kind | the particulars |

Kinds: `option` (a flag or value, a `--sweep` without its control pair),
`deck` (not found, proxied, illegal for `--format`), `packs` (a `--packs`
that cannot be enabled), `pool` (a `--field`/`--matrix` with nothing in
it), `out` (the folder is a file, cannot be made, or holds files),
and the AutoDeck's own `sets`, `list`, `keep`, `vary`. A refusal
*during* a run keeps its exit code and its stderr and prints no envelope
— by then stdout is the report.

## `--dry-run` — the plan, and nothing played

Both tools take `--dry-run`: every check runs (a bad deck still refuses,
with the envelope), then the plan is printed as pretty JSON on stdout,
exit 0, **no folder is made, nothing is written**. `"dry_run": true` is
always in it.

Deck Lab plan keys: `tool`, `mode` (`duel` `gauntlet` `matrix`
`tournament` `random` `sweep`), `decks[]` (`name`, `file`, `cards`,
`sideboard`), `matchups`, `games_per_matchup`, `unit` (`games` or
`matches`), **`total`** (what the run will play), `seed`, `jobs`,
`procs`, `profile_a`, `profile_b`, `packs` (the switch's value, `null`
when the game's setting decides), `packs_on` (the packs actually on),
`rated`, `format`, `rules`, `out`, `estimate` (`seconds`, at a nominal
rate the note says is a guess — the run measures its own). Tournament
adds `field[]`, `gauntlet[]`, `top`; a sweep adds `knob`, `values`,
`null`, `arms[]`, `pairs[]`, `control`, and `total` is arms × pairs ×
games.

AutoDeck plan keys: `tool`, `count`, `combinations`, `seed`,
`seed_rolled` (no `--seed`: the run would roll one), `source`, `sets`,
`packs`, `packs_on`, `wishes{}`, `distinct`, `keep`/`kept_cards`,
`vary{}`, `list`, `out`, `out_exists`, `out_holds` (files already there
— the `--force` question), `force`, `files{decks,manifest,list}`,
`disk_bytes`, `next` (the Lab command that plays the field, as one
string).

## Deck Lab — `DeckLab/deck_lab.sh`

Plays decks against decks headless and measures. Modes by switch:

```
--deck-a A --deck-b B                 duel (rated unless --no-elo)
--deck-a A --gauntlet DIR|LIST         one deck vs a group
--matrix DIR|LIST                      every pair, round robin
--field DIR|LIST --gauntlet DIR|LIST   tournament: field ranked vs gauntlet (never rated)
--deck-a A --deck-b random             a deck vs the field, a fresh draw a game (--deck-pool DIR)
--deck-a A --deck-b B --sweep KNOB=V1,V2 --control-deck-a C --control-deck-b D
                                       one AI knob, test pair and control pair
```

Deck paths resolve as given, then `decks/NAME`, then `res://decks/NAME`.
`--games N` per matchup, `--seed N`, `--jobs N` threads, `--procs N`
worker processes, `--packs 1,3|all|none`, `--profile-a/-b NAME[:knob=v]`,
`--best-of 3 --sideboard on`, `--rules fifth|modern`, `--format
unrestricted|wild|type1|type1.5|highlander`, `--group NAME` (one deck
group of an expanded folder — `tournament` is the good decks), `--top N`,
`--record losses|stalls|all` (`--record-max N`, default 50), `--out DIR`,
`--resume OUT` (below). `--help` lists every switch; the tables it is read from are the
parser's own, so the help is never behind the code.

Files in `--out` after exit 0: `report.txt` (= stdout), **`results.json`**,
`matchups.csv`, `winrates.svg`, `turns.svg`, **`run.json`**; tournament
adds `standings.csv` and `top.txt`; a sweep writes `report.txt`,
**`sweep.json`**, `sweep.csv`, `games.csv`, `run.json` instead; with
`--record`, a `records/` folder of game logs.

`results.json`: `mode`, `games_per_matchup`, `seed`, `profile_a`,
`profile_b`, `lives`, `ante`, `mulligan`, `rules`, `rule_overrides`,
`format`, `packs`, `elapsed_seconds`, `matchups[]`; each matchup `deck_a`,
`deck_b`, `games`, `a_wins`, `b_wins`, `stalled`, (`draws` when any),
`winrate{low,mid,high}` (Wilson 95%), `winrate_on_play`,
`winrate_on_draw`, `avg_turns`, `median_turns`. Present only when used:
`best_of`/`sideboard`, `field`, `challenge`, and for a tournament
`standings[]`, `gauntlet[]`, `rated:false`.

`sweep.json`: `knob`, `values`, `null`, `games_per_arm`, `seed`,
`matchups[]` and `control{}` each with `arms[]` (`value`, `null`,
`profile_a`, `profile_b`, the matchup stats, `delta{points,margin,clear}`
against the null arm, and on the control pair `verdict{pass,...}`),
**`control_pass`** (false ⇒ exit 4). Read `delta.clear` before quoting
`delta.points`.

Invariants: a `--sweep` needs both `--control-deck-*`; `--no-elo` on any
mined or experimental field (the ledger `decks/ratings.txt` is the
project's own record); one `--seed` replays one run game for game;
tournaments are never rated; `--out` must not be a file.

### `--record` — the games themselves

`--record losses` writes the engine log of every game deck A lost,
`stalls` of every game that hit the turn limit, `all` of every game, to
`OUT/records/`. One file a game, `pairP_seedS[_armA][_duelD]_OUTCOME.log`
(`a_won`, `a_lost`, `drawn`, `stalled`), a `#` header a program reads
before the log:

```
# deck_a: Big Green
# deck_b: White Knights
# pair: 0
# seed: 5
# a_on_play: true
# outcome: a_lost
# turns: 23
# lines: 162
Game set up: SeatZero (40 cards) vs SeatOne (40 cards)
...
```

`--record-max N` caps the files per run (default 50, `0` = no cap; a
thousand logs is a gigabyte) — exact per process, "about N" across
`--procs` workers. `results.json` / `sweep.json` gain
`records{filter,max,written,dir}` only when the switch was used. The
seed in the name replays that game: `--seed S --games 1` on the same
pair.

### `--resume OUT` — finishing an interrupted run

A run writes `run.json` with `exit: null` before its first game and,
as each game lands, one JSON line to `OUT/checkpoint.jsonl` —
`{arm, pair, seed, record, run}` (`run` = `run.json`'s `run_id`; a
resume keeps only its own run's lines, and a fresh run truncates the
file). A run that finishes removes the
checkpoint; a run that was killed leaves both behind, and that is what
an interrupted run looks like: `run.json` with `exit: null` beside a
`checkpoint.jsonl`.

```
DeckLab/deck_lab.sh --resume OUT
```

is the whole line: the switches are read back from `OUT/run.json`
(`argv`), the games in the checkpoint are kept as played, the rest are
played, and the report is written as if nothing had happened —
`run.json` then has `exit: 0`, the original `argv`, and
`resumed {from, reused, played}`. Anything typed beside `--resume` is
refused (exit 2, `kind: "option"`) rather than merged into the line —
but for the chrome flags `--quiet`, `--no-banner` and `--progress MODE`,
which change how the run prints, not what it plays, and never enter the
recorded `argv` (2026-10-03);
a folder without `run.json`, a `run.json` another tool wrote, or a run
that finished (`exit` not null) is refused with `kind: "resume"` and
`path` (and `run_exit` for the finished one). Works for every mode —
a tournament's field × gauntlet is one flat game list, so a three-hour
run that died in its third hour loses only the game it was on.

## `run.json` — after every run

Every run that made its `--out` folder writes `run.json` there before
the first game (`exit: null`) and again at the end, whatever the exit —
the one file to read first:

| Key | Meaning |
|---|---|
| `tool` | `deck_lab` or `auto_deck` |
| `version`, `git` | the project version and the checkout's commit (`""` in a release) |
| `argv[]` | the line as typed, without the program name |
| `mode`, `seed`, `packs`, `packs_on`, `out`, `started` (UTC, `...Z`), `elapsed_seconds` | the run's particulars |
| `exit` | the code the process exits with — `0`, `1`, or the sweep's `4`; `null` while the run is unfinished (see `--resume`) |
| `files[]` | what was written (the Lab); AutoDeck: `files{decks,manifest,list}` |
| `control_pass` | a sweep: whether the control pair replayed game for game |
| `resumed` | `{from, reused, played}` — only on a run finished by `--resume` |
| **`next`** | `{why, argv[]}` — the run that would settle what this one left open — or `null` |

`next.argv` is a complete Deck Lab line built from this run's own argv
with the changing flags stripped and re-added: a duel, gauntlet, matrix
or random run whose matchups still straddle even (`winrate.low < 0.5 <
winrate.high`) gets four times the games at `OUT_more`, unrated; a
tournament gets its `top.txt` as the field at five times the games at
`OUT_top`, same gauntlet; a sweep whose candidate deltas are not `clear`
gets four times the games; AutoDeck's is the Lab line that plays the
field. `null` means nothing is open — every matchup decided, every
delta clear — or, on a sweep whose control moved, that more of the
same would not settle it. A program that loops `run.json.next.argv`
until `null` has run the study; it should still cap the loop.

## AutoDeck CLI — `DeckLab/auto_deck_cli.sh`

Builds decks by the thousand from wishes — the field the Lab plays.

```
DeckLab/auto_deck_cli.sh --out DIR --count N [--seed S] [--colors G,WU,random]
    [--sets 4ed,ice] [--source sets|list|sealed] [--packs 1,2] [--size 40|60]
    [--lean spells|balanced|creatures] [--speed fast|medium|slow] [--gold on|off]
    [--variety PCT] [--distinct PCT] [--keep FILE [--vary "2 Card, 1 Other"]] [--force]
```

Every axis takes a comma list of alternatives and the run walks the
cartesian product `--count` times. `--keep` and `--distinct` imply
`--variety 50` when none was spoken. `--out` must be empty or `--force`
(which clears the previous run's `deck_*.deck`, `decks.csv`,
`decklist.txt` and nothing else).

Files in `--out`: `deck_NNNNN_COLORS_sSEED.deck` per deck, **`decks.csv`**
(one row per deck — `file`, `index`, `seed`, `source`, `sets`, `pool`,
`packs`, the wish columns, `colors_built`, the cards; a row rebuilds its
deck), `decklist.txt` (the paths in order, one a line — a `--gauntlet` or
`--field` reads it), and `run.json` (above; `seed_rolled` says the seed
was the run's own draw, `next.argv` the Lab line). The last stderr line
is `next: DeckLab/deck_lab.sh --field DIR ...`, the same line as words;
`--dry-run` gives it as `next`.

## Asking before running — `DeckLab/lab_query.sh`

Three questions, each answered as ONE pretty-printed JSON document on
stdout and nothing else there. Exit 0 is an answer (a deck that cannot
be played is an answer), 2 a line that could not be answered (the
envelope above, `tool: "lab_query"`), 1 an answer that would not write.

```
DeckLab/lab_query.sh check DECK [DECK...] [--packs LIST] [--format NAME]
DeckLab/lab_query.sh packs
DeckLab/lab_query.sh cards NAME [NAME...]
```

**`check`** loads each deck the way the Lab would (as typed, then
`decks/NAME`) and reports instead of refusing: `decks[]` each with
`file`, `path` (where it was found), `name`, `cards`, `sideboard`,
`errors[]` (lines that are not `COUNT Card Name`), `unknown[]` — every
name the card pool does not know, with `count`, `where`
(`main|sideboard|both`), `pack` (the pack that supplies it; `""` for
none: unimplemented or misspelled) and, for those, `near[]` (the
nearest real names) — `packs_needed[]`, `packs_missing[]` (needed and
not on), `format{name,ok,problem}` with `--format`, and **`playable`**
(no errors, no unknown names, the format met: what the Lab would play);
top-level `playable` over every deck, `packs` (the switch), `packs_on`.
A deck file that is not there is the `deck` refusal with `tried` and
`suggestions`.

**`packs`**: `known[]`, `available[]` (found), `enabled[]` (on) and
`packs[]` — per pack `id`, `label`, `available`, `enabled`, `path`,
`rejection` (why a found zip was not accepted), and for a found pack
`sets[]` and `cards`.

**`cards`**: `cards[]` — a known card's `name`, `cost` (`{3}{W}{W}`),
`mana_value`, `colors[]`, `types[]`, `supertypes[]`, `subtypes[]`,
`keywords[]`, `power`/`toughness` (creatures), `text`, `set`, `sets[]`
(the printings in the pool as configured), `rarity`, `pack` (`""` for a
base card); an unknown one `known: false`, `pack` (the pack that would
supply it) and `near[]`.

## The referee — `DeckLab/referee.sh`

One duel played **through a pipe, a program in a seat**: the game's
engine, the shipped computer players, the LAN wire's own actions.
Every decision goes out on stdout as one JSON line; the answer comes
back on stdin as one JSON line; nothing but JSON is ever written to
stdout (the release's `referee.sh`, the game's `--referee`; the door's
`referee` verb).

```
DeckLab/referee.sh --deck-a DECK --deck-b DECK [--seat-a SEAT] [--seat-b SEAT]
    [--seed N] [--turns N] [--packs LIST] [--rules PRESET] [--log FILE] [--dry-run]
DeckLab/referee.sh --join INVITATION|CODE | --table NAME --deck DECK [--port N]
    [--name NICK] [--wait SECONDS] [--turns N] [--packs LIST] [--log FILE]
DeckLab/referee.sh --host NAME --deck DECK [--access open|invitation] [--address IP]
    [--port N] [--name NICK] [--wait SECONDS] [--turns N] [--packs LIST] [--rules PRESET]
    [--log FILE]
DeckLab/referee.sh ... --listen FILE [--idle SECONDS]
```

**Seats** (`--seat-a`, `--seat-b`; default `agent` vs `wizard`, at
least one `agent`): `agent` is the program on the pipe — both seats,
and it plays itself; `apprentice`, `magician`, `sorcerer`, `wizard` are
the shipped computer players; `unfair` the wizard that reads hidden
cards. A deck is tried as typed, then under `decks/`. `--seed` unset
draws one and reports it. `--turns` (200) calls the duel a draw past
that turn. `--log FILE` writes the engine's own log at the end (at a
table, the journal this seat saw). `--rules PRESET` (2026-10-04) is the
rules forks the duel plays under, one of the Options screen's presets:
`modern`, `modern_mana_burn` (the standard table every SGManalink host
opens — the default) or `fifth` (the 1997 Fifth Edition rules: mana
burn, the damage-prevention window, life checked at phase ends...);
a local duel or `--host` (the host command carries it), refused with
`--join`/`--table` (the host's table decides; `hello.rules` says what
it is); the view's `presentation.rules` has every fork. `--dry-run`
prints the plan (`seats`, `seed`, `turns`, `packs`, `rules`, `ops`)
as one JSON line and plays nothing.

**The lines** (stdout, one JSON object each, `"type"` first):

- `hello` — once, before play: `tool`, `protocol` (1), `version`,
  `git`, `seed`, `seats[]` (`seat`, `player`, `name`, `deck`, `file`),
  `toss` (the seat that won it), `turns`, `rules` (the preset id —
  `modern`, `modern_mana_burn`, `fifth`, or `custom` at a joined table
  whose host mixed its own), `ops[]` (every op the referee accepts),
  `limits{decisions, refusals}`.
- `decision` — `n` (counts up), `seat`, `mode`
  (`opening|priority|attack|block|discard|damage|choice`), `turn`,
  `step`, `options` and `view`. **`options` is the seat's legal answers
  read from its view**: per mode the ops it takes and what each takes
  — `play{lands[{card,name}]}`, `prepare{casts[],abilities[]}` (each
  with its `budget`), `mana{sources[]}`, `special{specials[]}`,
  `respond`, `attack{attackable[]}`, `block{blockable[]}`,
  `choice{prompt,options,count}`, `discard{count,hand}`,
  `damage{request}` — and `concede: true` always. **`casts` and
  `abilities` are usable-only** (2026-10-04): an entry is there only
  when the engine would accept it right now — a cast whose timing
  allows it (on the opponent's turn: instants, flash, the Mirage flash
  rider, a Winding Canyons grant), with something to aim at, its
  non-mana costs there (object costs, an additional sacrifice, life)
  and a payment the seat can reach; an ability that is not used up
  ("Activate only once each turn"), inside its printed timing, not
  banned, whose {T} source is untapped and not summoning-sick, whose
  cost bodies, life, cards and counters are there (Zuran Orb needs a
  land to sacrifice), with something to aim at and reachable mana.
  `mana.sources` lists only sources the engine would tap (no tapped
  land, no sick Elf). `respond` is true when an instant-speed cast or
  an ability is listed — the "holds something" signal a pass-through
  loop stops on. A spell with modes or payment rows (Fireblast's
  "sacrifice two Mountains", Force of Will's pitch, a "Choose one —")
  lists `modes` — every label at its index, the `mode` a line names —
  and `usable_modes`, the indices it can be cast in now (each row's
  object costs, card to exile, life, target and mana); it is a cast at
  all only when one is. A hand card that is not castable keeps its
  `presentation.cards` row and its cost (`castable` false); a spell's
  first spell row there is its printed cost, and one more spell row
  follows for each open mode (`index` the mode, `cost` that row's
  mana). `view` is the seat's
  whole LAN view (`docs/sgmanalink-local-playtest.md`: `hand`,
  `players`, `stack`, `presentation.cards` with `castable` per card,
  `announcement`, `journal`); the `journal` carries only entries not
  sent before.
- `refused` — `n`, `seat`, `reason`, `action`, `left`: the answer could
  not be applied (not JSON, an op that is not a duel op, wrong keys, a
  value the wire would not carry, the wrong seat, or the engine's own
  refusal — "not castable now"). **The same decision follows again**,
  same `n`, from the live view: act on `decision` lines alone. Twenty
  refusals in a row concede the seat. A refused `prepare`, `autoprepare`,
  `autopay`, `submit`, `mana` or `tap` that leaves mana in the seat's
  pool says so: `floating{total, W, U, B, R, G, C}` (the colours held).
  A refusal no payment can change (the once-a-turn limit, timing, a
  ban, a tapped source, nothing to aim at) comes at `prepare`, before
  any land is tapped; a `submit` refused after its payment leaves the
  announcement open — `cancel` withdraws it, the mana stays until the
  step ends (mana burn under the table's rules).
- `result` — `winner` (`-1` for no winner), `draw`, `turns`, `reason`
  (`concluded`, `conceded`, `eof` — the pipe closed —, `refusals`,
  `limit`, `decisions` — 20,000 in one duel —, `stalled` — a computer
  seat could not move —, `left`/`offline` — a table went away —,
  `idle` — a kept game's decision waited `--idle` long for nobody),
  `decisions`, `refusals`, `seed`, `life[]`, `names[]`, `log`.
- `table` — only with `--host`, once, before `hello` and before anyone
  sits: `id`, `name`, `access`, `host` (the nickname), `address`,
  `port`, `invitation` (`sglan1:...`), `discovery` (the advert went
  out). A kept hosted game replays it before `hello`.
- `resume` — only on a kept game's socket, to a client that connects:
  `decisions`, `refusals`, `awaiting` (a decision is open), its `n`,
  `finished`; sent after `table` and `hello` again and before that
  decision again, this time with the WHOLE journal.
- `{"error": {...}}` — the envelope above, `tool: "referee"`: nothing
  was played, exit 2.

**The answers** (stdin, one JSON object a line, the wire's own actions
— `hello.ops` lists them; a line may carry `"seat"`, which must be the
decision's): opening `{"op":"order","play":true}` (the toss winner,
once), `{"op":"keep"}`, `{"op":"mulligan"}`; priority `{"op":"pass"}`,
`{"op":"play","card":ID}`, `{"op":"prepare","card":ID,"kind":"spell",
"index":I,"x":X,"mode":M}` then `{"op":"autopay","excluded":[],
"count":1}` then `{"op":"submit","targets":[[TOKEN,AMOUNT]...]}` (or
`{"op":"cancel"}`), `{"op":"autoprepare","card":ID,"kind":K,"index":I,
"mode":M,"excluded":[],"count":1}` to prepare and pay in one line, and
with `"targets":[TARGET...]` the three in one (below),
`{"op":"mana","card":ID,"index":I}`, `{"op":"tap","card":ID}`,
`{"op":"special","index":I}`; attack `{"op":"attack","cards":[ID...]}`;
block `{"op":"block","pairs":[[BLOCKER,ATTACKER]...]}`; discard
`{"op":"discard","cards":[ID...]}`; damage
`{"op":"damage","points":[[ID|"player",N]...]}`; choice
`{"op":"choice","picks":[I...]}`; any time `{"op":"concede"}`. A blank
line is skipped. Card IDs are the view's handles (`c7`), and every
`options` row names the card beside its handle.

**What a casting line may leave out** (2026-10-04; the referee fills it
in, the wire keeps its strict keys): `prepare` — `kind` (`"spell"`),
`index` (0), `x` (0), `mode` (0); `autoprepare` — `kind` (`"spell"`),
`index` (0), `mode` (0), `excluded` ([]), `count` (1, or the number of
its `targets`); `autopay` — `excluded` ([]), `count` (1); `submit` —
`targets` ([]). So `{"op":"autoprepare","card":"c5"}` casts c5 and pays
for it, and an ability is `{"op":"autoprepare","card":"c9","kind":
"ability","index":0}`. A TARGET, in `submit` and in `autoprepare`, is a
slot token (`t0`, from the announcement), a card handle (`c7`),
`player:0` / `player:1`, or `ability:oN` / `damage:oN` — what the
view's `presentation.targets` (`[{token, ref:{kind, id}}]`) says each
token stands for — bare or as `[TARGET, AMOUNT]` (AMOUNT 0 unless the
slot divides an amount). Handles are matched to the announcement's
slots in order: list them in slot order. **The three in one**:
`{"op":"autoprepare","card":"c5","targets":["c11"]}` — the referee
opens the announcement at X 0 with nothing paid, finds every target
among its candidates (one that is not there refuses the line, nothing
tapped, the candidates named), then prepares and pays (X as large as
the mana allows, as `autoprepare` always did) and submits; `targets:
[]` for a spell or ability with no slots. A question the payment holds
the duel on (a Fellwar Stone's colour, which Forest to return) ends the
line there: answer it, then `submit`.

**A table** (`--join`, `--table`): the same pipe at a table the game
hosts — a person, or another program. `--join` takes the LAN invitation
(`sglan1:...`) the host's screen shows, or the same-computer access
code with `--port`; `--table NAME` instead asks the LAN (the Game
Browser's discovery) for an OPEN host advertising a table of that name
and joins with the invitation its advert carries (an invitation-only
host's table is refused by name — `kind: "table"` — paste its
invitation). `--deck` is the deck this seat brings, `--name` its
nickname (`Agent`), `--wait` (300 s) how long to wait for an open
table, `--log FILE` where the journal this seat saw — every line of the
game as the table told it — is written at the end. The referee joins
the first open room, sends the deck when the table plays own decks,
readies, and then asks the pipe whenever the table's view says it is
this seat's decision; `hello` carries `table{id, name, seat, hosted}`,
`log` and `seed: -1` (the host shuffles). The host sees an ordinary
guest. A lobby command the room moved on under (the lobby's "The room
changed. Please try again." — the other seat's mark or deck landed
meanwhile) is sent again with the fresh revision, up to five times;
a game action is not — the seat decides afresh from the next view.

**A hosted table** (`--host NAME`, 2026-10-03): the referee runs the
game's own LAN host in-process, opens one table of that name with this
program in seat 0 and writes the `table` line before anything else —
how a person finds it. `--access open` (default): the table is listed
in every Game Browser on the LAN and a person joins it by name;
`--access invitation`: listed without its secret, the person pastes
the `invitation` into the game's Join screen. `--address` is one of
this computer's private IPv4 addresses (default the first; refused
off the LAN), `--port` the host's port (17897; 0 any free port),
`--name` the host's nickname, `--wait` (300 s) how long the empty
chair is held — `kind: "host"`, exit 2 when nobody sits — and the
rest as at a joined table. The host's seat is marked ready again each
time the lobby clears the marks (a guest sitting down, their deck), so
the duel starts on the guest's own mark; `hello.table.hosted` is true;
the host stops with the result. The guest sees an ordinary host.

**A kept game** (`--listen FILE`): the same lines served on a loopback
TCP socket instead of the pipe, so the program may go away and come
back — a client restarted, a server that crashed — while the duel
waits. The referee writes FILE once it listens (`{port, token, pid,
version, started}`, as `.part` then renamed; the token is drawn by the
referee and never put on a command line); a client connects to
`127.0.0.1:port`, sends `{"token": ..., "client": ...}` as its first
line and is told where the duel stands (`hello`, `resume`, the awaited
decision). One client at a time: a newcomer with the token replaces
the last; a connection without it is dropped. stdout still carries
every line — the transcript — and stdin is not read. `--idle SECONDS`
(1800; 0 never) concedes the seat when a decision has waited that long
with nobody connected (`reason: idle`). Protocol 1 still: the pipe's
lines are unchanged, `resume` travels only on the socket.

**Exit codes**: 0 a result line was written, whatever the reason; 2 the
line could not be run (a deck, a seat, a switch, a table) — the
envelope on stdout; 1 a file would not write.

## The MCP server — `./shandalar.sh mcp`

Every tool above as **one MCP server on stdio** (`tools/shandalar_mcp.py`,
JSON-RPC 2.0, one message a line; no third-party module — the Python
that runs the other tools runs this one). An MCP client is pointed at
the command; `tools/list` is the whole catalogue, each tool with the
description and the schema a program reads before it calls, and
`initialize` carries a short guide as its `instructions`. The same
script ships in a release at `tools/shandalar_mcp.py`, so the same
verb works in the checkout and in Unix release folders.
On a **Windows release**, use `python tools/shandalar_mcp.py` with Python
3.10 or newer (or `py -3 tools/shandalar_mcp.py`). Point the client's
arguments at the full script path when launching from another directory.
The server discovers `Shandalar.console.exe` beside the extracted game's
files and runs it directly — no Bash or batch-file interpreter required.
Both ordinary tools and persistent referee games use this route. Keep the
whole release together, including `VERSION.txt` (generated from the game's
version, not the engine's); `--door` can explicitly name the console executable.
Deck conversion remains a source-checkout tool, not a packaged-release tool.

```
./shandalar.sh mcp                       the server, on the standard streams
python3 tools/shandalar_mcp.py --catalogue   the tool list as JSON, no client needed
python3 tools/shandalar_mcp.py [--door PATH] [--workspace DIR]
```

**The tools** (`tools/list`): `status` (version, folders, open games),
`contract` (this page), `play_guide` (the MTG learning guide),
`manual` (one tool's `--help`); `packs`, `cards`,
`check_deck` (the Lab Query, quoted); `list_decks`, `read_deck`,
`write_deck` (rows of `4 Lightning Bolt`, written in the format
`engine/deck_list.gd` reads and **checked by the engine as it is
written** — the answer is `check_deck`'s), `convert_deck`; `autodeck`,
`lab` (structured arguments for every switch, `--no-elo` unless `rated`,
`--quiet` always, `dry_run` for the plan; or a whole `argv`; a line
that names no `out` runs into `workspace/runs/lab-STAMP`, so its answer
carries `run`, `results` and `next` like any other),
`lab_resume`, `read_run`, `lab_next` (runs `run.json`'s `next.argv`);
`referee_start`, `referee_join`, `referee_host`, `referee_act`,
`referee_cast`, `referee_play_land`, `referee_view`,
`referee_autoplay`, `referee_wait`, `referee_stop`, `referee_resume`;
`referee_menu`, `referee_pick` (the decision-model menus, below).
Every answer is the door's JSON as
`structuredContent` (and the same text in `content` — except a REFEREE
answer that carries a decision or a result: its `content` is the
compact table summary, see "the compact text" below, unless the game
was opened with `text: "json"`); a refusal is
`isError: true` with the door's envelope untouched under `error`; an
argument a tool does not take is refused with `suggestions`, like a
flag. `cards` looks in every pack the server finds (`--packs all`)
unless its `packs` says otherwise (2026-10-04: a Pack 8 card answered
`known: false` in a profile whose game setting left the pack off; a
found pack that cannot be enabled falls back to the game's setting). Resources: `shandalar://contract` (this page),
`shandalar://play-guide` (the full guide), and
`shandalar://manual/VERB`.

**Learning before playing.** `play_guide {}` returns the full Markdown guide;
`play_guide {chapter: 8}` returns combat, `chapter: 9` the game's rules
differences, and `chapter: 16` deck building. Chapters 1–16 can be requested
separately to keep an observation small. Reading the guide starts no engine,
changes no settings and exposes no game state. The same file ships beside
the release's command-line tools.

**Browsing bundled decks.** Releases include the public `decks/` tree beside
the binary as well as inside its game archive. Keep the whole extraction
together. `list_decks {}` lists this library and the workspace; `folder`
limits it to a subtree, such as `decks/tournament` — a relative folder is
looked for under the checkout, then under the workspace, and the word
`workspace` is the workspace itself wherever `--workspace` put it. `search` matches part of
a name or path, case-insensitively. Optional `offset` (default 0) and `limit`
page the results: `count` is the total matching decks, `returned` the page
size, and `next_offset` is null on the last page. Without `limit`, all matches
are returned. Pass a returned `file` unchanged to `read_deck`, `check_deck`,
`lab` or `referee_start`. Browsing does not validate card availability:
use `check_deck` before playing; some historical lists need optional packs or
contain cards outside the implemented pool. To edit a bundled deck, write a
copy in the workspace. The packager's public allowlist excludes local decks
and the mutable ratings ledger.

**Playing is a session.** `referee_start {deck_a, deck_b, seat_a,
seat_b, seed, turns, packs, rules, log, keep, view, text}` opens the
referee's pipe (`rules`, the table's preset — `modern`,
`modern_mana_burn`, the default, or `fifth` — goes to the referee's
`--rules` and comes back as `hello.rules`; `referee_host` takes it too) and
answers `{game: "g1", hello, decision}`; `referee_act {game, action,
until}` writes one answer and returns the next `decision` (or the
`result`); nothing is played between calls, so a client may think as
long as it likes. `action` is one of the decision's `options` as the wire takes
it (the `seat` is filled in) or the string `default` — the built-in
pilot's answer (keep, play a land, cast the first castable spell,
attack with everything, block nothing; after a refusal on the same
decision the quiet answer, the third refusal concedes).
`referee_autoplay {game, decisions}` lets the pilot answer N decisions
or run to the `result`. A `refused` entry in an answer means the
referee could not apply the action and the same decision is back. The
decision's board is rendered `brief` by default — `turn`, `step`,
`active`, `actor`, both `players` (life, hand and library counts,
mana, graveyard and exile names, the `battlefield` with `pt`,
`tapped`, `sick`, `attacking`, `blocking`, `damage`, `counters`,
`rules`, and for an Aura or Equipment `attached` — the host's handle —
with `attached_name`; the `phased_out` permanents, the same rows marked
`phased_out: true` with `returns` — "returns at your next untap step",
"…the opponent's…", "held by Oubliette (c9): phases in when it leaves
the battlefield", "phases in with Grizzly Bears (c5)"), this seat's
`hand` with `cost` and `castable`, the `stack`,
the open prompts (`announcement`, `choice`, `damage_request`,
`discard_count`), the new `journal` lines — a tenth of the wire's
view; `view: "full"` is the referee's own line, `"options"` the legal
answers alone, `"delta"` what moved since the last answer (the first
delta is a `baseline`; later ones carry only changed life with
`life_was`, `hand_added/gone/changed`, `battlefield_added/changed/gone`,
`phased_out_added/changed/gone`, `attached_changed` (`{id, name, to,
from}`) and `graveyard_added` per player, the `stack`, `castable` names
and the new `journal`). **`view: "compact"`** (2026-10-04, recommended
for a model) is the decision as a few deterministic lines of text: the
clock and the decision; per player life, hand, library and graveyard
counts, the lands on one line, every other permanent with P/T, its
state in brackets (tapped, sick, attacking, blocking, damage, counters,
`on HOST`, `PHASED OUT, returns at …`) and a one-line rules hint; this
seat's hand with costs and `CASTABLE` marks; the stack, top first; the
open prompt (an announcement's slots with every token, its label and
the card it stands for; a choice's options with their indexes; a damage
assignment; a discard); the legal answers one line each (lands to play,
casts with their cost, abilities with `#index` and cost, attackers,
blockers, the op to send or the one-call tool); and the journal.
**The compact text is every referee answer's `content` by default**
(0.50.13, whatever `view` is — what an MCP client shows its model, so an
agent reads the table every turn without asking): every answer of
`referee_start`, `referee_act`, `referee_cast`, `referee_play_land`,
`referee_wait`, `referee_view`, `referee_resume`, `referee_autoplay`,
`referee_stop`, `referee_join`/`referee_host` once seated (a `pending`
answer before that stays JSON), and `referee_menu`/`referee_pick` (the
board with the numbered menu) that carries a decision or a result. It
is headed by the game, what was sent, why a pass stopped, any refusal
and a one-call cast's outcome; a result is one line from the seat's
side ("RESULT: YOU WON (seat 0) | life you 12 / opponent -8 | turns 19 |
reason concluded"); the last line says the full JSON is in
`structuredContent` and names the view it is rendered in and the views.
`structuredContent` is the JSON exactly as `view` renders it (`brief`,
`delta`, `full`, `options`; `compact` is the brief plus the same text as
`compact`), so a program loses nothing. `text: "json"` on
`referee_start`, `referee_join`, `referee_host` or `referee_resume`
(remembered for the game, a kept game's record included) puts the JSON
in `content` instead.
`referee_view {game, view}` renders the pending decision again in any
view without acting and without changing the view the game answers in
(`referee_wait` with `view` changes it). No journal line is lost
between internal passes: a decision answered without being shown — by
`until`, by `referee_autoplay`'s pilot, by a step of `referee_cast` —
hands its lines to the next decision shown. `referee_join {invitation | table, deck, port,
name, wait, turns, log, packs, keep, view, timeout}` sits at a table a
person hosts in the game — a human opponent — by the invitation the
host's screen shows or by the name of an open LAN table; the answer is
`pending: true` until the table starts and `referee_wait` reads on.
`referee_host {table, deck, access, name, port, address, wait, turns,
log, packs, keep, view, timeout}` hosts the table yourself: the answer
is `pending: true` with `table` — the name, the `access` rule, the
host's `address` and `port`, the `invitation`, `discovery` — and a
`note` saying how the person finds it (an `open` table by its name in
their Game Browser; an `invitation` one by pasting the invitation);
`referee_wait` reads on until they sit down, when `hello` (with
`table.hosted: true`) and the first decision arrive. While the chair
is empty every `pending` answer carries `table` again, and `status`
lists the game with `hosted`.
A `result` closes the game; `referee_stop` closes the pipe (`reason:
eof`); the server's own end closes every game it opened — unless kept.
After an action has been sent, a timeout also returns `pending: true`:
the previous decision is consumed, not offered again. Call `referee_wait`
until the next decision or result arrives; do not resend the action.
Timeouts must be finite and greater than zero.

**Progress** (2026-10-03). A `lab` or `lab_next` call whose request
carries `_meta.progressToken` is run with the Lab's `--progress json`
(one `{"progress": {done, total, unit, elapsed}}` line a second on its
stderr), and each line reaches the client as `notifications/progress`
(`progress` = games played, `total`, a `message`), before the answer and
never decreasing. Without a token the line is unchanged.

**Cancelling, and the server while a call runs** (2026-10-03). Calls are
answered one at a time, in the order they came, while the server keeps
reading: a `ping` is answered at once even behind a fifteen-minute Lab
run, and `notifications/cancelled {requestId}` stops that call — the
door's child is killed with its whole process group (the Lab's worker
processes too), a referee wait stops reading — and the cancelled call is
not answered; a call cancelled before it started is skipped. A game a
cancelled `referee_act` was waiting on stays open: its last answer was
sent, so `referee_wait` reads on. A SIGTERM does the same to the call in
flight before the server ends; closing the input still answers every
request already sent, so a file of requests may be piped in.

**Passing with `until`.** `referee_act {action, until}` sends the
answer and then passes priority for the seat up to the next point a
player would act: `main` the seat's own main phase, `end` this turn's
end step, `turn` the seat's next turn, `play` its main phase with
something castable, `respond` only a reaction window. Every value stops
where a real player reacts — the opponent's spell or ability on the
stack (the counterspell, the response), their declared attackers (the
trick before blocks), their blocks, their first-strike damage and their
end step while this seat holds something, the seat's own block decision
on the opponent's turn, and every attack, block, discard, damage and
choice of its own. The answer carries `stop` (why: "the opponent's
Lightning Bolt is on the stack and you can respond", "their declare
attackers: you can respond", "decision: block", "your main phase, with
something to play", "an answer was refused", …), `passed` (decisions
passed over) and the decision shown has the journal of everything
passed; 400 passes without the stop is a stop too. `until: "end"`
passes the seat's own main phase — `play` is the "next time I can do
something" stop. **`until: "mine"`** (2026-10-04, the recommended one)
is the smart pass to the seat's next real decision: its own main phase
with something to do (a land, a listed cast or ability, a special
action) and every attack, block, discard, damage and choice of its own,
and on the opponent's account — their spell or ability on top of the
stack, their declared attackers, their blocks, their first-strike
damage, their end step, and the blocks of the seat's own attack — only
while the seat holds something usable right then, read from the
decision's options (the referee's usable-only `prepare.casts` while it
says `respond`, and `prepare.abilities`; never mana abilities, never
card types): "their Lightning Bolt is on the stack; you hold Disenchant
(castable)". A window where it holds nothing — a sorcery in hand, an
exhausted once-a-turn ability — is passed straight through.
`"mine-strict"` never stops on the opponent's account at all (its own
decisions and its own main phase only), for a client that wants speed.

**One-call actions** (2026-10-04). `referee_cast {game, card, kind,
index, x, mode, targets, exclude, until, view}` casts a spell (`kind:
"spell"`, the default) or activates an ability (`"ability"`; `index`
only when the card has several usable now) in one call: `prepare`,
`autopay`, `submit`. `card` is the handle or the name (among several of
one name, the untapped one first); `x` is required for an X cost and
`mode` (index or label) for a modal spell — unset, the first mode the
referee lists as castable now (`usable_modes`; 0 from a referee that
does not say), and a mode not castable now is refused with the usable
ones (the compact view marks the others "(not now)") — all refused
before anything is sent. `targets` are named by what they are: a card handle
or name, `me`/`opponent`/a seat (`0`, `1`, `player:1`), an
announcement token, `[target, amount]` or `{target, amount, slot}` for
a divided spell (one target takes the whole amount, several without
amounts share it evenly); they are laid on the slots in order, each
token known by the view's `presentation.targets`. A target that is not
legal, a name that fits two, a short slot or an amount that does not
add up is refused with `legal` (every slot's candidates with token,
label and card) BEFORE any mana is made, the announcement withdrawn;
a payment or a submission the referee refuses is withdrawn too
(`cancel`) and comes back as the refusal with `floating_mana` — never a
half-announced cast. The refusal is `isError: true` with `cast`
(`stage`, `reason`, `withdrawn`), `sent` (the ops), the referee's
`refused` lines and the `decision` now pending. A question the payment
asks (a colour) comes back `cast.result: "open"` with that decision:
answer it with `referee_act`, then `referee_cast` the same card again
(it resumes at the submission). A successful cast answers `cast.result:
"cast"` with the targets as laid, and `until` passes on from there.
`referee_play_land {game, card, until, view}` plays a land by handle or
name (unset: the first offered). `referee_act` takes the same as
`{"op":"cast",...}` / `{"op":"activate",...}`, fills an op's missing
keys with the wire's defaults (`prepare` kind spell, index 0, x 0,
mode 0; `autoprepare` kind, index, mode, excluded [], count 1;
`autopay` excluded [], count 1; `submit` targets []; `attack` cards [];
`block` pairs []) and turns a `card` given by name into the handle the
options list it under.

**Decision menus** (0.50.13) — the bridge of "Decision models" below,
inside the server: `referee_menu {game, rich, probe, view, timeout}`
answers the pending decision as `{game, n, obs, menu, stats}` — the
compact observation (with its `features` vector) and every complete
legal action as a numbered `{id, label}` item (`pass`, `play:c3`,
`cast:c12->opp`, `act:c5:0`, `attack:add:c7`, `block:c4->c9`,
`choice:1`, …; item 0 the "do nothing"); `referee_pick {game, pick,
until, rich, view, timeout}` applies one item — its index, its id or
`{"pick": …}` — and answers with the next menu (`picked`, `refused`
for a step the referee refused, which was cancelled at once and left
the menu; with `until`, `stop`, `passed` and `until` — the server's own
stop rule, `mine` included), or the `result`. A pick not on the menu is
refused (`kind: "option"`, `menu` with the ids) before anything is sent.
The server sends the wire ops itself (`tools/decision_menu.py`'s
`Driver` over the game, kept in it from call to call); the aimed spells
are read ahead — a `prepare` and a `cancel`, nothing paid (`probe:
false` turns that off for the game). In the `compact` view the answer's
`content` is the board with the menu as numbered lines (`  3. Cast Holy
Strength → Grizzly Bears — opponent's  [cast:c16->c24]`) in place of the
wire's options. A game the menu tools touched stays playable by every
other referee tool, and the next `referee_menu` takes its decision up
afresh.

**The kept game.** `referee_start`/`referee_join`/`referee_host` take
`keep` (a join and a host are kept by default, a start is not): the
referee listens on a loopback
socket (`--listen`) and the server writes `workspace/games/GAME.json`
(the record: the command, the view, the files) beside the referee's
handshake `GAME.keep.json` and the transcript `GAME.lines`; the game
outlives the server. A new server — a client restarted — lists what is
kept with `referee_resume {}` (`kept[]` with each game's `argv`,
`view`, `started`, `lines`, and its `result` when the transcript ended
alone or a `note`; `games[]` the ones open here) and takes one up with
`referee_resume {game, view, timeout}`: the referee replays `hello`,
its counters (`decisions`, `refusals`) and the awaited decision with
the whole journal, and `referee_act` goes on from there (`resumed:
true` the first time). A kept referee that waited 30 minutes with
nobody connected concedes the seat (`reason: idle`); a kept game whose
referee is gone is reported from its transcript (its `result`, or
`kind: "keep"` when it has none) and forgotten. `referee_stop` ends a
kept game too (`kept: true` in its answer), and removes the record.
The token that opens the socket is drawn by the referee and written to
the handshake file only — never on a command line, never in an answer.
Games are numbered past every file in `workspace/games`, so a second
server never writes over the first's — the number is claimed on disk as
each game opens, so two servers running at once on one workspace never
share one either.

**The rules the server keeps**: stdout is the protocol's (each game's
stderr goes to `workspace/games/GAME.stderr`); a path a tool writes —
`out`, `log`, `file`, a conversion's output — lies under the checkout
or the workspace (`--workspace`, default `workspace/` beside the door,
ignored by git), or the tool refuses with `kind: "path"`; a deck a tool
names (`check_deck`, `lab`, `autodeck`'s `keep`, the referee's seats)
passes as typed when the door will find it — an absolute path, a path
under the checkout or under `decks/` — and a bare name that is a file or
folder in the workspace (the deck `write_deck` wrote, the AutoDeck's
field) is handed over as its absolute path, so `write_deck {file:
"mine.deck"}` then `lab {deck_a: "mine.deck", ...}` is the whole
building-and-measuring loop (since 0.40.35; any other word, `random`,
passes through untouched); a tool never invents a result. Pinned by
`tools/test_shandalar_mcp.py` (a fake door, no engine) and
`tests/tools/test_mcp_2026_09_27.gd` (the real one: a deck written and
checked, a duel played to its end through the pilot, a duel through the
compact view, `until: "mine"` and `referee_cast`).
Advertised types and bounds are enforced before tools run. Raw `argv`,
`extra_args` and recorded `next.argv` also check every `--out`, `--resume`
and `--elo-file` destination. A raw Lab line defaults to `--no-elo` unless
`rated: true`; resume and next-run operations retain the recorded settings.
These checks prevent accidental writes outside the chosen folders; the
local server is trusted tooling, not a security sandbox for hostile clients.

## Decision models — `tools/shandalar_decide.py`

For a program that **chooses moves rather than chats** — a small local
model, a scripted bot, a reinforcement-learning policy, a decision tool
(2026-10-04). Every decision is a compact observation and a **numbered
menu of complete legal actions**; the model answers one number (or the
item's id) and the bridge turns it into the referee's ops — prepare,
autopay, submit, the attack and block lists, the choice picks — and
returns the next decision. No MTG wire knowledge is needed.
`tools/decision_menu.py` is the pure half (menus, observation, the
`Driver` that sequences a pick over two callables); `shandalar_decide.py`
runs the referee through the MCP server's own door route (`shandalar.sh
referee`, a Windows release's console executable) and offers it three
ways. Both ship in a release's `tools/` beside `shandalar_mcp.py`.

```
python3 tools/shandalar_decide.py --deck-a D --deck-b D [--opponent wizard|...|self]
    [--seat 0|1] [--seed N] [--packs 8] [--turns N] [--rules R]
    [--policy random|first|greedy [--episodes N] [--trace]]
    [--rich] [--no-features] [--no-probe] [--no-skip-forced] [--door PATH]
python3 tools/shandalar_decide.py --describe   every numeric field, by name
```

**The lines** (no `--policy`): stdout carries one JSON line a decision,
`{"n", "obs", "menu": [{"id", "label"}...]}` (`--rich`: each item's
`kind`, `info` and `ops` too); stdin answers one line — an index (`3`),
an id (`"cast:c12->opp"`) or `{"pick": 3}`. A line that names no item is
answered `{"n", "error"}` and the **same decision again**; the last line
is `{"result", "summary"}`; a closed stdin leaves the duel (the seat
concedes). `--policy` plays itself instead — `first` always item 0 (the
passive baseline), `random`, `greedy` (a one-ply example) — one line a
game (`winner`, `won`, `turns`, `reason`, `decisions`, `forced`,
`wire_decisions`, `probes`, `refusals`, `boot_seconds`,
`seconds_per_decision`) and `{"summary"}` over `--episodes` (game *i*
plays `--seed`+*i*). Exit 0 played, 2 a line that could not be run (the
referee's own envelope on stdout), 1 the referee went away, 3 no Godot.

**The menu.** Item 0 is the mode's "do nothing" wherever it has one (pass,
no attack, no blocks, keep, play first, damage in order). Ids are stable
across identical states:

| Mode | Items |
|---|---|
| opening | `order:play`, `order:draw` (the toss winner, once), then `keep`, `mulligan` |
| priority | `pass`; `play:<land>`; `cast:<card>[:m<mode>][:x<X>][-><target>]` — one item per legal target of a one-target spell, read from the referee's own announcement (a `prepare` + `cancel` *probe*, once per state); `act:<card>:<i>[...]` an activated ability; `special:<i>`. A modal spell is offered in each mode its `usable_modes` lists (every mode from a referee that does not send it), the id keeping the mode's index. Mana abilities are not items (the auto-pay taps); identical hand cards are listed once |
| targets | a cast whose targets do not fit one flat list (two slots, "up to N", divided damage, an X spell, more than 16 candidates): `target:<t>`, `target:none`/`target:done`, `cancel`; "another target" leaves out an earlier slot's pick; divided amounts split evenly |
| attack | `attack:none`, `attack:all`, `attack:add:<card>` one at a time, `attack:declare` (a must-attack creature is preselected) |
| block | `block:none`, `block:<blocker>-><attacker>` one pair at a time, `block:declare` |
| discard | `discard:<card>` one pick at a time |
| damage | `damage:ordered`, `damage:upto:<id>`, `damage:all:<id>` (free assignment only) |
| choice | `choice:<i>` (a multi-pick question one pick at a time), `choice:none` (it takes none), `choice:cancel` (a cost withdrawn) |

A sub-menu step sends nothing until its last pick. A decision whose menu
has one item is answered by the bridge (`forced`; `--no-skip-forced`
shows it). **The guard**: a cast is `prepare`, `autopay` only once the
announcement says the payment is reachable, `submit`; a refused step is
cancelled at once — never left half-announced — and the action leaves
the menu until the turn, step, stack or board changes; every refusal is
counted (`refusals`, the referee's own in `referee_refusals`). A payment
that asks a question (a colour, a land to return) shows it to the model
and submits after the answer.

**The observation** (`obs`): `mode`, `turn`, `step`, `active` (`me`/
`opp`), `me`/`opp` (life, hand and library counts, mana, poison, the
battlefield with type, P/T, keywords, tapped/sick/attacking/blocking,
damage, counters, `attached`; `phased_out`; graveyard and exile names),
`hand` (cost, `castable`), `stack`, `prompt`, `selection` (a sub-menu's
picks), `journal` (every line since the model last chose) and
`features` — a fixed vector of 66 floats in [-1, 1], each field named
by `--describe` (`decision_menu.FEATURES`; one item's 30 in
`ITEM_FEATURES`).

**The Python API**: `Env(deck_a, deck_b, opponent="wizard", seed=None,
packs=None, rules=None, seat=0, ...)`; `reset()` → obs; `menu()`;
`step(choice)` → `(obs, reward, done, info)` (reward ±1 at a won/lost
end); `done`, `result`, `stats()`, `hello`; a context manager. `rules`
(`--rules`) goes to the referee as its `--rules`: `modern`,
`modern_mana_burn` (the standard table, its default) or `fifth` (the 1997
rules); the preset played is `hello["rules"]`, in `stats()` and in each
`--policy` game line, and a word the referee does not know is its own
refusal envelope. Pinned by
`tools/test_shandalar_decide.py` (recorded referee lines in
`tools/fixtures/decide_decisions.json`; `LiveTest` behind
`SHANDALAR_DECIDE_LIVE=1` plays whole duels against the wizard with zero
refusals). The same menus inside the MCP server: `referee_menu` and
`referee_pick` ("The MCP server", "Decision menus").

**Typed decision models — Laya, Jev and the like (initial support,
2026-10-04).** Laya (run locally with `laya-serve`) and Jev (a hosted API)
read the same request: a `state` and typed `questions`, `POST
/v1/systemone`, a `choice` question answered with the option picked and a
probability for each. `--policy systemone --url URL [--model NAME]` asks
such a model every decision: the state is the compact observation (no
numeric vector, no journal), the one `choice` question names every menu
item by its readable label, and the model's `choice` (or its most likely
option) is the pick; `SYSTEMONE_API_KEY`, when set, goes as `Authorization:
Bearer`. On stdin/stdout, `--systemone` adds each decision's ready-made
request to its record, and an answer object with `answers.action.choice` is
accepted as the pick. In Python: `systemone_request(obs, menu)` and
`systemone_pick(answer, request)`. Deliberately minimal — fitting the state
to a model's context length, or asking `score`/`noul` questions, is the
model user's to take further. Training data for such a model is possible
with `--trace` (every decision, its options and the pick, then the winner);
a dataset export and Wizard teacher labels are an open, unbuilt request
(ROADMAP, 0.50.13).

## Deck convert — `./deck_convert.sh INPUT OUTPUT`

Formats come from the extensions (`.deck`/`.dec` ↔ `.dck`). Exit 0 with
the converted deck's report on stdout; 2 on anything else (a missing
argument, a deck with problems or no cards, an unknown extension, a file
that would not write — the reason on stderr). No JSON envelope here yet.

## The game itself

`godot --path .` (or the released binary) takes `--deck-lab`,
`--auto-deck`, `--lab-query` and `--referee`, each hosting that headless
tool inside the game binary (what a release's `deck_lab.sh`,
`auto_deck.sh`, `lab_query.sh` and `referee.sh` are), and
`--verify-pack-1..5`; the LAN protocol is 24
(`docs/sgmanalink-*.md`). Headless soaks and audits live under
`tools/*.gd` (`./duel_soak.sh --help`). `./run_tests.sh` is the gate:
trust its exit code, not the printed tally.

## A session, in order

```
./shandalar.sh packs                                                         # what is on
./shandalar.sh autodeck --out mined --count 200 --colors random --dry-run    # plan
./shandalar.sh autodeck --out mined --count 200 --colors random              # build
./shandalar.sh check mined/deck_00001_G_s11.deck                             # playable?
./shandalar.sh lab --field mined --gauntlet decks/ --group tournament \
    --games 20 --no-elo --record losses --out mined_run --dry-run            # plan
./shandalar.sh lab --field mined --gauntlet decks/ --group tournament \
    --games 20 --no-elo --record losses --out mined_run 2>/dev/null          # play
jq '.standings[:10]' mined_run/results.json                                  # read
jq -r '.next.argv // empty | @sh' mined_run/run.json                         # what next
./shandalar.sh referee --deck-a mined/deck_00001_G_s11.deck \
    --deck-b decks/white_knights.deck --seat-b wizard --seed 7 2>/dev/null   # play it
```

The referee's stdout is `hello`, then `decision` lines each answered on
its stdin (`{"op": ...}`), then one `result`; a `refused` line means the
same decision follows again.

The same session through the MCP server is `packs` → `autodeck` (or
`write_deck`) → `check_deck` → `lab` (`dry_run`, then the run) →
`read_run`/`lab_next` → `referee_start` and `referee_act` (with
`until` to skip to where a player acts) until the `result` — every tool
listed by `tools/list`, none needing a shell; a game kept across a
restart comes back through `referee_resume`.

A non-zero exit: read stdout for `{"error":...}`, branch on `kind`, offer
`suggestions`; never retry the same line. A zero exit: read `run.json`,
and `next.argv` is the line that settles what this run left open.
