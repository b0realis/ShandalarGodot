# Code review — 2026-09-01

Date: 2026-09-01, the evening of the day the card pool went 837 → 897, seven
engine subsystems landed and ~400 tests were added by five parallel sessions.
Nobody had read the tree as a whole since. Scope: the ORPHAN-NODE report
nobody had investigated, `engine/` outside the files another session owned,
`game/` outside the Deck Builder, `tools/`, and the test infrastructure.

Two other sessions were editing `cards/`, `engine/effects/`,
`engine/mtg_game.gd` and `game/deck_builder/` throughout, so findings in those
areas are **reported, not fixed** — they are in the second table.

Method, and what "verified" means here: **every row in the first table has a
test that failed before its fix and passes after**, or a reproduction script
whose output is quoted. Two suspicions that could not be made to fail are
labelled as such and were not "fixed". Suite at the end of the pass:
**2829 tests / 2829 passing / 0 risky / 0 orphans / 164 scripts / `./run_tests.sh` exit 0** (the count moves: two other sessions were adding cards and tests throughout).

## The orphan nodes, which turned out to be one line

GUT reported **63 orphans** at the end of every run. Every one of them was a
`Window`, and the listing named the tests: `tests/tools/test_deck_lab.gd`
(62) and `tests/unit/test_proxy_card.gd` (1). Both reach the Deck Lab's
argument parser through `load("res://tools/simulate.gd").new()`.

`simulate.gd` extends `SceneTree`. A `SceneTree` is a plain `Object` — not
`RefCounted` — and it builds a root `Window` the moment it is constructed.
Measured with a five-instance probe:

```
orphans at start: 1
after 1 new(): orphans=2   ...   after 5 new(): orphans=6
after free():   orphans=1
```

One orphan node per `.new()`, and the tree object itself leaked alongside it.
`autofree()` on both call sites took the suite from 63 orphans to **0**.

**There is no orphan leak in `game/`.** The four-figure per-test counts in the
log are a different measurement: GUT samples `Node.get_orphan_node_ids()` in
`end_test`, before the frame's deletion queue drains, and the duel's widgets
are rebuilt with the deliberate `remove_child(child); child.queue_free()`
idiom — detaching first is what makes them orphans for the rest of the frame.
That pattern is correct and documented at each site; the transient count is an
artefact of asserting synchronously after a rebuild.

## Findings — fixed, with the test that pins each

