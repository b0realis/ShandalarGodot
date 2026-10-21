# Whole-project review — 2026-10-21

The owner, on 0.50.41: a review of the whole project as it stands, not of a
diff. Then, on the ranked list: *"All! engine-3:as separate phases!
Document each fix"*.

Five read-only reviewers took one area each — the rules engine, the cards
and packs, the computer opponent and Deck Lab, the duel screen and menus,
and the network, saves and tools (the new Android and offline-Web code
included). A skeptic per area then tried to refute every finding, re-running
the reviewer's probe or writing its own. **27 findings, 25 real (5 medium,
20 low), 2 refuted**: Man-o'-War held for an Aluren with no green source is
the pinned design (`test_the_card_a_loop_casts_is_held_for_it`), and Options
› Card back › Remove deleting a picture put there by hand is what it is for
(`test_card_back.gd`). Four fixers then worked on disjoint files, each
turning its findings into tests that failed before the fix.

What held: 300 seeded AI-against-AI duels with 156 decks under all three
rule presets broke no game invariant; the mana planner paid exactly on 600
random boards (one wasted mana, below); random-player, held-question and
search-journal fuzzing came back clean apart from Gem Bazaar (engine-4).

New regression scripts (10 GUT, plus new Python cases) are listed in
`docs/CODE_MAP.md` under "The whole-project review (2026-10-21)".

## The rules engine

### engine-1 — a target that left play and came back (medium)

**Was.** A spell or an activated ability whose target left the battlefield
and came back still hit it, though the card that came back is a new object
(CR 400.7). The AI's own Aluren loop made it real: Terror at a Shrieking
Drake, the Drake bounced and recast through Aluren in response, and Terror
destroyed the NEW Drake. A Lightning Bolt or a Prodigal Sorcerer ping killed
a creature that had blinked; Holy Strength attached to one. A card keeps its
instance id across zones, and only triggers recorded which incarnation they
aimed at.

**Fix.** `StackItem.target_incarnations` records the incarnation of every
card a spell or ability targets as it goes on the stack
(`MtgGame._pin_target_incarnations`), with the same reading triggers use.
A redirection records its new target (`_pin_new_target`, from
`retarget_spell`, `retarget_stack_item`, `offer_new_targets`); a copy that
keeps the original's targets keeps its record; Ertai's Meddling prefers the
record taken at cast. Every resolution check asks `_target_still_chosen` —
`_all_targets_illegal`, the fizzle loop in `_resolve_spell` and the
per-target filter in `_run_effects_impl`. The record is journaled, and
snapshots copy it. `docs/mechanics.md` (Fizzling, Partial illegality).

**Tests.** `tests/unit/test_review_2026_10_21_engine_stale_targets.gd` (12):
Bolt, Aura, a graveyard card, a two-target Fireball, both redirections, a
copy, a Sorcerer ping, an AI search that blinks and unmakes, the real
Aluren + Drake + Terror line, and two that must still hit (a control
change, a ping at a creature that stayed).

**Left.** A card script that reads `current_targets()` by hand for an
untargeted rider still sees the raw list. A card countered and recast while
targeted on the stack counts as the same object (rare).

### engine-2 — a spell cast from the opponent's library

**Was.** A card cast with Grinning Totem stayed its owner's while it was a
spell: "target opponent" meant its own caster (Mana Clash could be aimed at
the caster, not at the opponent), and Reflect Damage and Eye for an Eye
answered the owner.

**Fix.** `cast_spell` makes the caster the card's controller as it goes on
the stack (journaled), and the target checks before that see the caster
too (`_propose_caster` / `_withdraw_caster` in `_cast_checks`, the adverse
and random target fills, and the helpers the duel screen, SGManalink and the
AI ask: `target_legal_at`, `legal_targets_at`, `target_refusal_at`). The
card goes back to its owner whenever it leaves the stack other than onto the
battlefield (`_spell_goes_home`). The fizzle check judges from the spell's
controller. `docs/mechanics.md` ("A spell's controller").

