# DeckLab and base-game audit — 2026-09-13

Scope: inspect the headless deck-testing CLI, fix reproduced bugs, make a
second base-game pass, and take worthwhile low-cost improvements. The starting
tree was local commit `2e68494`; the Mac baseline remains separate. Windows,
Linux, macOS and Web are core targets. No AI, card or rules behavior changed.

## Reproduced and fixed

### Worker processes rounded large seeds

The parent's task used a signed 64-bit integer. JSON parsing in the child
turned it into a double before play. A headless probe of Mountain Artillery
against itself, Wizard pilots, captured this before the fix:

```text
SEED before=9007199254740993 after=9007199254740992
SEED fingerprints_equal=false direct_turns=17 worker_turns=38
```

`_worker_payload` now copies the task metadata and encodes each seed as a
decimal string. `_run_worker` restores the integer before a duel or match.
The parent's seeds and public report schemas are unchanged. Tests pin both
signed limits, zero, negative seeds, and a real duel and best-of-three match
replayed through the worker reader, including their full log fingerprints.

### A failed Elo save was a successful CLI run

Four White Knights–Big Green games at seed 4242, with an existing scratch
directory as `--elo-file`, reproduced:

```text
ERROR: EloLedger: cannot write ../shandalar-build/decklab-audit-2026-09-13/blocked-ledger
CLI_EXIT=0
```

The report also printed apparent rating changes from 1500.0 to 1500.2 and
1499.8. `EloLedger.save()` now returns success only after the file opens,
writes and flushes. The CLI retains completed matchup reports, explicitly
labels **Elo NOT SAVED**, and exits 1. There is no silent fallback ledger and
no change to rating math. Tests also cover retrying after a blocked save.

### CSV exports changed deck titles

A real two-game run at seed 4242 loaded a scratch deck named `Audit, "Burn"`.
Its CSV row began:

```text
Audit  "Burn",Big Green,2,0,2,0,
```

The comma had been replaced by a space, and the quotes were unescaped.
One shared CSV-cell encoder now quotes commas, quotes and line endings in
`matchups.csv`, `sweep.csv` and `games.csv`. Plain titles remain byte-for-byte
unchanged. Tests include Unicode, embedded quotes, CR and LF.

### Settings forgot a failed save

A directory temporarily blocking the isolated test profile's settings file
produced this before any fix:

```text
SETTINGS dirty=false counted_writes=1
```

The regression test additionally proved that a later flush did not persist
the change. Settings now checks `ConfigFile.save()`'s result, keeps failed
writes dirty, reports the problem, and increments its write counter only on
success. The test removes the obstruction and verifies a successful retry.
The fixture protects and restores the previous settings file; it never runs
against the player's real profile. This is retry handling, not a promise that
an unwritable disk can persist data or that an unsaved value survives exit.

### Home paths assumed a Unix environment

With HOME absent and `USERPROFILE=C:\Users\Deck Tester`, the pre-fix test
reported:

```text
["/Music"] expected to equal ["C:/Users/Deck Tester/Music"]
[""] expected to equal ["C:/Users/Deck Tester"]
```

With neither variable available, `~/Music` still became `/Music`. GamePaths
now falls back to USERPROFILE, normalizes home separators, and leaves an
unknown `~` intact. Display shortening uses the same home lookup. The test
emulates the environment on macOS and restores it before assertions; it is
not native Windows certification. Browser paths remain `user://`.

## Small improvements and review boundaries

The `--jobs 0` help, hint, validation message and manual now agree with the
existing implementation: default `min(4, cores)`, not every core. No thread
count behavior changed.

The additional base-game review covered settings persistence, GamePaths'
ownership checks, DeckStore saving, MatchScreen's configuration/advance and
sideboard paths, and SkinPack's import/replacement paths. No speculative
changes were made to match sequencing or skin replacement. Replacement
failure recovery and worker result publication/validation remain candidates
for dedicated fault-injection work; they are not claimed as reproduced bugs
or fixed in this pass. (2026-10-27: worker result publication was fixed in
0.40.22 — a worker writes its slice under a working name (`.part`) and
renames it whole, the parent lands a slice only under its final name, and
a dead worker is replaced for the same slice; `DeckLab/simulate.gd`,
`docs/releases/0.40.22.md`. No dedicated fault-injection suite was built.)

## Verification

Evidence is retained outside Git in
`../shandalar-build/decklab-audit-2026-09-13/`.

- Six new targeted regressions: 6 passed, 50 assertions, exit 0.
- Final `test_game_paths.gd` run: 14 tests, 75 assertions, exit 0, including
  the host-home expectations updated to accept the Windows fallback.
- Python tools: 219 tests, one platform-specific skip, exit 0.
- Full `./run_tests.sh`: 6,100 tests, 156,551 assertions, 353 scripts,
  207.819 seconds, wrapper exit 0 (including the wrapper's error/leak checks).
  The 98 existing anchor-size warnings also appear in the previous pass's
  full log; this is not described as a warning-free suite.
- Real CLI checks: duel, best-of-three with sideboarding, three-deck matrix,
  two-opponent gauntlet, random field, sweep, bad-seed refusal, successful
  rated accumulation, and blocked-ledger failure. All completed with their
  expected exit codes. The first match invocation in the scratch harness
  correctly refused a bare `--sideboard`; the completed check uses
  `--sideboard on`.
- Wizard sweeps at seed 4242: 20 games × 3 arms × 2 pairs (120 per run),
  identical `games.csv` bytes at jobs/procs 1/1, 4/1 and 1/2. At seed
  9007199254740993, another 120-game sweep matched exactly at procs 1 and 2.
  Each control arm passed its own null. These are reproducibility checks,
  not claims about AI strength or deck ranking.
- Twelve best-of-three matches at seed 4242 gave identical `matchups.csv`
  at procs 1 and 2. Matrix/gauntlet/field/match reports contained zero stalls
  and consistent game totals; the random field's 7+13 rows summed to 20.
- An independent CSV reader recovered the exact quoted title from all three
  CSV outputs (1 plain row, 6 sweep rows, 12 per-game rows); JSON totals and
  generated SVG XML syntax also checked cleanly.
- Scratch Elo accumulated 8 games per deck across two four-game runs. The
  tracked `decks/ratings.txt` is unchanged. The blocked-ledger run retained
  a byte-identical matchup CSV to its pre-fix run while returning 1.
- A fresh, separate `./build_release.sh --macos --out
  ../shandalar-build/decklab-audit-2026-09-13/macos` built and smoke-booted
  the 186 MB local debug-template app. Its packaged headless DeckLab ran the
  120-game large-seed sweep with two worker processes, exit 0, no fallback,
  and byte-identical fingerprints to the source serial run. A temporary
  `override.cfg` isolated its profile; that override was removed afterward.
- Native `./duel_soak.sh --rules modern`: six completed duels, seeds 1000,
  1037 and 1074 in demo and human-fuzz modes, exit 0. The human runs made
  119, 73 and 102 clicks, including the live options path; the wrapper found
  no ERROR/WARNING/STALL lines.
- `codesign --verify --deep --strict` passed after the packaged CLI probe
  and removal of its temporary override. The existing play app was neither
  overwritten nor relaunched by this audit.

The one-off probe script, CLI-check script and scratch deck were removed
after answering their questions. Regression tests and logs are retained.

No native Windows/Linux run or browser playtest is implied by these macOS
gates. Existing release presets and build workflows are unchanged. No remote
Git operation or publication was performed.