| Area | Issue | Severity | Pinned by |
|---|---|---|---|
| `CardRegistry` (thread safety) | The card-name → first-printing index and the illustrator index were each built **lazily**, and each set its `_loaded` flag **before** filling its dictionary. `originally_printed_in` is asked from inside a game (City in a Bottle, Golgothian Sylex) and `tools/simulate.gd` fans games out over a `WorkerThreadPool`. An 8-thread probe on a cold index measured **7 of 8 threads answering `false` for a card that is an Arabian Nights original**, and the process **segfaulted within ten cold starts** — two threads writing one `Dictionary`. Both indexes now come from ONE pass that `ensure_loaded()` runs, so no worker ever finds it cold, and the build fills locals and publishes them before flipping the flag. | HIGH | `test_the_printing_index_is_built_before_a_worker_thread_can_ask` |
| Text changes (CR 613 layer 3) | A `land_type` text change **replaced the whole live mana-ability list** with a single ability for the new type. A land has one intrinsic mana ability per basic land type it carries (CR 305.6), so Magical Hack on a **Tundra** (`island` → `swamp`) left a permanent whose type line still read Plains Swamp but which tapped only for {B}. Rewriting a type onto one the land already had also duplicated the subtype. | HIGH | `test_hacking_one_half_of_a_dual_land_keeps_the_other_half`, `..._does_not_double_it` |
| Combat / CR 708.2 | `cant_be_blocked_by`, `cant_block_power_ge` and `cant_be_blocked_by_power_ge` were the last combat characteristics with **no live mirror**, so `CombatState.block_illegality` read them off the printed `CardData` (CONTRIBUTING.md rule 5). A **Juggernaut** put onto the battlefield face down by Illusionary Mask — a nameless 2/2 with no abilities — still refused a Wall block; a masked Ironclaw Orcs still refused to block, a masked Amrou Kithkin still refused big blockers. Three `cur_*` fields, reset from print and cleared by the face-down branch. | HIGH | `test_a_masked_juggernaut_can_be_blocked_by_a_wall` (+2) |
| Battle setup (`game/setup_screen.gd`) | `_start_battle` loaded each deck strictly and **never looked at `deck.errors`**. A deck deleted between the scan and Go!, or `<random deck>` with an empty playable pool (which resolves to the path `""`), handed the seat `cards == []` and started the duel with an **empty library**. Neither existing gate catches it: `ProxyCard.refusal_for([], [])` is `""` and no format has a minimum deck size. | HIGH | `test_go_refuses_a_deck_the_parser_could_not_read`, `test_go_refuses_a_seat_with_no_deck_file_at_all` |
| Duel screen arrows / markers / flights | `TargetArrows._collect` walks the whole screen, and `_close_graveyard` closes the overlay by setting `visible = false` rather than emptying it — so every MiniCard the view built stayed parented, at its last laid-out rect, for the rest of the duel. A graveyard card has no board widget, so the hidden one was the **only** match for its id and won the lookup: the next Raise Dead or Animate Dead drew an amber arrow into empty board. `_target_anchor`'s own doc promised a graveyard card "is skipped rather than drawn to nowhere". Guard added to all three copies of the scan (`target_arrows`, `damage_marker_layer`, `spell_flight`). | HIGH | `test_a_closed_graveyard_view_is_not_an_arrow_anchor` |
| Deck Lab statistics | A **draw** (CR 104.4b, both duelists losing at once) leaves `winner` at −1, and the game record carried only `a_won` — so `SimStats` read "not a_won" as "B won" and scored every draw as a win for deck B, and fed it to the Elo ledger as one. `SimStats`' own class doc promised draws were "counted and excluded from winrate denominators, never silently mixed into either side". **Measured**: 1 draw in 600 games across all ten shipped-gauntlet pairings, and **2 in 120** for Mountain Artillery vs Big Green alone (seed 1000, `--jobs 4`) — Orcish Artillery's 3 damage to its own controller is the common way both seats reach 0 at once. In that run the fix moves the reported score from 46&ndash;74 to **46&ndash;72** and keeps two phantom losses out of the Elo ledger. The record now carries `drawn`; draws leave every winrate denominator, the play/draw splits included. | MEDIUM | `test_a_drawn_game_is_not_a_win_for_deck_b`, `test_every_game_record_says_whether_it_was_drawn` |
| Continuous effects (1997 fork) | The "a tapped artifact's continuous effects cease — artifact **creatures** excepted" pass (manual p.124) ran **before** the animation registry was applied, so it judged every permanent on its pass-1 types. Its own comment claimed the opposite ("an animated artifact (Jade Statue) is exempt while it is a creature"), which is how it survived. A Cursed Rack animated by Xenic Poltergeist was suspended anyway. | MEDIUM | `test_an_animated_tapped_artifact_keeps_its_static` |
| Help screen | `_rebuild` called `queue_free()` on the old page's blocks **without detaching them**, so for that frame the VBox held both pages at double height — and `scroll_vertical = 0` was applied against that. Every other rebuild in the tree detaches first. | MEDIUM | `test_a_page_turn_leaves_only_the_new_pages_blocks` |
| Hand window drag | `DRAG_SLOP` gated the `_drag_moved` **flag** but not the movement: `global_position` was rewritten on every motion event. The 1–2px a mouse travels under the finger during a click nudged the window, and the release branch — seeing `_drag_moved == false` — then folded the hand and skipped saving the corner. The window drifted on every header click and snapped back next duel. | MEDIUM | `test_a_wobble_inside_the_slop_does_not_move_the_window` |
| Battle setup | The AI difficulty picker was **connected to nothing**, so the seat name froze at whatever skill was current when the mode was applied. `_start_battle` copies that text into `DuelConfig.player_names` and the field is `editable = false` for an AI seat: choosing Apprentice gave an Apprentice pilot labelled "AI Wizard" for the whole duel, uncorrectably. | MEDIUM | `test_the_ai_seats_name_follows_the_difficulty_it_is_given` |
| `MiniCard` face-down | `refresh()`'s face-down branch hid the name, art, P/T, badges and every state overlay — but not `_stripes`, so a widget FLIPPED face down kept its mana slashes, the one thing a card back exists to withhold. And `disabled = true` was never undone, so a widget turned face up again stayed unclickable. Latent (nothing in the duel sets `MiniCard.face_down` today) but on a public property the class doc advertises. | LOW | `test_flipping_a_card_face_down_hides_its_mana_stripes`, `test_a_card_flipped_back_face_up_is_clickable_again` |
| `DeckGroups.declared_in` | `USER` is documented as "DERIVED, never declared — a file cannot claim it", but `declared_in` walks `ORDER`, which contains `USER` because `ORDER` is the DISPLAY order. A shipped `decks/*.deck` could type `# group: User-created` into itself and be filed under the player's own heading. | LOW | `test_a_shipped_deck_cannot_declare_itself_user_created` |
| `CardInstance.has_lethal_damage` | Read `data.is_creature()` — the printed type — so an animated Mishra's Factory on lethal damage answered `false`. A CONTRIBUTING.md rule-5 violation on a public method with no callers: a trap for the next one rather than a live bug. | LOW | `test_has_lethal_damage_reads_the_live_type` |
| Doc rot (`engine/random_effects.gd`) | `distribute()` promised "random **positive** parts" while every point is rolled independently and a bucket can end at 0; `creature_type_of()` scans the graveyard without saying so, and the card it cites says "in target opponent's **deck**", which makes the pile list a rules question. Both docs corrected in place. | LOW | (comment-only) |
| Test infrastructure | 63 orphan `Window`s per run — see the section above. | LOW | 0 orphans in the run summary |