**Tests.** `tests/unit/test_review_2026_10_21_engine_spell_controller.gd`
(12), among them the real Grinning Totem + Mana Clash line, Reflect Damage,
Eye for an Eye, going home after resolving, a counter and a fizzle, and a
search that unmakes.

**Left.** Under the 1997 damage-prevention window, a stolen spell's damage
waits until after the card has gone home, so Reflect Damage used in that
window still names the owner (Fifth Edition rules, a human seat and Grinning
Totem together).

### engine-3 — the 1997 upkeep and draw are phases of their own (ruling)

**Was.** Under the 1997 rules the mana pool empties and life is checked at
the end of each PHASE, but the engine used the modern phase map, which
makes untap, upkeep and draw ONE beginning phase. Mana floated in the
upkeep survived unburned into the draw step, and a player at −2 after the
upkeep was not checked until the draw ended. The manual names six phases
(p.60, `docs/glossary-1997.md` §3): Untap, Upkeep, Draw, Main, Discard,
Cleanup. The owner: *"as separate phases!"*

**Fix.** `Mtg.Phase1997` and `Mtg.phase_of_1997` — untap, upkeep and draw a
phase each, main in its three parts with combat one of them, end step and
cleanup one — and `MtgGame._phase_ends_now` reads it. Only the two 1997
forks read that function, so the modern presets are unchanged. The Options
text of "1997 mana-pool timing" says so, and Help's mana page.

**Tests.** `tests/unit/test_review_2026_10_21_engine_fifth_phases.gd` (8):
burn at the end of the upkeep and of the draw, life lost in the upkeep,
life regained in time, combat still one phase, both modern presets
unchanged, the map itself. The test that pinned the old reading in
`tests/unit/test_fifth_edition.gd` is now
`test_the_1997_upkeep_is_a_phase_and_burns_as_it_ends`, with the ruling.

### engine-4 — Gem Bazaar changed colour after the computer thought

**Was.** A mana ability's side effect was not journaled. When an AI search
tapped Gem Bazaar and undid it, the tap and the random stream came back but
the Bazaar's new colour stayed: the real Bazaar then showed, and made, a
different colour without having been tapped.

**Fix.** `MtgGame._rec_mana_side_effect`, called from `tap_for_mana` before
any mana-ability side effect runs, records the source card whole and the
per-turn tables, as a resolving spell's are — only during a search. A
general fix, not a patch on the card: a sweep over the 30 or so side-effect
mana abilities found only Gem Bazaar drifting, and none can now.

**Tests.** `tests/unit/test_review_2026_10_21_engine_mana_side_effects.gd`
(4), the sweep among them.

### engine-5 — an instant on the table in Test hands

**Was.** Test hands put an instant or a sorcery "On the table" as a
permanent, for the whole duel, where "destroy target permanent" could see
it.

**Fix.** The picker offers only permanents for the table
(`TestHandsScreen._fill_picker`, through `DuelPosition.fits_on_table`);
`DuelPosition.refusal` names any non-permanent a saved or hand-edited test
puts there — *"Seat 1 puts Lightning Bolt on the table, but an instant or a
sorcery is never a permanent. Put it in the hand, the graveyard or on top of
the library."* — and `MtgGame._place_from_position` never places one even if
asked (it stays in the library, CR 304.4). Help's Test hands page.

**Tests.** `tests/unit/test_review_2026_10_21_engine_test_position.gd` (6),
`tests/ui/test_review_2026_10_21_table_picker.gd` (3).

## The computer opponent

### ai-1 — a combo's mana for cards it was not going to cast (medium)

**Was.** CARD-COMBOS sized its "mana for the hand" loop by the mana value of
every card in hand — Counterspells held for a response, a Serra Angel with
no white source, cards the cast gates refuse — and the mana burned: 6 life
in a probe, 3 twice in one Deck Lab game.

