# Development

The front door for somebody who has just cloned this repository. It exists to
get you oriented, productive, and unlikely to break something, in one read.

**It points; it does not repeat.** Where a fact already lives somewhere, this
file names that file and says when to open it. The house rules are
`CONTRIBUTING.md` and it is the one that is maintained. The design is
`docs/ARCHITECTURE.md`. The encyclopaedia — every file in the project and what
is in it — is `docs/CODE_MAP.md`, and it is exact; keep it that way. Nothing
below restates them, because a second copy of a fact is a fact that will
drift — and this project was bitten by that twice on 2026-09-11 alone: a
`--help` that quoted its own header by line number and stopped mid-sentence
when the header outgrew it, and a ledger row citing code lines a thousand
lines from where the code had moved to.

Everything here was verified against the tree on **2026-09-12** (version
`0.20.0-dev`). Numbers that are somebody else's measurement carry the date
they were measured.

---

## 1. What you have cloned

A from-scratch GDScript remake of MicroProse's 1997 *Magic: The Gathering*
("Shandalar") on Godot 4.7, under GPL-3.0. Not a new game inspired by it — a
remake with a **fidelity standard**, and that standard is the thing that makes
this codebase unusual to work in.

**Port, don't invent.** Where the 1997 game made a decision, that decision
wins, and its own files are the authority. `Provenance.md` (674 lines, repo
root) is the register: three tiers of source, which outranks which, and the
traps in reading each one. Read it before you cite anything. A behaviour
carries a marker at the site saying where it came from — measured today:

| Marker | Sites | Means |
|---|---|---|
| `[1997]` | 18 | the original did this, and the source is named |
| `[QoL]` | 285 | ours, a modern convenience, deliberately labelled |
| `[s30]` | 9 | taken from the 30th-anniversary remake, which the 1997 game did not have |
| `[forge]` | 18 | a mechanism read out of Forge's AI, naming file, lines and commit |

(`grep -rn '\[QoL\]' engine/ game/ cards/ | wc -l` and friends.) `[QoL]` is by
far the largest because the rule is that every convenience is labelled, not
that conveniences are rare. Forge's file-and-line pointers are all read against
**one pinned commit** (`b09a3d3f`); `docs/forge/README.md` says why the commit
is part of the citation and not an afterthought.

**Every shortcut is written down.** A rules simplification carries the word
`SIMPLIFIED` in caps at the exact site *and* a row in a ledger:
`docs/simplified-cards.md` for a card-scoped one, `docs/ROADMAP.md` for an
engine-wide one. Today: **three card files** carry the marker
(`grep -rlw SIMPLIFIED cards/sets/`) against two live ledger rows, and **four
engine files** carry engine-wide ones. `tests/test_simplified_ledger.gd` pins
marker and ledger to each other in three directions — a marked file nobody
wrote down, a row that outlived its marker, and (since 2026-09-11) an
`engine/` marker that names no doc. Lifting a simplification means deleting
the marker, deleting the row, and pinning the full behaviour with a test.

**Where the 1997 rules and modern Magic genuinely disagree, it is a switch,
not a default.** `engine/rules_options.gd` holds all seven forks (mana burn,
revocable attackers, ...), each with the manual page that establishes the 1997
answer; all seven are implemented, and every one defaults to the modern
answer.

---

## 2. Get it running

### The engine binary

The project pins **Godot 4.7.2**. Every script looks for it at `../tools/godot`
— the sibling of the checkout, *outside* the repository — and falls back to
`godot` on `PATH`. Note that the repository has its own `tools/` directory as
well, holding Python pipelines; they are two different places with the same
name, and the Godot binary is never in the one you can see.

If your binary is anywhere else, or you are working in a **git worktree**
(where `../tools` resolves to nothing), set it explicitly — every script reads
the same variable:

```sh
export GODOT=/path/to/ShandalarGodot/tools/godot
```

`DeckLab/deck_lab.sh` is the only one that fails honestly without it — exit 3
and a message naming the two places it looked. `run_tests.sh` and
`duel_soak.sh` fall through to a bare `godot`, and what you see is `timeout`
complaining about a missing file, which does not look like a missing engine at
all.

### The gate

