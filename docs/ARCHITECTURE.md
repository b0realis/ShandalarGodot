# Architecture

Shandalar is a from-scratch GDScript remake of MicroProse's 1997 *Magic: The
Gathering*, targeting the latest stable Godot (currently **4.7.x**). Its design
is informed by two working references we keep locally: **s30** (Ben Prew's
Go/Ebiten remake) and **mage-go** (its MTG rules engine, ~3,200 tests). We
follow their proven decisions and write down every deviation.

## The two-layer rule

The project is split into two worlds with a hard boundary:

```
┌────────────────────────────────────────────────────┐
│  game/     Godot presentation: scenes, UI, audio,  │
│            adventure mode. Knows about Nodes.      │
└──────────────────────┬─────────────────────────────┘
                       │ public API calls ↓ / signals ↑
┌──────────────────────┴─────────────────────────────┐
│  engine/   Pure MTG rules. RefCounted only —       │
│  cards/    no Node, no scene, no rendering,        │
│            no Input. Runs headless.                │
└────────────────────────────────────────────────────┘
```

**The engine never imports anything from `game/`.** It runs identically inside
the editor, in an exported game, and under the headless test runner. This is
the same boundary s30 draws between its Ebiten screens and mage-go, and it is
what lets the suite's thousands of rules tests run headless in a terminal.

## Engine design (engine/, cards/)

### A fair-information player

The rules engine owns complete game state; the computer player must not
reason from secrets its seat cannot know. `AiObservation` creates value-only
planning/cache views, `AiDeckStudy` analyses only the seat's own registered
list at attachment, and `AiActionPlanner`/`AiCombatStudy` operate on bounded
proposals and flat public combat models. Existing engine-facing policies
and card-choice hints remain subject to the same information rule and
substitution tests. No difficulty changes that boundary. See
[fair play](fair-play.md) and the [planning design and limits](planning-study-2026-09-13.md).

### One mutation surface

Every rule-relevant change to game state — zone moves, life totals, damage,
characteristics — goes through **`MtgGame`** (engine/mtg_game.gd). Effects,
triggers, and card files never mutate state directly; they call MtgGame's
helpers (`deal_damage`, `draw_cards`, `destroy`, ...). Consequences:

- the whole rules surface is auditable by reading one file;
- every change is logged (`MtgGame.log_lines`) and signaled;
- the AI search's undo journal (`engine/undo_log.gd`) records at those
  helpers, and the LAN referee (`game/sgmanalink/`) runs `MtgGame` on the
  host and sends each seat a filtered view: both build on this one class.

### Synchronous, imperative API

The engine is driven by plain method calls that return `""` on success or a
human-readable refusal string:

```gdscript
var err := game.cast_spell(0, bolt, [TargetRef.card(bear)])
# err == "" — cast; err == "not enough mana for Lightning Bolt ({R})" — refused
```

The same API serves the UI (button handlers call it, show refusals verbatim),
the AI (which plans over legal calls), and the tests. Unlike mage-go's
goroutine/channel design, there is no concurrency: Godot's scene tree is
single-threaded and GDScript has `await` if the UI ever needs to yield. A
duel's flow control is just: call methods; when both players pass priority the
stack resolves; steps advance.

### Data model

| Concept | Class | File |
|---|---|---|
| Printed card (immutable, one per name) | `CardData` | engine/core/card_data.gd |
| A copy of a card in one game | `CardInstance` | engine/core/card_instance.gd |
| One duel | `MtgGame` | engine/mtg_game.gd |
| A seat (life, zones, pool) | `MtgPlayer` | engine/mtg_player.gd |
| Object waiting on the stack | `StackItem` | engine/stack_item.gd |
| "What may this target?" | `TargetSpec` | engine/core/target.gd |
| A chosen target (by id, never pointer) | `TargetRef` | engine/core/target_ref.gd |

`CardInstance` holds *current* characteristics (`cur_power`, `cur_toughness`,
`cur_keywords`, `cur_types`, `cur_colors`, the live ability lists) that are
**recomputed from scratch** after every state change by
`ContinuousEffects.recalculate()` (engine/continuous.gd). The passes run in
CR 613 LAYER order — type changes (4), colour changes (5), ability losses
(6), then the power/toughness sublayers 7a/7b/7c/7d/7e — with battlefield
timestamp order deciding within a layer; the file header lists the exact
sequence and `docs/mechanics.md` explains it card by card. Recompute-the-world
is the approach XMage/mage-go use; it trades negligible CPU for correctness
that never drifts, and `docs/audit-2026-09.md` has the measurements behind
the parts that were made cheaper. General dependency analysis (613.8) is
still missing; `engine/continuous.gd` handles this pool's land-type
reader/writer dependency in two waves. See `DEVELOPMENT.md` for the scope.

### Cards as composition

A card is data plus composable behavior pieces — never a subclass hierarchy:

- **one-shot effects** (`EffectBase` subclasses: `DamageEffect`, `DrawEffect`,
  `DestroyEffect`, `PumpEffect`) for what spells do on resolution;