**Fix.** `CardCombos._mana_for_the_hand` counts only what the main-phase
ranking would really cast now (`_hand_casts`: past the same gates,
`AiPlayer._ranking_gates_refuse`, worth casting, coloured costs payable
from our own lands). Under mana burn the loop never makes more colourless
than those cards' generic costs use, its opening mana included, and keeps
the lands their colours need out of the opening. Without mana burn it still
makes mana for the whole countable hand. The same Deck Lab lab (Power
Artifact against The Deck, 12 games) went from 5 such loops and 2 burns to
none. `docs/ai-difficulty.md`.

**Tests.** In `tests/ai/test_review_2026_10_21_ai_pilot.gd`: held
Counterspells, a colour with no source, never past what the hand spends;
controls that must still pay for the hand.

**Left.** `_ranking_gates_refuse` repeats the gate list of `_try_cast_best`;
X spells are not counted (the lethal-X step is apart).

### ai-2 — small creatures held from an unfed Goblin Bombardment (medium)

**Was.** The Wizard's cast veto counted Goblin Bombardment and Orcish
Mechanics as free removal even when their controller had nothing to
sacrifice, and held every small creature: Soul Warden from turn 5 to
turn 21 in one Lab game.

**Fix.** `AiPlayer._answered_on_arrival` passes over every ability whose
cost is more than mana — sacrificing another permanent, exiling,
discarding, removing counters, other object costs — as its own comment
always said ("fewer vetoes, never more") and as `_cheapest_pump_of` does.

**Tests.** An unfed Bombardment and Savannah Lions, unfed Mechanics and
Grizzly Bears; a mana pinger still answers a 1-toughness body.

### ai-3 — Shrieking Drake cast to return itself

**Was.** Every AI level cast Shrieking Drake only for it to return itself,
once per blue source each turn.

**Fix.** `_try_cast_best` asks `_returns_itself`: the Drake is cast when a
creature of ours is worth returning (`_rebuy_pick` — one whose arrival hits
something of theirs again, like a Man-o'-War with a creature to bounce, or a
liability) or when our table pays out on each arrival (`_arrival_paid_out`:
Soul Warden, Pandemonium — the Aluren loops), and `answer_card` then returns
that creature. Otherwise it keeps the Drake.

**Tests.** A lone Drake on all four levels with combos on and off, a Drake
beside a plain creature, the Drake returning a Man-o'-War; the Pandemonium
and Aluren loops still run. `tests/unit/test_loop_limit.gd` reaches the
limit with a Soul Warden on the table now, since the pointless self-return
loop it used is gone.

### ai-4 — Mana Drain's payout burned

**Was.** The Wizard drained a harmless 6-mana Book of Rass and lost 6 life
to mana burn at its next main phase.