Two commands, and both are gates rather than reports — read their exit codes,
not their output.

```sh
./run_tests.sh                                  # the whole GUT suite, headless
python3 -m unittest discover -s tools -p 'test_*.py'
```

On this tree today: **6085 passing tests / 156 339 asserts across 353 scripts**
in about 365 s, exit 0; and **217 tests OK** in three seconds for the Python
side.

`run_tests.sh` checks its own log because **GUT lies by omission**: a test
script it cannot parse is silently skipped and the summary still reads "All
tests passed" (verified 2026-08-31 — one broken file, 1894/1894 green, a whole
file never run). So the script additionally fails on a parse/compile error, on
any `ERROR:`/`SCRIPT ERROR:` line, on a risky or pending test, on the
leaked-objects line at exit, and on a timeout. Its header block explains each
one and what it cost. **Trust exit 0; do not grep the summary.**

Running less than everything:

```sh
./run_tests.sh -gselect=test_simplified_ledger.gd            # one script
./run_tests.sh -gunit_test_name=test_bolt_kills_a_bear       # one test
```

Both take seconds. Everything on the command line that is not `-h`/`--help`
or `-V`/`--version` is handed to GUT unchanged.

### The other two checks

```sh
$GODOT --headless --path . --quit-after 3       # boot smoke: does the project load
./duel_soak.sh                                  # whole duels through the live screen
```

The boot smoke is what catches a card file that will not parse, and you want
it after touching any card — see the trap in §6. The soak plays complete duels
through the real duel screen under Xvfb with AI seats and a fuzzed human seat;
a bare run is three seeds in both modes — six whole duels, about three
minutes, ending in `SOAK done: 6 duel(s) finished`. Run it after
touching anything under `game/duel/`: the suite drives one widget at a time
and cannot see what the soak catches. It passes only on `SOAK done` with no
`ERROR`/`WARNING`/`STALL` line — exit 2 means a duel stood still or never
started (a stuck prompt, which is what it exists to catch), 3 a bad argument,
124 the whole-run guard, 1 a stray line Godot printed. Its header has the
rest.

### Where `user://` goes

`user://` is the same directory for a dev run as for the shipped game, because
it is the same project name. `run_tests.sh` and `duel_soak.sh` therefore point
`XDG_DATA_HOME` at a scratch directory (`$TMPDIR/shandalar-test-data`,
override `SHANDALAR_TEST_DATA_HOME`) so a test can never write a player's real
profile. Anything you run by hand does **not** get that for free. The incident
that made it a rule is in `run_tests.sh`'s header and in `docs/ROADMAP.md`
("WHY THE THREE DOTS DID NOT REACH THE OWNER").

### The art, which is not in the repository

`assets/original/` and `assets/cardart/` are gitignored — no 1997 file and no
card image is distributed here, ever. **The game is complete and plays with
none of it**, because every skinned path has a drawn fallback of the same
geometry, and nothing is unreachable. The *suite* is a different matter: a
handful of UI tests measure against the real 1997 files and fail if they are
absent — see §6 before you read a red suite as your fault.

`README.md`'s "The art, and how to reconstruct it" is the complete recipe
(`tools/mtg_assets.py` reads your own copy of the 1997 game and writes a skin
zip; `tools/fetch_card_art.py` fetches card art from Scryfall).
`docs/player-files.md` maps every path the built game reads or writes, and
`docs/skin-catalogue.txt` lists every picture, font, sound and tune a skin has
to contain, so one can be drawn from scratch.

---

## 3. The folder tour