### Output-format note for the Deck Lab

`tools/simulate.gd`'s determinism check compares `report.txt`, `results.json`
and `matchups.csv` byte for byte, so the draw fix follows the file's own
existing rule (the `"field"` key's comment): the draw count appears in
`report.txt` and `results.json` **only when there is one**, and
`matchups.csv` keeps its columns — a draw count there is
`games - a_wins - b_wins - stalled`. A draw-free run therefore still writes
byte-identical files, and **no default moved**.

## Findings — reported, not fixed (another session owns the file)

| File | Issue | Severity |
|---|---|---|
| `engine/core/card_instance.gd` → `engine/effects/` authors | The `"mana_color"` text change (Quarum Trench Gnomes) rebuilds the ability with a bare `ManaAbility.new(now, …)`, dropping every rider the original carried: `cost`, `taps_source`, `sacrifice_source`, `restriction_key`, `life_cost`, `side_effect`, `dynamic_amount`, `color_options`, the counter costs. It also forces `produces[0]` to the new colour even when that pair did not match. Latent — no card in the pool carries a rider on a `{W}` source — so this is an invariant a future card author can violate with no warning. | MEDIUM (latent) |
| `engine/mtg_game.gd:703` | The layer-6 silencing pass (`continuous.gd`) walks `battlefield_with_type_statics()`, and that index is populated only by `if st.changes_types`. A static tagged `.silencing_abilities()` **without** `.changing_types()` would therefore never run first — it would fall through to the last general pass and apply after everything it was meant to silence. Only Titania's Song uses the flag and it happens to tag both, so nothing is broken today; the index, not the flag, is what makes it work. | MEDIUM (latent) |
| `engine/core/mana_pool.gd:158` | `pay`'s generic loop is bounded only by `assert(best != -1)`. Godot compiles `assert()` out of release exports, and `_take(-1, …)` spends nothing and returns `due` unchanged — so a caller that skipped `can_pay` turns a debug crash into a **release hang**. A `break` on `best == -1` costs one line. Not fixed because it cannot be given a failing test: the assert fires first in every build the suite runs. | MEDIUM |
| `game/duel/damage_marker_layer.gd:133` | `if anchor is Control and is_instance_valid(anchor)` tests validity **after** the typed test, on values that are routinely freed — reached every frame from `_process`, and the same object is used as a `Dictionary` key. `target_arrows.gd:287` states the rule explicitly and orders it correctly. Not fixed: a freed-object read cannot be made to fail deterministically in a debug build, so any "fix" would ship untested. | MEDIUM |
| `game/options_screen.gd:71` | Every slider tick rewrites `user://settings.cfg` (`Settings.set_value` saves unconditionally, `Range.value_changed` fires per step): dragging AI pace 0.1 → 1.5 at 0.05 is 28 file writes. The class doc justifies the unconditional save with "options are rare writes"; a drag is not one. | MEDIUM |
| `game/duel/duel_screen.gd:1886` | `Input.set_custom_mouse_cursor` is process-global and nothing resets it on teardown: begin targeting, right-click away, Concede → Yes, and the crosshair survives the freed screen for the rest of the session. | MEDIUM |
| `game/duel/duel_screen.gd:3303` | `_is_human(-1)` is `true` (`not _ais.has(pid)`), so a `damage_assignment_request()` missing its `assigner` key puts the screen into `Mode.DAMAGE` for a seat that does not exist. | LOW |
| `game/setup_screen.gd:678` | Go! has no re-entrancy guard: `queue_free()` defers, so a second press in the same frame builds a second screen under `root` and orphans the first, still processing. | LOW |
| `game/duel/human_agent.gd:231` | `_take()` calls `mark_answered_by_player()` and pops the entry **before** the staleness test runs, so a discarded stale pick still counts as "answered by the player" in `unanswered_choices` — the bookkeeping the class doc exists for. Same shape at `:165`. | LOW |
| `engine/core/target.gd:492` vs `:562` | The same condition (`cur_cant_be_spell_target` with a source on the stack or in hand) returns `WHY["abilities"]` on the `SPELL_OR_PERMANENT` path and `WHY["spell"]` on the permanent path. `WHY` is documented as the 1997 diagnostic priority table, and #14 is the entry for exactly this state, so the first is wrong. Reachable only by forcing a target the spec would not offer. | LOW |
| `engine/continuous.gd:275` | The granted-ability dedupe keys on `ActivatedAbility.text`, which defaults to `""` and is not required. Two different granted abilities with empty text on one permanent silently collapse into one. | LOW |
| `game/duel/mana_icons.gd:63` | A PCRE2 `RegEx` is compiled per call, and `cost_row` is called per permanent per board refresh and on every hover. Belongs in a `static var` beside `_atlas_cache`. **Not measured** — reported as a candidate, not as a regression. | LOW |
| `game/duel/original_dialog.gd:212` | An uncached per-pixel image walk; `combat_bar.gd:224` does the identical keying and caches it with the comment "must not run per frame". **Not measured.** | LOW |

### Checked and found clean

`tools/simulate.gd`'s threading contract holds: `_run_one_game` reads only
`_tasks[index]` and the immutable `_duel_opts`, and writes only
`_results[index]`; every deck is loaded and validated on the main thread
before `add_group_task`. The only shared mutable state a worker could touch
was `CardRegistry`'s lazy indexes, which is the HIGH row above.

**Determinism (rule 7) is clean.** No `randi()`/`randf()`/`randomize()`/
`Array.shuffle()` in `engine/`, `cards/` or `tools/` outside `MtgGame.rng`.
The four `randi()` calls in `game/` are seed *generation* for a new duel
(`setup_screen._resolve_seed`, `duel_screen`, `match_screen`), which is the
one place a fresh number is the point.

`game/duel/duel_options.gd`'s `ground_key` has an `if` that never fires — but
that is the documented forward hook for the two territory art styles whose
only surviving copies are Manalink `.bmp`s (`Provenance.md`'s rule). Behaviour
is correct; not a finding.

`EloLedger`'s Bresenham interleave, `SimStats.wilson_interval`,
`DeckList`'s two parsers, `DeckFormat.legal`, and `CardRegistry`'s printing
order (Mountain resolves to 2ed, not Arabian Nights) were all read and are
correct.

### One housekeeping note

`tools/_audit_dump.gd` and `tools/_audit_specs.gd` are undocumented scratch
from the 2026-09 audit — CONTRIBUTING.md's rule is that a probe gets deleted when
the question it answered is answered. They were left in place rather than
removed because another session may be running them right now.

## A note on running the suite while other sessions edit

One full run during this pass reported a single failure,
`test_ydwen_efreet_may_fizzle_its_own_block`. It passes in isolation, and
`cards/sets/arn/ydwen_efreet.gd` and `tests/cards/test_pool_wave38.gd` were
both written by another session **while that run was executing**. A red run
whose only failure sits in a file whose mtime is inside the run window is a
torn read, not a regression — but it is worth saying out loud, because the
next reader will find the same thing in a log and reach for a bisect that
does not exist.