- **`ActivatedAbility`** (cost → effects, uses the stack);
- **`TriggeredAbility`** (event match → resolve callable, uses the stack);
- **`StaticAbility`** (continuous contribution, no stack);
- **`ManaAbility`** (tap for mana; deliberately stackless per CR 605.3).

New mechanics are new effect/ability classes in `engine/effects/` or
`engine/abilities/` — card files stay declarative. This mirrors mage-go's
"effects are the core abstraction" design.

### The card registry

`CardRegistry` (engine/card_registry.gd) loads the eight core set folders
under `cards/sets/` (`SET_ORDER`: 2ed, arn, atq, leg, drk, 4ed, past, phpr)
at first use. **Every `.gd` file in a set folder is exactly one card**
(filename = snake_case card name); the folder name becomes the card's set
code. There is no manifest to maintain — dropping a file into one of those
eight folders ships the card. The numbered packs' own set folders (`fem/`,
`ice/` and the rest) load only while their pack is enabled; see
docs/adding-card-packs.md. Cards extend `CardScript` and
implement `build() -> CardData`. See docs/adding-cards.md for the authoring
pipeline.

### Events and triggers

`MtgGame.dispatch_event` offers every `GameEvent` to every battlefield
permanent's triggered abilities (APNAP ordering per CR 603.3b) and mirrors it
on the `event_occurred` signal for the UI. Trigger resolution receives the
original event, so context like Ankh of Mishra's "that land's controller" is
read straight from `event.data` — no fragile global state.

### Determinism

All randomness flows through `MtgGame.rng` (seedable). A seed + the sequence
of API calls reproduces a game exactly — the foundation for bug reports,
replays and the Deck Lab's AI-versus-AI runs.

## Testing (tests/)

Framework: **GUT 9.x** (addons/gut, vendored). Run via `./run_tests.sh`
(headless, uses the pinned Godot discovered by `tools/runtime.sh`). Current
measured test counts and timings live in `DEVELOPMENT.md` and the dated
verification records; this architecture overview does not keep another count.

- `tests/game_test.gd` — `GameTest`, the harness DSL: `put_battlefield`,
  `give_hand`, `add_mana`, `resolve_stack`, `run_combat`,
  `assert_ok`/`assert_refused`. Setup helpers may bend rules; every action
  under test goes through the real public API.
- `tests/unit/` — engine behavior (mana, turn/priority/stack, combat).
- `tests/cards/` — card behavior and interaction regressions.
- `tests/ui/`, `tests/ai/`, `tests/tools/` — presentation, pilot and tool gates.

Policy, inherited from mage-go: **cards are implemented test-first**, and a
card is not "done" until its test quotes the oracle-text behavior.

## Documentation map

- `docs/mechanics.md` — every mechanic the engine implements, its CR rule,
  the class that implements it, an example card. Start here to learn what
  the engine can do.
- `docs/CODE_MAP.md` — where every file lives and what is in it.
- `docs/adding-cards.md` — the card-authoring pipeline and its checklist.
- `docs/simplified-cards.md` — the fidelity ledger (card-scoped deviations);
  `docs/ROADMAP.md` carries the engine-wide ones.
- `docs/audit-vs-mage-go.md`, `docs/code-review-2026-08.md`,
  `docs/audit-2026-09.md`, `docs/code-review-2026-09.md` — the four audit
  records, each with the test that pins every fix.

## Presentation layer (game/)

`game/main.tscn` is the working title screen. Magic Battle leads through
battle setup to the duel screen; the shell also exposes Gauntlet, Deck
Builder, Options, Help and the globe (SGManalink LAN duels and tournaments,
`game/sgmanalink/`). The duel screen holds an `MtgGame`, renders its
state and signals, and calls the same public API the tests use. Whole duels
through this presentation layer are checked by `duel_soak.sh` in addition to
the component tests. See `docs/CODE_MAP.md` for the implemented scene layout.

The adventure layer (`game/adventure/`: the world, its places and
creatures, the castles, the dungeons and the end) is built on the same
duel engine; `docs/adventure-implementation-notes.md` is its record.

## Why these technology choices

- **Godot 4.7 / GDScript**: huge community, fully open-source engine —
  project independence was an explicit requirement. No C#/GDExtension
  dependency keeps contributions one-language simple.
- **GUT**: the de-facto standard GDScript test framework; CLI-friendly for CI.
- **Vendored test framework + pinned engine binary** (`../tools/godot`):
  reproducible builds/tests regardless of system state.

## Provenance & upstream references

These sit beside the repository, not in it; `Provenance.md` ranks them.

- `../s30/` — Go remake (screens, adventure systems, rogue decks in
  `assets/configs/rogues/`, original text in `assets/text/`).
- `../mage-go/` — a local clone of the rules-engine reference; its
  `cards/limited/` is our implementation checklist.
- `../shandalar-src/` — Manalink 3.0 snapshot (original game binaries +
  assets; engine internals documented in `src/manalink.h`).
- `../docs/SHANDALAR_LORE.md` — game/lore reference (world magics, lairs,
  enemy tiers, difficulty tables).