| Folder | What is in it | May depend on | Why the boundary |
|---|---|---|---|
| `engine/` | The MTG rules engine. 71 `.gd` files: `core/` (data model and the shared enum vocabulary), `effects/`, `abilities/`, `ai/`, and `mtg_game.gd` — the orchestrator and the single mutation surface | nothing but itself | See below. This is the load-bearing boundary of the project |
| `cards/` | `sets/<set>/` — **897 card files, one card per file**, filename = snake_case card name, no `class_name`; `data/` — the Scryfall-derived JSON the files were generated from, plus the 1997 `.dck` id table; `todo/` — eight set folders, empty *on purpose* and held in git by a `.gitkeep` that says why | `engine/` only | A card is data plus composed behaviour objects. No card touches engine internals, and the registry scans the folder, so there is no manifest to update |
| `game/` | The Godot presentation layer. 83 `.gd`, 8 `.tscn`: `duel/` (49 files — the duel screen, its widgets, and the gauntlet), `deck_builder/`, `help/`, `input/` (the touch layer), plus the title screen, options, skin loading and `paths.gd` | `engine/`, `cards/` | Everything that knows what a Node is lives here |
| `decks/` | **319 `.deck` files**: five starters at the root, then one subfolder per provenance group — `1997/` (157), `tournament/` (76), `community/` (64), `extended_community/` (15), `variants/` (2, ours) — plus `ratings.txt`, the Deck Lab's committed Elo ledger | data only | `docs/decks-1997.md` carries the provenance of every group, pinned by `tests/unit/test_decks_1997.gd` |
| `tests/` | GUT suite: 353 test scripts under `unit/` (73), `cards/` (116), `ui/` (91), `ai/` (70), `tools/` (2), plus `game_test.gd` — the `GameTest` harness DSL — and `test_simplified_ledger.gd` at the root | everything | Setup helpers may bend the rules; the action under test goes through the real public API |
| `tools/` | Pipelines, Python 3 stdlib only: 13 `.py` (seven tools, five unittest files, the shared banner) and 6 `.gd` (SceneTree scripts — the soak player, two benches, the deck-format converter, the art generator, the screenshot tour) | — | Run *at* the repo, not *by* the game: the export preset excludes `tools/*` from the `.pck` outright. Four of them (plus the shared banner) are copied *beside* a packaged game, so a player can build their own art from their own copy of 1997 |
| `DeckLab/` | The headless AI-vs-AI measurement harness: `simulate.gd` (a `SceneTree` script), Wilson intervals, SVG charts, the Elo ledger, and `deck_lab.sh` | `engine/` only | It is the instrument §5 is about. It must not need a window, a scene or a frame |
| `addons/gut/` | Vendored GUT 9.6.1, unmodified | — | Pinned framework + pinned engine = a reproducible suite regardless of system state |
| `assets/` | Not in git. The 1997 material and the card art, on the developer's own machine | — | §2 |
| `docs/` | 27 markdown files, three `.txt` files that travel with a build (the player's setup notes and the skin catalogue), and two provenance notes. §8 says how to read the big ones | — | — |
| `branding/` | The project wordmark: `logo.png` (the master) and the 360px cut the README shows | — | `game/icon.png` is the 256px cut of the same master, and it ships |

Four things this table is deliberately brief about, because `docs/CODE_MAP.md`
is not:

**`engine/` and `cards/` are Node-free and run headless, and this is a hard
rule (CONTRIBUTING.md rule 1), not a style preference.** RefCounted only — no
`Node`, no scene, no `Input`, nothing from `game/`. Four things depend on it:
the suite runs the entire rules layer in a terminal in seconds; the Deck Lab
can play **thousands of duels with no window**, which is the only reason any
AI claim here is measurable (§5); `duel_soak.sh` can drive the real screen as
a separate check instead of a substitute; and the rules layer behaves
identically in the editor, in an exported game and under the test runner. It
is the same boundary s30 draws between its screens and mage-go. `DeckLab/`
obeys it too, which is why you will find no `res://game/` reference in it.

**All state mutation goes through `MtgGame` (rule 2).** Zone moves, life,
damage, characteristics — effects, triggers and card files call `MtgGame`
helpers and never touch the arrays. That is what makes the rules surface
auditable by reading one file, logged on `MtgGame.log_lines`, and undoable.

**Action methods return `""` or a refusal string (rule 3).** A player-level
mistake is never an assert or a throw; it is a human-readable sentence the UI
shows verbatim. The same API serves the UI, the AI and the tests.

**Randomness only through `MtgGame.rng` (rule 7).** A seed plus a sequence of
API calls reproduces a game exactly. Everything in §5 rests on it.

---

## 4. The rules of engagement

`CONTRIBUTING.md` has the seven hard rules and a "Gotchas" section; read them
rather than a summary. The three that catch people who have not read them are
rule 1 (above), rule 5 — **rules code reads `cur_power`/`cur_toughness`/
`cur_keywords`, the live values rebuilt after every state change, never
`data.power`, the printed one** — and rule 6, the `SIMPLIFIED` ledger (§1).

Two conventions that are not rules but are how this repository reads:

- **Cite Comprehensive Rules numbers in comments for rules behaviour.** The
  existing code shows the style, and `docs/mechanics.md` is the catalogue:
  every mechanic the engine implements, its CR rule, the class behind it and
  an example card from this pool. Open it to answer "does the engine already
  do X?" without reading ten thousand lines of GDScript.
- **A new file or class gets a row in `docs/CODE_MAP.md`, in the same pass.**
  Not later.

---

## 5. How the work is actually done here

This is the most distinctive thing about the project and the part least
visible from the code. It is currently only legible by reading twelve thousand
lines of `docs/ROADMAP.md`, so it is written out once here.

### Reproduce first, and quote the reproduction

A defect is reproduced before a line is written to fix it — by a headless
probe, a seeded Deck Lab run, or a test that fails against the current tree —
and **the probe's own output is quoted**, verbatim, in the doc comment or the
ROADMAP row. `engine/ai/ai_profile.gd`'s `develops_late` block shows the form:
"THE REPRODUCTION IS REAL AND IT IS NOT A NUMBER", followed by four lines of
what the pilot actually did. ROADMAP rows open with sentences like "reproduced
with a headless probe before a line was written".

The other half of the rule matters as much: **a report that does not reproduce
is written down as not reproduced, and nothing is built.** The phrase "DID NOT
REPRODUCE" occurs twelve times under `docs/`, each time attached to a
capability that was designed and then not built because the probe would not
show the behaviour it was designed to fix. Grep for it before you act on a
plausible-sounding note.

Probes and benchmarks belong **outside `tests/`** and get deleted when the
question they answered is answered — `CONTRIBUTING.md`, "Scratch files", with
the incident behind the rule.

### Every AI change is a knob, and every knob is measured

Nothing about the AI is "improved". An AI change is a **named field on
`AiProfile`** (`engine/ai/ai_profile.gd` — 49 fields today) — so that "make
the AI stronger, weaker or different" never means editing decision code, and
so that the change can be turned off exactly. A capability knob is off below
the difficulty rung it belongs to and on above it; `docs/ai-difficulty.md`'s
table is every knob against the four 1997 difficulties, with what it does and
what it measured.

Two constraints on a knob that have held since the first one landed: it must
be **monotone** (as good or better one rung up — the ladder is never inverted
in any single number), and it must not be a second difficulty concept of its
own. Difficulty scales through `mistake_chance` and through which layers are
on. Seven knobs are on at *every* rung, including the Apprentice's, because
they are the line between a weak player and a broken one; they are knobs only
so that the Lab can run the null.

The measurement happens in the **Deck Lab**, headless, at scale, over a seed
set, in three pairs at once (`--sweep`, since 2026-09-06):

- the **candidate pair** — deck A piloted with the knob on, deck B with it off;
- the **null pair** — both seats at the null;
- the **control pair** — two decks the knob *cannot fire on*, which must come
  out **byte-identical to its own null**, game for game.

If the control moves, the "delta" was the seeding and not the knob, and the
run is worthless. `deck_lab.sh` exits **4** on exactly that — "a `--sweep`
finished, but its control pair did not replay the null" — and the report names
the first game that moved. Picking a control pair the knob genuinely cannot
fire on is the hard part and the usual place the method goes wrong;
`DeckLab/README.md`'s "The sweep" section has the worked example and about two
hundred lines of per-knob cautionary tales. Read it before you run one.

The statistics are Wilson intervals rather than naive ±, play and draw
alternate and are reported apart, and when the win rate is a wash the second
instrument is the **paired count** — how many games ended differently and how
many changed hands, against what a fair toss over that many would give.

Three consequences worth stating plainly, because they look like failures and
are not:

- **The null must stay the null**, and it is proved by replay rather than by
  argument. The phrase to search for is "THE NULL IS EXACTLY THE NULL" (fifteen
  occurrences in `docs/ai-difficulty.md`): the off arm of the new sweep is
  identical game for game to the null recorded before the change, and a
  previously published sweep re-run on the new tree with the knob forced off
  reproduces its old `games.csv` byte for byte. A knob that changes every
  opening hand has no possible control pair and its sweep exits 4 by
  construction; that is said out loud rather than worked around.
- **A wash that removes a visible malfunction is a legitimate ship — for a
  knob.** The ruling, written 2026-09-10: *"a wash that removes a malfunction
  ships for a KNOB; a constant with no null needs more, and it does not have
  it."* If the win rate does not move but the AI stops doing something a player
  can see is wrong at the table, and the thing can be switched off, that is a
  reason to ship, and the row says which of the two it is claiming. A change to
  a bare constant has no null and must actually win.
- **A refusal with evidence is a complete result.** A capability designed,
  built, measured and then *not kept* is finished work: the measurement is the
  deliverable, and the rows say so — "THE LAB SAID NO, AND THAT IS THE RESULT",
  "THE NUMBERS REFUSED THE RUNG, AND THAT IS THE RESULT", "a NO CHANGE with the
  evidence attached, which is the whole point of the exercise". Six
  `AiProfile` fields exist today **solely** because a measurement refused them
  and the question was left askable instead of thrown away:
  `crack_back_margin` (0), `develops_late` (false), `holds_the_closer` (false),
  `w_hand` (1.5), `defender_scale` (0.0) and `ability_bonus` (0.0). Every
  preset ships every one of them at its null, so the shipped pilot is
  provably unchanged, and the question is now one Lab command instead of a
  patch to the file. Other refusals left no field at all, because there was
  nothing worth keeping askable (the mulligan floor of three; `reads_race`'s
  tolerance half, where the *other* half shipped and the refused half was
  removed from the tree).

  **Do not treat a measured refusal as a failed task, and do not re-try a
  refused idea without first reading the row that refused it.** The ROADMAP
  collects them under headings of their own — "Tried, measured, and NOT kept" —
  and the commit titles say it out loud ("built, measured and refused", "the
  attack bar is refused", "the horizon refused").

### Quote the seed with any Lab number

Every game seeds as `base_seed + matchup_offset + game_index`, so a run
reproduces bit for bit regardless of `--jobs` — and therefore a number without
its seed cannot be checked. This became house practice on 2026-09-11, when a
published 39.1% turned out to be 40.0% at seed 11 and 40.1% at seed 1 on its
own tree, and the commit that published it had recorded no seed
(`docs/ROADMAP.md`, "THE OFFER NOBODY HAD EVER PRICED"; `DeckLab/README.md`,
"Determinism"). The claim could not be subtracted from anything, so it was
withdrawn.

---

## 6. The traps that have actually cost time

Not hypotheticals. Each of these has a date and a cost.

**A git worktree has no `assets/`.** `assets/original/` and `assets/cardart/`
are gitignored, so a worktree or a fresh clone has nothing there, and the
tests that measure against the real 1997 material fail for a reason that is
not yours — **24 UI tests and one pool test** when this was measured on
2026-09-08 (medallions, cost plates, badges, the 1997 button face). Symlink
the checkout's `assets` into the worktree and re-run
`--headless --import` before you conclude anything about a red suite. The
`cards/todo/` half of that measurement is **fixed** — eight tracked `.gitkeep`
files have held the empty set folders since 2026-09-10, and the one in
`cards/todo/2ed/` explains itself and records that the missing folders cost
two agents an hour. The `assets/` half is still live, and still costs a
failing test the moment you look.

**`../tools/godot` does not resolve from a worktree.** §2. Set `GODOT`.

**101 of the 319 decks cannot be loaded, and it is not a bug.** A *proxy* is a
card name a deck holds that the registry does not know
(`engine/proxy_card.gd`), and every door into a duel asks before it deals.
Counted once on 2026-09-11: 319 deck files, **218 load, 101 are proxy-blocked
over 212 distinct names** — all of `tournament/` bar five and all of
`extended_community/` bar one, while **all 157 decks the 1997 game itself
shipped play**. Not one of the 212 names is a card this pool is meant to hold:
they are printings from sets later than this pool's scope, one misspelling in
a historic list that stays as published, and one card excluded by a standing
ruling of the project's own. So when a design note names a deck as the one
that exercises something and the Lab refuses it by name, that is the census,
not a regression — `DeckLab/README.md` "The proxy census" has the tables and
`docs/ROADMAP.md` has the ruling.

**A plain Deck Lab run writes `decks/ratings.txt`.** The Elo ledger is a
committed file, and every run folds its results in unless you say otherwise —
so a repeated seed re-counts the same games into a deck's lifetime record and
leaves a dirty tree. **Give every experiment and every rerun `--no-elo`** (or
`--elo-file` pointing at scratch). A `--sweep` forces it off for you; nothing
else does.

**Never mutate an ability object in a test.** `CardInstance`'s live lists are
refilled with `Array.assign` from the `CardData`, so the *array* is the
instance's own and appending to it is fine — but every `ActivatedAbility`,
`ManaAbility` and `TriggeredAbility` *in* it is the very object the registry's
`CardData` holds, and the registry is process-global for the whole run. Change
one and you have changed that card for every later test in the process.
Rewrite the list with copies instead; `engine/abilities/activated_ability.gd`
has `shallow_copy()` and `discounted()` for exactly this, and
`cards/sets/atq/power_artifact.gd` shows the shape.

**No `static var` may hold a `CardData` or a `CardInstance`.** Godot destroys
the static table after the card scripts whose Callables it points into,
corrupting the heap: every run ended in exit 134 (SIGABRT) for weeks and it
was written off as renderer noise until it was bisected on 2026-09-01. A
second such cache aborted every run that had opened the Deck Builder until
2026-09-02. Key caches by name or by instance id.

**One unparseable card file drops the pool from 897 to 708** and produces
hundreds of failures that look like something else. The commonest way to write
one is GDScript's inference error, which this project treats as fatal:
`var x := weakref(g)` does not parse — write `var x: WeakRef = weakref(g)`.
Run the boot smoke after touching any card.

**Never pipe a Godot run into a reader.** `timeout 100 xvfb-run -a godot … |
tail -6` looks reasonable and is the single most expensive line in this
project's history: `timeout` kills `xvfb-run`, not the Godot it spawned, the
orphan holds the pipe open, and a 100-second guard became **12.7 hours**. The
safe recipe — `timeout` *inside* `xvfb-run`, output to a file, stdin closed —
is in `CONTRIBUTING.md` under "Commands that can hang". Read it before your
first windowed run, not after.

**A `-s` SceneTree script is compiled before the autoloads exist.** Naming an
autoload in anything the script's type-hints pull in is "Identifier not found"
for the whole chain, and the tool silently never starts — while the suite,
which runs as a scene, stays green. Keep scratch `-s` scripts' screen
variables untyped and reach autoloads through the tree at call time.

**A hand-written Godot run writes the real profile and rotates the real
logs.** The two gate scripts isolate `XDG_DATA_HOME` and pass `--log-file`;
your scratch probe does not until you say so. `CONTRIBUTING.md` "Scratch
files" has the flags and the reason for each — including the disk one: if
your `/tmp` is tmpfs it is RAM, the screenshot tour writes about 100 MB a run,
and a session once accumulated 2.4 GB across 420 directories and was
OOM-killed. One scratch directory, inspect, delete.

---

## 7. Your first change

Add a card, or fix one. It is the contribution the pipeline is built for — two
files and no engine code, as long as the mechanics it needs already exist — and
it exercises every convention above.

1. **Read `docs/adding-cards.md` end to end.** It has the walkthroughs, a
   toolbox table mapping "you need X" to the effect or ability class that does
   it and a card that uses it, the oracle-reading checklist the 2026-09 audit
   produced, and the PR checklist to copy.
2. **Write the test first.** `tests/cards/`, extending `GameTest`. Setup
   helpers (`put_battlefield`, `give_hand`, `add_mana`) may cheat; the action
   under test goes through the real API and asserts on the refusal string.
   Test the card's *edges* — illegal targets, fizzling, timing, the
   interactions its oracle text names.
3. **Write the card.** One file in `cards/sets/<set>/`, filename = snake_case
   card name, no `class_name`, header doc comment = name/cost/type line +
   exact oracle text + implementation notes. Composition only: if it needs a
   mechanic the engine lacks, the mechanic lands in `engine/` first, as its own
   class with its own engine test, and the card file stays declarative.
4. **If you took a shortcut, mark it and write the row** — §1. The ledger test
   will find you if you do half of it.
5. **Run the gate.** `./run_tests.sh` (exit 0, nothing else counts) and the
   boot smoke. `./duel_soak.sh` too if you went anywhere near `game/duel/`.
6. **Update `docs/CODE_MAP.md`** if you added a file or a class, and
   `docs/mechanics.md` if the card taught the engine a new mechanic.

If instead you are picking up the AI: read `docs/ai-difficulty.md` (what each
of the four opponents can and cannot do), then `DeckLab/README.md`, then
`docs/AI-next-wave.md` — a plan that is now closed, and therefore the worked
example of what a plan here looks like: every item with its knob, its rung, the
pair that would measure it and the control that would prove it, written before
anything was built. Do not start by writing decision code. Start by finding
which `AiProfile` field your idea is, and which two decks it cannot fire on.

---

## 8. Reading the big documents

A few files in `docs/` are long enough that a newcomer needs to be told how
they are shaped. `docs/CODE_MAP.md`'s own `docs/` section annotates all of
them and everything else in the folder.

- **`docs/ROADMAP.md` (12 183 lines, 127 `##` sections) is a dated ledger, not
  a plan.** It is append-only and **newest at the bottom**; the original
  milestone record (M1–M5) sits in the middle, kept as history. Start at the
  top — `## STATE AS OF …` is the running summary — then jump to the end for
  what happened this week. Every section is dated in its heading, so search by
  date or by the phrase you are chasing, and **never cite it, or anything else
  here, by line number**: a row in this file that cited engine code by line
  number was pointing a thousand lines from the code it meant, which is how the
  ledger test came to check engine markers too. The last section is "Standing
  quality gates", and it is three lines long.
- **`docs/CODE_MAP.md` (6 900 lines)** is one annotated tree of the whole
  project. It is the thing to grep when you want to know where something lives
  and what it does. It is currently exact; a change that moves a file and not
  its row here is an incomplete change.
- **`docs/duel-todo.md` and `docs/duel-screen-design.md`** are the duel
  screen's work list (cleared) and its design record, with the 1997 citation
  behind every decision.
- **`docs/ai-difficulty.md` (4 052 lines)** is what the four difficulties
  actually do, knob by knob, with the measurement behind each.

The rest of the reading list is `README.md`'s "Getting oriented" table.

---

## 9. What is not done

Stated plainly, because the README's Status section is a summary and this is
the working view.

- **M5, adventure mode — the overworld, cities, quests, dungeons, world
  magics, the ante economy — is not started.** It has a placeholder section in
  `docs/ROADMAP.md` and gets its own design document before any code. It is
  the largest remaining piece of the project by a wide margin.
- **The AI's plan of 2026-09-08 is closed, not abandoned.**
  `docs/AI-next-wave.md` was written as the next wave's work list and every row
  of it was settled in the week that followed — some shipped, several built,
  measured and refused (§5), a few not built because the probe would not
  reproduce what they were meant to fix. A struck row is *closed*, whichever
  way it went. So the next AI question needs a new plan written the same way,
  and the closed one is the worked example of how.
- **CR 613.8 has no general dependency analysis.** There is no graph and no
  cycle rule; the one dependency this pool actually has — a retyper that reads
  a land type, against every retyper that writes one — is resolved by
  construction, in two waves, and `engine/continuous.gd` says exactly that at
  the site. If a future card makes a second one, this is where it lands.
  (`docs/ARCHITECTURE.md` still states the flat "613.8 is missing" from before
  the two waves went in, 2026-09-10.)
- **The web build has been checked in a desktop browser pretending to be a
  tablet, not on a real one** (`README.md`, "Play in the browser").
- **Set packages** (`docs/set-packages-plan.md`) are a design with the pack
  *format* implemented and the gating and loader not.

Where something is half-done, the row that tracks it is in `docs/ROADMAP.md`
or in the design document named above. If you cannot find a row for it, that
is worth saying out loud before you build it.
