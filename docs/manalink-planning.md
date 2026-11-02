# Original-engine planning refinements and the Unfair challenge

These are bounded extensions of the existing player, not a port of the
original executable or a claim of superiority over Forge, mage-go or Manalink.

## What informed the changes

The original decompilation at `0328cbb80c11abd0291c9c69c054da917a4cd0c0`,
`magic/sid/Ai.c`, entry `004c4c84` (lines 13362–13420), temporarily removes
a creature and compares the resulting position with the baseline. This
motivates **context value**, not copying its global-state evaluator. Several
reconstructed function names are misleading; the control flow is the evidence.

Manalink at `868a7c5b0cc373c531197edd0a130c4d36cd7a1d`,
`src/functions/dialog.c`, carries legality, targets and costs together in
`choice_t`; `dialog_ai` validates a remembered choice before replay.
`src/functions/ai.c`, `ai_decision_phase`, processes damage and graveyard
consequences before scoring. Much of its search still calls into the original
binary. These patterns motivate complete choices and bounded aftermath.

No alternate card-generation branch, hidden-library evaluation, binary
snapshot evaluator or recorded-random-choice mechanism was copied.

## Three fair refinements

- `values_context`: static support creatures are priced by the difference
  in public creature-board value when their presence is removed and continuous
  effects are recalculated. Removal targets, own sacrifices and combat-model
  casualties use this contribution. Ordinary creatures retain the old value.
  This is a static counterfactual, not a death simulation: it deliberately
  invokes no leave hooks, triggers, choices or hidden-zone effects.
- `plans_modes`: main-phase casting compares mode, X, targets and payable
  cost together. Unusable first modes no longer discard the whole card.
  Known life-gain, damage and sweeper shapes get mode-specific payoff;
  unknown shapes retain authored hints and existing target heuristics.
  Execution rechecks legality and rebuilds payment before tapping sources.
  This does not enumerate every target combination or arbitrary mid-resolution
  choice. Only already-independent development lines can be cached.
- `forecasts_aftermath`: declared-damage forecasts may resolve up to 32 newly
  generated, explicitly reviewed public triggers. Initially these are
  Fungusaur, Sengir Vampire and Dingus Egg. Unknown triggers stop the refinement;
  tactical scoring falls back to the existing damage-only forecast. Older
  stack objects are not consumed. The journal restores game state and RNG.

The refinements are enabled on Sorcerer and Wizard and have independent null
switches for measurement. They do not change the standard information policy.

## Unfair is a separate challenge

`UnfairPlayer` is constructed explicitly; its profile is always Wizard. No
`AiProfile` override enables hidden information. Setup and Gauntlet have a
separate control, and the duel displays a persistent warning independent of
player names. The human's view of the opponent's hand is unchanged.

In setup, **Challenge modifier → Unfair challenge** sits below the four
standard levels. Enabling it displays and locks Wizard; disabling it restores
the previous fair level, including after reopening setup. These choices are
saved when starting a game, and cannot silently change a duel in progress.
Gauntlet uses the same separate grouping and restores its previous enemy level.
Each affected pilot has a compact **Unfair** badge in the bottom-right of its
life panel; its tooltip explains current-hand knowledge. This also identifies
each affected seat in demos. Poison uses the opposite corner when needed.
Deck names retain their dedicated space below the opponent's piles and above
the player's piles, with no extra sidebar row or shift of the large card.

The UI follow-up passed the strict full gate: 6,238 tests and 231,574 assertions
in 209.6 seconds. Native macOS viewport captures verified both setup states,
Gauntlet and the life-panel badge with the original skin. A 960×600 capture
also checked 400 life alongside poison and the badge. Eleven focused challenge
tests cover placement, poison separation, unchanged deck-name/preview space,
both demo seats, setup persistence and Gauntlet toggling.

The challenge reads **current opposing hand cards only** in addition to the
normal permitted information. It changes sequencing around an affordable
unconditional counter, discounts damage that an affordable pump can defeat,
holds extra bodies against an affordable creature sweeper when not in danger,
and studies up to eight single-pump responses to its attack. Costs, colors,
restrictions, visible targets and cast bans are checked. These are predictions,
not forced opponent responses or a general opponent-turn solver.
Mixed repeatable-pump boards retain Wizard's specialised analysis. The
single-spell mini-study excludes creature mana sources, so it never assumes
one creature can tap for a trick and block too. It does not combine two
different hidden responses as if the same mana could pay for both.

