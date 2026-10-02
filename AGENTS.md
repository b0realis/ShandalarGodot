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
`{arm, pair, seed, record}`. A run that finishes removes the
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
refused (exit 2, `kind: "option"`) rather than merged into the line;
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
    [--seed N] [--turns N] [--packs LIST] [--log FILE] [--dry-run]
DeckLab/referee.sh --join INVITATION|CODE --deck DECK [--port N] [--name NICK]
    [--wait SECONDS] [--turns N] [--packs LIST]
```

**Seats** (`--seat-a`, `--seat-b`; default `agent` vs `wizard`, at
least one `agent`): `agent` is the program on the pipe — both seats,
and it plays itself; `apprentice`, `magician`, `sorcerer`, `wizard` are
the shipped computer players; `unfair` the wizard that reads hidden
cards. A deck is tried as typed, then under `decks/`. `--seed` unset
draws one and reports it. `--turns` (200) calls the duel a draw past
that turn. `--log FILE` writes the engine's own log at the end.
`--dry-run` prints the plan (`seats`, `seed`, `turns`, `packs`, `ops`)
as one JSON line and plays nothing.

**The lines** (stdout, one JSON object each, `"type"` first):

- `hello` — once, before play: `tool`, `protocol` (1), `version`,
  `git`, `seed`, `seats[]` (`seat`, `player`, `name`, `deck`, `file`),
  `toss` (the seat that won it), `turns`, `ops[]` (every op the
  referee accepts), `limits{decisions, refusals}`.
- `decision` — `n` (counts up), `seat`, `mode`
  (`opening|priority|attack|block|discard|damage|choice`), `turn`,
  `step`, `options` and `view`. **`options` is the seat's legal answers
  read from its view**: per mode the ops it takes and what each takes
  — `play{lands[{card,name}]}`, `prepare{casts[],abilities[]}` (each
  with its `budget`), `attack{attackable[]}`, `block{blockable[]}`,
  `choice{prompt,options,count}`, `discard{count,hand}`,
  `damage{request}` — and `concede: true` always. `view` is the seat's
  whole LAN view (`docs/sgmanalink-local-playtest.md`: `hand`,
  `players`, `stack`, `presentation.cards` with `castable` per card,
  `announcement`, `journal`); the `journal` carries only entries not
  sent before.
- `refused` — `n`, `seat`, `reason`, `action`, `left`: the answer could
  not be applied (not JSON, an op that is not a duel op, wrong keys, a
  value the wire would not carry, the wrong seat, or the engine's own
  refusal — "not castable now"). **The same decision follows again**,
  same `n`, from the live view: act on `decision` lines alone. Twenty
  refusals in a row concede the seat.
- `result` — `winner` (`-1` for no winner), `draw`, `turns`, `reason`
  (`concluded`, `conceded`, `eof` — the pipe closed —, `refusals`,
  `limit`, `decisions` — 20,000 in one duel —, `stalled` — a computer
  seat could not move —, `left`/`offline` — a table went away),
  `decisions`, `refusals`, `seed`, `life[]`, `names[]`, `log`.
- `{"error": {...}}` — the envelope above, `tool: "referee"`: nothing
  was played, exit 2.

**The answers** (stdin, one JSON object a line, the wire's own actions
— `hello.ops` lists them; a line may carry `"seat"`, which must be the
decision's): opening `{"op":"order","play":true}` (the toss winner,
once), `{"op":"keep"}`, `{"op":"mulligan"}`; priority `{"op":"pass"}`,
`{"op":"play","card":ID}`, `{"op":"prepare","card":ID,"kind":"spell",
"index":I,"x":X,"mode":M}` then `{"op":"autopay","excluded":[],
"count":1}` then `{"op":"submit","targets":[[TOKEN,AMOUNT]...]}` (or
`{"op":"cancel"}`), `{"op":"autoprepare",...}` for the three in one,
`{"op":"mana","card":ID,"index":I}`, `{"op":"tap","card":ID}`,
`{"op":"special","index":I}`; attack `{"op":"attack","cards":[ID...]}`;
block `{"op":"block","pairs":[[BLOCKER,ATTACKER]...]}`; discard
`{"op":"discard","cards":[ID...]}`; damage
`{"op":"damage","points":[[ID|"player",N]...]}`; choice
`{"op":"choice","picks":[I...]}`; any time `{"op":"concede"}`. A blank
line is skipped. Card IDs are the view's handles (`c7`), and every
`options` row names the card beside its handle.

**A table** (`--join`): the same pipe at a table the game hosts — a
person, or another program. `--join` takes the LAN invitation
(`sglan1:...`) the host's screen shows, or the same-computer access
code with `--port`; `--deck` is the deck this seat brings, `--name` its
nickname (`Agent`), `--wait` (300 s) how long to wait for an open
table. The referee joins the first open room, sends the deck when the
table plays own decks, readies, and then asks the pipe whenever the
table's view says it is this seat's decision; `hello` carries
`table{id, name, seat}` and `seed: -1` (the host shuffles). The host
sees an ordinary guest.

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
`--quiet` always, `dry_run` for the plan; or a whole `argv`),
`lab_resume`, `read_run`, `lab_next` (runs `run.json`'s `next.argv`);
`referee_start`, `referee_join`, `referee_act`, `referee_autoplay`,
`referee_wait`, `referee_stop`. Every answer is the door's JSON as
`structuredContent` (and the same text in `content`); a refusal is
`isError: true` with the door's envelope untouched under `error`; an
argument a tool does not take is refused with `suggestions`, like a
flag. Resources: `shandalar://contract` (this page),
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
seat_b, seed, turns, packs, log, view}` opens the referee's pipe and
answers `{game: "g1", hello, decision}`; `referee_act {game, action}`
writes one answer and returns the next `decision` (or the `result`);
nothing is played between calls, so a client may think as long as it
likes. `action` is one of the decision's `options` as the wire takes
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
`rules`), this seat's `hand` with `cost` and `castable`, the `stack`,
the open prompts (`announcement`, `choice`, `damage_request`,
`discard_count`), the new `journal` lines — a tenth of the wire's
view; `view: "full"` is the referee's own line, `"options"` the legal
answers alone. `referee_join {invitation, deck, port, name, wait}`
sits at a table a person hosts in the game — a human opponent; the
answer is `pending: true` until the table starts and `referee_wait`
reads on. A `result` closes the game; `referee_stop` closes the pipe
(`reason: eof`); the server's own end closes every game it opened.
After an action has been sent, a timeout also returns `pending: true`:
the previous decision is consumed, not offered again. Call `referee_wait`
until the next decision or result arrives; do not resend the action.
Timeouts must be finite and greater than zero.

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
checked, a duel played to its end through the pilot).
Advertised types and bounds are enforced before tools run. Raw `argv`,
`extra_args` and recorded `next.argv` also check every `--out`, `--resume`
and `--elo-file` destination. A raw Lab line defaults to `--no-elo` unless
`rated: true`; resume and next-run operations retain the recorded settings.
These checks prevent accidental writes outside the chosen folders; the
local server is trusted tooling, not a security sandbox for hostile clients.

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
`read_run`/`lab_next` → `referee_start` and `referee_act` until the
`result` — every tool listed by `tools/list`, none needing a shell.

A non-zero exit: read stdout for `{"error":...}`, branch on `kind`, offer
`suggestions`; never retry the same line. A zero exit: read `run.json`,
and `next.argv` is the line that settles what this run left open.