**Fix.** Under the mana-burn rules `_try_counter` prices the payout
(`_payout_burns`, `_payout_spend`): the colourless the hand cannot spend
next turn is added, as life at `_burn_price`'s rate, to what the countered
spell must be worth (`_counter_clears_bar`'s new optional parameter). Spells
it always counters are still drained; a burn that would kill it never is.

**Tests.** A harmless six-drop is not drained into six burn; a real threat
is; without mana burn the payout is free; a payout the hand spends is no
burn.

**Left.** Next turn's spending is guessed from the hand alone.

### ai-5 — a second copy of a combo piece counted as progress

**Was.** A second Power Artifact was rated as completing the loop and aimed
at the Monolith that already wore one, even beside a bare Monolith; a second
Ashnod's Altar was "progress".

**Fix.** `CardCombos.spell_choice` passes over a non-Aura piece whose slot
is already on our table, and `_aura_host` over a host already wearing that
Aura (`_wears`).

**Tests.** Four, among them the second Power Artifact going on the bare
Monolith.

## The duel screen and the settings

### ui-1 — leaving a Gauntlet or match duel threw the run away (medium)

**Was.** In a Gauntlet round, or any duel of a best-of match, the opening
screen's "Reconfigure duel" and Pause › Exit duel went straight to Magic
Battle without a word. A Gauntlet run (up to twenty opponents, never saved)
or a match record was gone.

**Fix.** A duel can be held by another screen
(`DuelScreen.leave_title`, `leave_question`, `leave_label`,
`leave_confirmed`): a held duel asks, in the Concede question's window and
words (`_ask_to_leave`, Cancel focused), and never changes scene itself.
- **Gauntlet:** the opening screen's button reads "Quit Gauntlet"; it and
  Exit duel ask *"Quit the gauntlet? Your run ends here, in round N, and you
  go back to Gauntlet Options."* Yes ends the run and brings back Gauntlet
  Options with the run's settings, as the 1997 game ended every run
  (`GauntletScreen._quit_from_duel`); a new run takes a new, logged seed.
- **A best-of match from Magic Battle:** the button still reads
  "Reconfigure duel"; both doors ask *"Quit this match? Its record so far is
  lost, and you go back to Magic Battle."*
- Pressing the button stops the opening screen's countdown; Esc cancels; the
  question closes if the duel ends. Plain duels and Test hands are as they
  were. `docs/gauntlet-design.md` §13, Help's matches page.

**Tests.** `tests/ui/test_review_2026_10_21_leaving_a_held_duel.gd` (10; 12 with the rulings below).

**The owner's rulings, the same day (0.50.43).** Pause › Return to main
menu asks too — *"Yes."* (`DuelScreen.menu_question`, `menu_confirmed`; a
match's own words: *"Quit this match? Its record so far is lost, and you go
back to the main menu."*) — and *"Quit gauntlet goes to title, quit duel
goes to title."*: every door out of a Gauntlet duel now ends the run at the
title, as the round window's own Quit Gauntlet always did, not at Gauntlet
Options.

### ui-2, ui-3, ui-4 — hand-edited settings of the wrong kind

**Was.** `docs/player-files.md` promises that a value of the wrong kind
"reads as meant where it can … and as the default where it cannot". Three
readers broke it with script errors: a number in `enabled_card_packs`
switched every pack off; a number for a name in `test_hands_saved` stopped
the Saved tests list; `"yes"` in `deck_builder_extras` or a number in
`sealed_sets` broke the Deck Builder, which then wrote all-on over the
player's switches.

**Fix.** Each reads through `Settings.coerce`: `Settings.enabled_card_packs`
skips what is not text; `TestHandsScreen.saved_tests` reads a number name
as its digits and drops other kinds (the next Save or Delete writes text);
`DeckBuilderScreen._restore_extras` reads yes/no/on/off/true/false/1/0 as
meant and anything else as on, and `_sealed_sets` skips what is not text.

**Tests.** `tests/ui/test_review_2026_10_21_wrong_kinds.gd` (8).

### cards-1 — "manifest mismatch" where a version was meant

**Was.** Packs 2–9 compared a zip's manifest key by key with the trusted
one BEFORE asking about versions, so their "requires game version" refusal
could never be reached: a pack built for a newer game, or another build of
the same pack, was refused as "Pack N manifest mismatch: version" (or
"…: minimum_game_version"). A version written as a number was a script
error in all eight.

**Fix.** Two helpers in `game/portal_pack.gd` that all eight contracts call:
`version_refusal` asks first, as Pack 1 does — *"requires game version X or
newer (this is Y)"*, or *"this is Pack N version V, and this game needs
version W: rebuild Pack-….zip with this release's tools/pack_N_….py"* — and
`manifest_mismatch` compares the rest, kinds first. The refusal itself is
unchanged. `docs/adding-card-packs.md`.

**Tests.** `tests/unit/test_review_2026_10_21_pack_versions.gd` (6), each
over all eight packs.

## Saves, packages and tools

### nettools-1 — the Android guide's way to add card packs (medium)

**Was.** `ANDROID.md` (`docs/android-experimental.md`) said finished card
packs are imported through the game's chooser; that chooser (Options ›
Skin) takes skins only and refuses every numbered pack.

**Fix.** The guide says what the chooser takes (a skin or `cardart.zip`)
and gives the way that works today: start the game once so it makes
`Android/data/com.b0realis.shandalar.android/files/cardpacks/`, copy the
pack there with adb (into Download, then `cp`), and Rescan. An in-game way
to add a pack would be a new button — the owner's pick, from mockups.

**Tests.** `tools/test_build_android.py`,
`test_the_guide_sends_numbered_packs_to_the_card_folder`.

**Then (0.50.43).** The owner picked the in-game way from three mockups —
*"Yes A is the leanest"*: **Options › Card Packs › Add pack...**, beside Open
Folder and Rescan (`CardPacks.add_pack`; `tests/ui/test_card_packs_add_pack.gd`).
The guide now gives it first and keeps adb for a device whose file box
cannot reach Downloads (not yet tried on a real device).

### nettools-2 — the Web README promised LAN play

**Was.** Every package's README said "LAN SGManalink are included". The
browser build cannot host or join a table (a web page may not open the TCP
and UDP sockets LAN play uses; its Host and Find buttons are off).

**Fix.** `tools/package_release.py` (`PLAY`, `WEB_PLAY`): the two Web
READMEs say LAN play needs an installed build;
`tools/package_web_offline.py` drops the old line from a 0.50.41-or-older
Web ZIP it wraps; `docs/setup-web.txt` says the same.

**Tests.** `test_the_web_readmes_say_the_browser_has_no_lan_play`,
`test_an_older_web_readme_loses_its_lan_promise`.

### nettools-3 — the offline packer took a threaded export

**Was.** `package_web_offline.py` refused a threaded export by markers Godot
4.7 no longer writes, so `--refresh` gave a real threaded export a service
worker.

**Fix.** `THREADED_PAGE` (`GODOT_THREADS_ENABLED = true`, `threads: true`,
`"threads": true`) and `THREADED_ENGINE` (Emscripten's `PThread` in the
engine script, or an `index.worker.js`), checked against the local 4.7
templates: both threaded ones match, both single-threaded ones do not.

**Tests.** `test_threaded_input_refused` (rewritten for the real 4.7 page
and engine), `test_the_single_threaded_47_page_is_accepted`.

### nettools-4 — the service worker's test ran nowhere

**Was.** `tools/test_web_offline.cjs`, the one test of the offline cache
(updates that wait, corrupt updates refused, eviction repaired), ran neither
in CI nor in the release recipe.

**Fix.** A `web-offline` job in `.github/workflows/gate.yml` (Node 24.21.0,
Playwright 1.63.0, Chromium only; `--channel chromium`, a new option of the
test); "The offline Web package" in `docs/release-builds.md`, building both
offline ZIPs and running the test against one; the test named in
`DEVELOPMENT.md`.

**Left.** The job has not run yet: Playwright is not installed on the desk
the fixes were made on. Its first CI run is its test.

### nettools-5 — the privacy check knew only one home folder

**Was.** `tools/test_tracked_tree.py` looked for the current machine's own
home folder only, and skipped every binary file — a path in a picture's
metadata, or another machine's login, passed.

**Fix.** Any user's home in any spelling (`/home/<name>`, `/Users/<name>`,
`C:\Users\<name>`, doubled and JSON-escaped backslashes), with a short
allow-list of the placeholders the docs use, each with its reason; every
tracked file is read, binaries included (UTF-16 text such as a font's name
table, PNG text chunks, an editor's hex EXIF block). The current tree is
clean. `CONTRIBUTING.md`.

**Tests.** `AnyonesHomeTest` (5) in the same file.

### nettools-6 — choosing a new skin or card back could break the old one

**Was.** Options › Skin › Choose (and a card-art zip) and Options › Card
back › Choose wrote over the kept file in place: a full disk or a crash
part-way left a broken file where the working one was.

**Fix.** `SkinPack.copy_whole` writes the copy beside the kept zip, checks
it, and renames it into place (on Windows, where a mounted zip stays open,
a refused rename falls back to the old copy); `SkinPack._take` no longer
deletes the kept zip before its rename; `CardBack.adopt_bytes` goes through
`Settings.write_atomically`. `docs/player-files.md`.

**Tests.** `tests/unit/test_review_2026_10_21_atomic_adopt.gd` (5).

## Found on the way

- **The Options test that took the wrong list.**
  `tests/ui/test_c2_f_sac_rules_option.gd` found the rules preset list as the
  first four-row dropdown on Options; 0.50.40's Situation Bar frame list has
  four rows too. It now also checks the Custom row, as
  `test_options_rules.gd` already did.

- **The privacy check refused itself on CI (0.50.43).** The first CI run of
  0.50.42 failed one test: `tools/test_tracked_tree.py` wrote the CI
  runner's home out whole (two comments and an allow-list case), and on CI
  that path IS the machine's home, which the release guard refuses in every
  file. The file now never spells it whole; the test passes with HOME set to
  the runner's and to the desk's. The new `web-offline` job passed on its
  first run.

## Left open

- Seen by the reviewers but not taken up: a pasted deck list has no limit on
  its total size; the MCP server's read-deck tools read any path (the write
  tools are fenced); ante cards still work with Ante off; Fireball divides X
  among the targets still legal on resolution; Test hands' Clear all resets
  lives to the last test's, not the starting ones; deck notes lose blank
  lines; the duel log is trimmed in place; the mana planner floats one extra
  mana with Plateau + Volcanic Island + Black Lotus for {W}{R}{R}.