No secret library order, future draws, RNG-state inspection, hidden face-down
identity, extra resources or rules exceptions are permitted. Hand knowledge
is not published through reveal flags and is not retained after departure.
Standard observations remain unchanged; only the challenge's own cache key
includes its extra hand knowledge.

Deck Lab accepts `unfair` outside its four standard profile names. It forces
no Elo updates, rejects profile overrides and fair sweeps, labels text/JSON
reports and uses a separate default output prefix. Seat reversal and match
workers carry the explicit challenge token with the deck.

## Reproduce validation

```sh
SUITE_TIMEOUT=600 ./run_tests.sh
SOAK_HEADLESS=1 ./tools/duel_soak.sh --unfair --rules modern --seeds 91328
SOAK_HEADLESS=1 ./tools/duel_soak.sh --unfair --rules fifth --seeds 91328
DeckLab/deck_lab.sh --deck-a big_green.deck --deck-b white_knights.deck \
  --profile-b unfair --games 100 --no-elo --no-svg
```

`SOAK_HEADLESS=1` exercises the live scene/controls without a renderer, useful
on a locked Mac or CI. A normal soak still uses the platform's window system.
It verifies integration, not pixel-perfect visual appearance.

Focused regressions cover actual cast order, blocked/unaffordable responses,
all four fair cache boundaries, current-hand-only challenge observations,
combat decisions, static support, modal targets, real aftermath cards,
unknown-trigger refusal, the trigger limit and nested journal restoration.

## Verification results — 2026-09-13

- Final strict gate: **6,235 tests, 231,479 assertions, 365 scripts**;
  exit 0, 206.8 seconds. No script/runtime errors.
- Fair five-deck matrix: Big Green, White Knights, original Merfolk Shaman,
  Goblin Warlord and Fungus Master; 250 games for each of ten pairs, seed
  91328. Candidate on deck A: 1,955/2,500 wins; candidate on deck B:
  582/2,500 wins. Reversing which deck receives the candidate yields
  **2,537/5,000 (50.74%)**. A further 2,500 all-null games had no stalls.
  This modest sample does not establish a large or universal strength gain.
- Independent `values_context` sweep: Merfolk Shaman versus Goblin Warlord,
  300 games per arm, seed 91329: 46.7% null versus 50.0% candidate.
  The reported difference is +3.3 ±7.9 percentage points, inconclusive.
  Big Green versus White Knights control: **300/300 byte-identical games**.
  All 1,200 sweep games completed without stalls.
- Separate Unfair integration: 100 best-of-three matches, sideboarding on,
  four worker processes, seed 1, Big Green versus White Knights. No stalls;
  reports contain `challenge: unfair-current-hand` and `rated: false`.
  These are challenge checks, not fair-strength measurements.
- Live-scene Unfair soaks: seed 91328, demo and human-clicker modes, modern
  and fifth-edition rules. All four duels finished cleanly.
- Public combat latency: 12 creatures per side, five measured repetitions,
  median 90.56 ms without an own-hand trick and 93.47 ms with one; maximum
  94.05 ms. Observed search leaves stayed below the 3,000-leaf budget.
  Timings are diagnostic on this Mac, not cross-platform performance promises.
- Separate Unfair latency probe with an opposing Giant Growth: on the same
  12-versus-12 board, 838–873 ms median and 874 ms maximum (rounded). Its
  eight-response limit bounds extra studies, each using Wizard's existing
  leaf budget. Large-board challenge decisions can therefore take visibly
  longer; they are not represented by the fair player's 90–94 ms figure.
  Reproduce with `tools/bench_planning.gd -- --unfair` through headless Godot.

The local macOS test app is universal arm64/x86_64, uses the project's usual
debug export template and is ad-hoc signed. Its exported challenge smoke
completed four games and mounted the existing 240-file skin and 1,794-file
card-art packs. Neither pack is part of the source changes.

Local logs and reports are under the sibling build directory,
`shandalar-build/manalink-study-2026-09-13/`; no ratings or player saves were
updated. The fair matrix null disables only `values_context`, `plans_modes`
and `forecasts_aftermath`. The earlier deck/combat study remains enabled in
both arms. The final suite adds edge and integration regressions after the
initial 6,228-test pass, including the modal-creature cache boundary.