## Verification

Targeted, after all four fixers had finished (the owner's test-scope
policy), in three chains of `./run_tests.sh -gselect=…`, every one exit 0
with no `ERROR:` line:

- Rules: the 11 new review scripts (95 tests), `test_c2_f` (63 scripts,
  510), `test_fifth_edition`, `test_loop_limit`, `test_target`,
  `test_turn_and_stack`, `test_undo_log`, `test_mana_burn`,
  `test_fidelity_2026_09` (379), `test_campaign_fix` (423),
  `test_bug_pass_2026_10_03` (114), `test_damage`, `test_delayed_triggers`,
  `test_exile_audit`, `test_engine_sweep`, `test_2ed_cards`,
  `test_original_pool`, `test_pool_wave` (74 scripts, 1,254),
  `test_player_protection`, `test_simplified_ledger`.
- AI and cards: `test_ai_` (129 scripts, 1,702), `test_card_combos`,
  `test_mirage_bugpass_cards`, `test_cost_choice_contract`, `test_pack_`
  (180 scripts, 3,630).
- Screens and LAN: `test_duel_` (219), `test_gauntlet` (89),
  `test_match_screen`, `test_test_hands`, `test_deck_builder` (235),
  `test_options_`, `test_original_dialog`, `test_situation_bar`,
  `test_bar_frame`, `test_card_back`, `test_skin_pack`, `test_card_packs`,
  `test_help`, `test_sgmanalink` (38 scripts, 386), `test_android`.

`./duel_soak.sh` and `./duel_soak.sh --rules fifth`: exit 0, 6 duels each
(the demo and the human seat) through the live duel screen. Python:
`python3 -m unittest discover -s tools -p 'test_*.py'`, 797 tests OK (15
skipped). The version bump to 0.50.42 also moves the Android preset's
`version/code` to 50042 (`packaging/android/export-preset.cfg`,
`export_presets.cfg.example`), which `tools/build_android.py` checks.
